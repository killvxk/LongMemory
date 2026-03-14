---
description: 将 LongMemory 记忆系统使用规范注入到项目的 CLAUDE.md 中
allowed-tools: Bash, Read, Write, Edit, Glob
---

# LongMemory Prompts — 注入记忆系统规范到 CLAUDE.md

将 LongMemory 的记忆系统使用规范写入当前项目的 `CLAUDE.md`，使每次会话自动遵循记忆优先的工作流。

## 执行步骤

### 1. 检测全局经验库状态

按优先级查找全局经验库配置：

1. 读取 `{cwd}/.claude/longmemory.json` 中的 `globalMemoryPath`
2. 读取 `~/.claude/longmemory/config.json` 中的 `globalMemoryPath`
3. 默认路径 `~/.claude/longmemory`

检查全局经验库是否存在（config.json 是否存在），记录状态供步骤 3 使用。

### 2. 检测项目记忆状态

检查当前项目的记忆使用情况：

```bash
# 检查 docs/memory/ 目录是否存在及条目数
ls docs/memory/*.md 2>/dev/null | grep -v overview | grep -v catalog | grep -v domains | wc -l
# 检查 docs/memory/catalog.md 是否存在
ls docs/memory/catalog.md 2>/dev/null
```

记录以下动态信息：
- `has_global_lib`：全局经验库是否可用（true/false）
- `memory_count`：项目记忆条目数
- `has_catalog`：是否已有 catalog.md

### 3. 生成规范内容

根据步骤 1-2 收集的状态信息，生成以下规范段落。

**重要**：下方模板中被 `{变量}` 标记的位置，需要用步骤 1-2 收集的动态信息替换。没有 `{变量}` 标记的部分原样输出。

````markdown
## LongMemory 记忆系统

