---
description: 保存当前工作记忆到项目的 docs/memory 目录，自动更新索引
allowed-tools: Bash, Read, Write, Glob, Grep
---

# 保存工作记忆

将当前会话的工作记忆保存到项目的 `docs/memory/` 目录，并维护 L0/L1/L2 三层检索结构。

## 执行步骤

### 1. 准备目录结构

检查并创建必要的目录：

```bash
mkdir -p docs/memory
```

### 2. 收集 Git 上下文

如果当前目录是 git 仓库，收集变更信息：

```bash
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

如果 git 命令失败，跳过此步骤，继续后续操作。

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
- brief-description 从 Summary 中提取 2-4 个关键词，用连字符连接，全部小写
- 如果文件名已存在，追加序号：`YYYY-MM-DD-brief-description-2.md`

检查文件名冲突：

```bash
ls docs/memory/ 2>/dev/null | grep "^$(date +%Y-%m-%d)"
```

### 5. 写入 L2 完整 Memory 文件

使用 Write 工具创建 `docs/memory/YYYY-MM-DD-brief-description.md`。

格式模板参见 `${CLAUDE_PLUGIN_ROOT}/references/save-templates.md` 中的 "L2 完整 Memory 文件格式"。

### 6. 生成 .overview.md 概览文件（L1）

使用 Write 工具创建 `docs/memory/YYYY-MM-DD-brief-description.overview.md`。

从 L2 文件中提取内容，按 `${CLAUDE_PLUGIN_ROOT}/references/save-templates.md` 中 "L1 Overview 文件格式" 写入。

### 7. 更新 catalog.md（L0 目录索引）

读取 `docs/memory/catalog.md`，如果不存在则创建初始结构：

```markdown
# Memory Catalog

## Entries

## Recent Overviews
```

**操作逻辑**：

1. 在 `## Entries` 下追加新行，格式为：
   ```
   YYYY-MM-DD | brief-description | tag1,tag2,tag3 | 会话标题
   ```

2. 在 `## Recent Overviews` 区域顶部（紧接标题行后）插入新条目的概览内容（与 .overview.md 内容相同）：
   ```markdown
   ### YYYY-MM-DD-brief-description
   **摘要**: ...
   **关键决策**: ...
   **待办**: N 项未完成
   **标签**: tag1, tag2, tag3
   ```

3. 统计 `## Recent Overviews` 下的概览条目数（通过计算 `### ` 开头的行数）：
   - 如果条目数超过 10，移除区域末尾最旧的概目（其对应的独立 .overview.md 文件已在步骤 6 创建，不需要额外操作）

如果 catalog.md 格式异常（无法解析 `## Entries` 或 `## Recent Overviews` 区域），则直接追加到文件末尾，不覆盖原内容。

使用 Write 工具覆盖写入更新后的 catalog.md。

### 8. 更新 domains.md（领域索引）

读取 `docs/memory/domains.md`，如果不存在则按 `${CLAUDE_PLUGIN_ROOT}/references/save-templates.md` 中 "domains.md 初始结构" 创建。

**操作逻辑**：根据新条目的 tags，对每个 tag：
1. 查找 `## tag名` section，存在则追加条目并将计数 `(N)` 更新为 `(N+1)`
2. 不存在则在文件末尾追加 `## tag名 (1)` + `- YYYY-MM-DD-brief-description`

一条记忆可以出现在多个领域下（每个 tag 对应一个领域）。

使用 Write 工具覆盖写入更新后的 domains.md。

### 9. 更新 index.json（v2 schema）

读取 `docs/memory/index.json`，如果不存在则按 `${CLAUDE_PLUGIN_ROOT}/references/save-templates.md` 中 "index.json v2 schema" 创建初始结构。如果 `version` 为 `"1.0"`，按同文件中 "index.json v1 → v2 迁移" 执行迁移。

**添加新 entry**：

获取文件大小：
```bash
wc -c < docs/memory/YYYY-MM-DD-brief-description.md 2>/dev/null || \
  stat -c%s docs/memory/YYYY-MM-DD-brief-description.md 2>/dev/null || \
  stat -f%z docs/memory/YYYY-MM-DD-brief-description.md 2>/dev/null || \
  echo 0
```

在 `entries` 数组末尾追加新 entry（含 file, date, title, tags, sizeBytes, hasOverview: true）。

**更新 stats**：`total` = entries 长度，`totalSizeBytes` = 所有 sizeBytes 累加，`lastUpdated` = 当前 ISO 8601。

如果 index.json 损坏（JSON 解析失败），备份为 `index.json.bak` 后重新创建。

使用 Write 工具覆盖写入更新后的 index.json。

### 10. 输出完成提示

保存全部完成后，输出：

```
✓ Memory 已保存到 docs/memory/YYYY-MM-DD-brief-description.md
✓ 概览已生成: YYYY-MM-DD-brief-description.overview.md
✓ 索引已更新 (共 N 条记忆)

💡 如果本次会话有通用化的经验（与项目无关），可运行 /longmemory:learn 存入全局经验库
```

将 `N` 替换为 index.json 中更新后的 `stats.total` 值。

## 错误处理

- **目录创建失败**: 提示用户检查写入权限
- **git 命令失败**: 跳过 git 上下文收集，继续后续步骤
- **index.json 损坏**: 备份为 `index.json.bak` 后重新创建
- **catalog.md 格式异常**: 追加到文件末尾，不覆盖原内容
- **文件写入失败**: 保留原索引不变，提示用户具体错误

## 完成标准

- [ ] `docs/memory/` 目录存在
- [ ] L2 Memory 文件已创建（`YYYY-MM-DD-brief-description.md`）
- [ ] L1 Overview 文件已创建（`YYYY-MM-DD-brief-description.overview.md`）
- [ ] `catalog.md` 已更新（Entries 追加、Recent Overviews 更新）
- [ ] `domains.md` 已更新（按 tags 分域索引）
- [ ] `index.json` 已更新为 v2 schema，新 entry 已添加
- [ ] 用户收到保存成功的确认消息和经验提示
