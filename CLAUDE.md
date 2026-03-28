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

- 项目记忆：`docs/memory/`（L0 目录索引 / L1 概览 / L2 完整内容，当前 7 条）
- 全局经验库：`~/.claude/longmemory/`

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
