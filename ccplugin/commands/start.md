---
description: "加载全局经验库概览，检测技术栈，注入领域信息到当前会话上下文"
---

# /longmemory:start — 加载全局经验库

在会话开始时手动运行此命令，加载全局经验库的领域概览和技术栈信息。

## 执行步骤

### 1. 发现全局经验库路径

按优先级查找：

1. **项目级配置**: `{cwd}/.claude/longmemory.json` 中的 `globalMemoryPath` 字段
2. **用户级配置**: `~/.claude/longmemory/config.json` 中的 `globalMemoryPath` 字段
3. **默认路径**: `~/.claude/longmemory`

### 2. 检查配置

- 读取 `config.json`，确认 `autoRecall` 是否为 `true`
- 若全局库不存在或 `autoRecall` 为 `false`，输出提示并结束

### 3. 读取领域信息

**优先从 `triggers.json` 读取**（精确可靠）：
- 解析每个域名和关键词数量
- 格式: `{domain}({N}个关键词)`

**备选从 `catalog.md` 解析**（当 triggers.json 不存在时）：
- 解析领域概览表格行 `| domain | count | keywords |`
- 提取领域名称列表

### 4. 检测项目技术栈

检查当前工作目录下的标识文件：

| 文件 | 技术栈 |
|------|--------|
| `package.json` | Node.js/TypeScript |
| `Cargo.toml` | Rust |
| `go.mod` | Go |
| `requirements.txt` / `pyproject.toml` | Python |
| `*.csproj` | .NET/C# |
| `pom.xml` | Java/Maven |
| `build.gradle` | Java/Gradle |

### 5. 输出加载结果

向用户展示加载结果，格式：

```
[LongMemory] 全局经验库已加载。
可用领域: {domain_list}
技术栈检测: {tech_stack}
使用 /longmemory:recall <关键词> 查询经验。
```

若全局库未配置或不存在，输出：

```
[LongMemory] 全局经验库未找到。
使用 /longmemory:learn 从当前会话提炼经验并创建全局库。
```
