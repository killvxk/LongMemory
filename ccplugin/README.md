# LongMemory Plugin

文件系统式记忆系统 for Claude Code — 检索粒度分层索引、全局经验库。

## 命令

| 命令 | 说明 |
|------|------|
| `start` | 手动加载全局经验库概览 + 技术栈检测（SessionStart hook 备选） |
| `save` | 保存工作记忆，更新 L0 目录/L1 概览/index |
| `list` | 列出 catalog.md 目录索引，支持领域和时间过滤 |
| `get` | 获取记忆，默认返回 L1 概览，`--full` 返回完整内容 |
| `search` | L0→L1→L2 渐进式检索，支持 `--global` 全局搜索 |
| `all` | 分层加载：L0 目录 / L1 概览 / L2 完整内容 |
| `compact` | 可选磁盘清理，删除旧原文保留概览 |
| `learn` | 从会话提炼通用经验，存入全局经验库 |
| `recall` | 手动查询全局经验库 |

## 检索粒度层（L0/L1/L2）

| 层级 | 类比 | 内容 | Token 消耗 |
|------|------|------|-----------|
| L0 | `ls` | catalog.md 目录索引（一行一条） | ~14 tokens/条 |
| L1 | `head` | .overview.md 概览（摘要+决策+待办） | ~50 tokens/条 |
| L2 | `cat` | 完整 .md 原文 | 原始大小 |

检索流程：L0 定位 → L1 确认 → L2 按需读取

## Hook 说明

| Hook | 脚本 | 功能 | Timeout |
|------|------|------|---------|
| Stop | auto-save-memory | 会话结束时检测 git 变更，触发保存 | 10s |
| SessionStart | session-start | 新会话启动时加载全局经验库概览（matcher: startup） | 10s |
| PreCompact | pre-compact | 压缩前检测 git 变更，建议保存记忆 | 10s |

平台: Bash (优先) + PowerShell (fallback)

## 目录结构

```
ccplugin/
├── commands/
│   ├── start.md      # 手动加载全局经验库（SessionStart hook 备选）
│   ├── save.md       # 保存（L2 + overview + catalog + domains + index）
│   ├── list.md       # L0 目录列出
│   ├── get.md        # L1 概览 / L2 全文获取
│   ├── search.md     # 渐进式检索
│   ├── all.md        # 分层全量加载
│   ├── compact.md    # 可选磁盘清理
│   ├── learn.md      # 全局经验提炼
│   └── recall.md     # 全局经验查询
├── hooks/
│   └── hooks.json    # Hook 注册（Stop/SessionStart/PreCompact）
├── scripts/
│   ├── auto-save-memory.sh     # Stop hook (Bash)
│   ├── auto-save-memory.ps1    # Stop hook (PowerShell)
│   ├── session-start.sh        # SessionStart hook (Bash)
│   ├── session-start.ps1       # SessionStart hook (PowerShell)
│   ├── pre-compact.sh          # PreCompact hook (Bash)
│   └── pre-compact.ps1         # PreCompact hook (PowerShell)
└── .claude-plugin/
    └── plugin.json
```

## 详细文档

参见项目根目录的 [README.md](../README.md)
