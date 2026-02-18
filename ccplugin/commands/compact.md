---
description: 可选的磁盘清理工具，删除旧记忆的完整内容只保留概览
argument-hint: "[dry-run|restore <filename>|clean <days>]"
allowed-tools: Bash, Read, Write, Glob, Grep
---

# 可选的磁盘清理工具

清理旧记忆文件的完整内容，只保留概览文件，释放磁盘空间。这是一个**可选操作**，不影响正常的记忆查询功能（概览文件始终保留）。

## 执行步骤

### 1. 参数解析

支持以下参数：

| 参数 | 说明 |
|------|------|
| 无参数 | 预览模式，等同 `dry-run` |
| `dry-run` | 预览可清理的文件，不执行实际删除 |
| `clean <days>` | 清理 N 天前的记忆原文（默认 90 天） |
| `restore <filename>` | 从 `.archive/` 恢复指定文件 |

参数示例：
- `/longmemory:compact` → 预览模式
- `/longmemory:compact dry-run` → 预览模式
- `/longmemory:compact clean` → 清理 90 天前的文件
- `/longmemory:compact clean 60` → 清理 60 天前的文件
- `/longmemory:compact restore 2025-11-10-db-migration.md` → 恢复指定文件

### 2. 计算时间边界

使用 Bash 计算时间边界（`clean <days>` 和 `dry-run` 模式需要）：

```bash
# 获取 days 参数，默认 90
DAYS=${DAYS:-90}

# 计算边界日期（跨平台兼容）
BOUNDARY=$(date -d "${DAYS} days ago" +%Y-%m-%d 2>/dev/null || date -v-${DAYS}d +%Y-%m-%d 2>/dev/null)

echo "清理边界: ${BOUNDARY} (${DAYS} 天前)"
```

### 3. 扫描可清理文件

扫描 `docs/memory/` 目录下的所有 `.md` 文件（排除隐藏目录和概览文件）：

```bash
# 列出所有记忆文件
ls docs/memory/*.md 2>/dev/null
```

对每个文件，检查：
1. **文件名日期**：从文件名提取日期（格式 `YYYY-MM-DD-xxx.md`），与边界日期比较
2. **概览文件**：检查对应的概览文件是否存在（`docs/memory/{文件名}.overview.md`，与 L2 文件同目录）
3. **已归档**：检查 `docs/memory/.archive/{文件名}` 是否已存在

只将以下文件纳入可清理列表：
- 日期早于边界日期
- 尚未在 `.archive/` 中存在备份

### 4. 预览模式（dry-run）

输出可清理文件的预览信息：

```
[预览] 可清理的文件 (>90天前):

  - 2025-11-10-db-migration.md (4.2 KB) → 有概览
  - 2025-10-05-auth-setup.md (3.1 KB) → 有概览
  - 2025-09-20-init-project.md (2.8 KB) → 需生成概览

预计可释放: 10.1 KB
概览文件将保留，可通过 /longmemory:get 查看
原文将备份到 docs/memory/.archive/

运行 /longmemory:compact clean 90 执行清理
```

文件大小通过以下方式获取：

```bash
# 获取文件大小（跨平台）
wc -c < docs/memory/FILENAME.md 2>/dev/null || stat -f%z docs/memory/FILENAME.md 2>/dev/null || stat -c%s docs/memory/FILENAME.md 2>/dev/null
```

"需生成概览"表示该文件尚无对应的 `.overview.md` 文件，执行 clean 时会先生成概览再删除原文。

如果没有可清理的文件，输出：

```
没有超过 90 天的记忆文件可以清理

最旧的文件: 2026-01-15-auth-refactor.md (34 天前)

下次检查时间建议: 2026-05-19 (距今 90 天)
```

### 5. 清理模式（clean）

对每个需要清理的文件执行以下操作：

#### 5.1 确保概览文件存在

检查该文件是否有对应的概览文件：`docs/memory/{文件名}.overview.md`（与 L2 文件同目录）。

如果概览文件**不存在**，先生成概览：

读取原文件内容，生成概览文件，格式与 save.md 生成的一致：

