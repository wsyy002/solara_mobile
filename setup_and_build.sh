#!/bin/bash
# ==============================================
# Solara Mobile - 完整环境搭建 + APK 构建脚本
# 在有互联网的机器上运行
# ==============================================

set -e

echo "========================================"
echo " Solara Mobile APK 构建工具"
echo "========================================"
echo ""

# 项目路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 检测操作系统
OS="$(uname -s)"
ARCH="$(uname -m)"

echo "📋 系统信息: $OS $ARCH"
echo ""

# 检查必备工具
check_command() {
    if command -v "$1" &> /dev/null; then
        echo "  ✅ $1: $($1 --version 2>&1 | head -1)"
        return 0
    else
        echo "  ❌ $1: 未安装"
        return 1
    fi
}

# === 1. 检查 Flutter ===
echo "🔍 检查环境..."
if ! check_command flutter; then
    echo ""
    echo "📥 需要安装 Flutter SDK"
    echo "   推荐安装到 $HOME/flutter"
    echo ""
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "   快速安装 (Linux):"
        echo "   curl -LO https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.27.4-stable.tar.xz"
        echo "   tar xf flutter_linux_3.27.4-stable.tar.xz -C \$HOME"
        echo "   export PATH=\"\$HOME/flutter/bin:\$PATH\""
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "   快速安装 (macOS):"
        echo "   curl -LO https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.27.4-stable.zip"
        echo "   unzip flutter_macos_3.27.4-stable.zip -d \$HOME"
        echo "   export PATH=\"\$HOME/flutter/bin:\$PATH\""
    fi
    echo ""
    echo "   或访问: https://docs.flutter.dev/get-started/install"
    exit 1
fi

# === 2. 检查 Java ===
if ! check_command java; then
    echo ""
    echo "📥 需要安装 Java JDK 17+"
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "   sudo apt-get install -y openjdk-17-jdk-headless"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "   brew install openjdk@17"
    fi
    exit 1
fi

echo ""
echo "✅ 环境检查通过"
echo ""

# === 3. 安装 Dart 依赖 ===
echo "📦 安装 Dart 依赖..."
flutter pub get
echo "✅ 依赖安装完成"
echo ""

# === 4. 接受 Android 许可 ===
echo "📋 接受 Android SDK 许可..."
flutter doctor --android-licenses 2>/dev/null || echo "  (可能需要手动运行 flutter doctor)"
echo ""

# === 5. 配置 Android SDK ===
echo "🔧 检查 Android SDK..."
if [ -z "$ANDROID_HOME" ] && [ -z "$ANDROID_SDK_ROOT" ]; then
    echo "  ⚠️  ANDROID_HOME 未设置"
    echo "  如果使用 Android Studio，默认路径:"
    echo "  - Linux:   \$HOME/Android/Sdk"
    echo "  - macOS:   \$HOME/Library/Android/sdk"
    echo ""
    echo "  配置方法:"
    echo "  flutter config --android-sdk \$HOME/Android/Sdk"
fi

# === 6. 更新 project 配置 ===
echo "📝 更新项目配置..."
cd android
echo "sdk.dir=$ANDROID_HOME" > local.properties
echo "flutter.sdk=$(which flutter | xargs dirname | xargs dirname)" >> local.properties
cd ..

echo ""

# === 7. 构建 APK ===
echo "========================================"
echo " 🔨 开始构建 APK..."
echo "========================================"
echo ""

# 选择构建类型
echo "请选择构建类型:"
echo "  1) Debug APK (快速开发测试)"
echo "  2) Release APK (发布用，默认)"
echo "  3) Release APK (按架构拆分)"
read -p "选择 [1-3]: " build_type

case "$build_type" in
    1)
        flutter build apk --debug
        APK_DIR="build/app/outputs/flutter-apk/app-debug.apk"
        ;;
    2)
        flutter build apk --release
        APK_DIR="build/app/outputs/flutter-apk/app-release.apk"
        ;;
    3|*)
        flutter build apk --release --split-per-abi
        APK_DIR="build/app/outputs/flutter-apk"
        ;;
esac

echo ""
echo "========================================"
echo " ✅ 构建完成！"
echo "========================================"
echo ""

# 列出 APK
if [ -d "$APK_DIR" ]; then
    find "$APK_DIR" -name "*.apk" -exec ls -lh {} \;
elif [ -f "$APK_DIR" ]; then
    ls -lh "$APK_DIR"
fi

echo ""
echo "📱 将 APK 安装到 Android 设备:"
echo "   adb install ${APK_DIR}app-arm64-v8a-release.apk 2>/dev/null"
echo ""
echo "📋 或通过 NAS 共享下载:"
echo "   cp ${APK_DIR}app-arm64-v8a-release.apk /vol1/1000/VM/solara-mobile.apk"
echo ""
echo "🎵 Solara Mobile 已就绪！"
