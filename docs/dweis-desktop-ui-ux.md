# DWeis Desktop UI / UX 设计文档

日期：2026-06-25

## 1. 设计目标

DWeis Desktop 是一个 Chat / Code 双模式 AI 工作台。

UI/UX 的核心目标：

1. 用户始终知道 AI 在看什么。
2. 用户始终知道 AI 正在做什么。
3. 用户始终能控制 AI 是否写入真实文件。
4. Chat 和 Code 是同一套助手能力的两种工作模式，而不是两个割裂应用。
5. 桌面端强调信息密度、可追踪性和低打扰。

设计关键词：

```text
Calm IDE
AI-first Workspace
Context Transparency
Preview Before Apply
Local-first
```

不追求花哨动效，不模仿 VS Code 全量功能，不做传统 IDE，而是做一个更轻、更透明的 AI 编程工作台。

---

## 2. 视觉风格

推荐风格：

```text
Linear / Raycast / Vercel 风格
```

特点：

- 低饱和背景。
- 细线分割。
- 柔和圆角。
- 轻量阴影。
- 高信息密度。
- 少弹窗，多内联反馈。
- 动效克制、短促、用于解释状态变化。

### 2.1 颜色

浅色：

```text
background: #F7F7F8
surface:    #FFFFFF
surface-2:  #F3F4F6
border:     #E5E7EB
text:       #111827
muted:      #6B7280
primary:    #2563EB
success:    #16A34A
warning:    #F59E0B
error:      #DC2626
```

深色：

```text
background: #0B0D10
surface:    #111318
surface-2:  #181B20
border:     #252A31
text:       #F9FAFB
muted:      #9CA3AF
primary:    #3B82F6
success:    #22C55E
warning:    #FBBF24
error:      #EF4444
```

### 2.2 字体

推荐：

```text
UI: Inter / system-ui
Code: JetBrains Mono / SF Mono / Menlo
```

字号：

| 用途 | 字号 | 字重 |
|---|---:|---:|
| 页面标题 | 18 | 600 |
| 面板标题 | 14 | 600 |
| 正文 | 14 | 400 |
| 聊天正文 | 15 | 400 |
| 辅助信息 | 12 | 400 |
| 代码 | 13 | 400 |

### 2.3 间距与圆角

```text
基础间距: 4 / 8 / 12 / 16 / 24
卡片圆角: 10-12
面板圆角: 12-16
按钮圆角: 8-10
输入框圆角: 12
```

桌面端不需要像移动端那样大圆角，整体更紧凑。

---

## 3. 信息架构

主结构：

```text
┌──────────────────────────────────────────────────────────────┐
│ Top Bar: DWeis   [Chat] [Code]   Workspace   Model   Settings│
├───────────────┬──────────────────────────────┬───────────────┤
│ Left Panel     │ Main Canvas                  │ Right Panel    │
│               │                              │               │
│ Chat: 会话列表 │ Chat: 对话流                  │ Plan / Context │
│ Code: 文件树   │ Code: 文件查看 / 代码预览       │ AI / Tools     │
└───────────────┴──────────────────────────────┴───────────────┘
```

三栏职责：

| 区域 | Chat 模式 | Code 模式 |
|---|---|---|
| Left Panel | 会话列表、笔记入口 | 文件树、搜索、Git 状态 |
| Main Canvas | 对话流 | 文件查看、Diff、预览 |
| Right Panel | 任务/草稿/记忆/工具 | AI 对话、工具日志、任务计划 |

---

## 4. 顶部栏

顶部栏固定，高度 44-48px。

结构：

```text
DWeis      [Chat] [Code]        Workspace: xxx      Model: xxx      Settings
```

### 4.1 模式切换

使用 segmented control：

```text
[ Chat ] [ Code ]
```

规则：

- 当前模式高亮。
- 切换模式不清空当前会话。
- Chat / Code 各自保留上次状态。
- 切换动画 150ms fade + slight slide。

