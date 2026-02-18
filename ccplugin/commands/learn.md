---
description: 从当前会话提炼通用经验，存入全局经验库
argument-hint: "[domain] [--from <memory-file>]"
allowed-tools: Bash, Read, Write, Glob, Grep
---

# 提炼通用经验并存入全局经验库

将当前会话中的通用化教训、最佳实践、踩坑记录提炼出来，存入全局经验库，供未来项目复用。

## 执行步骤

### 1. 定位全局经验库

按以下优先级查找全局经验库配置：

**优先级 1**：检查项目内配置
- 读取 `.claude/longmemory.json`
- 如存在，读取其中的 `globalMemoryPath` 字段

**优先级 2**：检查全局配置
- 读取 `~/.claude/longmemory/config.json`
- 如存在，读取其中的 `globalMemoryPath` 字段

**优先级 3**：创建默认配置
- 如两处都不存在，创建 `~/.claude/longmemory/config.json`：

```json
{
  "version": "1.0",
  "globalMemoryPath": "~/.claude/longmemory",
  "autoRecall": true,
  "maxInjectTokens": 500,
  "recentOverviewCount": 10
}
```

确保目录结构存在：

```bash
# 使用 mkdir -p 创建目录（跨平台）
mkdir -p {globalMemoryPath}/domains
```

将确定的 `globalMemoryPath` 记为 `GLOBAL_PATH`，后续步骤均使用此变量。

### 2. 提取经验来源

根据参数决定经验提取来源：

**无 `--from` 参数**：
- 从当前对话历史中分析，识别出可通用化的经验
- 重点关注：踩过的坑、做出的技术决策、发现的最佳实践、解决问题的模式
- 过滤掉项目特定内容（具体文件名、特定业务逻辑），只保留可迁移的通用经验

**有 `--from <memory-file>` 参数**：
- 读取指定的项目记忆文件（如 `docs/memory/2026-02-18-auth-impl.md`）
- 重点提取以下部分内容：
  - `## Learnings` 区块
  - `## Decisions & Rationale` 区块
  - `## Technical Details` 中的通用配置经验
- 过滤项目特定内容，保留可通用化的部分

**用户在命令参数中指定了 domain**（如 `/longmemory:learn auth`）：
- 记录目标领域为 `auth`，后续跳过领域选择步骤

### 3. 分析并构造经验条目

对提取到的内容，识别其中可通用化的经验，为每条经验构造以下结构：

```markdown
## {经验标题（简短，5-15字）}
**触发词**: {5-10个关键词，中英文混合，逗号分隔}
**场景**: {一句话描述适用场景}
**教训**:
- {教训要点1}
- {教训要点2}
- {教训要点3（如有）}
**推荐做法**: {一段话，描述推荐的处理方式}
**来源**: {今天日期 YYYY-MM-DD} {项目名（从 .claude/longmemory.json 或当前目录名获取）}
```

触发词选取原则：
- 包含该经验最常用的技术术语（英文）
- 包含中文同义词或描述词
- 避免过于泛化的词（如 "error"、"问题"）
- 优先选择在实际编码场景中会出现的词

向用户展示构造好的经验条目列表，格式如下：

```
从对话中识别到以下通用经验，请确认后存入全局库：

─── 经验 1 ───
## JWT Token 管理
**触发词**: jwt, token, refresh, 过期, expiry, bearer
**场景**: JWT token 的生成、刷新、过期处理
**教训**:
- Access token 应短期（15min-1h），Refresh token 长期（7-30d）
- 永远不要在 JWT payload 中存储敏感信息
**推荐做法**: 使用 rotating refresh tokens，每次刷新时旧 token 立即失效
**来源**: 2026-02-18 my-project

─── 经验 2 ───
（如有多条）

是否存入全局库？(y/n/edit)
```

等待用户确认。若用户回答 `edit`，让用户直接修改内容后再确认。

### 4. 选择或创建领域

**如果用户已在参数中指定 domain**，直接使用，跳过本步骤。

