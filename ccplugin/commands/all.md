---
description: 读取所有 memory 条目，支持分层加载选择
argument-hint: [time:范围] [level:L0|L1|L2] [--global]
allowed-tools: Bash, Read, Glob, Grep
---

# LongMemory All Command

读取所有 memory 条目，默认加载 L0 目录索引，按需升级到 L1 概览或 L2 完整内容。

## 执行步骤

### 1. 解析参数

从用户输入中提取过滤和级别参数：
- `time:` 时间范围过滤（如 time:7d, time:2026-02, time:2026-01-01..2026-01-31）
- `level:` 加载层级（如 level:L0, level:L1, level:L2）
- `--global` 标志：加载全局经验库

### 2. 默认加载 L0（catalog 目录）

无 `level:` 参数时，使用 Read 工具读取 `docs/memory/catalog.md`，输出 `## Entries` 区全量内容：

```
已加载 L0 目录索引（共 N 条）

## Entries
2026-02-18 | refactor-plan  | refactor,design,memory | 文件系统式记忆重构方案
2026-02-14 | jwt-impl       | auth,jwt,security      | JWT 认证模块实现
...

需要更多详情？
- level:L1  输出所有条目的概览（Summary + 关键决策 + 待办）
- level:L2  读取所有完整文件（注意：可能占用大量 token）
```

如果 catalog.md 不存在，回退读取 `docs/memory/index.json` 的 `entries` 数组，格式化输出同等信息。

### 3. `level:L0`：仅输出 catalog Entries 区

与步骤 2 相同，明确指定时不再询问，直接输出。

### 4. `level:L1`：输出所有概览

1. 先读 `docs/memory/catalog.md` 获取文件名列表（L0 定位）
2. 读取 catalog.md 的 `## Recent Overviews` 区（热数据，覆盖最近 10 条）
3. 对不在热数据区的条目，使用 Read 工具读取 `docs/memory/{文件名}.overview.md`（每个记忆对应一个独立概览文件）
4. 若对应的 `.overview.md` 文件不存在，从 L2 文件提取前几个 section 作为概览替代

**time: 过滤**：在文件名列表阶段按日期过滤，只读取符合时间范围的条目概览。

L1 输出格式：
```
已加载 L1 概览（共 N 条）

━━━ 2026-02-18-refactor-plan ━━━
摘要: 分析了 L0/L1/L2 检索粒度层重构方案...
关键决策: 选择 domains.md 分域索引 + 独立 overview 文件
待办: 3 项未完成
标签: refactor, design, memory

━━━ 2026-02-14-jwt-impl ━━━
摘要: 实现了基于 JWT 的认证系统...
关键决策: JWT 而非 Session，Access token 24h
待办: 2 项未完成
标签: auth, jwt, security

...
```

### 5. `level:L2`：读取所有完整文件

**容量保护（必须执行）**：

先读取 `docs/memory/index.json` 的 `stats.totalSizeBytes` 字段（若不存在则跳过容量检查）：

- `totalSizeBytes > 100KB`：输出警告并暂停：
  ```
  警告: 即将读取 N 条 memory，总大小约 XXX KB（预估 ~XXK tokens）

  建议使用过滤参数减少加载量：
  - /longmemory:all level:L2 time:30d   最近 30 天
  - /longmemory:all level:L2 time:2026-02  指定月份
  - /longmemory:all level:L1             只加载概览

  确认继续加载完整内容？（请回复"继续"或使用过滤参数重新执行）
  ```
  等待用户明确确认后再继续。

- `totalSizeBytes ≤ 100KB`：直接读取，无需确认。

**`time:` 过滤**：在读取文件前先按日期过滤文件名列表，只读取符合条件的文件。

**读取顺序**：按时间正序排列（最早在前，便于理解时间线）。

使用 Read 工具依次读取每个 `docs/memory/<文件名>.md`。

L2 输出格式：
```
已加载 L2 完整内容（共 N 条 | 总大小: XXX KB | 预估 ~XXK tokens）

━━━ 1. docs/memory/2026-01-10-db-migration.md ━━━
[完整文件内容]

━━━ 2. docs/memory/2026-02-14-jwt-impl.md ━━━
[完整文件内容]

...

全部 N 条 memory 已加载到上下文中。
```

### 6. `time:` 过滤逻辑

对所有 level 均适用，在获取文件名列表后立即过滤：
- `time:7d` → 计算今日日期，只保留最近 7 天的文件名
- `time:2026-02` → 文件名中日期前缀匹配 `2026-02`
- `time:2026-01-01..2026-01-31` → 日期区间匹配

### 7. `--global` 参数：全局经验库

1. **发现全局库路径**：
   - 先读项目内 `.claude/longmemory.json`（若存在），取 `globalMemoryPath` 字段
   - 否则读 `~/.claude/longmemory/config.json`，取 `globalMemoryPath` 字段
2. 按同样的 level 逻辑，将路径替换为 `{globalMemoryPath}/`
3. L1 对应读取全局域文件（`{globalMemoryPath}/domains/*.md`）
4. 输出时标注 `[全局经验库]`

### 8. 空结果处理

如果没有找到任何条目（含过滤后为空）：

```
未找到 memory 条目。

使用 /longmemory:save 创建第一条记录。
```

## 注意事项

- 默认行为是 L0，token 消耗极低，不加载任何详细内容
- L2 模式在 totalSizeBytes > 100KB 时必须警告并等待确认
- 按时间正序输出完整内容（最早在前），便于理解知识演进脉络
- L1 模式优先利用 Recent Overviews 热数据区，减少额外文件读取
- catalog.md 不存在时回退 index.json，再不存在才做文件系统扫描
- 全局经验库路径必须动态发现，不能硬编码