```markdown
### {文件名（去掉.md后缀）}
**摘要**: {从原文件 Summary 部分提取前2-3句话}
**关键决策**: {从原文件 Decisions & Rationale 提取每条决策的一句话总结，逗号分隔}
**待办**: {未完成 TODO 数量} 项未完成
**标签**: {从原文件提取的标签}
```

使用 Write 工具将概览写入 `docs/memory/{文件名}.overview.md`。

#### 5.2 备份原文

创建备份目录（如不存在）：

```bash
mkdir -p docs/memory/.archive
```

将原文件复制到备份目录：

```bash
cp docs/memory/{filename}.md docs/memory/.archive/{filename}.md
```

#### 5.3 删除原文

删除 `docs/memory/` 中的原始完整内容文件：

```bash
rm docs/memory/{filename}.md
```

#### 5.4 更新 index.json

读取 `docs/memory/index.json`，找到对应的 entry，更新以下字段：
- `sizeBytes`: 置为 `0`（原文已删除）
- `hasOverview`: 置为 `true`
- `archived`: 置为 `true`

保留其他字段（`file`、`date`、`title`、`tags` 等）。

使用 Write 工具写入更新后的 index.json。

#### 5.5 更新 catalog.md

读取 `docs/memory/catalog.md`，在 Entries 区找到对应条目，在其末尾追加 `[已归档]` 标记：

原：`- 2025-11-10 | db-migration | 数据库迁移 | ...`
改：`- 2025-11-10 | db-migration | 数据库迁移 | ... [已归档]`

使用 Write 工具写入更新后的 catalog.md。

### 6. 清理完成输出

```
✓ 磁盘清理完成

已清理: 3 个文件
释放空间: 10.1 KB
原文已备份到 docs/memory/.archive/

保留的概览文件可通过 /longmemory:get 查看
使用 /longmemory:compact restore <filename> 恢复原文
```

如果处理过程中有文件生成了新概览，额外提示：

```
新生成概览: 1 个
  - 2025-09-20-init-project.md.overview.md
```

### 7. 恢复模式（restore）

当参数为 `restore <filename>` 时：

**步骤 1**：检查备份文件是否存在：

```bash
ls docs/memory/.archive/{filename} 2>/dev/null
```

如果不存在，输出：

```
错误: 备份文件 "{filename}" 不存在

已备份的文件列表:
  - 2025-11-10-db-migration.md
  - 2025-10-05-auth-setup.md
  ...

使用 /longmemory:compact dry-run 查看可用备份
```

**步骤 2**：恢复文件：

```bash
cp docs/memory/.archive/{filename} docs/memory/{filename}
```

**步骤 3**：更新 index.json：
- 找到对应的 entry
- `sizeBytes`: 更新为恢复后文件的实际大小
- `archived`: 置为 `false`

**步骤 4**：更新 catalog.md：
- 找到对应条目，移除 `[已归档]` 标记

**步骤 5**：输出确认：

```
✓ 已从备份恢复: {filename}
  位置: docs/memory/{filename}
  大小: 4.2 KB
✓ 索引已更新，[已归档] 标记已移除
```

## 错误处理

- 如果 `docs/memory/` 目录不存在，提示用户先运行 `/longmemory:save`
- 如果 `index.json` 不存在，跳过 index 更新步骤（只做文件操作）
- 如果备份目录创建失败，终止清理操作并输出错误信息
- 如果某个文件删除失败，记录错误并继续处理其他文件
- 如果 index.json 更新失败，保留原 index.json，输出警告提示手动检查

## 安全注意事项

- 本命令会**永久删除** `docs/memory/` 中的原文内容（原文备份在 `.archive/`）
- 执行 `clean` 前，建议先运行 `dry-run` 确认范围
- `.archive/` 目录中的备份不会被自动删除，可随时通过 `restore` 恢复
- 如果需要彻底清除备份，用户需要手动删除 `.archive/` 目录中的文件

## 跨平台注意事项

- 文件复制：优先使用 Bash `cp` 命令，Windows 下使用 `copy`
- 文件删除：优先使用 Bash `rm` 命令，Windows 下使用 `del`
- 目录创建：使用 `mkdir -p` 或 Windows 下 `New-Item -ItemType Directory -Force`
- 文件大小：跨平台获取方式见步骤 4 中的示例
