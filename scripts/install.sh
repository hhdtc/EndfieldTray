#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
AUTOSTART=0
HIDE_PANEL=0

for arg in "$@"; do
  case "$arg" in
    --autostart) AUTOSTART=1 ;;
    --hide-panel) HIDE_PANEL=1 ;;
    -h|--help)
      cat <<USAGE
Usage: $0 [--autostart] [--hide-panel]

Installs to \$PREFIX (default: ~/.local):
  bin/endfield-tray
  share/applications/endfield-tray.desktop
  share/icons/hicolor/scalable/apps/endfield-tray.svg
  bin/endfield-plasma-panel

  --autostart   also create ~/.config/autostart/endfield-tray.desktop
  --hide-panel  set existing Plasma panels to autohide (reversible)
USAGE
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

for tool in cmake ninja g++; do
  command -v "$tool" >/dev/null || { echo "Missing build tool: $tool" >&2; exit 1; }
done

cmake -S "$ROOT" -B "$ROOT/build" -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build "$ROOT/build" -j "$(nproc)"

install -Dm755 "$ROOT/build/endfield-tray" "$PREFIX/bin/endfield-tray"
install -Dm644 "$ROOT/assets/endfield-tray.svg" "$PREFIX/share/icons/hicolor/scalable/apps/endfield-tray.svg"
install -Dm755 "$ROOT/scripts/plasma-panel.sh" "$PREFIX/bin/endfield-plasma-panel"

# Resolve the executable explicitly so autostart does not depend on the
# session PATH including ~/.local/bin.
desktop_tmp="$(mktemp)"
sed "s|^Exec=endfield-tray$|Exec=$PREFIX/bin/endfield-tray|" "$ROOT/assets/endfield-tray.desktop" > "$desktop_tmp"
install -Dm644 "$desktop_tmp" "$PREFIX/share/applications/endfield-tray.desktop"

if command -v update-desktop-database >/dev/null; then
  update-desktop-database "$PREFIX/share/applications" 2>/dev/null || true
fi
if command -v gtk-update-icon-cache >/dev/null; then
  gtk-update-icon-cache -f -t "$PREFIX/share/icons/hicolor" 2>/dev/null || true
fi

if [[ "$AUTOSTART" == 1 ]]; then
  install -Dm644 "$desktop_tmp" "$HOME/.config/autostart/endfield-tray.desktop"
fi
rm -f "$desktop_tmp"

if [[ "$HIDE_PANEL" == 1 ]]; then
  "$PREFIX/bin/endfield-plasma-panel" hide
fi

echo "Installed Endfield Tray to $PREFIX/bin/endfield-tray"
echo "Run: endfield-tray"
if [[ "$AUTOSTART" == 1 ]]; then
  echo "Autostart entry installed."
fi
if [[ "$HIDE_PANEL" == 1 ]]; then
  echo "Plasma panels set to autohide. Restore with: endfield-plasma-panel show"
fi
