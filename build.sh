#!/bin/bash
# 一键构建脚本：编译 Swift 源码并打包为可双击运行的 .app
#
# 用法：
#   ./build.sh            # 构建到 ./build/护眼强制休息.app
#   ./build.sh --install  # 构建后复制到 /Applications 并启动
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="护眼强制休息"
BUNDLE_ID="com.xiaofeixia.eyeguard"
SRC_DIR="Sources/EyeGuard"
BUILD_DIR="build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"

echo "==> 清理旧构建"
rm -rf "${BUILD_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"

echo "==> 编译 Swift 源码（release）"
/usr/bin/swiftc \
    -O \
    -parse-as-library \
    -framework Cocoa \
    -framework ServiceManagement \
    "${SRC_DIR}"/*.swift \
    -o "${APP_DIR}/Contents/MacOS/EyeGuard"

echo "==> 写入 Info.plist"
cp Info.plist "${APP_DIR}/Contents/Info.plist"

echo "==> 生成图标"
if [ -f "icon.png" ]; then
    ICONSET="${BUILD_DIR}/AppIcon.iconset"
    mkdir -p "${ICONSET}"
    for size in 16 32 64 128 256 512; do
        /usr/bin/sips -z $size $size icon.png --out "${ICONSET}/icon_${size}x${size}.png" >/dev/null 2>&1 || true
        dbl=$((size * 2))
        /usr/bin/sips -z $dbl $dbl icon.png --out "${ICONSET}/icon_${size}x${size}@2x.png" >/dev/null 2>&1 || true
    done
    /usr/bin/iconutil -c icns "${ICONSET}" -o "${APP_DIR}/Contents/Resources/AppIcon.icns" 2>/dev/null || true
fi

echo "==> 本地签名（ad-hoc）"
/usr/bin/codesign --force --deep --sign - "${APP_DIR}" 2>/dev/null || \
    echo "    （签名跳过，不影响本地运行）"

echo "==> 构建完成：${APP_DIR}"

if [ "${1:-}" = "--install" ]; then
    echo "==> 安装到 /Applications"
    rm -rf "/Applications/${APP_NAME}.app"
    cp -R "${APP_DIR}" "/Applications/${APP_NAME}.app"
    echo "==> 启动应用"
    open "/Applications/${APP_NAME}.app"
    echo "已安装并启动：/Applications/${APP_NAME}.app"
else
    echo ""
    echo "双击运行：open \"${APP_DIR}\""
    echo "安装到应用程序：./build.sh --install"
fi
