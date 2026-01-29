#!/bin/bash
# Moss 智能管家 - 构建脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# 检查 Flutter
check_flutter() {
    if ! command -v flutter &> /dev/null; then
        error "Flutter 未安装，请先安装 Flutter"
    fi
    info "Flutter 版本: $(flutter --version | head -n 1)"
}

# 清理构建
clean() {
    info "清理构建缓存..."
    flutter clean
    success "清理完成"
}

# 获取依赖
get_deps() {
    info "获取依赖..."
    flutter pub get
    success "依赖获取完成"
}

# 代码生成
code_gen() {
    info "运行代码生成..."
    flutter pub run build_runner build --delete-conflicting-outputs 2>/dev/null || true
    success "代码生成完成"
}

# 运行测试
run_tests() {
    info "运行测试..."
    flutter test || warning "部分测试失败"
}

# 构建 Android APK (Debug)
build_apk_debug() {
    info "构建 Android Debug APK..."
    flutter build apk --debug
    success "Debug APK 构建完成"
    info "输出路径: build/app/outputs/flutter-apk/"
}

# 构建 Android APK (Release)
build_apk_release() {
    info "构建 Android Release APK..."
    flutter build apk --release
    success "Release APK 构建完成"
    info "输出路径: build/app/outputs/flutter-apk/"
}

# 构建 Android APK (分架构)
build_apk_split() {
    info "构建 Android APK (分架构)..."
    flutter build apk --release --split-per-abi
    success "分架构 APK 构建完成"
    info "输出路径: build/app/outputs/flutter-apk/"
}

# 构建 Android App Bundle
build_aab() {
    info "构建 Android App Bundle..."
    flutter build appbundle --release
    success "App Bundle 构建完成"
    info "输出路径: build/app/outputs/bundle/release/"
}

# 构建 Web
build_web() {
    info "构建 Web 版本..."
    flutter build web --release --web-renderer canvaskit
    success "Web 构建完成"
    info "输出路径: build/web/"
}

# 分析代码
analyze() {
    info "分析代码..."
    flutter analyze || warning "存在代码问题"
}

# 显示帮助
show_help() {
    echo "Moss 智能管家 - 构建脚本"
    echo ""
    echo "用法: ./build.sh [命令]"
    echo ""
    echo "命令:"
    echo "  clean       清理构建缓存"
    echo "  deps        获取依赖"
    echo "  gen         运行代码生成"
    echo "  test        运行测试"
    echo "  analyze     分析代码"
    echo "  apk         构建 Release APK"
    echo "  apk-debug   构建 Debug APK"
    echo "  apk-split   构建分架构 APK"
    echo "  aab         构建 App Bundle (用于 Google Play)"
    echo "  web         构建 Web 版本"
    echo "  all         完整构建 (clean + deps + test + apk + web)"
    echo "  help        显示帮助"
    echo ""
    echo "示例:"
    echo "  ./build.sh apk       # 构建 Release APK"
    echo "  ./build.sh all       # 完整构建流程"
}

# 完整构建
build_all() {
    clean
    get_deps
    code_gen
    run_tests
    build_apk_release
    build_web
    success "完整构建完成!"
}

# 主函数
main() {
    check_flutter
    
    case "$1" in
        clean)
            clean
            ;;
        deps)
            get_deps
            ;;
        gen)
            code_gen
            ;;
        test)
            run_tests
            ;;
        analyze)
            analyze
            ;;
        apk)
            build_apk_release
            ;;
        apk-debug)
            build_apk_debug
            ;;
        apk-split)
            build_apk_split
            ;;
        aab)
            build_aab
            ;;
        web)
            build_web
            ;;
        all)
            build_all
            ;;
        help|--help|-h|"")
            show_help
            ;;
        *)
            error "未知命令: $1\n使用 './build.sh help' 查看帮助"
            ;;
    esac
}

main "$@"
