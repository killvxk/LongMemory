#!/bin/bash
# pre-compact.sh
# PreCompact hook: 压缩前检查是否有未保存的 git 变更，提示保存记忆

# 前置检查: jq 是必需依赖，缺失时以非零码退出让 pwsh fallback 生效
command -v jq >/dev/null 2>&1 || exit 127

EVENT=$(cat)
if [ -z "$EVENT" ]; then exit 0; fi

CWD=$(echo "$EVENT" | jq -r '.cwd // empty' 2>/dev/null)
if [ -z "$CWD" ]; then CWD="${CLAUDE_WORKING_DIR:-$(pwd)}"; fi

# 检测 git 变更
HAS_CHANGES=false
if git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    GIT_STATUS=$(git -C "$CWD" status --porcelain 2>/dev/null)
    if [ -n "$GIT_STATUS" ]; then HAS_CHANGES=true; fi
fi

if [ "$HAS_CHANGES" = false ]; then exit 0; fi

# 不阻塞压缩，仅注入建议性系统消息（systemMessage 为通用字段，显示警告给用户）
jq -n '{
  "systemMessage": "[LongMemory] 检测到未提交的 git 变更。建议在压缩前运行 /longmemory:save 保存当前工作记忆，避免上下文压缩后丢失关键信息。"
}'
exit 0
