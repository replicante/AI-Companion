#!/usr/bin/env bash
set -euo pipefail

PLASMOID_ID="com.local.aicompanion"
INSTALL_DIR="$HOME/.local/share/plasma/plasmoids/$PLASMOID_ID"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "→ Limpiando instalación anterior…"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

echo "→ Copiando archivos…"
cp    "$SCRIPT_DIR/metadata.json" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/contents"      "$INSTALL_DIR/"

echo ""
echo "→ Estructura:"
find "$INSTALL_DIR" -type f | sort

echo ""
echo "→ Reiniciando plasmashell…"
kquitapp6 plasmashell 2>/dev/null || true
sleep 2
kstart6 plasmashell &>/dev/null &
disown

echo ""
echo "✓ Listo. Clic derecho en panel → Añadir widgets → AI Companion"
