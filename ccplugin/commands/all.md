---
description: 读取所有 memory 条目到上下文中，感知分层状态，智能容量保护
argument-hint: [time:范围] [project:路径]
allowed-tools: Bash, Read, Glob, Grep
---

# LongMemory All Command

读取所有 memory 条目到上下文中，支持过滤和智能容量保护。

## 执行步骤

### 1. 解析参数
从用户输入中提取过滤参数：
- `time:` 时间范围过滤（如 time:7d, time:2026-02, time:2026-01-01..2026-01-31）
- `project:` 项目路径过滤（如 project:/api）

### 2. 索引优先读取
使用 Read 工具读取 `docs/memory/index.json`：
- 索引存在：
  - 从 `entries` 数组获取文件列表
  - 读取 `totalSizeBytes` 字段用于容量评估
  - 应用 time 和 project 过滤
- 索引不存在：回退到步骤 3

### 3. 文件系统扫描（回退）
使用 Bash 工具执行：
```bash
ls -1 docs/memory/*.md 2>/dev/null | grep -v index.json
```
对每个文件使用 Bash 获取大小：
```bash
wc -c < "docs/memory/文件名.md"
```
累加计算总大小

### 4. 应用过滤
根据参数过滤文件列表：
- `time:` 参数：解析时间范围，过滤文件名中的日期
  - `7d` → 最近 7 天
  - `2026-02` → 2026 年 2 月
  - `2026-01-01..2026-01-31` → 日期区间
- `project:` 参数：匹配 tags 中包含项目路径的条目（需读取 frontmatter）

### 5. 智能容量保护
基于总大小进行容量评估：
- `totalSizeBytes > 100KB`：显示警告
  ```
  ⚠️  警告: 即将读取 N 条 memory，总大小约 XXX KB（预估 ~XXK tokens）

  建议使用过滤参数减少加载量：
  - /longmemory:all time:30d  # 最近 30 天
  - /longmemory:all time:2026-02  # 指定月份
  - /longmemory:all project:/api  # 指定项目

  继续加载全部？(y/n)
  ```
- 等待用户确认或自动应用 `time:30d` 过滤

### 6. 按时间正序排列
将文件列表按日期从早到晚排序（便于理解时间线）

### 7. 读取所有文件
使用 Read 工具依次读取每个文件的完整内容

### 8. 分层标记输出
输出格式：
```
已读取 N 条 memory (L0: X | L1: Y | L2: Z, 预估 ~XXK tokens)

━━━ 1. docs/memory/2026-01-10-db-migration.md [L2 归档] ━━━
# 数据库迁移方案

## Summary
设计了从 MySQL 到 PostgreSQL 的迁移方案...

[归档内容]

━━━ 2. docs/memory/2026-02-07-api-design.md [L1 压缩] ━━━
# API 设计评审

## Summary
评审并确定了 v2 API 接口...

[压缩内容]

━━━ 3. docs/memory/2026-02-14-auth-impl.md [L0] ━━━
# 实现用户认证功能

## Summary
完成 JWT 认证模块的实现...

[完整内容]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ 全部 memory 已加载到上下文中。
```

### 9. 统计信息
在输出开头显示：
- 总条目数
- 各层级分布（L0/L1/L2）
- 预估 token 占用（约 totalSizeBytes / 4）

### 10. 空结果处理
如果没有找到任何条目：
```
未找到 memory 条目。

使用 /longmemory:save 创建第一条记录。
```

## 注意事项
- 必须使用 Bash ls/wc 命令（Windows 兼容性）
- 优先使用索引获取大小信息
- 超过 100KB 必须警告并建议过滤
- 按时间正序排列（最早在前）
- 清晰标注各层级状态（L0/L1/L2）
- 预估 token 占用帮助用户评估上下文消耗
- 支持用户中断大批量加载
