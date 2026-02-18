---
description: 获取指定的 memory 条目，支持按文件名、日期或关键词匹配，默认返回概览
argument-hint: [latest|日期|文件名|关键词] [--full] [--global]
allowed-tools: Bash, Read, Glob, Grep
---

# LongMemory Get Command

获取指定的 memory 条目，默认返回 L1 概览，按需加载 L2 完整内容。

## 执行步骤

### 1. 解析参数

识别用户输入的查询类型和标志：
- 空参数或 `latest` → 获取最新一条
- `--original <filename>` → 从 `.archive/` 读取原始归档版本（保留旧功能）
- `--full` → 读取 L2 完整内容（而非默认的 L1 概览）
- `--global` → 从全局经验库查询
- `YYYY-MM-DD` 格式 → 日期精确匹配
- 完整文件名（含 .md） → 直接读取
- 其他关键词 → 文件名模糊匹配，失败则内容搜索

### 2. 定位目标文件

**优先读取 `docs/memory/catalog.md` 的 `## Entries` 区**（使用 Read 工具）：

- `latest` → 取 Entries 区第一行（最新条目）
- 日期 → 匹配行首日期字段
- 文件名 → 匹配文件名字段（去掉 .md 后缀匹配）
- 关键词 → 匹配标题或标签字段

catalog.md 不存在时，回退读取 `docs/memory/index.json` 的 `entries` 数组做同等匹配：
- 日期匹配：比对 `file` 字段中的日期前缀
- 关键词匹配：搜索 `title`、`tags`、`file` 字段

index.json 也不存在时，使用 Bash 命令做文件系统匹配：
```bash
# 日期匹配
ls -1 docs/memory/*2026-02-14*.md 2>/dev/null

# 关键词匹配（文件名）
ls -1 docs/memory/*.md 2>/dev/null | grep -i "关键词"
```

### 3. 默认输出 L1 概览

定位到目标文件名后（未使用 `--full` 时），按以下顺序获取概览：

1. 检查 catalog.md 的 `## Recent Overviews` 区，找到对应条目的概览块（热数据，0 额外读取）
2. 若不在热数据区，使用 Read 工具读取 `docs/memory/{文件名}.overview.md`（每个记忆对应一个独立概览文件）
3. 若对应的 `.overview.md` 文件不存在，直接进入步骤 4 读取 L2 全文

L1 概览输出格式：
```
docs/memory/2026-02-14-jwt-impl.md [L1 概览]
─────────────────────────────────────────────────
摘要: 实现了基于 JWT 的认证系统，支持 Access/Refresh token 双令牌机制...
关键决策: JWT 而非 Session，Access token 24h，Refresh token 7d
待办: 2 项未完成
标签: auth, jwt, security

提示: 使用 --full 查看完整内容 → /longmemory:get --full 2026-02-14-jwt-impl
```

### 4. --full 参数：读取 L2 完整内容

使用 Read 工具直接读取 `docs/memory/<文件名>.md`，输出完整内容：

```
docs/memory/2026-02-14-jwt-impl.md [L2 完整]
─────────────────────────────────────────────────
[完整文件内容]
```

### 5. --global 参数：全局经验库查询

1. **发现全局库路径**：
   - 先读项目内 `.claude/longmemory.json`（若存在），取 `globalMemoryPath` 字段
   - 否则读 `~/.claude/longmemory/config.json`，取 `globalMemoryPath` 字段
2. **定位条目**：
   - 读取全局 `{globalMemoryPath}/catalog.md` 的 Entries 区，按同样逻辑匹配
   - 或读取全局 `{globalMemoryPath}/triggers.json` 查找关键词
3. **读取域文件**：
   - 找到匹配的域名称后，读取 `{globalMemoryPath}/domains/{域名}.md` 中对应条目
4. 输出时标注 `[全局经验库]`

### 6. --original 参数：归档版本

如果参数为 `--original <filename>`：
- 构建路径：`docs/memory/.archive/<filename>`
- 使用 Read 工具读取归档文件
- 输出时标注 `[归档原始版本]`

### 7. 多条匹配处理

根据匹配结果数量：
- 1 个文件：直接输出概览（或全文）
- 2–5 个文件：全部输出概览，按时间倒序
- > 5 个文件：输出最新 5 条概览，提示总匹配数

### 8. 未找到处理

如果没有匹配结果：

```
未找到匹配的 memory 条目: "查询关键词"

建议：
- 使用 /longmemory:list 查看所有条目
- 使用 /longmemory:search 进行全文搜索
```

## 注意事项

- 默认返回 L1 概览，不自动读取 L2 全文，节省 token
- 若找到 L2 文件但没有对应的 `.overview.md` 概览块，直接输出 L2 内容
- `--original` 读取 `.archive/` 归档目录，与 L2 是不同路径
- 全局经验库路径必须动态发现，不能硬编码
- 匹配优先级：精确文件名 > 日期 > 关键词模糊匹配
