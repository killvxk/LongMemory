---
description: 压缩归档历史记忆，将过期的 L0 压缩为 L1，L1 压缩为 L2
argument-hint: "[force|dry-run|restore <filename>]"
allowed-tools: Bash, Read, Write, Glob, Grep
---

# 压缩归档历史记忆

将过期的记忆文件按时间分层压缩，减少存储空间并保持索引清晰。

## 分层策略

- **L0 (详细层)**: 最近 7 天的记忆，保留完整内容
- **L1 (压缩层)**: 7-30 天的记忆，保留关键信息
- **L2 (归档层)**: 30 天以上的记忆，仅保留摘要和关键决策

## 执行步骤

### 1. 参数解析

支持以下参数：

- **无参数**: 自动压缩需要降级的文件
- **force**: 强制重新压缩所有非 L0 文件
- **dry-run**: 预览压缩效果，不实际执行
- **restore <filename>**: 从 `.archive/` 恢复原始文件到 `docs/memory/`

### 2. 读取索引文件

检查 `docs/memory/index.json` 是否存在：

```bash
if [ ! -f docs/memory/index.json ]; then
  echo "索引文件不存在，正在扫描 docs/memory/ 生成初始索引..."
fi
```

如果不存在，扫描 `docs/memory/*.md` 生成初始索引：

```bash
# 使用 ls 扫描（Windows 兼容）
ls docs/memory/*.md 2>/dev/null
```

对每个文件：
- 提取日期（从文件名）
- Read 读取标题和 Summary
- 计算文件大小
- 默认 layer 为 L0，compacted 为 false

### 3. 计算分层边界

使用 Bash 计算时间边界：

```bash
# 获取今天日期
TODAY=$(date +%Y-%m-%d)

# L0/L1 边界：7 天前
L1_BOUNDARY=$(date -d "7 days ago" +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d 2>/dev/null)

# L1/L2 边界：30 天前
L2_BOUNDARY=$(date -d "30 days ago" +%Y-%m-%d 2>/dev/null || date -v-30d +%Y-%m-%d 2>/dev/null)

echo "分层边界:"
echo "  L0: >= $L1_BOUNDARY (最近 7 天)"
echo "  L1: $L2_BOUNDARY ~ $L1_BOUNDARY (7-30 天)"
echo "  L2: < $L2_BOUNDARY (30 天以上)"
```

### 4. 识别需要降级的文件

遍历 index.json 的 entries，找出需要降级的文件：

**L0 → L1 条件**：
- `layer == "L0"`
- `date < L1_BOUNDARY`

**L1 → L2 条件**：
- `layer == "L1"`
- `date < L2_BOUNDARY`

**force 模式**：
- 重新压缩所有 `layer == "L1"` 或 `layer == "L2"` 的文件

**dry-run 模式**：
- 仅输出将要压缩的文件列表，不执行实际操作

### 5. L0 → L1 压缩规则

对每个需要从 L0 降级到 L1 的文件：

1. **Read 读取原始内容**

2. **创建备份目录**：
```bash
mkdir -p docs/memory/.archive
```

3. **备份原文件**：
```bash
cp docs/memory/YYYY-MM-DD-brief-description.md docs/memory/.archive/
```

4. **生成压缩版本**，保留以下内容：

   **完整保留**：
   - Summary
   - Decisions & Rationale
   - Open Items / Follow-ups
   - Learnings

   **压缩为简要列表**：
   - Changes Made: 仅保留文件名列表，移除详细描述
     ```markdown
     ## Changes Made (简化)

     - src/components/Auth.tsx
     - src/api/login.ts
     - tests/auth.test.ts
     ```

   - Technical Details: 仅保留关键配置变更，移除代码片段
     ```markdown
     ## Technical Details (关键配置)

     - 启用 JWT 认证，过期时间 24h
     - 数据库连接池大小: 10 → 20
     ```

   **简化**：
   - Testing: 仅保留通过/失败状态
     ```markdown
     ## Testing

     - 单元测试: 通过 (15/15)
     - 集成测试: 通过 (3/3)
     ```

