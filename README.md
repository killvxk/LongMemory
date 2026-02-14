# LongMemory - 分层记忆系统 for Claude Code

解决 Claude Code memory 系统的三大痛点：文件膨胀、上下文爆炸、检索低效。通过分层记忆（L0/L1/L2）+ 持久化索引 + 自动压缩归档实现。

## 特性

- **分层记忆**: L0（≤7天完整）→ L1（7-30天压缩）→ L2（>30天归档）
- **持久化索引**: index.json 加速查询，避免全量扫描
- **自动压缩**: Claude 实时生成压缩摘要，原文备份到 .archive/
- **Stop Hook 联动**: 会话结束时自动保存 + 更新索引
- **跨平台**: 支持 Windows (PowerShell) / macOS / Linux (Bash)

## 安装

```bash
# 添加 marketplace
/plugin marketplace add killvxk/LongMemory

# 安装
/plugin install longmemory
```

## 命令参考

| 命令 | 说明 |
|------|------|
| `/longmemory:save` | 保存当前工作记忆，自动更新索引 |
| `/longmemory:list` | 列出记忆索引，显示分层状态 |
| `/longmemory:get <id>` | 获取指定记忆，支持 `--original` 查看原文 |
| `/longmemory:search <query>` | 三维搜索（scope/time/project），索引加速 |
| `/longmemory:all` | 全量读取，智能容量保护 |
| `/longmemory:compact` | 压缩归档，支持 `--dry-run`/`--force`/`--restore` |

### 命令示例

```bash
# 保存当前工作记忆
/longmemory:save

# 列出所有记忆
/longmemory:list

# 获取指定记忆
/longmemory:get 2026-02-14-api-refactor

# 查看原始未压缩版本
/longmemory:get 2026-01-20-auth-impl --original

# 搜索记忆
/longmemory:search authentication
/longmemory:search "API design" --scope=technical --days=30

# 全量读取（用于深度分析）
/longmemory:all

# 压缩归档
/longmemory:compact --dry-run  # 预览
/longmemory:compact             # 执行压缩
/longmemory:compact --restore 2026-01-15-feature  # 恢复原文
```

## 分层策略

### L0 层（≤7天）
- **保留内容**: 完整原文
- **文件位置**: `docs/memory/YYYY-MM-DD-description.md`
- **用途**: 近期工作的详细上下文

### L1 层（7-30天）
- **保留内容**: Claude 生成的压缩摘要（约 30-40% 原文大小）
- **文件位置**:
  - 压缩版: `docs/memory/YYYY-MM-DD-description.md`
  - 原文备份: `docs/memory/.archive/YYYY-MM-DD-description.md.original`
- **压缩策略**: 保留关键决策、技术细节、测试结果，移除冗余描述
- **用途**: 中期历史的快速回顾

### L2 层（>30天）
- **保留内容**: 高度压缩的归档摘要（约 10-20% 原文大小）
- **文件位置**:
  - 归档版: `docs/memory/YYYY-MM-DD-description.md`
  - 原文备份: `docs/memory/.archive/YYYY-MM-DD-description.md.original`
- **压缩策略**: 仅保留核心决策、关键变更、重要教训
- **用途**: 长期历史的索引和检索

## index.json 格式

持久化索引文件，加速查询和分层管理。

```json
{
  "version": "1.0",
  "lastUpdated": "2026-02-14T10:30:00Z",
  "entries": [
    {
      "id": "2026-02-14-api-refactor",
      "date": "2026-02-14",
      "title": "API 重构 - 统一错误处理",
      "tags": ["api", "refactor", "error-handling"],
      "layer": "L0",
      "compacted": false,
      "sizeBytes": 15234,
      "scope": "technical"
    }
  ],
  "stats": {
    "total": 42,
    "l0": 5,
    "l1": 18,
    "l2": 19,
    "totalSizeBytes": 512000
  }
}
```

### 字段说明

- `id`: 记忆文件名（不含扩展名）
- `date`: 创建日期（ISO 8601）
- `title`: 记忆标题（从文件内容提取）
- `tags`: 标签列表（3-5个，用于搜索）
- `layer`: 分层标识（L0/L1/L2）
- `compacted`: 是否已压缩
- `sizeBytes`: 文件大小（字节）
- `scope`: 范围标识（technical/business/process）

## 从旧版迁移

### 从 ~/.claude/commands/memory/ 迁移

```bash
# 1. 复制现有 memory 文件到项目
cp ~/.claude/commands/memory/*.md docs/memory/

# 2. 运行 list 命令生成索引
/longmemory:list

# 3. 根据需要执行压缩
/longmemory:compact --dry-run
```

### 从 project-memory plugin 迁移

如果你之前使用 project-memory plugin，LongMemory 完全兼容其文件格式。只需：

1. 确保 memory 文件位于 `docs/memory/` 目录
2. 运行 `/longmemory:list` 自动生成索引
3. 使用 `/longmemory:compact` 对旧文件进行分层压缩

## 工作流程

### 日常使用

1. **自动保存**: 会话结束时 Stop Hook 自动触发保存
2. **手动保存**: 重要节点使用 `/longmemory:save` 手动保存
3. **定期压缩**: 每周运行 `/longmemory:compact` 维护分层结构
4. **按需检索**: 使用 `/longmemory:search` 或 `/longmemory:get` 查找历史

### 最佳实践

- **保存频率**: 每个功能完成、重要决策后手动保存
- **压缩周期**: 每周或每月运行一次 compact
- **标签规范**: 使用一致的标签体系（技术栈、功能模块、问题类型）
- **原文备份**: 重要记忆在压缩前使用 `--original` 确认内容

## 容量管理

### 智能保护机制

- **all 命令**: 超过 100KB 时警告，超过 500KB 时拒绝
- **自动压缩**: L1/L2 层自动触发压缩，减少 60-90% 体积
- **索引优先**: 优先使用 index.json 查询，避免全量扫描

### 容量估算

假设每个 memory 文件平均 10KB：

- **L0（7天）**: 约 7 个文件 = 70KB
- **L1（23天）**: 约 23 个文件 × 40% = 92KB
- **L2（长期）**: 约 100 个文件 × 15% = 150KB
- **总计**: 约 312KB（可管理范围）

## 技术架构

### 目录结构

```
docs/
└── memory/
    ├── index.json                    # 持久化索引
    ├── 2026-02-14-api-refactor.md   # L0 完整记忆
    ├── 2026-01-20-auth-impl.md      # L1 压缩记忆
    └── .archive/
        └── 2026-01-20-auth-impl.md.original  # L1 原文备份
```

### 命令实现

所有命令使用 Claude Code 的 Skill 系统实现，位于 `ccplugin/commands/` 目录。

### Hook 实现

Stop Hook 脚本位于 `ccplugin/scripts/`，支持：
- Unix/Linux/macOS: `auto-save-memory.sh`
- Windows: `auto-save-memory.ps1`

## 故障排查

### Hook 未触发

检查 Claude Code 配置：
```bash
# 查看 hook 配置
cat ~/.claude/config.json | grep -A 5 hooks
```

### 索引损坏

重建索引：
```bash
# 删除旧索引
rm docs/memory/index.json

# 运行 list 命令重建
/longmemory:list
```

### 压缩失败

使用 dry-run 模式诊断：
```bash
/longmemory:compact --dry-run
```

## License

MIT License - 详见 [LICENSE](LICENSE) 文件

## 贡献

欢迎提交 Issue 和 Pull Request。

## 相关资源

- [Claude Code 文档](https://docs.anthropic.com/claude-code)
- [Plugin 开发指南](https://docs.anthropic.com/claude-code/plugins)
