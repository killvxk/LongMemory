# LongMemory Plugin

分层记忆系统 for Claude Code - 解决 memory 文件膨胀、上下文爆炸、检索低效问题。

## 包含的命令

| 命令 | 说明 |
|------|------|
| `save` | 保存当前工作记忆，自动更新索引 |
| `list` | 列出记忆索引，显示分层状态 |
| `get` | 获取指定记忆，支持 --original 查看原文 |
| `search` | 三维搜索（scope/time/project），索引加速 |
| `all` | 全量读取，智能容量保护 |
| `compact` | 压缩归档，支持 dry-run/force/restore |

## Hook 说明

### Stop Hook: auto-save-memory

在会话结束时自动触发，检测 git 变更并提示 Claude 保存工作记忆。

**触发条件:**
- 检测到 git 仓库中有未提交的变更
- 非 hook 递归调用（防止无限循环）

**执行逻辑:**
1. 收集 git 变更上下文（status/diff/log）
2. 生成 memory 文件到 `docs/memory/YYYY-MM-DD-description.md`
3. 更新 `docs/memory/index.json` 索引

**跨平台支持:**
- Unix/Linux/macOS: `scripts/auto-save-memory.sh`
- Windows: `scripts/auto-save-memory.ps1`

## 目录结构

```
ccplugin/
├── commands/          # 命令实现
│   ├── save.md
│   ├── list.md
│   ├── get.md
│   ├── search.md
│   ├── all.md
│   └── compact.md
├── scripts/           # Hook 脚本
│   ├── auto-save-memory.sh
│   └── auto-save-memory.ps1
└── claude-plugin.json # 插件配置
```

## 详细文档

参见项目根目录的 [README.md](../README.md)