本项目使用 [LongMemory](https://github.com/killvxk/LongMemory) 管理会话记忆和经验复用。

```yaml
# 记忆系统配置
memory_first: true              # 任何操作前先查记忆

# 存储路径
memory_path: docs/memory

# 自动化行为
longmemory:
  auto_start: true              # 会话开始自动加载全局经验库（SessionStart hook）
  auto_recall: true             # 任务开始前自动检索相关经验
  auto_save: true               # 任务完成后自动保存会话记忆（Stop hook 提醒）
  auto_learn: true              # 有通用经验时提炼到全局经验库
```

### 会话生命周期

#### 会话开始（Phase 0）

1. **加载经验库**：SessionStart hook 自动加载全局经验库关键词到上下文（零手动操作）
2. **召回相关经验**：根据当前任务关键词运行 `/longmemory:recall <关键词>` 检索已有经验
3. **恢复上下文**：检查 `docs/memory/` 和 `docs/plans/` 是否有未完成的计划或上次会话记录，有则优先恢复

#### 每个子任务开始前（Phase 3）

- 运行 `/longmemory:recall <子任务相关关键词>` 检查是否有相关经验可复用
- 避免重复踩坑或重复劳动

#### 会话结束（Phase 4）

1. 运行 `/longmemory:save` 保存当前会话记忆到 `docs/memory/`
2. 若本次会话产生了可复用的通用经验（调试技巧、平台踩坑、架构决策等），运行 `/longmemory:learn` 提炼到全局经验库
3. 保存内容须包含：任务描述、提交记录、关键变更、技术决策、未完成项

#### 中断恢复

- 恢复时自动加载全局经验（SessionStart hook）
- 读取 `docs/plans/` 下最新计划文件
- 运行 `/longmemory:search scope:todos` 检查未完成项
- 从未完成项继续执行

### 阶段检查点

| 检查点 | 记忆操作 |
|--------|---------|
| Phase 0 完成 | 全局经验已加载、相关经验已召回 |
| 每个子任务开始 | `/longmemory:recall <子任务关键词>` |
| 每个子任务完成 | 更新计划状态、记录测试结果 |
| Phase 4 完成 | `/longmemory:save` + `/longmemory:learn`（如有通用经验） |

### 自动化 Hook

| Hook | 触发时机 | 功能 |
|------|---------|------|
| SessionStart | 会话启动 | 自动加载全局经验库领域概览和触发关键词到上下文 |
| Stop | 会话结束 | 检测未保存的工作，提醒运行 `/longmemory:save` |
| PreCompact | 上下文压缩前 | 检测未保存变更，建议先保存记忆 |

### 存储路径

- 项目记忆：`docs/memory/`（L0 目录索引 / L1 概览 / L2 完整内容，当前 {memory_count} 条）
- 全局经验库：`{global_memory_path}`

### 命令参考

| 命令 | 场景 |
|------|------|
| `/longmemory:recall <关键词>` | 开始工作前，检索全局经验库中的相关经验 |
| `/longmemory:save` | 完成工作后，保存会话记忆到 `docs/memory/` |
| `/longmemory:learn [domain]` | 提炼通用经验到全局经验库 |
| `/longmemory:search <关键词>` | 在项目记忆中智能搜索，支持 scope/time 过滤 |
| `/longmemory:start` | 手动加载全局经验库概览（通常由 hook 自动完成） |
| `/longmemory:list` | 查看记忆目录索引，支持 domain/time 过滤 |
| `/longmemory:get <id>` | 获取记忆概览（默认 L1），`--full` 获取完整内容 |
| `/longmemory:all` | 分层加载全部记忆：`level:L0` / `level:L1` / `level:L2` |
| `/longmemory:compact` | 磁盘清理：`dry-run` / `clean <天数>` / `restore <文件>` |
| `/longmemory:prompts` | 更新本段 CLAUDE.md 中的记忆系统规范 |

### 禁止行为

- **会话开始时未运行 `/longmemory:recall` 检索已有经验就直接开始工作**
- **遇到技术问题未先检索已有经验就直接尝试解决**
- **会话结束或任务完成后未运行 `/longmemory:save` 保存记忆**
- **产生通用经验后未运行 `/longmemory:learn` 提炼到全局经验库**
- 未查本地上下文（`docs/memory/`）即给出结论
- 执行完成后未写入 memory 总结
````

**动态替换规则**：

| 占位符 | 替换值 | 示例 |
|--------|--------|------|
| `{memory_count}` | 步骤 2 检测到的项目记忆条目数；若为 0 则显示 `尚无记忆` | `当前 5 条` / `尚无记忆` |
| `{global_memory_path}` | 步骤 1 发现的全局经验库路径 | `~/.claude/longmemory/` |

**动态追加**：
- 如果 `has_global_lib` 为 false，在规范末尾追加：
  ```
  > **注意**：全局经验库尚未初始化。首次使用 `/longmemory:learn` 时会自动创建。
  ```

### 4. 写入 CLAUDE.md

使用 Read 工具检查 `CLAUDE.md` 的当前状态：

**情况 A：文件不存在**
- 使用 Write 工具创建 `CLAUDE.md`，写入步骤 3 生成的规范内容

**情况 B：文件存在但无 `## LongMemory` 段落**
- 使用 Edit 工具在文件末尾追加规范内容（前面加一个空行分隔）

**情况 C：文件存在且有 `## LongMemory` 段落**
- 定位 `## LongMemory` 到下一个同级标题（`## `）之间的全部内容（含 `## LongMemory` 行本身）
- 使用 Edit 工具将这段内容整体替换为步骤 3 生成的新规范内容（幂等更新）

### 5. 展示结果

向用户确认写入成功：

```
✓ LongMemory 使用规范已写入 CLAUDE.md

  全局经验库: {可用/未初始化}（路径: {global_memory_path}）
  项目记忆: {N 条 / 尚无记忆}
  注入模式: {创建新文件 / 追加到已有文件 / 更新已有段落}

💡 每次会话启动时 Claude 会自动遵循这些规则
💡 再次运行 /longmemory:prompts 可更新规范内容（幂等）
```

## 卸载说明

如需移除规范，手动删除 `CLAUDE.md` 中 `## LongMemory 记忆系统` 段落即可。
