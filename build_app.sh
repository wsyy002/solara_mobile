#!/bin/bash
# ============================================
# Solara Mobile - APK 构建脚本
# 在安装了 Flutter SDK 的开发机上运行
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=============================="
echo " Solara Mobile APK Builder"
echo "=============================="
echo ""

# 检查 Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ 未找到 Flutter SDK，请先安装:"
    echo "   https://docs.flutter.dev/get-started/install"
    exit 1
fi

echo "✅ Flutter: $(flutter --version 2>&1 | head -1)"

# 安装依赖
echo ""
echo "📦 安装依赖..."
flutter pub get

# 清理
echo ""
echo "🧹 清理旧构建..."
flutter clean

# 构建
echo ""
echo "🔨 构建 Release APK..."
flutter build apk --release --split-per-abi

APK_DIR="build/app/outputs/flutter-apk"
echo ""
echo "=============================="
echo " ✅ 构建完成！"
echo "=============================="

# 列出生成的 APK
find "$APK_DIR" -name "*.apk" -exec ls -lh {} \;

# 如果有 NAS 共享目录，复制过去
NAS_DIR="/vol1/1000/VM"
if [ -d "$NAS_DIR" ]; then
    echo ""
    echo "📤 复制到 NAS 共享目录..."
    cp "$APK_DIR"/*.apk "$NAS_DIR/" 2>/dev/null || true
    ls -lh "$NAS_DIR/"*.apk 2>/dev/null || echo "（没有找到 APK 文件）"
    echo "   → $NAS_DIR/"
fi

echo ""
echo "🎵 Solara Mobile 已就绪！"
echo "将 APK 传到手机上安装即可使用。"
