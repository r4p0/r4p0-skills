#!/bin/bash

# GitHub 文档缓存清理脚本
# 用法: bash cleanup.sh [options]
#
# 此脚本用于：
# 1. 强制清理所有缓存文件（重建缓存）
# 2. 清理磁盘空间
#
# 注意：日常使用时，fetch_docs.sh 会自动处理过期缓存的刷新
# 此脚本仅在需要时手动运行
#
# 环境变量:
#   GITHUB_DOCS_CACHE_DIR  - 缓存目录 (默认: ~/.cache/github-docs/)

set -e

# 默认配置
CACHE_DIR="${GITHUB_DOCS_CACHE_DIR:-$HOME/.cache/github-docs}"

# 解析参数
FORCE=false
HELP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f)
            FORCE=true
            shift
            ;;
        --help|-h)
            echo "用法: $0 [options]"
            echo ""
            echo "选项:"
            echo "  --force, -f    强制清理（删除所有缓存文件）"
            echo "  --help, -h     显示帮助"
            echo ""
            echo "说明:"
            echo "  日常使用时，fetch_docs.sh 会自动处理过期缓存的刷新。"
            echo "  此脚本仅在需要时手动运行以清理磁盘空间或重建缓存。"
            exit 0
            ;;
        *)
            echo "错误: 意外的参数: $1" >&2
            exit 1
            ;;
    esac
done

echo "GitHub 文档缓存清理工具" >&2
echo "缓存目录: $CACHE_DIR" >&2
echo "" >&2

# 检查缓存目录是否存在
if [ ! -d "$CACHE_DIR" ]; then
    echo "缓存目录不存在: $CACHE_DIR" >&2
    exit 0
fi

# 统计当前缓存
TOTAL_FILES=$(find "$CACHE_DIR" -name "*.md" -type f 2>/dev/null | wc -l)
TOTAL_SIZE=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)

echo "当前缓存状态:" >&2
echo "  - 文件数: $TOTAL_FILES" >&2
echo "  - 总大小: $TOTAL_SIZE" >&2
echo "" >&2

if [ "$FORCE" = true ]; then
    echo "执行强制清理..." >&2
    
    # 删除所有缓存文件
    find "$CACHE_DIR" -name "*.md" -type f -delete 2>/dev/null || true
    
    # 清理空目录
    find "$CACHE_DIR" -type d -empty -delete 2>/dev/null || true
    
    echo "" >&2
    echo "清理完成！" >&2
    echo "缓存目录已清空，下次访问时将重新获取文档。" >&2
else
    echo "提示:" >&2
    echo "  - 使用 --force 参数可强制清理所有缓存" >&2
    echo "  - 日常使用无需清理，fetch_docs.sh 会自动处理过期缓存" >&2
    echo "" >&2
    echo "示例:" >&2
    echo "  bash cleanup.sh --force    # 强制清理所有缓存" >&2
fi
