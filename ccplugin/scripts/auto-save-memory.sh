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

# 构建 systemMessage - 指示 Claude 按 save 命令逻辑保存
# 关键改进：不再直接指定文件格式,而是引用 save 命令的完整模板
SYSTEM_MESSAGE="<AUTO-SAVE-MEMORY>
检测到 git 仓库中有文件变更。在停止前,你必须保存工作记忆。

请按照以下步骤执行(等同于 /longmemory:save 命令的逻辑):

1. 收集 git 变更上下文:
   git status --porcelain
   git diff --stat HEAD
   git log --oneline -5

2. 分析当前会话内容,生成 memory 文件,写入 docs/memory/YYYY-MM-DD-description.md
   使用标准 7 section 模板: Summary, Changes Made, Decisions & Rationale, Technical Details, Testing, Open Items / Follow-ups, Learnings

3. 更新 docs/memory/index.json:
   - 如果不存在,创建初始索引(version: 1.0)
   - 添加新 entry(layer: L0, compacted: false)
   - 从内容提取 3-5 个 tags
   - 更新 stats(total, l0/l1/l2 计数, totalSizeBytes)

完成保存和索引更新后,你可以停止。
</AUTO-SAVE-MEMORY>"

jq -n \
    --arg reason "Need to save work memory and update index before stopping" \
    --arg systemMessage "$SYSTEM_MESSAGE" \
    '{decision: "block", reason: $reason, systemMessage: $systemMessage}'
exit 0
