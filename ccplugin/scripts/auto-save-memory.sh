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

# reason 作为下一轮用户输入回传给 Claude，包含完整的 save 执行指令
REASON="检测到 git 仓库中有文件变更，请在停止前保存工作记忆。

请按照以下步骤执行：

1. 收集 git 变更上下文：
   git status --porcelain
   git diff --stat HEAD
   git log --oneline -5

2. 分析当前会话内容，生成 memory 文件，写入 docs/memory/YYYY-MM-DD-description.md
   使用标准 7 section 模板：Summary, Changes Made, Decisions & Rationale, Technical Details, Testing, Open Items / Follow-ups, Learnings

3. 更新 docs/memory/index.json：
   - 如果不存在，创建初始索引（version: 1.0）
   - 添加新 entry（layer: L0, compacted: false）
   - 从内容提取 3-5 个 tags
   - 更新 stats（total, l0/l1/l2 计数, totalSizeBytes）

完成保存和索引更新后，你可以停止。"

jq -n \
    --arg reason "$REASON" \
    '{decision: "block", reason: $reason}'
exit 0
