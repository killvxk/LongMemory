#!/bin/bash
# keyword-trigger.sh
# UserPromptSubmit hook: 检测触发词，自动注入匹配的经验

EVENT=$(cat)
if [ -z "$EVENT" ]; then exit 0; fi

# 获取用户消息内容
PROMPT=$(echo "$EVENT" | jq -r '.prompt // .content // empty' 2>/dev/null)
if [ -z "$PROMPT" ]; then exit 0; fi

# 获取工作目录
CWD=$(echo "$EVENT" | jq -r '.cwd // empty' 2>/dev/null)
if [ -z "$CWD" ]; then CWD="${CLAUDE_WORKING_DIR:-$(pwd)}"; fi

# 发现全局经验库路径
discover_global_memory_path() {
    local project_config="$CWD/.claude/longmemory.json"
    if [ -f "$project_config" ]; then
        local path
        path=$(jq -r '.globalMemoryPath // empty' "$project_config" 2>/dev/null)
        if [ -n "$path" ]; then
            echo "$path"
            return
        fi
    fi

    local user_config="$HOME/.claude/longmemory/config.json"
    if [ -f "$user_config" ]; then
        local path
        path=$(jq -r '.globalMemoryPath // empty' "$user_config" 2>/dev/null)
        if [ -n "$path" ]; then
            echo "$path"
            return
        fi
    fi

    echo "$HOME/.claude/longmemory"
}

GLOBAL_MEMORY_PATH=$(discover_global_memory_path)
# 展开路径中的 ~ 为 $HOME（jq 读取的字符串不会自动展开 tilde）
GLOBAL_MEMORY_PATH="${GLOBAL_MEMORY_PATH/#\~/$HOME}"
CONFIG_FILE="$GLOBAL_MEMORY_PATH/config.json"
TRIGGERS_FILE="$GLOBAL_MEMORY_PATH/triggers.json"

# 快速检查：triggers.json 不存在则立即退出
if [ ! -f "$TRIGGERS_FILE" ]; then exit 0; fi
if [ ! -f "$CONFIG_FILE" ]; then exit 0; fi

# 检查 autoRecall
AUTO_RECALL=$(jq -r '.autoRecall // false' "$CONFIG_FILE" 2>/dev/null)
if [ "$AUTO_RECALL" != "true" ]; then exit 0; fi

# 读取最大注入 token 数（默认 500）
MAX_INJECT_TOKENS=$(jq -r '.maxInjectTokens // 500' "$CONFIG_FILE" 2>/dev/null)
MAX_INJECT_BYTES=$(( MAX_INJECT_TOKENS * 4 ))

# 将用户消息转为小写
PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# 读取所有域名称
DOMAIN_NAMES=$(jq -r '.domains | keys[]' "$TRIGGERS_FILE" 2>/dev/null)
if [ -z "$DOMAIN_NAMES" ]; then exit 0; fi

MATCHED_CONTENT=""
TOTAL_BYTES=0

# 遍历所有域，匹配关键词
while IFS= read -r domain; do
    # 获取该域的关键词列表
    KEYWORDS=$(jq -r --arg d "$domain" '.domains[$d].keywords[]' "$TRIGGERS_FILE" 2>/dev/null)
    DOMAIN_FILE=$(jq -r --arg d "$domain" '.domains[$d].file' "$TRIGGERS_FILE" 2>/dev/null)

    MATCHED_KW=""
    while IFS= read -r kw; do
        if echo "$PROMPT_LOWER" | grep -qiF "$kw"; then
            MATCHED_KW="$kw"
            break
        fi
    done <<< "$KEYWORDS"

    # 如果有关键词命中
    if [ -n "$MATCHED_KW" ] && [ -n "$DOMAIN_FILE" ]; then
        FULL_DOMAIN_FILE="$GLOBAL_MEMORY_PATH/$DOMAIN_FILE"
        if [ ! -f "$FULL_DOMAIN_FILE" ]; then continue; fi

        # 检查剩余可注入空间
        if [ "$TOTAL_BYTES" -ge "$MAX_INJECT_BYTES" ]; then break; fi

        # 从域文件中提取包含匹配关键词的条目区块（## 标题到 --- 分隔）
        BLOCK=$(awk -v kw="$MATCHED_KW" '
            BEGIN { in_block=0; block=""; found=0 }
            /^## / {
                if (in_block && found) { print block; found=0 }
                block=$0"\n"; in_block=1; found=0
                next
            }
            /^---/ {
                if (in_block && found) { print block }
                in_block=0; block=""; found=0
                next
            }
            in_block {
                block=block $0"\n"
                if (tolower($0) ~ tolower(kw)) { found=1 }
            }
            END {
                if (in_block && found) { print block }
            }
        ' "$FULL_DOMAIN_FILE" 2>/dev/null)

        if [ -n "$BLOCK" ]; then
            BLOCK_BYTES=${#BLOCK}
            REMAINING=$(( MAX_INJECT_BYTES - TOTAL_BYTES ))
            if [ "$BLOCK_BYTES" -gt "$REMAINING" ]; then
                # 截断到剩余空间
                BLOCK=$(echo "$BLOCK" | head -c "$REMAINING")
            fi
            MATCHED_CONTENT="${MATCHED_CONTENT}${BLOCK}\n"
            TOTAL_BYTES=$(( TOTAL_BYTES + BLOCK_BYTES ))
        fi
    fi
done <<< "$DOMAIN_NAMES"

# 如果没有匹配内容，静默退出
if [ -z "$MATCHED_CONTENT" ]; then exit 0; fi

FINAL_MSG="[LongMemory 经验召回]\n\n${MATCHED_CONTENT}"

# 输出 JSON 响应
jq -n --arg msg "$(printf '%b' "$FINAL_MSG")" '{"decision": "allow", "systemMessage": $msg}'
exit 0
