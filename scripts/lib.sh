#!/usr/bin/env bash
# Shared helpers for dropbox_cleanup scripts.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RULES_SRC="${REPO_ROOT}/rules/rules.dropboxignore"
XATTR_NAME="com.dropbox.ignored"

# Config: config.local > config > env vars > defaults
CONFIG_FILE="${CONFIG_FILE:-$REPO_ROOT/config}"
DROPBOX_ROOT="${DROPBOX_ROOT:-}"
SCAN_ROOTS=()
SCAN_TOP="${SCAN_TOP:-15}"

load_config() {
  local f key val
  for f in "$CONFIG_FILE" "$REPO_ROOT/config.local"; do
    [[ -f "$f" ]] || continue
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%%#*}"
      line="${line#"${line%%[![:space:]]*}"}"
      line="${line%"${line##*[![:space:]]}"}"
      [[ -z "$line" ]] && continue
      [[ "$line" != *"="* ]] && continue
      key="${line%%=*}"
      val="${line#*=}"
      key="${key%"${key##*[![:space:]]}"}"
      val="${val#"${val%%[![:space:]]*}"}"
      case "$key" in
        dropbox_root) DROPBOX_ROOT="$(expand_path "$val")" ;;
        scan_root)    SCAN_ROOTS+=("$(expand_path "$val")") ;;
        scan_top)     SCAN_TOP="$val" ;;
      esac
    done < "$f"
  done

  [[ -z "$DROPBOX_ROOT" ]] && DROPBOX_ROOT="$(expand_path '~/Dropbox')"
  if [[ ${#SCAN_ROOTS[@]} -eq 0 ]]; then
    if [[ -n "${SCAN_ROOT:-}" ]]; then
      SCAN_ROOTS+=("$(expand_path "$SCAN_ROOT")")
    else
      SCAN_ROOTS+=("${DROPBOX_ROOT}/CodingProjects")
    fi
  fi

  RULES_DEST="${DROPBOX_ROOT}/rules.dropboxignore"
}

expand_path() {
  local p="$1"
  # Fix accidental "$HOME/~/..." (e.g. dropbox_root=/Users/you/~/Dropbox)
  p="${p//$HOME\/\~/$HOME}"
  p="${p//\/\~\//\/}"
  # Note: ${p#~/} does not work — ~ is special in bash prefix patterns.
  if [[ "$p" == "~" || "$p" == "~/"* ]]; then
    echo "${p/#\~/$HOME}"
  else
    echo "$p"
  fi
}

# Call once scripts source lib.sh
load_config

is_ignored() {
  local path="$1"
  xattr -p "$XATTR_NAME" "$path" &>/dev/null
}

mark_ignored() {
  local path="$1"
  xattr -w "$XATTR_NAME" 1 "$path"
}

unmark_ignored() {
  local path="$1"
  xattr -d "$XATTR_NAME" "$path" 2>/dev/null || true
}

# Basename-only folder rules (e.g. node_modules/). Excludes /CodingProjects/... paths.
read_dir_patterns() {
  grep -E '^[^#[:space:]/][^/]*/$' "$RULES_SRC" \
    | sed 's|/$||' \
    | sed 's|^\./||'
}

read_absolute_paths() {
  grep -E '^/[^#[:space:]]+' "$RULES_SRC" || true
}

resolve_under_dropbox() {
  local rel="${1#/}"
  echo "${DROPBOX_ROOT}/${rel}"
}

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "error: these scripts require macOS (xattr com.dropbox.ignored)" >&2
    exit 1
  fi
}

require_dropbox() {
  if [[ ! -d "$DROPBOX_ROOT" ]]; then
    echo "error: Dropbox root not found: $DROPBOX_ROOT" >&2
    echo "Set dropbox_root= in config or DROPBOX_ROOT env." >&2
    exit 1
  fi
}

require_scan_roots() {
  local root
  for root in "${SCAN_ROOTS[@]}"; do
    if [[ ! -d "$root" ]]; then
      echo "error: scan root not found: $root" >&2
      exit 1
    fi
  done
}

# Iterate scan roots; sets $SCAN_ROOT for each (backward compat).
each_scan_root() {
  local root
  for root in "${SCAN_ROOTS[@]}"; do
    SCAN_ROOT="$root"
    "$@"
  done
}
