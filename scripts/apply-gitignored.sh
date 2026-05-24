#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

require_macos
require_dropbox

DRY_RUN=0
ROOT_OVERRIDES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --root)
      shift
      [[ -n "${1:-}" ]] || { echo "error: --root requires a path" >&2; exit 1; }
      ROOT_OVERRIDES+=("$(expand_path "$1")")
      shift
      ;;
    -h|--help)
      echo "Usage: apply-gitignored.sh [--root <path>] [--dry-run]"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done
[[ ${#ROOT_OVERRIDES[@]} -gt 0 ]] && SCAN_ROOTS=("${ROOT_OVERRIDES[@]}")

require_scan_roots

find_git_repos() {
  local root
  for root in "${SCAN_ROOTS[@]}"; do
    find "$root" -name .git -type d 2>/dev/null
  done
}

if command -v dbx-ignore &>/dev/null; then
  echo "Using dbx-ignore (marks git-ignored paths per repo)"
  echo "Scan roots: ${SCAN_ROOTS[*]}"
  [[ "$DRY_RUN" -eq 1 ]] && {
    echo "dbx-ignore has no dry-run. Repo count:"
    find_git_repos | wc -l | xargs echo " "
    exit 0
  }
  while IFS= read -r gitdir; do
    repo=$(dirname "$gitdir")
    echo "--- $repo"
    (cd "$repo" && dbx-ignore)
  done < <(find_git_repos)
  exit 0
fi

echo "dbx-ignore not installed. Using .gitignore (top-level dirs only)."
echo "Install: ./scripts/install-dbx-ignore.sh"
echo ""

marked=0
while IFS= read -r gitdir; do
  repo=$(dirname "$gitdir")
  [[ -f "$repo/.gitignore" ]] || continue
  while IFS= read -r line; do
    line="${line%%#*}"
    line="${line// /}"
    [[ -z "$line" ]] && continue
    [[ "$line" == *"*"* ]] && continue
    line="${line%/}"
    [[ -d "$repo/$line" ]] || continue
    dir="$repo/$line"
    is_ignored "$dir" && continue
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "would ignore: $dir"
    else
      mark_ignored "$dir"
      echo "ignored: $dir"
    fi
    marked=$((marked + 1))
  done < "$repo/.gitignore"
done < <(find_git_repos)

echo ""
[[ "$DRY_RUN" -eq 1 ]] && echo "Would mark $marked paths." || echo "Marked $marked paths."
