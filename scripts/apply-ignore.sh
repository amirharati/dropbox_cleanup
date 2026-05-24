#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

require_macos
require_dropbox

DRY_RUN=0
VERBOSE=0
ROOT_OVERRIDES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -v|--verbose) VERBOSE=1; shift ;;
    --root)
      shift
      [[ -n "${1:-}" ]] || { echo "error: --root requires a path" >&2; exit 1; }
      ROOT_OVERRIDES+=("$(expand_path "$1")")
      shift
      ;;
    -h|--help)
      echo "Usage: apply-ignore.sh [--root <path>] [--dry-run] [-v|--verbose]"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done
[[ ${#ROOT_OVERRIDES[@]} -gt 0 ]] && SCAN_ROOTS=("${ROOT_OVERRIDES[@]}")

require_scan_roots

marked=0
skipped=0
# pattern -> count (bash 3: use temp file)
APPLY_STATS="$(mktemp)"
trap 'rm -f "$APPLY_STATS"' EXIT

apply_one() {
  local dir="$1" pattern="${2:-?}"
  [[ -d "$dir" ]] || return 0
  if is_ignored "$dir"; then
    skipped=$((skipped + 1))
    return 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    [[ "$VERBOSE" -eq 1 ]] && echo "would ignore: $dir"
    echo "$pattern" >> "$APPLY_STATS"
  else
    mark_ignored "$dir"
    [[ "$VERBOSE" -eq 1 ]] && echo "ignored: $dir"
    echo "$pattern" >> "$APPLY_STATS"
  fi
  marked=$((marked + 1))
}

apply_root() {
  local root="$1" name dir n
  echo "Under: $root" >&2
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    echo "  pattern: $name …" >&2
    n=0
    while IFS= read -r dir; do
      apply_one "$dir" "$name"
      n=$((n + 1))
      # Progress every 25 dirs (dry-run is quiet on stdout)
      if (( n % 25 == 0 )); then
        echo "    … $n matches so far ($name)" >&2
      fi
    done < <(find "$root" -type d -name "$name" -prune 2>/dev/null)
    echo "    done: $n dirs ($name)" >&2
  done < <(read_dir_patterns)
}

echo "Apply ignore markers" >&2
echo "Scan roots: ${SCAN_ROOTS[*]}" >&2
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "(dry-run — no xattr changes; may take 10–30+ min on full CodingProjects)" >&2
  echo "Tip: use --root <one-project> for a quick preview" >&2
else
  echo "(writes com.dropbox.ignored on each folder — Dropbox app must be running)" >&2
fi
echo "" >&2

for root in "${SCAN_ROOTS[@]}"; do
  apply_root "$root"
done

while IFS= read -r abs; do
  [[ -z "$abs" ]] && continue
  apply_one "$(resolve_under_dropbox "$abs")" "@extra"
done < <(read_absolute_paths)

echo ""
if [[ -s "$APPLY_STATS" ]]; then
  echo "=== By pattern ==="
  sort "$APPLY_STATS" | uniq -c | sort -nr | while read -r c pat; do
    printf "  %-24s %4d\n" "$pat" "$c"
  done
  echo ""
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Would mark $marked directories ($skipped already ignored)."
  [[ "$VERBOSE" -eq 0 && "$marked" -gt 0 ]] && echo "Tip: apply --dry-run --verbose  (list every path)"
else
  echo "Marked $marked directories ($skipped already ignored)."
  echo "Dropbox will remove these from the cloud; local copies remain."
fi