### 4.2 Workspace 区域

Chat 模式：显示“无工作区”或最近工作区。

Code 模式：显示当前项目名和路径简写：

```text
personal_agent_app · D:/program/...
```

点击可打开工作区选择器。

---

## 5. Chat 模式 UX

Chat 模式用于日常 AI 助手。

布局：

```text
┌───────────────┬──────────────────────────────┬───────────────┐
│ 会话列表       │ 对话流                        │ Context Tabs   │
│ 笔记           │ 输入框固定底部                 │ Plan / Memory  │
└───────────────┴──────────────────────────────┴───────────────┘
```

### 5.1 左侧会话列表

包含：

- 新建会话。
- 会话搜索。
- 最近会话。
- 笔记入口。
- 设置入口。

会话项：

```text
会话标题
最后消息摘要 · 时间
```

### 5.2 中间对话流

保留当前 DWeis 的优势：

- 打字机效果。
- 工具状态行。
- 可展开时间线。
- Markdown 渲染。
- 代码块复制。

桌面端增强：

- 消息最大宽度 760-840px。
- 居中排版。
- 长代码块横向滚动。
- 支持 Ctrl+C 复制选中内容。

### 5.3 右侧 Context Tabs

Tabs：

```text
[任务] [草稿] [记忆] [工具]
```

#### 任务

显示当前 task_plan。

#### 草稿

显示 scratch 文件。

#### 记忆

显示 USER / MEMORY / AGENT。

#### 工具

显示最近工具调用日志。

---

## 6. Code 模式 UX

Code 模式用于 AI 编程。

布局：

```text
┌───────────────┬──────────────────────────────┬───────────────┐
│ Explorer       │ Editor / Diff / Preview       │ AI Panel       │
│ Files/Search   │                              │ Chat/Plan/Tools │
└───────────────┴──────────────────────────────┴───────────────┘
```

### 6.1 左侧 Explorer

Tabs：

```text
[Files] [Search] [Git]
```

#### Files

文件树规则：

- 默认隐藏 `node_modules`、`.git`、`dist`、`build`、`.dart_tool`。
- 文件夹可展开/折叠。
- 当前文件高亮。
- 大文件显示 warning。

#### Search

搜索结果展示：

```text
query: task_plan

lib/tools/task_plan_tool.dart
  16: class TaskPlanTool...
  72: await _loadPlan()
```

#### Git

MVP 只读：

- 当前分支。
- changed files。
- 不做 commit。

### 6.2 中间主区域

MVP 只做文件查看。

视图类型：

- Monaco read-only editor。
- Markdown preview。
- Search result preview。
- 空状态。

空状态：

```text
Open a workspace to start
or ask DWeis to inspect a project.
```

### 6.3 右侧 AI Panel

Tabs：

```text
[Chat] [Plan] [Tools] [Context]
```

#### Chat

AI 编程对话。

#### Plan

编程任务计划。

#### Tools

显示 workspace 工具调用。

#### Context

显示 AI 当前可见上下文。

---

## 7. 上下文透明性

Code 模式必须清楚展示 AI 看到什么。

Context 面板示例：

```text
Context
- Workspace: personal-agent-app
- Current file: lib/controllers/chat_controller.dart
- Selection: none
- Open files: 2
- Git diff: disabled
- Memory: enabled
```

当用户发送消息时，输入框上方显示 context chips：

```text
@workspace  @current-file  @selection
```

用户可以移除 chip，控制 AI 可见范围。

---

## 8. 输入框 UX

### 8.1 Chat 模式输入框

```text
Ask DWeis...
[Attach]                       [Send]
```

快捷键：

- Enter：发送。
- Shift+Enter：换行。
- Ctrl+K：命令面板。
- Ctrl+N：新会话。

### 8.2 Code 模式输入框

```text
Ask about this workspace...
[@file] [@selection] [@diff]           [Send]
```

Code 模式输入框应强调上下文：

- 当前文件。
- 选中代码。
- 搜索结果。
- 未来的 diff。

