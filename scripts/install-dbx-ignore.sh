#!/usr/bin/env bash
# Install dbx-ignore (macOS + Linux) — direct GitHub release binary.
# Avoids upstream install.sh which fails under `sh` (BASH_SOURCE + set -u).
set -euo pipefail

VERSION="${DBX_IGNORE_VERSION:-0.4.0}"
REPO="thomastheyoung/dbx-ignore"
INSTALL_DIR="${INSTALL_DIR:-}"

if command -v dbx-ignore &>/dev/null; then
  echo "dbx-ignore already installed: $(command -v dbx-ignore)"
  dbx-ignore --help 2>/dev/null | head -5 || true
  exit 0
fi

os=$(uname -s)
arch=$(uname -m)
asset=""
case "$os" in
  Darwin)
    asset="dbx-ignore-macos-universal"
    ;;
  Linux)
    case "$arch" in
      x86_64|amd64) asset="dbx-ignore" ;;
      *)
        echo "error: Linux $arch — official release is x86_64 only." >&2
        echo "Try: cargo install dbx-ignore  (from https://github.com/$REPO)" >&2
        exit 1
        ;;
    esac
    ;;
  *)
    echo "error: unsupported OS: $os (macOS and Linux only)" >&2
    exit 1
    ;;
esac

url="https://github.com/${REPO}/releases/download/v${VERSION}/${asset}"
echo "Installing dbx-ignore v${VERSION} for ${os}/${arch}"
echo "Download: $url"

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

if ! command -v curl &>/dev/null; then
  echo "error: curl is required" >&2
  exit 1
fi

curl -fsSL "$url" -o "$tmp" || {
  echo "error: download failed (404? wrong version/arch)" >&2
  exit 1
}

chmod +x "$tmp"

# Install target: ~/.local/bin (default, no sudo) or INSTALL_DIR or /usr/local/bin
pick_install_dir() {
  if [[ -n "$INSTALL_DIR" ]]; then
    echo "$INSTALL_DIR"
    return
  fi
  if [[ -d "$HOME/.local/bin" ]] || mkdir -p "$HOME/.local/bin" 2>/dev/null; then
    echo "$HOME/.local/bin"
    return
  fi
  if [[ -w /usr/local/bin ]]; then
    echo "/usr/local/bin"
    return
  fi
  echo "$HOME/.local/bin"
}

dest_dir=$(pick_install_dir)
mkdir -p "$dest_dir"
dest="${dest_dir}/dbx-ignore"

if [[ -f "$dest" ]]; then
  cp "$dest" "${dest}.backup.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
fi

if [[ -w "$dest_dir" ]]; then
  mv "$tmp" "$dest"
  trap - EXIT
else
  echo "Installing to $dest (sudo)…"
  sudo mkdir -p "$dest_dir"
  sudo mv "$tmp" "$dest"
  sudo chmod +x "$dest"
  trap - EXIT
fi

echo ""
echo "Installed: $dest"
"$dest" --help 2>/dev/null | head -3 || true

case ":$PATH:" in
  *":$dest_dir:"*) ;;
  *)
    echo ""
    echo "Add to PATH (e.g. in ~/.zshrc or ~/.bashrc):"
    echo "  export PATH=\"$dest_dir:\$PATH\""
    ;;
esac

echo ""
echo "Then: ./dropbox-cleanup.sh apply-git"
