# Learn 命令模板参考

## 经验条目格式

```markdown
## {经验标题（简短，5-15字）}
**触发词**: {5-10个关键词，中英文混合，逗号分隔}
**场景**: {一句话描述适用场景}
**教训**:
- {教训要点1}
- {教训要点2}
- {教训要点3（如有）}
**推荐做法**: {一段话，描述推荐的处理方式}
**来源**: {今天日期 YYYY-MM-DD} {项目名（从 .claude/longmemory.json 或当前目录名获取）}
```

## 触发词选取原则

- 包含该经验最常用的技术术语（英文）
- 包含中文同义词或描述词
- 避免过于泛化的词（如 "error"、"问题"）
- 优先选择在实际编码场景中会出现的词

## 展示格式（向用户确认）

```
从对话中识别到以下通用经验，请确认后存入全局库：

─── 经验 1 ───
## JWT Token 管理
**触发词**: jwt, token, refresh, 过期, expiry, bearer
**场景**: JWT token 的生成、刷新、过期处理
**教训**:
- Access token 应短期（15min-1h），Refresh token 长期（7-30d）
- 永远不要在 JWT payload 中存储敏感信息
**推荐做法**: 使用 rotating refresh tokens，每次刷新时旧 token 立即失效
**来源**: 2026-02-18 my-project

是否存入全局库？(y/n/edit)
```

## 领域文件头格式

```markdown
# {Domain} 经验库

收录与 {领域描述} 相关的通用经验、最佳实践和踩坑记录。

---
```

## triggers.json 结构

```json
{
  "version": "1.0",
  "domains": {
    "{DOMAIN_NAME}": {
      "keywords": ["{触发词1}", "{触发词2}"],
      "file": "domains/{DOMAIN_NAME}.md"
    }
  }
}
```

## catalog.md 初始结构

```markdown
# Global Experience Catalog

## 领域概览
| 领域 | 条目数 | 关键词示例 |
|------|--------|-----------|

## 最近新增
```

## config.json 默认结构

```json
{
  "version": "1.0",
  "globalMemoryPath": "~/.claude/longmemory",
  "autoRecall": true,
  "maxInjectTokens": 500,
  "recentOverviewCount": 10
}
```