---

## 9. 工具调用展示

工具调用不应该只显示原始工具名。

简洁层：

```text
✓ 读取 lib/main.dart
✓ 搜索 "task_plan"
✓ 找到 6 个相关结果
```

详情层：

```json
{
  "tool": "workspace_search",
  "query": "task_plan",
  "matches": 6
}
```

规则：

- 成功：绿色勾。
- 进行中：蓝色 spinner / pulse。
- 失败：红色标记 + 可操作建议。
- 高风险操作：必须等待用户确认。

---

## 10. task_plan UX

任务面板必须可追踪。

```text
Task Plan
✓ 读取项目结构
⟳ 分析入口文件
□ 搜索状态管理
□ 总结架构
```

状态：

| 状态 | 表达 |
|---|---|
| pending | 灰色文字 |
| in_progress | 蓝色文字 + 左侧蓝条 |
| done | 绿色 ✓ |
| failed | 红色 ✕ |
| blocked | 橙色 ! |

点击任务展开：

- 相关工具调用。
- 相关文件。
- 任务备注。
- 错误原因。

---

## 11. Code 修改 UX（后续阶段）

MVP 不写文件，但后续必须遵守：

```text
AI 生成修改建议
↓
Changes 面板
↓
Diff 预览
↓
用户 Apply
↓
写入文件
↓
可 Undo
```

### Changes 面板

```text
Changes
2 files changed

src/auth.ts        +12 -3
src/login.tsx      +8  -1

[Review Diff] [Apply All]
```

### Diff View

- side-by-side diff。
- 每个 hunk 可 accept/reject。
- 应用前明确展示文件路径。

---

## 12. 空状态设计

### Chat 空状态

```text
What can I help with today?

[总结一段文字]
[保存一条笔记]
[制定任务计划]
```

### Code 空状态

```text
Open a workspace to start coding with DWeis.

[Open Folder]
```

### 无搜索结果

```text
No results for "xxx"
Try a broader keyword.
```

### 工具失败

```text
读取文件失败：文件过大
建议：选择更具体的文件或搜索关键词。
```

---

## 13. 动效规范

动效原则：短、轻、解释状态变化。

| 场景 | 动效 |
|---|---|
| 模式切换 | 150ms fade + slide |
| 面板展开 | 180ms height |
| 工具状态变化 | 120ms icon/color |
| 消息入场 | 160ms fade up |
| 打字机 | 16-24ms / 2-5 字符 |
| Diff apply | 200ms success flash |

不做：

- 大面积渐变动画。
- 多层弹簧乱跳。
- 长时间 loading spinner。

---

## 14. 安全确认 UX

写操作必须确认。

风险分级：

| 操作 | 交互 |
|---|---|
| read/search | 直接执行 |
| write/edit | Diff 后确认 |
| delete | 二次确认 |
| run command | 展示命令后确认 |
| git commit | 展示 diff + commit message 后确认 |

确认按钮文案必须具体：

- `Apply 2 files`
- `Run npm test`
- `Delete src/tmp.ts`

不使用泛泛的 `OK`。

---

## 15. MVP UI 成功标准

MVP 达成时，用户应能：

1. 在顶部清楚看到当前是 Chat 还是 Code。
2. 在 Chat 模式完成普通对话。
3. 在 Code 模式打开一个项目。
4. 在左侧看到文件树。
5. 点击文件后在中间看到代码。
6. 在右侧问 AI 文件相关问题。
7. 看到 AI 调用了哪些 workspace 工具。
8. 看到 task_plan 的执行状态。
9. 明确知道 AI 当前上下文。
10. 不担心 AI 会直接改文件。

---

## 16. 暂不做

第一阶段不做：

- 手机联动。
- 账号登录。
- 云同步。
- 自动写文件。
- 自动运行命令。
- Git commit。
- 多 Agent。
- 图片/视频/提醒。

这些等 Chat / Code 双模式验证成立后再做。