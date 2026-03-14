---
name: longmemory
description: >
  This skill should be used when the user asks to "save my work progress",
  "recall past experience", "what did I do last time", "search memory history",
  "list past sessions", "clean up old memories", "learn from this session",
  "保存工作进度", "回顾上次工作", "查找历史记忆", "上次做了什么",
  "提炼经验", "清理旧记忆", "inject memory rules into CLAUDE.md",
  "注入记忆规范", "配置 CLAUDE.md", or mentions session memory management,
  experience recall, work history retrieval, or CLAUDE.md memory configuration.
---

# LongMemory — 记忆系统使用指南

LongMemory 是一个基于文件系统的分层记忆系统。根据当前场景选择合适的命令。

## 场景 → 命令映射

### 会话开始时
运行 `/longmemory:start` 加载全局经验库概览和技术栈检测。

### 需要回忆过去经验时
运行 `/longmemory:recall <关键词>` 从全局经验库检索相关经验。
- 无参数：查看经验库目录
- `domain:领域名`：查看特定领域全部经验
- `--all`：列出所有领域和条目

### 需要搜索项目记忆时
运行 `/longmemory:search <关键词>` 在项目 memory 中搜索。
- 支持 `scope:decisions`、`scope:todos`、`scope:learnings` 等过滤
- 支持 `time:7d`、`time:2026-02` 等时间范围
- `--global` 搜索全局经验库

### 需要查看历史记录时
- `/longmemory:list` — 列出所有记忆条目，支持 time/domain 过滤
- `/longmemory:get latest` — 获取最近一条记忆的概览
- `/longmemory:get <日期或关键词> --full` — 获取完整记忆内容
- `/longmemory:all` — 查看全部记忆目录

### 会话结束 / 保存工作时
运行 `/longmemory:save` 将当前会话的工作记忆保存到 `docs/memory/`。
- 自动生成 L2 完整文件 + L1 概览文件
- 自动更新 catalog.md、domains.md、index.json 索引

### 有通用经验值得记录时
运行 `/longmemory:learn [domain]` 将可复用的经验提炼到全局经验库。
- 支持 `--from <memory-file>` 从已保存的记忆文件提取
- 存入后，触发词会在未来会话中自动匹配召回

### 清理旧记忆时
运行 `/longmemory:compact` 管理旧记忆文件。
- `dry-run`：预览可清理的文件
- `clean <天数>`：归档超期文件，保留概览
- `restore <文件名>`：恢复已归档文件

### 将记忆规范注入项目 CLAUDE.md 时
运行 `/longmemory:prompts` 将记忆系统使用规范写入项目的 `CLAUDE.md`。
- 不存在则创建，已有则追加，已注入则幂等更新
- 注入后每次会话自动遵循记忆优先工作流

## 自动触发规则

- **SessionStart hook** 已自动加载全局经验库关键词，当用户消息中出现触发关键词时，主动运行 `/longmemory:recall <匹配关键词>`
- **Stop hook** 检测到 git 变更时会提示运行 `/longmemory:save`
- **PreCompact hook** 在压缩上下文前提醒保存未存的记忆
