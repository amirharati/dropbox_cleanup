#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

require_dropbox

VERBOSE=0
ROOT_OVERRIDES=()
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Usage: scan.sh [--root <path>] [-v|--verbose]"
  echo "  --root  Only this folder (and subfolders). Repeat for multiple."
  exit 0
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--verbose) VERBOSE=1; shift ;;
    --root)
      shift
      [[ -n "${1:-}" ]] || { echo "error: --root requires a path" >&2; exit 1; }
      ROOT_OVERRIDES+=("$(expand_path "$1")")
      shift
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done
[[ ${#ROOT_OVERRIDES[@]} -gt 0 ]] && SCAN_ROOTS=("${ROOT_OVERRIDES[@]}")

require_scan_roots

STATS="$(mktemp)"
trap 'rm -f "$STATS"' EXIT

log() { echo "$*" >&2; }

collect_dir() {
  local pattern="$1" dir="$2" kb marked
  kb=$(du -sk "$dir" 2>/dev/null | cut -f1) || return 0
  marked=0
  is_ignored "$dir" && marked=1
  echo "$pattern $kb $marked $dir" >> "$STATS"
  if [[ "$VERBOSE" -eq 1 ]]; then
    local tag=""
    [[ "$marked" -eq 1 ]] && tag=" [ignored]"
    printf "%8s MB  %s%s\n" "$((kb / 1024))" "$dir" "$tag"
  fi
}

scan_one_root() {
  local root="$1"
  log "Scanning: $root"

  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    log "  pattern: $name …"
    while IFS= read -r dir; do
      collect_dir "$name" "$dir"
    done < <(find "$root" -type d -name "$name" -prune 2>/dev/null)
  done < <(read_dir_patterns)
}

echo "Dropbox root: $DROPBOX_ROOT"
echo "Config: $CONFIG_FILE (+ config.local if present)"
echo "Scan roots: ${SCAN_ROOTS[*]}"
echo ""

for root in "${SCAN_ROOTS[@]}"; do
  scan_one_root "$root"
done

while IFS= read -r abs; do
  [[ -z "$abs" ]] && continue
  dir=$(resolve_under_dropbox "$abs")
  [[ -d "$dir" ]] || continue
  log "  extra path: $dir"
  collect_dir "@extra" "$dir"
done < <(read_absolute_paths)

if [[ ! -s "$STATS" ]]; then
  echo "No matching directories found."
  exit 0
fi

echo "=== By pattern ==="
awk '{
  pat[$1]+=$2; cnt[$1]++; if ($3) ign[$1]++
}
END {
  for (k in pat)
    printf "%.0f\t  %-24s %4d dirs  %8.1f GB  — %d already ignored\n",
      pat[k], k, cnt[k], pat[k]/1024/1024, ign[k]+0
}' "$STATS" | sort -t$'\t' -k1 -nr | cut -f2-

echo ""
echo "=== By scan root ==="
for root in "${SCAN_ROOTS[@]}"; do
  line=$(awk -v p="$root" '$4 ~ "^" p { kb+=$2; n++; if ($3) ig++ }
    END {
      if (n) printf "%d\t%.0f\t%d", n, kb, ig+0
      else print "0\t0\t0"
    }' "$STATS")
  n=$(echo "$line" | cut -f1)
  kb=$(echo "$line" | cut -f2)
  ig=$(echo "$line" | cut -f3)
  gb=$(awk "BEGIN { printf \"%.1f\", $kb/1024/1024 }")
  echo "  $root"
  if [[ "$n" -eq 0 ]]; then
    echo "    (no matches)"
  else
    printf "    %4d dirs  %8s GB  — %d already ignored\n" "$n" "$gb" "$ig"
  fi
done

echo ""
echo "=== Totals ==="
awk '{ kb+=$2; n++; if ($3) ig++ }
END { printf "  %d directories  ~%.1f GB  — %d already ignored\n", n, kb/1024/1024, ig+0 }' "$STATS"

echo ""
echo "=== Top ${SCAN_TOP} largest ==="
sort -t' ' -k2 -nr "$STATS" | head -n "$SCAN_TOP" | while read -r pat kb marked dir; do
  tag=""
  [[ "$marked" == "1" ]] && tag=" [ignored]"
  printf "  %8s MB  %-16s  %s%s\n" "$((kb / 1024))" "$pat" "$dir" "$tag"
done

if [[ "$VERBOSE" -eq 0 ]]; then
  echo ""
  echo "Tip: ./dropbox-cleanup.sh scan --verbose"
fi
