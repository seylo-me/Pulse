#!/bin/bash
# Rebuild the app icon and vector mark from the same geometry used by SwiftUI.
set -euo pipefail
PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOL_DIR="$PROJ_DIR/.build/brand-tools"
mkdir -p "$TOOL_DIR"
swiftc -O -module-cache-path "$TOOL_DIR/module-cache" \
    "$PROJ_DIR/Sources/PulseBrandGeometry.swift" \
    "$PROJ_DIR/Scripts/GenerateBrandAssets.swift" \
    -o "$TOOL_DIR/generate-brand-assets"
"$TOOL_DIR/generate-brand-assets" "$PROJ_DIR/Resources" "$TOOL_DIR"
/usr/bin/iconutil -c icns "$TOOL_DIR/AppIcon.iconset" -o "$PROJ_DIR/Resources/AppIcon.icns"
echo "Updated AppIcon.icns, AppIcon.png and PulseMark.svg from the approved dot geometry."
