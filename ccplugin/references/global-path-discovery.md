# 全局经验库路径发现

按以下优先级查找全局经验库配置，将结果记为 `GLOBAL_PATH`：

**优先级 1**：检查项目内配置
- 读取 `.claude/longmemory.json`
- 如存在，读取其中的 `globalMemoryPath` 字段

**优先级 2**：检查全局配置
- 读取 `~/.claude/longmemory/config.json`
- 如存在，读取其中的 `globalMemoryPath` 字段

**优先级 3**：默认路径
- 使用 `~/.claude/longmemory`

确保目录结构存在：

```bash
mkdir -p {GLOBAL_PATH}/domains
```
