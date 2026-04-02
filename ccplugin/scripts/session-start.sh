#!/bin/bash
# session-start.sh
# SessionStart hook: 加载全局经验库领域概览 + 注入项目记忆概览到 Claude 上下文
# 参考 remember 插件模式：直接注入记忆内容，而非仅注入元数据

# 前置检查: jq 是必需依赖，缺失时以非零码退出让 pwsh fallback 生效
command -v jq >/dev/null 2>&1 || exit 127

EVENT=$(cat)
if [ -z "$EVENT" ]; then exit 0; fi

# 获取工作目录
CWD=$(echo "$EVENT" | jq -r '.cwd // empty' 2>/dev/null)
if [ -z "$CWD" ]; then CWD="${CLAUDE_WORKING_DIR:-$(pwd)}"; fi

# ── 全局经验库 ────────────────────────────────────────────────

discover_global_memory_path() {
    local project_config="$CWD/.claude/longmemory.json"
    if [ -f "$project_config" ]; then
        local path
        path=$(jq -r '.globalMemoryPath // empty' "$project_config" 2>/dev/null)
        if [ -n "$path" ]; then echo "$path"; return; fi
    fi
    local user_config="$HOME/.claude/longmemory/config.json"
    if [ -f "$user_config" ]; then
        local path
        path=$(jq -r '.globalMemoryPath // empty' "$user_config" 2>/dev/null)
        if [ -n "$path" ]; then echo "$path"; return; fi
    fi
    echo "${HOME}/.claude/longmemory"
}

HAS_GLOBAL=false
DOMAIN_SUMMARY=""
KEYWORD_DETAIL=""

GLOBAL_MEMORY_PATH=$(discover_global_memory_path)
GLOBAL_MEMORY_PATH="${GLOBAL_MEMORY_PATH/#\~/$HOME}"
CONFIG_FILE="$GLOBAL_MEMORY_PATH/config.json"

