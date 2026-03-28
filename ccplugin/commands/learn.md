---
description: 从当前会话提炼通用经验，存入全局经验库
argument-hint: "[domain] [--from <memory-file>]"
allowed-tools: Bash, Read, Write, Glob, Grep
---

# 提炼通用经验并存入全局经验库

将当前会话中的通用化教训、最佳实践、踩坑记录提炼出来，存入全局经验库，供未来项目复用。

## 执行步骤

### 1. 定位全局经验库

按 `${CLAUDE_PLUGIN_ROOT}/references/global-path-discovery.md` 中的优先级发现全局经验库路径，记为 `GLOBAL_PATH`。

如配置不存在，创建 `~/.claude/longmemory/config.json`（格式参见 `${CLAUDE_PLUGIN_ROOT}/references/learn-templates.md` 中 "config.json 默认结构"）。

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

对提取到的内容，识别其中可通用化的经验。按 `${CLAUDE_PLUGIN_ROOT}/references/learn-templates.md` 中 "经验条目格式" 和 "触发词选取原则" 构造每条经验。

向用户展示构造好的经验条目列表（展示格式参见同文件 "展示格式"），等待用户确认（y/n/edit）。若回答 `edit`，让用户修改后再确认。

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

**如果文件不存在**，按 `${CLAUDE_PLUGIN_ROOT}/references/learn-templates.md` 中 "领域文件头格式" 创建。

**读取现有文件内容**，在末尾用 `---` 分隔后追加新经验条目（使用同文件中 "经验条目格式"）。

使用 Write 工具写入完整文件（现有内容 + 新增条目）。

### 6. 更新 triggers.json

读取 `{GLOBAL_PATH}/triggers.json`（如不存在，按 `${CLAUDE_PLUGIN_ROOT}/references/learn-templates.md` 中 "triggers.json 结构" 创建空结构）。

**已有领域**：将新经验的触发词合并到对应 domain 的 `keywords` 数组（去重，保持小写）。
**新领域**：添加新的 domain entry（含 keywords 数组和 file 路径）。

使用 Write 工具覆盖写入更新后的 triggers.json。

### 7. 更新全局 catalog.md

读取 `{GLOBAL_PATH}/catalog.md`（如不存在，按 `${CLAUDE_PLUGIN_ROOT}/references/learn-templates.md` 中 "catalog.md 初始结构" 创建）。

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
