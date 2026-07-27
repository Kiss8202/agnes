#!/bin/bash
# Agnes Backup Sync — GitHub 备份同步脚本
# 
# 用法: TOKEN_FILE=/path/to/.github_token bash sync.sh
# 或:   export GITHUB_TOKEN="ghp_xxx" && bash sync.sh
# 
# 由 qwenpaw cron 定时调用，每6小时同步工作区核心文件到 GitHub backup-sync 分支
#
# 安全: token 从文件读入变量，绝不硬编码在脚本中

set -e

WORKSPACE="/run/csi/mount-root/nas/4079184d856ecc166ed19d4887083405/workspaces/default"
REPO_DIR="/tmp/agnes-backup-repo"
BRANCH="backup-sync"

# 读取 token（从文件或环境变量）
if [ -n "$GITHUB_TOKEN" ]; then
    TOKEN="$GITHUB_TOKEN"
elif [ -n "$TOKEN_FILE" ] && [ -f "$TOKEN_FILE" ]; then
    TOKEN=$(cat "$TOKEN_FILE")
else
    echo "ERROR: Set GITHUB_TOKEN env var or TOKEN_FILE env var pointing to a token file."
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M')] Backup sync starting..."

# 初始化仓库
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"
git init -q 2>/dev/null || true
git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH" 2>/dev/null || true
git config user.email "agnes@local"
git config user.name "Agnes-2.0-Flash"

# 设置带认证的 remote URL（仅运行时生效，不写入配置文件）
REMOTE="https://kiss8202:${TOKEN}@github.com/Kiss8202/agnes.git"
git remote remove origin 2>/dev/null || true
git remote add origin "$REMOTE"

# 清理旧数据并复制工作区核心文件
rm -rf skills memory MEMORY.md PROFILE.md SOUL.md AGENTS.md HEARTBEAT.md digest 2>/dev/null || true

cp -r --no-preserve=ownership "$WORKSPACE/skills" . 2>/dev/null || true
cp -r --no-preserve=ownership "$WORKSPACE/memory" . 2>/dev/null || true
for f in MEMORY.md PROFILE.md SOUL.md AGENTS.md HEARTBEAT.md; do
    [ -f "$WORKSPACE/$f" ] && cp "$WORKSPACE/$f" .
done
cp -r --no-preserve=ownership "$WORKSPACE/digest" . 2>/dev/null || true

# Git add & commit
git add -A
if ! git diff --cached --quiet; then
    git commit -m "Auto-backup $(date '+%Y%m%d-%H%M')" 2>&1 || true
else
    echo "No changes detected."
    # 即使没有新变更也要 push（确保分支存活），但跳过以节省时间
    exit 0
fi

# Push with retry
MAX_RETRIES=3
for i in $(seq 1 $MAX_RETRIES); do
    if git push origin "$BRANCH" 2>/dev/null; then
        echo "✓ Synced to GitHub ($BRANCH branch)"
        exit 0
    fi
    echo "Retry $i/$MAX_RETRIES..."
    sleep 3
done

echo "! Push failed after $MAX_RETRIES attempts. Local backup preserved in $REPO_DIR"
exit 0
