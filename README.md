# LongMemory - 文件系统式记忆系统 for Claude Code

解决 Claude Code memory 系统的三大痛点：文件膨胀、上下文爆炸、检索低效。通过检索粒度分层（L0/L1/L2）+ 全局经验库实现。

## v2.1.3 — Bash/PowerShell 共存 + 命令化

- 恢复 Bash + PowerShell 双脚本架构（`bash ... || pwsh ...` fallback）
- 移除 SessionStart hook，改为 `/longmemory:start` 命令手动加载
- 移除 UserPromptSubmit hook（keyword-trigger 暂不支持）
- 保留 Stop 和 PreCompact 两个 hook

## v2.0 新特性

- **检索粒度层**: L0 目录索引 → L1 概览大纲 → L2 完整原文，渐进加载
- **全局经验库**: 跨项目通用知识存储，按领域分类

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
| `/longmemory:start` | 加载全局经验库概览 + 技术栈检测 |
| `/longmemory:save` | 保存工作记忆，更新 catalog/overview/index |
| `/longmemory:list` | 列出 L0 目录索引，支持 `domain:` 和 `time:` 过滤 |
| `/longmemory:get <id>` | 获取记忆，默认 L1 概览，`--full` 完整内容 |
| `/longmemory:search <query>` | L0→L1→L2 渐进检索，支持 `--global` |
| `/longmemory:all` | 分层加载：`level:L0` / `level:L1` / `level:L2` |
| `/longmemory:compact` | 可选磁盘清理，`dry-run` / `clean` / `restore` |
| `/longmemory:learn` | 从当前会话提炼通用经验存入全局库 |
| `/longmemory:recall` | 查询全局经验库，支持关键词和领域过滤 |

### 命令示例

```bash
# 会话开始时加载全局经验库
/longmemory:start

# 保存当前工作记忆
/longmemory:save

# 列出所有记忆（L0 目录）
/longmemory:list
/longmemory:list domain:auth
/longmemory:list time:7d

# 获取记忆概览（L1）
/longmemory:get 2026-02-14-jwt-impl
/longmemory:get latest --full          # 完整内容

# 渐进式搜索
/longmemory:search jwt                 # 项目内搜索
/longmemory:search jwt --global        # 含全局经验库

# 分层加载全部
/longmemory:all                        # 默认 L0 目录
/longmemory:all level:L1               # 所有概览
/longmemory:all level:L2 time:30d      # 最近30天完整内容

# 磁盘清理
/longmemory:compact                    # 预览
/longmemory:compact clean 90           # 清理90天前原文
/longmemory:compact restore xxx.md     # 恢复

# 全局经验
/longmemory:learn auth                 # 提炼经验存入 auth 域
/longmemory:recall jwt                 # 搜索全局经验
/longmemory:recall domain:auth         # 查看 auth 域全部经验
/longmemory:recall --all               # 列出所有领域
```

## 检索粒度层

### L0 — 目录索引 (`ls`)
- **内容**: catalog.md，一行一条（日期 | 文件名 | 标签 | 标题）
- **Token**: ~14 tokens/条
- **用途**: 瞬间定位领域和条目

### L1 — 概览大纲 (`head`)
- **内容**: .overview.md，摘要 + 关键决策 + 待办数
- **Token**: ~50 tokens/条
- **用途**: 确认相关性，判断是否需要全文

### L2 — 完整原文 (`cat`)
- **内容**: 原始 .md 文件，包含完整 7 个 section
- **Token**: 原始大小
- **用途**: 按需获取完整上下文

### 检索流程

```
L0 定位 → L1 确认 → L2 按需读取

100条记忆时：
  旧方式: 读 index.json 全量 → ~3000 tokens
  新方式: 读 catalog 匹配 → 读 overview → ~64 tokens
```

## 全局经验库

跨项目的通用知识存储，通过 `/longmemory:start` 命令手动加载。

### 结构

```
~/.claude/longmemory/            # 默认路径（可配置）
├── config.json                  # 配置
├── catalog.md                   # 领域概览
├── triggers.json                # 关键词→领域映射
└── domains/
    ├── auth.md                  # 认证领域经验
    ├── api-design.md            # API 设计经验
    └── debugging.md             # 调试经验
```

### 经验条目格式

```markdown
## JWT Token 管理
**触发词**: jwt, token, refresh, 过期, expiry, bearer
**场景**: JWT token 的生成、刷新、过期处理
**教训**:
- Access token 应短期（15min-1h），Refresh token 长期（7-30d）
- 永远不要在 JWT payload 中存储敏感信息
**推荐做法**: 使用 rotating refresh tokens
**来源**: 2026-02-14 jwt-impl 项目
```

### 加载经验库

会话开始时运行 `/longmemory:start`，手动加载全局经验库概览和技术栈信息。

## 项目记忆文件布局

```
{project}/docs/memory/
├── catalog.md                         # L0: 目录 + 最近10条概览
├── domains.md                         # L0: 领域→文件名映射
├── index.json                         # 机器可读元数据（v2 schema）
├── 2026-02-14-jwt-impl.md            # L2: 完整原文
├── 2026-02-14-jwt-impl.overview.md   # L1: 概览文件
└── .archive/                          # compact 备份
```

### index.json v2

```json
{
  "version": "2.0",
  "lastUpdated": "2026-02-18T10:00:00Z",
  "stats": {
    "total": 42,
    "totalSizeBytes": 512000
  },
  "entries": [
    {
      "file": "2026-02-14-jwt-impl.md",
      "date": "2026-02-14",
      "title": "JWT 认证实现",
      "tags": ["auth", "jwt", "security"],
      "sizeBytes": 15234,
      "hasOverview": true
    }
  ]
}
```

## Hook 系统

| Hook | 触发时机 | 功能 | Timeout |
|------|---------|------|---------|
| Stop | 会话结束 | 检测 git 变更，触发 `/longmemory:save` | 10s |
| PreCompact | 上下文压缩前 | 检测 git 变更，建议先保存记忆 | 10s |

平台: Bash (优先) + PowerShell (fallback)

## 从 v1.0 迁移

v2.0 完全向后兼容。首次运行 `/longmemory:save` 时：
- 自动检测 v1.0 的 index.json 并迁移到 v2 schema
- 自动生成 catalog.md 和 domains.md
- 旧的 L0/L1/L2 时间分层标记会被移除

## License

MIT License - 详见 [LICENSE](LICENSE) 文件
