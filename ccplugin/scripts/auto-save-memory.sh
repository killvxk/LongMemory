#!/bin/bash
# auto-save-memory.sh
# Stop hook: 检测 git 变更，提示 Claude 保存工作记忆并更新索引

EVENT=$(cat)
if [ -z "$EVENT" ]; then exit 0; fi

STOP_HOOK_ACTIVE=$(echo "$EVENT" | jq -r '.stop_hook_active // false')
CWD=$(echo "$EVENT" | jq -r '.cwd // empty')
if [ -z "$CWD" ]; then CWD="${CLAUDE_WORKING_DIR:-$(pwd)}"; fi

# 防止无限循环
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then exit 0; fi

# 检测 git 变更
HAS_CHANGES=false
if git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    GIT_STATUS=$(git -C "$CWD" status --porcelain 2>/dev/null)
    if [ -n "$GIT_STATUS" ]; then HAS_CHANGES=true; fi
fi

if [ "$HAS_CHANGES" = false ]; then exit 0; fi

# 确保 docs/memory 目录存在
mkdir -p "$CWD/docs/memory"

jq -n '{decision: "block", reason: "/longmemory:save"}'
exit 0
