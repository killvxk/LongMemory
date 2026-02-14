---
description: 获取指定的 memory 条目，支持按文件名、日期或关键词匹配
argument-hint: [日期或文件名，如 2026-02-14 或 latest 或 --original <filename>]
allowed-tools: Bash, Read, Glob, Grep
---

# LongMemory Get Command

获取指定的 memory 条目，支持多种匹配方式和原始版本查看。

## 执行步骤

### 1. 解析参数
识别用户输入的查询类型：
- 空参数或 `latest` → 获取最新一条
- `--original <filename>` → 从 `.archive/` 读取原始未压缩版本
- `YYYY-MM-DD` 格式 → 日期精确匹配
- 完整文件名（含 .md） → 直接读取
- 其他关键词 → 文件名模糊匹配，失败则内容搜索

### 2. 索引查找（优先）
使用 Read 工具读取 `docs/memory/index.json`：
- 索引存在：在 `entries` 数组中查找匹配项
  - 日期匹配：比对 `filename` 中的日期前缀
  - 关键词匹配：搜索 `title`、`tags`、`filename` 字段
  - 返回匹配的文件路径列表
- 索引不存在：跳到步骤 3

### 3. 文件系统查找（回退）
使用 Bash 工具执行：
```bash
# 日期匹配
ls -1 docs/memory/*2026-02-14*.md 2>/dev/null

# 关键词匹配（文件名）
ls -1 docs/memory/*.md 2>/dev/null | grep -i "关键词"

# 内容搜索（文件名匹配失败时）
grep -il "关键词" docs/memory/*.md 2>/dev/null
```

### 4. 原始版本处理
如果参数为 `--original <filename>`：
- 构建路径：`docs/memory/.archive/<filename>`
- 使用 Read 工具读取归档文件
- 输出时标注 `[原始未压缩版本]`

### 5. 读取策略
根据匹配结果数量：
- 1 个文件：直接读取完整内容
- 2-5 个文件：全部读取，按时间倒序显示
- >5 个文件：只读取最新 5 个，提示总匹配数

### 6. 分层感知输出
读取文件后检查 frontmatter 中的 `layer` 字段：

**L0 文件（活跃层）**：
```
📄 docs/memory/2026-02-14-auth-impl.md [L0]
─────────────────────────────────────────────────
[完整内容]
```

**L1/L2 文件（压缩/归档层）**：
```
📄 docs/memory/2026-02-07-api-design.md [L1 压缩版本]
─────────────────────────────────────────────────
[压缩后的内容]

💡 提示: 这是压缩版本。使用 /longmemory:get --original 2026-02-07-api-design.md 查看完整内容
```

### 7. 未找到处理
如果没有匹配结果：
```
未找到匹配的 memory 条目: "查询关键词"

建议：
- 使用 /longmemory:list 查看所有条目
- 使用 /longmemory:search 进行全文搜索
```

## 注意事项
- 必须使用 Bash ls/grep 命令（Windows 兼容性）
- 优先使用索引加速查找
- 压缩版本必须提示可查看原始版本
- 支持大小写不敏感的关键词匹配
- 原始版本从 `.archive/` 子目录读取
