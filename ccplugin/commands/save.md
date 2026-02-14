---
description: 保存当前工作记忆到项目的 docs/memory 目录，自动更新索引
allowed-tools: Bash, Read, Write, Glob, Grep
---

# 保存工作记忆

你需要将当前会话的工作记忆保存到项目的 `docs/memory/` 目录，并更新索引文件。

## 执行步骤

### 1. 准备目录结构

检查并创建必要的目录：

```bash
mkdir -p docs/memory
```

### 2. 收集 Git 上下文

如果当前目录是 git 仓库，收集变更信息：

```bash
# 检查是否是 git 仓库
if git rev-parse --git-dir > /dev/null 2>&1; then
  echo "=== Git Status ==="
  git status --short
  echo ""
  echo "=== Recent Changes ==="
  git diff --stat
  echo ""
  echo "=== Recent Commits ==="
  git log --oneline -5
fi
```

### 3. 分析会话内容

回顾当前会话的对话历史，提取以下 7 个部分的内容：

1. **Summary**: 本次会话的核心目标和完成情况（2-3 句话）
2. **Changes Made**: 修改的文件列表和主要变更类型
3. **Decisions & Rationale**: 关键技术决策及其理由
4. **Technical Details**: 重要的技术细节、配置变更、API 使用
5. **Testing**: 测试执行情况、通过/失败状态
6. **Open Items / Follow-ups**: 未完成的任务、待解决的问题
7. **Learnings**: 本次会话中的经验教训、最佳实践

**注意事项**：
- 不要包含敏感信息（密钥、密码、个人数据）
- 优先引用文件路径和行号，而非大段复制代码
- 保持简洁，捕获关键上下文而非流水账
- 如果某个 section 没有内容，可以省略

### 4. 生成文件名

使用格式：`YYYY-MM-DD-brief-description.md`

- 日期使用今天的日期
- brief-description 从 Summary 中提取 2-4 个关键词，用连字符连接
- 如果文件名已存在，追加序号：`YYYY-MM-DD-brief-description-2.md`

检查文件名冲突：

```bash
# 扫描现有文件
ls docs/memory/ 2>/dev/null | grep "^$(date +%Y-%m-%d)"
```

### 5. 写入 Memory 文件

使用 Write 工具创建文件，格式如下：

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

### 6. 更新索引文件

读取或创建 `docs/memory/index.json`：

```bash
# 检查索引文件是否存在
if [ ! -f docs/memory/index.json ]; then
  echo "索引文件不存在，将创建初始索引"
fi
```

如果文件不存在，创建初始结构：

```json
{
  "version": "1.0",
  "lastUpdated": "YYYY-MM-DDTHH:MM:SSZ",
  "stats": {
    "total": 0,
    "byLayer": {
      "L0": 0,
      "L1": 0,
      "L2": 0
    },
    "totalSizeBytes": 0
  },
  "entries": []
}
```

添加新的 entry：

```json
{
  "file": "YYYY-MM-DD-brief-description.md",
  "date": "YYYY-MM-DD",
  "title": "[从文件中提取的标题]",
  "summary": "[Summary 的第一句话]",
  "layer": "L0",
  "sizeBytes": 12345,
  "tags": ["tag1", "tag2", "tag3"],
  "compacted": false,
  "sections": ["Summary", "Changes Made", "Decisions & Rationale", "Technical Details", "Testing", "Open Items / Follow-ups", "Learnings"]
}
```

**提取 tags**：从内容中识别 3-5 个关键词，如：
- 技术栈名称（React, Python, Azure）
- 功能模块（auth, api, database）
- 操作类型（refactor, bugfix, feature）

**获取文件大小**：

```bash
# Linux/macOS
wc -c < docs/memory/YYYY-MM-DD-brief-description.md

# 或使用 stat（跨平台）
stat -c%s docs/memory/YYYY-MM-DD-brief-description.md 2>/dev/null || stat -f%z docs/memory/YYYY-MM-DD-brief-description.md
```

更新 stats：
- `total`: 总条目数 +1
- `byLayer.L0`: L0 层计数 +1
- `totalSizeBytes`: 累加新文件大小
- `lastUpdated`: 当前时间戳

使用 Write 工具覆盖写入更新后的 index.json。

### 7. 检查是否需要压缩

统计 L0 层的条目数：

```bash
# 从 index.json 中提取 L0 计数
# 如果 > 10，提示用户
```

如果 L0 条目数 > 10，输出提示：

```
✓ Memory 已保存到 docs/memory/YYYY-MM-DD-brief-description.md

注意: 当前有 N 条 L0 记忆，建议运行 /longmemory:compact 进行压缩归档。
```

否则输出：

```
✓ Memory 已保存到 docs/memory/YYYY-MM-DD-brief-description.md
✓ 索引已更新 (共 N 条记忆: L0: X | L1: Y | L2: Z)
```

## 错误处理

- 如果无法创建目录，提示用户检查权限
- 如果 git 命令失败，跳过 git 上下文收集
- 如果索引文件损坏，备份后重新创建
- 如果文件写入失败，保留原索引不变

## 完成标准

- [x] docs/memory/ 目录存在
- [x] Memory 文件已创建，包含所有相关 sections
- [x] index.json 已更新，新 entry 正确添加
- [x] stats 统计数据正确
- [x] 用户收到保存成功的确认消息
