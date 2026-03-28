# Save 命令模板参考

## L2 完整 Memory 文件格式

```markdown
# [会话标题]

**日期**: YYYY-MM-DD
**标签**: tag1, tag2, tag3

## Summary

[2-3 句话总结]

## Changes Made

- 文件路径:行号 - 变更描述
- ...

## Decisions & Rationale

### [决策标题]
- **决策**: ...
- **理由**: ...

## Technical Details

- 配置变更: ...
- API 使用: ...

## Testing

- 测试命令: ...
- 结果: 通过/失败

## Open Items / Follow-ups

- [ ] 待办事项 1
- [ ] 待办事项 2

## Learnings

- 经验 1
- 经验 2
```

## L1 Overview 文件格式

```markdown
### YYYY-MM-DD-brief-description
**摘要**: [Summary 的前2-3句话]
**关键决策**: [Decisions & Rationale 中每条决策的一句话总结，用逗号分隔；若无决策则填"无"]
**待办**: [Open Items 中未完成条目的数量] 项未完成
**标签**: tag1, tag2, tag3
```

## index.json v2 schema

```json
{
  "version": "2.0",
  "lastUpdated": "YYYY-MM-DDTHH:MM:SSZ",
  "stats": {
    "total": 42,
    "totalSizeBytes": 512000
  },
  "entries": [
    {
      "file": "YYYY-MM-DD-brief-description.md",
      "date": "YYYY-MM-DD",
      "title": "标题",
      "tags": ["tag1", "tag2", "tag3"],
      "sizeBytes": 12345,
      "hasOverview": true
    }
  ]
}
```

## index.json v1 → v2 迁移

如果读取到的 index.json 的 `version` 字段为 `"1.0"`，自动执行迁移：
- 删除每个 entry 中的 `layer`、`compacted`、`summary`、`sections` 字段
- 为每个 entry 新增 `"hasOverview": false`（旧版没有 overview 文件）
- 将 `version` 更新为 `"2.0"`
- 重新计算 stats：移除 `byLayer` 字段，保留 `total` 和 `totalSizeBytes`
- 输出提示: "索引已从 v1.0 迁移到 v2.0"

## catalog.md 初始结构

```markdown
# Memory Catalog

## Entries

## Recent Overviews
```

## domains.md 初始结构

```markdown
# Memory Domains
```
