#!/bin/bash
# session-start.sh
# SessionStart hook: 加载全局经验库领域概览并注入到系统消息

# 前置检查: jq 是必需依赖，缺失时以非零码退出让 pwsh fallback 生效
command -v jq >/dev/null 2>&1 || exit 127

EVENT=$(cat)
if [ -z "$EVENT" ]; then
    echo '{"decision":"allow"}'
    exit 0
fi

# 获取工作目录
CWD=$(echo "$EVENT" | jq -r '.cwd // empty' 2>/dev/null)
if [ -z "$CWD" ]; then CWD="${CLAUDE_WORKING_DIR:-$(pwd)}"; fi

# 发现全局经验库路径
discover_global_memory_path() {
    # 1. 检查项目级配置
    local project_config="$CWD/.claude/longmemory.json"
    if [ -f "$project_config" ]; then
        local path
        path=$(jq -r '.globalMemoryPath // empty' "$project_config" 2>/dev/null)
        if [ -n "$path" ]; then
            echo "$path"
            return
        fi
    fi

    # 2. 检查用户级配置
    local user_config="$HOME/.claude/longmemory/config.json"
    if [ -f "$user_config" ]; then
        local path
        path=$(jq -r '.globalMemoryPath // empty' "$user_config" 2>/dev/null)
        if [ -n "$path" ]; then
            echo "$path"
            return
        fi
    fi

    # 3. 默认路径
    echo "$HOME/.claude/longmemory"
}

GLOBAL_MEMORY_PATH=$(discover_global_memory_path)
CONFIG_FILE="$GLOBAL_MEMORY_PATH/config.json"
CATALOG_FILE="$GLOBAL_MEMORY_PATH/catalog.md"

# 检查全局库是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    echo '{"decision":"allow"}'
    exit 0
fi

# 检查 autoRecall 是否启用
AUTO_RECALL=$(jq -r '.autoRecall // false' "$CONFIG_FILE" 2>/dev/null)
if [ "$AUTO_RECALL" != "true" ]; then
    echo '{"decision":"allow"}'
    exit 0
fi

# 读取目录文件
if [ ! -f "$CATALOG_FILE" ]; then
    echo '{"decision":"allow"}'
    exit 0
fi

# 从 triggers.json 读取领域信息（主要来源，精确可靠）
DOMAIN_SUMMARY=""
TRIGGERS_FILE="$GLOBAL_MEMORY_PATH/triggers.json"
if [ -f "$TRIGGERS_FILE" ]; then
    DOMAIN_SUMMARY=$(jq -r '.domains | to_entries[] | "\(.key)(\(.value.keywords | length)个关键词)"' "$TRIGGERS_FILE" 2>/dev/null | tr '\n' ', ' | sed 's/, $//')
fi

# 如果 triggers.json 不可用，从 catalog.md 的领域概览表格解析领域行
# 表格行格式: | auth | 5 | jwt, token |
if [ -z "$DOMAIN_SUMMARY" ] && [ -f "$CATALOG_FILE" ]; then
    DOMAIN_SUMMARY=$(grep -E '^\|[^|]+\|[[:space:]]*[0-9]+[[:space:]]*\|' "$CATALOG_FILE" 2>/dev/null | \
        awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); if ($2 != "领域" && $2 != "" && $2 != "---") printf "%s, ", $2}' | \
        sed 's/, $//')
fi

# 检测项目技术栈
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
    # 去掉末尾
    echo "${stack%, }"
}

TECH_STACK=$(detect_techstack)

# 构建系统消息
MSG="[LongMemory] 全局经验库已加载。"
if [ -n "$DOMAIN_SUMMARY" ]; then
    MSG="${MSG}可用领域: ${DOMAIN_SUMMARY}。"
fi
if [ -n "$TECH_STACK" ]; then
    MSG="${MSG}技术栈检测: ${TECH_STACK}。"
fi
MSG="${MSG}使用 /longmemory:recall <关键词> 查询经验。"

# 输出 JSON 响应
jq -n --arg msg "$MSG" '{"decision": "allow", "systemMessage": $msg}'
exit 0
