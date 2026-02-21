#!/bin/bash
# auto-save-memory.sh
# Stop hook: 检测 git 变更，提示 Claude 保存工作记忆并更新索引

# 前置检查: jq 是必需依赖，缺失时以非零码退出让 pwsh fallback 生效
command -v jq >/dev/null 2>&1 || exit 127

EVENT=$(cat)
if [ -z "$EVENT" ]; then exit 0; fi

SESSION_ID=$(echo "$EVENT" | jq -r '.session_id // "unknown"' 2>/dev/null)
CWD=$(echo "$EVENT" | jq -r '.cwd // empty' 2>/dev/null)
if [ -z "$CWD" ]; then CWD="${CLAUDE_WORKING_DIR:-$(pwd)}"; fi

# 防止无限循环：使用基于 session_id 的临时文件作为锁
LOCK_FILE="${TMPDIR:-/tmp}/longmemory-stop-${SESSION_ID}"
if [ -f "$LOCK_FILE" ]; then exit 0; fi

# 检测 git 变更
HAS_CHANGES=false
if git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    GIT_STATUS=$(git -C "$CWD" status --porcelain 2>/dev/null)
    if [ -n "$GIT_STATUS" ]; then HAS_CHANGES=true; fi
fi

if [ "$HAS_CHANGES" = false ]; then exit 0; fi

# 确保 docs/memory 目录存在
mkdir -p "$CWD/docs/memory"

# 创建锁文件，防止再次触发时重复 block
touch "$LOCK_FILE"

jq -n '{
  decision: "block",
  reason: "检测到未提交的 git 变更，需要先保存工作记忆。",
  systemMessage: "请运行 /longmemory:save 保存当前工作记忆后再结束会话。"
}'
exit 0
