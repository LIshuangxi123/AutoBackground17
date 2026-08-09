#!/bin/sh
# 构建脚本：在 macOS 或 WSL/Linux（装有 Theos + iPhoneOS SDK）上执行
# 用法：export THEOS=/path/to/theos && ./build.sh
set -e

if [ -z "$THEOS" ]; then
    echo "请先设置 THEOS 环境变量，例如：export THEOS=/opt/theos"
    exit 1
fi

make clean || true
make package FINALPACKAGE=1

DEB=$(ls packages/*.deb 2>/dev/null | tail -1)
if [ -n "$DEB" ]; then
    echo "构建完成：$DEB"
else
    echo "构建完成（未找到 deb，请检查 packages/ 目录）"
fi