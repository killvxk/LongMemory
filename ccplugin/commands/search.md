---
description: 在 memory 中智能搜索，支持 scope/time/project 三维过滤，利用索引加速
argument-hint: <关键词> [scope:类型] [time:范围] [project:路径] [--global]
allowed-tools: Bash, Read, Glob, Grep
---

# LongMemory Search Command

在 memory 中智能搜索，采用 L0→L1→L2 渐进式检索，按需加载，降低 token 消耗。

## 执行步骤

### 1. 解析参数

从用户输入中提取：
- 关键词：不带前缀的文本
- `scope:` 搜索范围（如 scope:decisions, scope:changes, scope:todos, scope:summary）
- `time:` 时间范围（如 time:7d, time:2026-02）
- `project:` 项目路径（如 project:/api）
- `--global` 标志：搜索全局经验库而非当前项目

### 2. Scope 映射

将 scope 参数映射到 markdown section 标题：
- `scope:decisions` → "Decisions & Rationale" 或 "关键决策"
- `scope:changes` → "Changes Made" 或 "变更内容"
- `scope:todos` → "Open Items" / "待办"
- `scope:learnings` → "Learnings" 或 "经验教训"
- `scope:summary` → "Summary" 或 "摘要"
- `scope:files` → "Technical Details" 或 "技术细节"

### 3. L0 定位（catalog 级，~200 tokens）

读取 `docs/memory/catalog.md`（使用 Read 工具）：

**有领域关键词时**：
- 同时读取 `docs/memory/domains.md`
- 在 `domains.md` 中找到关键词匹配的领域区块
- 获取该领域下的候选文件名列表
- 再到 catalog.md 的 Entries 区找这些文件名的对应行

**无领域关键词时**：
- 直接扫描 catalog.md 的 `## Entries` 区（每行格式：`日期 | 文件名 | 标签 | 标题`）
- 对每行做关键词匹配（匹配标题、标签字段，大小写不敏感）

**`time:` 过滤**：对候选列表按文件名中的日期前缀过滤：
- `time:7d` → 最近 7 天
- `time:2026-02` → 2026 年 2 月

如果 catalog.md 不存在，回退到读取 `docs/memory/index.json` 的 `entries` 数组做同等匹配。

### 4. L1 确认（overview 级）

对 L0 获取的候选文件名列表，逐一检查：

1. 先查 catalog.md 的 `## Recent Overviews` 区是否已包含该条目的概览（热数据，0 额外读取）
2. 若不在热数据区，使用 Read 工具读取 `docs/memory/{文件名}.overview.md`（每个记忆对应一个独立概览文件）
   - 提取其中的 **摘要**、**关键决策**、**待办**、**标签** 字段
3. 若对应的 `.overview.md` 文件也不存在，则直接进入 L2 全文读取

**scope 在 L1 层过滤**：
- `scope:decisions` → 检查概览块的 **关键决策** 字段
- `scope:todos` → 检查概览块的 **待办** 字段
- `scope:summary` → 检查概览块的 **摘要** 字段
- 其他 scope → 暂时保留候选，留到 L2 阶段过滤

展示所有候选条目的 L1 概览后，判断是否需要进入 L2：

### 5. L2 按需加载（完整内容）

以下情况自动读取 L2 全文：
- 候选条目数 ≤ 3
- 用户明确请求（如输入中包含"完整"、"全文"或 `--full`）

其余情况输出 L1 结果后提示：
```
找到 N 条匹配。以上为概览摘要，如需完整内容请使用：
/longmemory:get --full <文件名>
```

需要 L2 时，使用 Read 工具读取 `docs/memory/<文件名>.md`，并在 scope 指定的 section 内做精确关键词匹配，高亮匹配位置。

### 6. --global 搜索

如果有 `--global` 标志：

1. **发现全局库路径**：
   - 先读项目内 `.claude/longmemory.json`（若存在），取 `globalMemoryPath` 字段
   - 否则读 `~/.claude/longmemory/config.json`，取 `globalMemoryPath` 字段
2. **关键词匹配触发器**：读取 `{globalMemoryPath}/triggers.json`，找到关键词匹配的触发条目，获取对应的域名称
3. **读取域文件**：读取 `{globalMemoryPath}/domains/{域名}.md`，输出匹配的经验条目
4. 若 `triggers.json` 无匹配，读取全局 `catalog.md` 的 Entries 区做关键词匹配

### 7. 输出格式

按时间倒序显示搜索结果，每条结果标注来源和检索层级：

```
搜索结果: N 条匹配（关键词: "xxx"）

━━━ 2026-02-18-refactor-plan [L1 概览] ━━━
来源: 项目记忆
摘要: 分析了 L0/L1/L2 检索粒度层重构方案...
关键决策: 选择 domains.md 分域索引 + 独立 overview 文件
待办: 3 项未完成
标签: refactor, design, memory

━━━ 2026-02-14-jwt-impl [L2 全文] ━━━
来源: 项目记忆
[完整内容，scope 匹配段落高亮]

━━━ jwt-auth-pattern [全局经验] ━━━
来源: 全局经验库 > auth 域
[匹配的经验条目内容]
```

### 8. 未找到处理

如果没有匹配结果：

```
未找到匹配 "关键词" 的 memory 条目

已应用过滤:
- scope: decisions
- time: 最近 7 天

建议：
- 移除部分过滤条件扩大搜索范围
- 使用 /longmemory:list 查看所有条目
- 尝试不同的关键词
```

## 注意事项

- L0 优先，仅在必要时升级到 L1/L2，减少 token 消耗
- catalog.md 不存在时回退到 index.json，index.json 也不存在时才做全文 grep
- `--global` 与本地搜索可同时进行，结果合并输出并注明来源
- 关键词匹配大小写不敏感，支持中英文
- 全局经验库路径必须动态发现，不能硬编码
