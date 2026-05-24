#!/usr/bin/env bash
# dropbox_cleanup — sync rules + mark existing folders ignored on macOS
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="${ROOT}/scripts"

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  sync-rules                    Copy rules/rules.dropboxignore → Dropbox root
  scan [--root <path>] [-v]       Summary of ignorable dirs (--root = one folder only)
  apply [--root <path>] [--dry-run] [-v]
  apply-git [--root <path>] [--dry-run]
  unignore <path> ...           Remove ignore marker

Config (repo root):
  config          Defaults (committed)
  config.local    Your overrides (gitignored) — copy from config.example

  dropbox_root=~/Dropbox
  scan_root=~/Dropbox/CodingProjects    # repeat for multiple roots
  scan_top=15                           # largest dirs shown in scan

Env overrides: DROPBOX_ROOT, SCAN_ROOT, CONFIG_FILE

Examples:
  $(basename "$0") sync-rules
  $(basename "$0") scan
  $(basename "$0") apply --dry-run
EOF
}

cmd="${1:-}"
shift || true

case "$cmd" in
  sync-rules)  exec bash "${SCRIPTS}/sync-rules.sh" "$@" ;;
  scan)        exec bash "${SCRIPTS}/scan.sh" "$@" ;;
  apply)       exec bash "${SCRIPTS}/apply-ignore.sh" "$@" ;;
  apply-git)   exec bash "${SCRIPTS}/apply-gitignored.sh" "$@" ;;
  unignore)    exec bash "${SCRIPTS}/unignore.sh" "$@" ;;
  -h|--help|help|"") usage ;;
  *)
    echo "Unknown command: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac
