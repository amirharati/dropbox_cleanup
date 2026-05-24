#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

require_dropbox

if [[ ! -f "$RULES_SRC" ]]; then
  echo "error: missing $RULES_SRC" >&2
  exit 1
fi

cp "$RULES_SRC" "$RULES_DEST"
echo "Synced rules → $RULES_DEST"
echo "Dropbox applies on save; confirm in Preferences → Sync → Ignore rules."
