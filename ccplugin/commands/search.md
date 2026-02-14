---
description: 在 memory 中智能搜索，支持 scope/time/project 三维过滤，利用索引加速
argument-hint: <关键词> [scope:类型] [time:范围] [project:路径]
allowed-tools: Bash, Read, Glob, Grep
---

# LongMemory Search Command

在 memory 中智能搜索，支持多维度过滤和索引加速。

## 执行步骤

### 1. 解析参数
从用户输入中提取：
- 关键词：不带前缀的文本
- `scope:` 搜索范围（如 scope:decisions, scope:changes）
- `time:` 时间范围（如 time:7d, time:2026-02）
- `project:` 项目路径（如 project:/api）

### 2. Scope 映射
将 scope 参数映射到 markdown section 标题：
- `scope:decisions` → "Decisions & Rationale" 或 "## 决策与理由"
- `scope:changes` → "Changes Made" 或 "## 变更内容"
- `scope:todos` → "Open Items" / "Follow-ups" 或 "## 待办事项"
- `scope:learnings` → "Learnings" 或 "## 经验教训"
- `scope:summary` → "Summary" 或 "## 总结"
- `scope:files` → "Technical Details" 或 "## 技术细节"

### 3. 索引加速查找
使用 Read 工具读取 `docs/memory/index.json`：
- 索引存在：
  - 用 `tags` 字段匹配关键词，缩小候选文件范围
  - 用 `sections` 字段判断 scope 对应的 section 是否存在
  - 用 `filename` 过滤 time 和 project 参数
  - 返回匹配的文件路径列表
- 索引不存在：跳到步骤 4

### 4. 全文搜索（回退）
使用 Bash 工具执行 grep 搜索：
```bash
# 基础关键词搜索
grep -il "关键词" docs/memory/*.md 2>/dev/null

# 带 scope 的搜索（先找包含 section 的文件）
grep -l "## Decisions" docs/memory/*.md | xargs grep -il "关键词"

# 时间过滤
ls -1 docs/memory/*2026-02*.md | xargs grep -il "关键词"
```

### 5. 应用多维过滤
对候选文件列表应用所有过滤条件：
- `time:` 参数：过滤文件名中的日期
- `project:` 参数：过滤 tags 中包含项目路径的文件
- `scope:` 参数：只保留包含指定 section 的文件

### 6. 读取策略
根据匹配结果数量：
- ≤5 个文件：全部读取完整内容
- >5 个文件：只读取最新 5 个，显示总匹配数

### 7. 分层感知输出
按时间倒序显示搜索结果，标注层级：

```
搜索结果: N 条匹配（已读取 M 条完整内容）

━━━ docs/memory/2026-02-14-auth-impl.md [L0] ━━━
# 实现用户认证功能

## Decisions & Rationale
选择 JWT 作为认证方案，因为...

[完整内容]

━━━ docs/memory/2026-02-07-api-design.md [L1 压缩] ━━━
# API 设计评审

## Summary
评审并确定了 v2 API 接口...

[压缩内容]

💡 提示: 这是压缩版本，可能缺少细节。使用 /longmemory:get --original 2026-02-07-api-design.md 查看完整内容

━━━ docs/memory/2026-01-10-db-migration.md [L2 归档] ━━━
# 数据库迁移方案

[归档内容]

💡 提示: 这是归档版本。使用 /longmemory:get --original 查看完整内容
```

### 8. 未找到处理
如果没有匹配结果：
```
未找到匹配 "关键词" 的 memory 条目

已应用过滤:
- scope: decisions
- time: 最近 7 天
- project: /api

建议：
- 移除部分过滤条件扩大搜索范围
- 使用 /longmemory:list 查看所有条目
- 尝试不同的关键词
```

## 注意事项
- 必须使用 Bash grep 命令（Windows 兼容性）
- 优先使用索引加速，回退到全文搜索
- 支持中英文 section 标题匹配
- 压缩/归档版本必须提示可能缺少细节
- 关键词搜索大小写不敏感
- scope 搜索时先定位 section，再在 section 内搜索关键词
