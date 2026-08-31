---
name: github-docs
description: GitHub 官方文档查询工具。当用户通过 WebFetch 访问 https://docs.github.com/* 时优先使用此技能。提供本地缓存机制加速文档获取，支持配置过期时间和缓存目录。当用户需要查询 GitHub Actions、REST API、GraphQL API 等官方文档时使用。
---

# GitHub 官方文档查询 Skill

此技能用于缓存和快速获取 GitHub 官方文档。当 WebFetch 请求 `https://docs.github.com/*` 时，优先使用此技能通过本地缓存获取文档。

## 工作原理

1. **检查缓存**：首先检查本地缓存目录是否有对应文档
2. **获取文档**：如果没有缓存或缓存已过期，从 GitHub API 获取并缓存
3. **返回结果**：返回文档内容

## 配置

可以通过环境变量配置以下参数：

| 配置项 | 环境变量 | 默认值 | 说明 |
|--------|----------|--------|------|
| 缓存目录 | `GITHUB_DOCS_CACHE_DIR` | `$HOME/.cache/github-docs/` | 缓存文件存储目录（用户级，跨项目共享） |
| 过期时间 | `GITHUB_DOCS_EXPIRY_DAYS` | `30` | 缓存有效期（天） |
| 语言 | `GITHUB_DOCS_LANG` | `zh` | 文档语言（zh/en） |

**注意**：缓存目录默认为用户级目录 `$HOME/.cache/github-docs/`，这样不同项目和 Agent 可以共享同一份缓存。

## 使用方法

### 在 WebFetch 中使用

当需要获取 GitHub 文档时，调用脚本：

```bash
# 使用默认配置（假设 skill 已安装到标准位置）
bash <skill-path>/scripts/fetch_docs.sh "https://docs.github.com/zh/actions/reference/workflow-syntax-for-github-actions"

# 自定义配置
GITHUB_DOCS_CACHE_DIR="/tmp/my-cache" GITHUB_DOCS_EXPIRY_DAYS=7 bash <skill-path>/scripts/fetch_docs.sh "https://docs.github.com/en/rest/releases/releases"
```

其中 `<skill-path>` 是 skill 的安装路径，例如：
- Claude Code: `~/.claude/skills/github-docs`
- opencode (项目级): `<project>/.opencode/skills/github-docs`
- 通用位置: `<any-path>/skills/github-docs`

**注意**：请根据实际安装位置调整 `<skill-path>`。

### 脚本输出

脚本会输出 Markdown 格式的文档内容到 stdout。

## 缓存结构

缓存文件存储在 `$HOME/.cache/github-docs/` 目录下：

```
$HOME/.cache/github-docs/
└── docs.github.com/
    ├── zh/
    │   ├── actions/
    │   │   └── reference/
    │   │       └── workflow-syntax.md
    │   └── rest/
    │       └── releases/
    │           └── releases.md
    └── en/
        └── ...
```

## URL 转换规则

将 GitHub 文档 URL 转换为缓存文件名：

| 原始 URL | 缓存路径 |
|----------|----------|
| `https://docs.github.com/zh/actions/reference/workflow-syntax` | `docs.github.com/zh/actions/reference/workflow-syntax.md` |
| `https://docs.github.com/en/rest/releases/releases` | `docs.github.com/en/rest/releases/releases.md` |
| `https://docs.github.com/api/article/body?pathname=/zh/actions/reference/workflows-and-actions/workflow-syntax` | `docs.github.com/zh/actions/reference/workflows-and-actions/workflow-syntax.md` |

转换规则：
1. 去掉协议头 `https://`
2. 替换路径分隔符 `/` 为 `_`（域名部分保留）
3. 添加 `.md` 扩展名

## 错误处理

脚本会在以下情况返回错误：
- 网络连接失败
- API 返回非 200 状态码
- 文档不存在（404）
- 缓存目录权限问题

错误信息会输出到 stderr，HTTP 响应状态码会输出到 stdout。

## 性能优化

- **首次访问**：需要从网络获取，约 1-3 秒
- **缓存命中**：本地读取，约 10-50ms
- **并发请求**：脚本会检查缓存是否存在，避免重复下载

## 缓存机制

### 自动缓存管理

`fetch_docs.sh` 脚本会在每次请求时自动检查缓存：

1. **缓存命中**：如果缓存文件存在且未过期，直接读取缓存
2. **缓存过期**：如果缓存文件过期，自动从网络获取新内容并覆盖缓存
3. **缓存缺失**：如果缓存文件不存在，从网络获取并保存

### 清理缓存

`cleanup.sh` 脚本用于手动清理缓存：

```bash
# 查看帮助
bash cleanup.sh --help

# 强制清理所有缓存（重建缓存）
bash cleanup.sh --force
```

**注意**：日常使用时无需手动清理，`fetch_docs.sh` 会自动处理过期缓存。
仅在需要释放磁盘空间或重建缓存时使用 `cleanup.sh`。

## 示例

### 获取 Actions 工作流语法文档

```bash
bash <skill-path>/scripts/fetch_docs.sh \
  "https://docs.github.com/zh/actions/reference/workflows-and-actions/workflow-syntax"
```

### 获取 Releases API 文档

```bash
bash <skill-path>/scripts/fetch_docs.sh \
  "https://docs.github.com/zh/rest/releases/releases"
```

### 使用英文文档

```bash
GITHUB_DOCS_LANG=en bash <skill-path>/scripts/fetch_docs.sh \
  "https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions"
```
