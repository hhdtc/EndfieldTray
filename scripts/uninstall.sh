#!/usr/bin/env bash
set -euo pipefail
PREFIX="${PREFIX:-$HOME/.local}"
rm -f "$PREFIX/bin/endfield-tray" "$PREFIX/bin/endfield-plasma-panel"
rm -f "$PREFIX/share/applications/endfield-tray.desktop"
rm -f "$PREFIX/share/icons/hicolor/scalable/apps/endfield-tray.svg"
rm -f "$HOME/.config/autostart/endfield-tray.desktop"
echo "Endfield Tray removed. Plasma panel state was not changed."
echo "Restore panels with: qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript 'var ps=panels(); for (var i=0;i<ps.length;i++) ps[i].hiding=\"none\";'"
