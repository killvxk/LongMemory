---
description: 手动查询全局经验库，支持关键词和领域过滤
argument-hint: "[关键词|domain:领域名] [--all]"
allowed-tools: Bash, Read, Glob, Grep
---

# 查询全局经验库

从全局经验库中检索相关经验，支持关键词搜索、领域过滤和全量浏览。

## 执行步骤

### 1. 定位全局经验库

按以下优先级查找全局经验库配置：

**优先级 1**：检查项目内配置
- 读取 `.claude/longmemory.json`
- 如存在，读取其中的 `globalMemoryPath` 字段

**优先级 2**：检查全局配置
- 读取 `~/.claude/longmemory/config.json`
- 如存在，读取其中的 `globalMemoryPath` 字段

**优先级 3**：未找到配置
- 输出提示：

```
未找到全局经验库配置

请先使用 /longmemory:learn 存入经验，系统会自动初始化经验库。
```

- 终止执行

将确定的 `globalMemoryPath` 记为 `GLOBAL_PATH`，后续步骤均使用此变量。

### 2. 解析参数

根据用户输入的参数，确定查询模式：

| 参数格式 | 查询模式 |
|---------|---------|
| 无参数 | **目录模式**：输出全局 catalog.md |
| `--all` | **全量模式**：列出所有领域和所有条目标题 |
| `domain:{名称}` | **领域模式**：显示指定领域全部条目 |
| 其他文本 | **关键词模式**：在 triggers.json 中匹配并检索 |

示例：
- `/longmemory:recall` → 目录模式
- `/longmemory:recall --all` → 全量模式
- `/longmemory:recall domain:auth` → 领域模式，显示 auth 领域
- `/longmemory:recall jwt` → 关键词模式，搜索 "jwt"
- `/longmemory:recall token refresh` → 关键词模式，搜索 "token" 和 "refresh"

### 3. 执行查询

#### 目录模式（无参数）

直接读取 `{GLOBAL_PATH}/catalog.md` 并输出其内容。

如果文件不存在，输出：

```
全局经验库为空

使用 /longmemory:learn 从当前会话提炼经验并存入库。
```

#### 全量模式（--all）

1. 读取 `{GLOBAL_PATH}/triggers.json`，获取所有领域列表
2. 逐一读取每个领域文件 `{GLOBAL_PATH}/domains/{domain}.md`
3. 提取每个条目的标题（`## ` 开头的二级标题）和触发词
4. 按领域分组输出：

```
全局经验库 — 全部条目

━━━ auth 领域（5条）━━━
  · JWT Token 管理 [jwt, token, refresh]
  · OAuth2 集成 [oauth, 第三方登录]
  · Session 管理 [session, cookie, httponly]
  · RBAC 权限设计 [rbac, 权限, role]
  · PKCE 流程 [pkce, code_challenge]

━━━ api-design 领域（3条）━━━
  · REST API 版本控制 [api, versioning, v1]
  · GraphQL Schema 设计 [graphql, schema, resolver]
  · 接口幂等性 [幂等, idempotent, retry]

合计: 2 个领域，8 条经验
使用 /longmemory:recall domain:{领域名} 查看详细内容
```

#### 领域模式（domain:{名称}）

1. 提取领域名称（`domain:` 后面的部分）
2. 读取 `{GLOBAL_PATH}/domains/{domain}.md`
3. 输出完整内容：

```
━━━ auth 领域（完整内容）━━━

# Auth 经验库

## JWT Token 管理
**触发词**: jwt, token, refresh, 过期, expiry, bearer
**场景**: ...
（完整内容）

---

## OAuth2 集成
（完整内容）

共 5 条经验
```

如果领域文件不存在：

```
领域 "xxx" 不存在

已有领域: auth, api-design, debugging

使用 /longmemory:recall --all 查看所有领域
```

#### 关键词模式

1. 读取 `{GLOBAL_PATH}/triggers.json`
2. 将用户输入的关键词（转为小写）与各领域的 `keywords` 数组进行匹配：
   - 精确匹配优先
   - 也支持部分匹配（关键词是 triggers.json 中某词的子串，或反之）
3. 找出所有匹配的领域
4. 对每个匹配领域，读取对应的领域文件
5. 在领域文件中，找出触发词与搜索关键词有交集的经验条目
6. 输出匹配结果：

```
全局经验搜索: "jwt"

━━━ auth 领域 ━━━

## JWT Token 管理
**触发词**: jwt, token, refresh, 过期, expiry, bearer
**场景**: JWT token 的生成、刷新、过期处理
**教训**:
- Access token 应短期（15min-1h），Refresh token 长期（7-30d）
- 永远不要在 JWT payload 中存储敏感信息
**推荐做法**: 使用 rotating refresh tokens，每次刷新时旧 token 立即失效
**来源**: 2026-02-14 jwt-impl

---

找到 1 条匹配经验（auth 领域）
```

多个关键词时（如 `token refresh`），取并集——只要条目触发词与任意一个搜索词匹配即纳入结果。

输出结果按领域分组，每个领域用分隔线区分：

```
全局经验搜索: "token refresh"

━━━ auth 领域（2条匹配）━━━

## JWT Token 管理
（...完整内容...）

---

## Session 管理
（...完整内容...）

━━━ api-design 领域（1条匹配）━━━

## 接口幂等性与重试
（...完整内容...）

---

共找到 3 条匹配经验（2 个领域）
```

### 4. 未找到结果的处理

当关键词模式未找到任何匹配时，输出：

```
未找到匹配 "{关键词}" 的全局经验

当前已有领域: auth (9词), api-design (7词), debugging (7词)

建议：
- 使用 /longmemory:recall --all 查看所有经验
- 使用 /longmemory:recall domain:auth 查看特定领域
- 使用 /longmemory:learn 添加新经验
```

括号中的数字为该领域 keywords 数组的长度。

## 输出规范

- 所有输出直接打印到对话中，不写入任何文件
- 条目之间使用 `---` 分隔线
- 领域之间使用 `━━━` 标题行分隔
- 触发词以逗号+空格连接显示
- 完整输出经验条目时，保留原始 Markdown 格式

## 错误处理

- `triggers.json` 不存在：提示用户使用 `/longmemory:learn` 初始化
- `triggers.json` 格式错误：提示 JSON 格式损坏，建议使用 `/longmemory:learn` 修复
- 领域文件不存在但 triggers.json 中有记录：显示提示并跳过该领域，继续显示其他结果
- `catalog.md` 不存在（目录模式）：提示经验库为空

## 跨平台注意事项

- 路径中的 `~` 需要展开为实际的 home 目录路径
- 读取文件使用 Read 工具，不依赖 shell 命令
- 关键词匹配不区分大小写（统一转小写比较）
