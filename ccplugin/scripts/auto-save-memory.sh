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

# 构建 systemMessage - 指示 Claude 调用 /longmemory:save 命令
SYSTEM_MESSAGE="<AUTO-SAVE-MEMORY>
检测到 git 仓库中有文件变更。在停止前，你必须保存工作记忆。

请立即使用 Skill 工具调用 longmemory:save 命令来保存记忆。不要手动执行保存逻辑，必须通过 Skill 工具触发命令。

完成保存后，你可以停止。
</AUTO-SAVE-MEMORY>"

jq -n \
    --arg reason "Need to save work memory and update index before stopping" \
    --arg systemMessage "$SYSTEM_MESSAGE" \
    '{decision: "block", reason: $reason, systemMessage: $systemMessage}'
exit 0