if [ -f "$CONFIG_FILE" ]; then
    AUTO_RECALL=$(jq -r '.autoRecall // false' "$CONFIG_FILE" 2>/dev/null)
    if [ "$AUTO_RECALL" = "true" ]; then
        HAS_GLOBAL=true

        # 从 triggers.json 读取领域信息和关键词明细
        TRIGGERS_FILE="$GLOBAL_MEMORY_PATH/triggers.json"
        if [ -f "$TRIGGERS_FILE" ]; then
            DOMAIN_SUMMARY=$(jq -r '
                .domains | to_entries[]
                | "\(.key)(\(.value.keywords | length)个关键词)"
            ' "$TRIGGERS_FILE" 2>/dev/null | tr -d '\r' | jq -R -s 'split("\n") | map(select(. != "")) | join(", ")' | tr -d '"')

            KEYWORD_DETAIL=$(jq -r '
                .domains | to_entries[]
                | "  - \(.key): \(.value.keywords | join(", "))"
            ' "$TRIGGERS_FILE" 2>/dev/null | tr -d '\r')
        fi

        # 如果 triggers.json 不可用，从全局 catalog.md 解析
        GLOBAL_CATALOG="$GLOBAL_MEMORY_PATH/catalog.md"
        if [ -z "$DOMAIN_SUMMARY" ] && [ -f "$GLOBAL_CATALOG" ]; then
            DOMAIN_SUMMARY=$(grep -E '^\|[^|]+\|[[:space:]]*[0-9]+[[:space:]]*\|' "$GLOBAL_CATALOG" 2>/dev/null | \
                awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); if ($2 != "领域" && $2 != "" && $2 != "---") printf "%s, ", $2}' | \
                sed 's/, $//')
        fi
    fi
fi

# ── 项目记忆 ──────────────────────────────────────────────────

PROJECT_MEMORY=""
MEMORY_STATS=""
PROJECT_CATALOG="$CWD/docs/memory/catalog.md"
PROJECT_INDEX="$CWD/docs/memory/index.json"

# 从 catalog.md 提取 Recent Overviews 段落（L1 概览，直接注入上下文）
if [ -f "$PROJECT_CATALOG" ]; then
    PROJECT_MEMORY=$(awk '/^## Recent Overviews/{f=1;next} /^## /{if(f)exit} f' "$PROJECT_CATALOG" 2>/dev/null | tr -d '\r')
fi

# 从 index.json 读取统计信息
if [ -f "$PROJECT_INDEX" ]; then
    TOTAL=$(jq -r '.stats.total // 0' "$PROJECT_INDEX" 2>/dev/null)
    LAST_DATE=$(jq -r '.lastUpdated // ""' "$PROJECT_INDEX" 2>/dev/null | cut -c1-10)
    if [ -n "$TOTAL" ] && [ "$TOTAL" != "0" ]; then
        MEMORY_STATS="共 ${TOTAL} 条，最近更新 ${LAST_DATE}"
    fi
fi

# ── 技术栈检测 ────────────────────────────────────────────────

detect_techstack() {
    local stack=""
    [ -f "$CWD/package.json" ] && stack="${stack}Node.js/TypeScript, "
    [ -f "$CWD/Cargo.toml" ] && stack="${stack}Rust, "
    [ -f "$CWD/go.mod" ] && stack="${stack}Go, "
    [ -f "$CWD/requirements.txt" ] && stack="${stack}Python, "
    [ -f "$CWD/pyproject.toml" ] && stack="${stack}Python, "
    if ls "$CWD"/*.csproj 2>/dev/null | head -1 | grep -q '.'; then
        stack="${stack}.NET/C#, "
    fi
    [ -f "$CWD/pom.xml" ] && stack="${stack}Java/Maven, "
    [ -f "$CWD/build.gradle" ] && stack="${stack}Java/Gradle, "
    echo "${stack%, }"
}

TECH_STACK=$(detect_techstack)

# ── 判断是否有内容需要注入 ────────────────────────────────────

if [ "$HAS_GLOBAL" = false ] && [ -z "$PROJECT_MEMORY" ] && [ -z "$MEMORY_STATS" ]; then
    exit 0
fi

# ── 构建上下文消息 ────────────────────────────────────────────

MSG=""

# 全局经验库部分
if [ "$HAS_GLOBAL" = true ]; then
    MSG="[LongMemory] 全局经验库已加载。"
    if [ -n "$DOMAIN_SUMMARY" ]; then
        MSG="${MSG}
可用领域: ${DOMAIN_SUMMARY}。"
    fi
    if [ -n "$KEYWORD_DETAIL" ]; then
        MSG="${MSG}
触发关键词:
${KEYWORD_DETAIL}"
    fi
fi

# 项目记忆部分（直接注入 L1 概览内容）
if [ -n "$PROJECT_MEMORY" ]; then
    if [ -n "$MSG" ]; then MSG="${MSG}
"; fi
    MSG="${MSG}[LongMemory] 项目记忆概览 (${MEMORY_STATS:-未知}):
${PROJECT_MEMORY}"
elif [ -n "$MEMORY_STATS" ]; then
    if [ -n "$MSG" ]; then MSG="${MSG}
"; fi
    MSG="${MSG}[LongMemory] 项目记忆: ${MEMORY_STATS}。使用 /longmemory:list 查看目录。"
fi

# 技术栈
if [ -n "$TECH_STACK" ]; then
    MSG="${MSG}
技术栈检测: ${TECH_STACK}。"
fi

# 自动召回指令（仅在全局库可用时）
if [ "$HAS_GLOBAL" = true ]; then
    MSG="${MSG}
当用户消息中出现上述触发关键词时，自动运行 /longmemory:recall <匹配的关键词> 获取相关经验并参考。无需等用户要求，主动召回。"
fi

# 使用 hookSpecificOutput.additionalContext 注入 Claude 上下文
jq -n --arg msg "$MSG" '{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": $msg
  }
}'
exit 0
