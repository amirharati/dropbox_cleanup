#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

require_macos

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <path> [<path> ...]" >&2
  exit 1
fi

for path in "$@"; do
  if [[ ! -e "$path" ]]; then
    echo "skip (missing): $path" >&2
    continue
  fi
  unmark_ignored "$path"
  echo "unignored: $path"
done
