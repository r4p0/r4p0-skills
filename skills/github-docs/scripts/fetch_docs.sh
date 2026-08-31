#!/bin/bash

# GitHub 官方文档获取脚本
# 用法: bash fetch_docs.sh <url> [options]
#
# 环境变量:
#   GITHUB_DOCS_CACHE_DIR  - 缓存目录 (默认: $HOME/.cache/github-docs/)
#   GITHUB_DOCS_EXPIRY_DAYS - 过期时间 (默认: 30)
#   GITHUB_DOCS_LANG       - 语言 (默认: zh)

set -e

# 默认配置
# 使用用户级缓存目录，支持跨项目和跨 Agent 共享
CACHE_DIR="${GITHUB_DOCS_CACHE_DIR:-$HOME/.cache/github-docs}"
EXPIRY_DAYS="${GITHUB_DOCS_EXPIRY_DAYS:-30}"
DEFAULT_LANG="${GITHUB_DOCS_LANG:-zh}"

# 解析参数
URL=""
LANG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --lang)
            LANG="$2"
            shift 2
            ;;
        --cache-dir)
            CACHE_DIR="$2"
            shift 2
            ;;
        --expiry)
            EXPIRY_DAYS="$2"
            shift 2
            ;;
        --help|-h)
            echo "用法: $0 <url> [options]"
            echo ""
            echo "选项:"
            echo "  --lang <lang>     文档语言 (zh/en), 默认: $DEFAULT_LANG"
            echo "  --cache-dir <dir> 缓存目录, 默认: $CACHE_DIR"
            echo "  --expiry <days>   过期时间(天), 默认: $EXPIRY_DAYS"
            echo "  --help, -h        显示帮助"
            exit 0
            ;;
        *)
            if [ -z "$URL" ]; then
                URL="$1"
            else
                echo "错误: 意外的参数: $1" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

# 检查参数
if [ -z "$URL" ]; then
    echo "错误: 请提供 URL" >&2
    echo "用法: $0 <url>" >&2
    exit 1
fi

# 确定语言
if [ -z "$LANG" ]; then
    # 从 URL 中提取语言
    if [[ "$URL" == *"/zh/"* ]]; then
        LANG="zh"
    elif [[ "$URL" == *"/en/"* ]]; then
        LANG="en"
    else
        LANG="$DEFAULT_LANG"
    fi
fi

# 从 URL 中提取文档路径
# 支持两种格式:
# 1. https://docs.github.com/zh/actions/reference/workflow-syntax
# 2. https://docs.github.com/api/article/body?pathname=/zh/actions/reference/workflow-syntax
DOC_PATH=""
if [[ "$URL" == *"article/body"* ]]; then
    # 从 pathname 参数提取
    DOC_PATH=$(echo "$URL" | grep -o 'pathname=[^&]*' | sed 's/pathname=//' || echo "")
elif [[ "$URL" == *"docs.github.com/"* ]]; then
    # 从 URL 路径提取
    DOC_PATH=$(echo "$URL" | sed -E 's|https?://docs\.github\.com/||' | cut -d'?' -f1)
fi

# 确保 DOC_PATH 以 / 开头
if [[ "$DOC_PATH" != /* ]]; then
    DOC_PATH="/${DOC_PATH}"
fi

# 从 DOC_PATH 提取语言（如果 URL 中没有指定）
if [[ "$DOC_PATH" == "/zh/"* ]]; then
    LANG="zh"
    DOC_PATH="${DOC_PATH#/zh/}"
elif [[ "$DOC_PATH" == "/en/"* ]]; then
    LANG="en"
    DOC_PATH="${DOC_PATH#/en/}"
fi

# 再次确保 DOC_PATH 以 / 开头
if [[ "$DOC_PATH" != /* ]]; then
    DOC_PATH="/${DOC_PATH}"
fi

# 构建缓存文件路径
# 格式: $HOME/.cache/github-docs/docs.github.com/{lang}/{path}.md
# 保留目录结构，不扁平化
REL_PATH=$(echo "$DOC_PATH" | sed 's|^/||')
CACHE_FILE="${CACHE_DIR}/docs.github.com/${LANG}/${REL_PATH}.md"

# 确保缓存目录存在
mkdir -p "$(dirname "$CACHE_FILE")"

# 计算过期时间戳
MAX_AGE_SECONDS=$((EXPIRY_DAYS * 86400))
CURRENT_TIME=$(date +%s)

# 检查缓存是否有效
check_cache() {
    local cache_file="$1"
    
    if [ ! -f "$cache_file" ]; then
        return 1
    fi
    
    # 检查过期时间
    local cache_time
    local cache_age
    
    if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "darwin"* ]]; then
        cache_time=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file")
    else
        cache_time=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file")
    fi
    
    cache_age=$((CURRENT_TIME - cache_time))
    
    if [ "$cache_age" -lt "$MAX_AGE_SECONDS" ]; then
        return 0  # 缓存有效
    fi
    
    return 1  # 缓存过期
}

# 从 API 获取文档
fetch_from_api() {
    local api_pathname="$1"
    local api_url="https://docs.github.com/api/article/body?pathname=${api_pathname}"
    
    echo "正在从 API 获取文档: $api_url" >&2
    
    # 使用 curl 获取文档
    local response
    response=$(curl -s -L "$api_url" 2>/dev/null) || {
        echo "错误: 无法获取文档" >&2
        return 1
    }
    
    # 检查是否为空
    if [ -z "$response" ]; then
        echo "错误: API 返回空响应" >&2
        return 1
    fi
    
    # 检查是否为错误响应
    if echo "$response" | grep -q '"error"'; then
        echo "错误: API 返回错误: $response" >&2
        return 1
    fi
    
    # 保存到缓存（覆盖）
    mkdir -p "$(dirname "$CACHE_FILE")"
    echo "$response" > "$CACHE_FILE"
    echo "已更新缓存: $CACHE_FILE" >&2
    
    echo "$response"
}

# 主逻辑
echo "获取文档: $URL" >&2
echo "语言: $LANG" >&2
echo "文档路径: $DOC_PATH" >&2
echo "缓存文件: $CACHE_FILE" >&2
echo "过期时间: $EXPIRY_DAYS 天" >&2
echo "" >&2

# 检查缓存（包括过期检查）
if check_cache "$CACHE_FILE"; then
    CACHE_AGE=$((CURRENT_TIME - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE")))
    echo "使用缓存（${CACHE_AGE}秒前）: $CACHE_FILE" >&2
    cat "$CACHE_FILE"
else
    echo "缓存不存在或已过期，从网络获取..." >&2
    
    # 构建 API URL 需要的 pathname
    # 格式: /{lang}/{path}
    API_PATHNAME="/${LANG}${DOC_PATH}"
    
    result=$(fetch_from_api "$API_PATHNAME")
    
    if [ $? -ne 0 ] || [ -z "$result" ]; then
        echo "从 API 获取失败，尝试直接获取网页..." >&2
        
        # 尝试直接从 docs.github.com 获取
        direct_url="https://docs.github.com${DOC_PATH}"
        result=$(curl -s -L "$direct_url" 2>/dev/null | sed 's|<[^>]*>| |g' | tr -s ' \n' | head -c 10000) || true
        
        if [ -n "$result" ]; then
            # 保存到缓存
            mkdir -p "$(dirname "$CACHE_FILE")"
            echo "$result" > "$CACHE_FILE"
            echo "$result"
        else
            echo "错误: 无法获取文档" >&2
            exit 1
        fi
    else
        echo "$result"
    fi
fi