5. **添加标记**：
   - 在标题后添加 `[L1 压缩版本]`
   - 文件末尾添加：
     ```markdown
     ---

     **原始完整版本**: docs/memory/.archive/YYYY-MM-DD-brief-description.md
     ```

6. **Write 写入压缩版本**，覆盖原文件

7. **更新 index.json**：
   - `layer`: "L0" → "L1"
   - `compacted`: false → true
   - `sizeBytes`: 更新为压缩后的大小

### 6. L1 → L2 压缩规则

对每个需要从 L1 降级到 L2 的文件：

1. **Read 读取原始内容**（如果已是 L1 压缩版本，从 .archive/ 读取原始版本）

2. **备份原文件**（如果尚未备份）

3. **生成归档版本**，保留以下内容：

   **保留**：
   - Summary: 仅保留前 3 句话
   - Decisions & Rationale: 仅保留最重要的 1-3 条决策
   - Open Items / Follow-ups: 仅保留未完成的 TODOs（已完成的移除）

   **移除**：
   - Changes Made
   - Technical Details
   - Testing
   - Learnings

4. **添加标记**：
   - 在标题后添加 `[L2 归档版本]`
   - 文件末尾添加：
     ```markdown
     ---

     **原始完整版本**: docs/memory/.archive/YYYY-MM-DD-brief-description.md
     ```

5. **Write 写入归档版本**，覆盖原文件

6. **更新 index.json**：
   - `layer`: "L1" → "L2"
   - `compacted`: true
   - `sizeBytes`: 更新为归档后的大小

### 7. 更新索引统计

重新计算 index.json 的 stats：

```json
{
  "stats": {
    "total": 总条目数,
    "byLayer": {
      "L0": L0 层计数,
      "L1": L1 层计数,
      "L2": L2 层计数
    },
    "totalSizeBytes": 所有文件大小总和
  },
  "lastUpdated": "当前时间戳"
}
```

使用 Write 工具覆盖写入更新后的 index.json。

### 8. 输出压缩报告

**正常模式**：

```
Memory 压缩完成

L0 → L1: N 个文件
L1 → L2: M 个文件
节省空间: XX KB

当前分布: L0: X | L1: Y | L2: Z (共 T 条)
原始文件已备份到 docs/memory/.archive/
```

**dry-run 模式**：

```
[预览] 将执行以下压缩操作:

L0 → L1 (N 个文件):
  - 2026-01-15-auth-refactor.md (3.2 KB → ~1.5 KB)
  - 2026-01-20-api-optimization.md (4.1 KB → ~2.0 KB)

L1 → L2 (M 个文件):
  - 2025-12-10-database-migration.md (2.5 KB → ~0.8 KB)

预计节省空间: XX KB

运行 /longmemory:compact 执行压缩
```

### 9. Restore 模式

当参数为 `restore <filename>` 时：

1. **检查备份文件是否存在**：
```bash
if [ ! -f docs/memory/.archive/<filename> ]; then
  echo "错误: 备份文件不存在"
  exit 1
fi
```

2. **恢复文件**：
```bash
cp docs/memory/.archive/<filename> docs/memory/
```

3. **更新 index.json**：
   - 找到对应的 entry
   - `layer`: 恢复为 "L0"
   - `compacted`: 恢复为 false
   - `sizeBytes`: 更新为原始文件大小

4. **输出确认**：
```
✓ 已从备份恢复: <filename>
✓ 索引已更新，文件恢复为 L0 层
```

## 错误处理

- 如果 index.json 不存在且无法扫描文件，提示用户先运行 `/longmemory:save`
- 如果备份目录创建失败，中止压缩操作
- 如果文件读取失败，跳过该文件并记录错误
- 如果索引更新失败，保留原索引文件（创建 .backup）

## 完成标准

