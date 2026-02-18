---
description: 列出所有 memory 条目的目录索引，支持时间和领域过滤
argument-hint: [time:范围] [domain:领域] [--global]
allowed-tools: Bash, Read, Glob, Grep
---

# LongMemory List Command

列出所有 memory 条目的目录索引，直接读取 catalog.md，支持时间和领域过滤。

## 执行步骤

### 1. 解析参数

从用户输入中提取过滤参数：
- `time:` 时间范围过滤（如 time:7d, time:2026-02, time:2026-01-01..2026-01-31）
- `domain:` 领域过滤（新增，如 domain:auth, domain:api）
- `--global` 标志：列出全局经验库的条目

### 2. 主路径：读取 catalog.md

使用 Read 工具读取 `docs/memory/catalog.md`：

**如果有 `domain:` 参数**：
1. 先使用 Read 工具读取 `docs/memory/domains.md`
2. 在 `domains.md` 中找到指定领域（如 `## auth`）的区块
3. 获取该领域下的文件名列表（候选集合）
4. 再从 catalog.md 的 `## Entries` 区，过滤出文件名在候选集合中的行

**如果有 `time:` 参数**：
对 catalog.md `## Entries` 区的每行，过滤行首日期字段：
- `time:7d` → 最近 7 天（与今日日期对比）
- `time:2026-02` → 2026 年 2 月（日期前缀匹配）
- `time:2026-01-01..2026-01-31` → 日期区间

**无参数时**：直接输出 catalog.md 的完整 `## Entries` 区内容。

### 3. 统计信息

读取 `docs/memory/index.json`（使用 Read 工具），获取 `stats` 字段：
- `stats.total` → 总条目数
- `stats.totalSizeBytes` → 总大小（换算为 KB）

若 index.json 不存在，则统计数量为过滤后的行数，大小显示"未知"。

### 4. 输出格式

```
Memory 目录索引（共 N 条 | 总大小: XXX KB）

## Entries
2026-02-18 | refactor-plan  | refactor,design,memory | 文件系统式记忆重构方案
2026-02-14 | jwt-impl       | auth,jwt,security      | JWT 认证模块实现
2026-01-20 | auth-refactor  | auth,refactor          | 认证模块重构
...

提示: 使用 /longmemory:get <文件名> 查看概览，--full 查看完整内容
```

如果参数触发了过滤，在标题中注明：

```
Memory 目录索引（共 N 条，已过滤 domain:auth | 总大小: XXX KB）
```

### 5. --global 参数：全局经验库

1. **发现全局库路径**：
   - 先读项目内 `.claude/longmemory.json`（若存在），取 `globalMemoryPath` 字段
   - 否则读 `~/.claude/longmemory/config.json`，取 `globalMemoryPath` 字段
2. 使用 Read 工具读取 `{globalMemoryPath}/catalog.md`
3. 同样支持 `time:` 和 `domain:` 过滤
4. 输出时标注 `[全局经验库]`

### 6. 兼容模式（catalog.md 不存在时）

按以下降级顺序处理：

**降级 1：读取 index.json**
使用 Read 工具读取 `docs/memory/index.json`，从 `entries` 数组构建列表，每条格式化为：
```
日期 | 文件名（去掉.md） | 标签列表 | 标题
```

**降级 2：文件系统扫描**
使用 Bash 命令扫描目录：
```bash
ls -1 docs/memory/*.md 2>/dev/null | grep -v "^\."
```
对每个文件用 Read 工具读取前 5 行，提取 `#` 标题和日期（从文件名解析），构建简化列表。

兼容模式下输出时注明：`（catalog.md 不存在，以下为降级模式输出）`

### 7. 空结果处理

如果没有找到任何条目：

```
未找到 memory 条目。

使用 /longmemory:save 创建第一条记录。
```

## 注意事项

- 直接输出 catalog.md 内容，保持原始格式，无需重新排版
- `domain:` 过滤需要先读 domains.md 获取候选文件名集合
- `time:` 过滤在 Entries 行上按日期字段操作，不读取实际文件
- 统计数据优先从 index.json 的 `stats` 字段获取，避免重复计数
- 全局经验库路径必须动态发现，不能硬编码