**否则**，读取 `{GLOBAL_PATH}/triggers.json`（如不存在则视为空），列出所有现有领域：

```
请选择存入的领域（输入编号或直接输入新领域名）：

  1. auth（认证授权）— 关键词: jwt, token, oauth...
  2. api-design（接口设计）— 关键词: rest, graphql...
  3. debugging（调试排查）— 关键词: debug, 死锁...
  n. 创建新领域

输入选择：
```

若用户选择已有领域，记录 `DOMAIN_NAME`。
若用户选择创建新领域，提示输入：
- 领域英文标识符（如 `database`，用于文件名）
- 领域描述（如 "数据库设计与优化"）

### 5. 写入领域文件

目标文件路径：`{GLOBAL_PATH}/domains/{DOMAIN_NAME}.md`

**如果文件不存在**，先创建文件头：

```markdown
# {Domain} 经验库

收录与 {领域描述} 相关的通用经验、最佳实践和踩坑记录。

---
```

**读取现有文件内容**，在末尾追加新的经验条目，条目之间用 `---` 分隔：

```markdown
（现有内容...）

---

## {新经验标题}
**触发词**: {触发词列表}
**场景**: {场景描述}
**教训**:
- {教训1}
- {教训2}
**推荐做法**: {推荐做法}
**来源**: {日期} {项目名}
```

使用 Write 工具写入完整文件（现有内容 + 新增条目）。

### 6. 更新 triggers.json

读取 `{GLOBAL_PATH}/triggers.json`（如不存在，从空结构开始）：

```json
{
  "version": "1.0",
  "domains": {}
}
```

**已有领域**：将新经验的触发词合并到对应 domain 的 `keywords` 数组（去重，保持小写）。

**新领域**：添加新的 domain entry：

```json
"{DOMAIN_NAME}": {
  "keywords": ["{触发词1}", "{触发词2}", "..."],
  "file": "domains/{DOMAIN_NAME}.md"
}
```

使用 Write 工具覆盖写入更新后的 triggers.json。

### 7. 更新全局 catalog.md

读取 `{GLOBAL_PATH}/catalog.md`（如不存在，先创建基础结构）：

```markdown
# Global Experience Catalog

## 领域概览
| 领域 | 条目数 | 关键词示例 |
|------|--------|-----------|

## 最近新增
```

**更新领域概览表格**：
- 找到对应领域的行，将条目数 +1
- 如果是新领域，在表格末尾添加新行：`| {domain} | 1 | {前3个触发词} |`

**更新最近新增列表**：
- 在 `## 最近新增` 下方顶部插入新条目：
  ```
  - {今天日期} | {domain} | {经验标题} | {前5个触发词}
  ```
- 保持列表不超过 20 条（超出则删除最旧的条目）

使用 Write 工具写入更新后的 catalog.md。

### 8. 输出确认

操作完成后，输出以下确认信息：

```
✓ 经验已存入全局库
  领域: {domain}
  条目: {经验标题}
  触发词: {触发词列表}
  文件: {GLOBAL_PATH}/domains/{domain}.md

💡 当对话中出现这些触发词时，相关经验会自动注入上下文
```

如果本次存入了多条经验，逐条列出。

## 错误处理

- 如果目录创建失败，提示用户手动创建 `{GLOBAL_PATH}/domains/` 目录
- 如果文件写入失败，显示错误信息并告知用户手动操作方式
- 如果 triggers.json 格式损坏，备份原文件为 `triggers.json.bak`，从头重建
- 如果 catalog.md 格式损坏，备份原文件为 `catalog.md.bak`，从头重建

## 跨平台注意事项

- 路径中的 `~` 需要展开为实际的 home 目录路径：
  ```bash
  # 获取 home 目录（跨平台）
  HOME_DIR=$(echo ~)
  ```
- 目录创建使用：`mkdir -p` 或 Windows 下 `New-Item -ItemType Directory -Force`
- 文件路径分隔符优先使用正斜杠 `/`