- [x] 正确识别需要降级的文件
- [x] 原始文件已备份到 .archive/
- [x] 压缩版本正确生成，符合压缩规则
- [x] index.json 已更新，layer 和 stats 正确
- [x] 用户收到压缩报告

## 压缩示例

**L0 原始文件** (3.5 KB):
```markdown
# 实现用户认证模块

**日期**: 2026-01-15
**标签**: auth, jwt, security

## Summary
实现了基于 JWT 的用户认证系统，包括登录、注册、token 刷新功能。

## Changes Made
- src/components/Auth.tsx:1-150 - 创建认证组件，包含登录表单和状态管理
- src/api/login.ts:1-80 - 实现登录 API 调用和 token 存储
- src/utils/jwt.ts:1-50 - JWT token 解析和验证工具
- tests/auth.test.ts:1-200 - 完整的认证流程测试

## Decisions & Rationale
### 使用 JWT 而非 Session
- **决策**: 采用 JWT token 进行认证
- **理由**: 支持分布式部署，减少服务器状态管理

### Token 过期时间设置
- **决策**: Access token 24h，Refresh token 30 天
- **理由**: 平衡安全性和用户体验

## Technical Details
- JWT 库: jsonwebtoken v9.0.0
- Token 存储: localStorage (考虑后续迁移到 httpOnly cookie)
- 密钥管理: 环境变量 JWT_SECRET
- 加密算法: HS256

## Testing
- 单元测试: 15/15 通过
- 集成测试: 3/3 通过
- 测试命令: npm test -- auth

## Open Items / Follow-ups
- [ ] 迁移 token 存储到 httpOnly cookie
- [ ] 添加 refresh token 自动刷新逻辑
- [x] 完成登录表单验证

## Learnings
- JWT payload 不应包含敏感信息
- token 刷新需要考虑并发请求场景
```

**L1 压缩版本** (1.8 KB):
```markdown
# 实现用户认证模块 [L1 压缩版本]

**日期**: 2026-01-15
**标签**: auth, jwt, security

## Summary
实现了基于 JWT 的用户认证系统，包括登录、注册、token 刷新功能。

## Changes Made (简化)
- src/components/Auth.tsx
- src/api/login.ts
- src/utils/jwt.ts
- tests/auth.test.ts

## Decisions & Rationale
### 使用 JWT 而非 Session
- **决策**: 采用 JWT token 进行认证
- **理由**: 支持分布式部署，减少服务器状态管理

### Token 过期时间设置
- **决策**: Access token 24h，Refresh token 30 天
- **理由**: 平衡安全性和用户体验

## Technical Details (关键配置)
- JWT 库: jsonwebtoken v9.0.0
- Token 过期: Access 24h, Refresh 30d
- 加密算法: HS256

## Testing
- 单元测试: 通过 (15/15)
- 集成测试: 通过 (3/3)

## Open Items / Follow-ups
- [ ] 迁移 token 存储到 httpOnly cookie
- [ ] 添加 refresh token 自动刷新逻辑

## Learnings
- JWT payload 不应包含敏感信息
- token 刷新需要考虑并发请求场景

---

**原始完整版本**: docs/memory/.archive/2026-01-15-auth-implementation.md
```

**L2 归档版本** (0.6 KB):
```markdown
# 实现用户认证模块 [L2 归档版本]

**日期**: 2026-01-15
**标签**: auth, jwt, security

## Summary
实现了基于 JWT 的用户认证系统，包括登录、注册、token 刷新功能。

## Decisions & Rationale
### 使用 JWT 而非 Session
- **决策**: 采用 JWT token 进行认证
- **理由**: 支持分布式部署，减少服务器状态管理

## Open Items / Follow-ups
- [ ] 迁移 token 存储到 httpOnly cookie
- [ ] 添加 refresh token 自动刷新逻辑

---

**原始完整版本**: docs/memory/.archive/2026-01-15-auth-implementation.md
```
