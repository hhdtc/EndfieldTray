#!/usr/bin/env bash
# Hide or restore KDE Plasma panels without destroying their layout.
# "hide" uses Plasma's autohide mode; the floating bar sits above the hidden edge.
set -euo pipefail

QDBUS="$(command -v qdbus6 || command -v qdbus || true)"
if [[ -z "$QDBUS" ]]; then
  echo "qdbus6/qdbus was not found. Is Plasma installed?" >&2
  exit 1
fi

action="${1:-status}"
case "$action" in
  hide)
    script='var ps=panels(); for (var i=0;i<ps.length;i++) { ps[i].hiding="autohide"; } print("panels="+ps.length+" hiding=autohide");'
    ;;
  show|restore)
    script='var ps=panels(); for (var i=0;i<ps.length;i++) { ps[i].hiding="none"; } print("panels="+ps.length+" hiding=none");'
    ;;
  status)
    script='var ps=panels(); var out=[]; for (var i=0;i<ps.length;i++) { out.push(ps[i].id+":"+ps[i].hiding); } print("panels="+out.join(","));'
    ;;
  *)
    echo "Usage: $0 {hide|show|status}" >&2
    exit 2
    ;;
esac

"$QDBUS" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$script"
