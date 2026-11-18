#!/bin/bash
# build_app.sh - 构建 Pulse.app 完整 macOS 应用包 (支持 Universal 与 Apple Silicon M系列架构)

set -e
PROJ_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Pulse"
VERSION="1.5.0"
BUNDLE_ID="com.sulee.pulse"
DIST_DIR="$PROJ_DIR/dist"

echo "🔨 [1/5] 生成品牌矢量资源与应用图标..."
bash "$PROJ_DIR/Scripts/generate_brand_assets.sh"

cd "$PROJ_DIR"

echo "⚡ [2/5] 编译 Apple Silicon (arm64) 原生二进制..."
swift build -c release --arch arm64

echo "⚡ [3/5] 编译 Intel (x86_64) 原生二进制..."
swift build -c release --arch x86_64

ARM64_BIN="$PROJ_DIR/.build/arm64-apple-macosx/release/SysBar"
X86_BIN="$PROJ_DIR/.build/x86_64-apple-macosx/release/SysBar"
UNIVERSAL_BIN="$PROJ_DIR/.build/release/SysBar-Universal"

mkdir -p "$PROJ_DIR/.build/release"
echo "🔀 [4/5] 生成 Universal 通用二进制 (arm64 + x86_64)..."
lipo -create -output "$UNIVERSAL_BIN" "$ARM64_BIN" "$X86_BIN"

echo "架构验证:"
echo "  Apple Silicon: $(lipo -info "$ARM64_BIN")"
echo "  Intel x86_64:  $(lipo -info "$X86_BIN")"
echo "  Universal:     $(lipo -info "$UNIVERSAL_BIN")"

# 辅助打包函数
assemble_bundle() {
    local TARGET_DIR="$1"
    local BIN_SRC="$2"
    
    rm -rf "$TARGET_DIR"
    mkdir -p "$TARGET_DIR/Contents/MacOS"
    mkdir -p "$TARGET_DIR/Contents/Resources"
    
    cp -R "$PROJ_DIR/Resources/." "$TARGET_DIR/Contents/Resources/"
    cp "$BIN_SRC" "$TARGET_DIR/Contents/MacOS/$APP_NAME"
    chmod +x "$TARGET_DIR/Contents/MacOS/$APP_NAME"
    
    cat > "$TARGET_DIR/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>Pulse</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>15</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
PLIST
}

echo "📦 [5/5] 打包应用包及发布镜像..."
mkdir -p "$DIST_DIR"

# 1. 默认应用包 (Universal 通用，支持所有 Mac)
UNIVERSAL_APP="$DIST_DIR/$APP_NAME.app"
assemble_bundle "$UNIVERSAL_APP" "$UNIVERSAL_BIN"

# 2. 专用 Apple Silicon 应用包 (M1/M2/M3/M4 原生)
ARM64_APP="$DIST_DIR/Pulse-AppleSilicon.app"
assemble_bundle "$ARM64_APP" "$ARM64_BIN"

# 3. 创建 DMG 安装包
create_dmg() {
    local APP_PATH="$1"
    local DMG_NAME="$2"
    local VOL_NAME="$3"
    local TMP_DMG_DIR="$DIST_DIR/.tmp_dmg_$VOL_NAME"
    
    rm -rf "$TMP_DMG_DIR" "$DIST_DIR/$DMG_NAME"
    mkdir -p "$TMP_DMG_DIR"
    cp -R "$APP_PATH" "$TMP_DMG_DIR/"
    ln -s /Applications "$TMP_DMG_DIR/Applications"
    
    hdiutil create -volname "$VOL_NAME" -srcfolder "$TMP_DMG_DIR" -ov -format UDZO "$DIST_DIR/$DMG_NAME" >/dev/null
    rm -rf "$TMP_DMG_DIR"
    echo "  ✅ 生成 DMG: $DIST_DIR/$DMG_NAME"
}

create_dmg "$ARM64_APP" "Pulse-v1.5-AppleSilicon.dmg" "Pulse (Apple Silicon)"
create_dmg "$UNIVERSAL_APP" "Pulse-v1.5-Universal.dmg" "Pulse (Universal)"

# 4. 创建 ZIP 压缩包 (方便 GitHub Releases 快速解压使用)
cd "$DIST_DIR"
rm -f "Pulse-v1.5-AppleSilicon.zip" "Pulse-v1.5-Universal.zip"
zip -qry "Pulse-v1.5-AppleSilicon.zip" "Pulse-AppleSilicon.app"
zip -qry "Pulse-v1.5-Universal.zip" "$APP_NAME.app"
echo "  ✅ 生成 ZIP: $DIST_DIR/Pulse-v1.5-AppleSilicon.zip"
echo "  ✅ 生成 ZIP: $DIST_DIR/Pulse-v1.5-Universal.zip"

echo ""
echo "🎉 全部构建完成！"
echo "--------------------------------------------------------"
echo "📱 Apple Silicon 安装包: $DIST_DIR/Pulse-v1.5-AppleSilicon.dmg"
echo "🌐 Universal 通用安装包: $DIST_DIR/Pulse-v1.5-Universal.dmg"
echo "--------------------------------------------------------"
