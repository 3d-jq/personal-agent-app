# DWeis Desktop Chat / Code 双模式 MVP 方案

日期：2026-06-25

## 1. 产品定位

DWeis Desktop 是一个本地优先的桌面端 AI 工作台，包含两种模式：

```text
DWeis Desktop
├─ Chat 模式：个人 AI 助手
└─ Code 模式：AI 编程助手
```

第一阶段目标不是替代 VS Code / Cursor，而是验证“Chat + Code 双模式 AI 工作台”的产品形态是否成立。

核心原则：

1. 本地优先，不做账号和多端同步。
2. Code 模式第一阶段只读项目，不直接修改真实文件。
3. AI 的工具调用、上下文、任务计划必须可见。
4. 写操作后续必须走 diff 预览和用户确认。
5. Chat 和 Code 共享 AI 核心、工具系统、上下文文档和 task_plan。

---

## 2. 技术栈

推荐技术栈：

```text
Tauri v2
React
TypeScript
Rust
Monaco Editor
Zustand
Tailwind CSS
```

职责划分：

| 层 | 技术 | 职责 |
|---|---|---|
| 桌面壳 | Tauri v2 | 窗口、权限、本地命令桥接 |
| 前端 UI | React + TypeScript | Chat/Code 界面、状态管理、工具状态展示 |
| 系统能力 | Rust | 文件系统、目录扫描、git、命令执行（后续） |
| 编辑器 | Monaco Editor | 文件查看、后续代码编辑和 diff |
| 状态管理 | Zustand | 会话、工作区、工具状态、模式切换 |
| 样式 | Tailwind CSS | 快速构建桌面 UI |

---

## 3. MVP 范围

### 3.1 必做

#### 通用能力

- Chat / Code 模式切换。
- 模型配置。
- OpenAI-compatible AI Provider。
- 打字机效果。
- 工具状态显示。
- task_plan。
- context_doc：SOUL / USER / MEMORY / AGENT。
- scratch 草稿纸。

#### Chat 模式

- 会话列表。
- 对话流。
- 输入框。
- 工具调用过程展示。
- 任务计划侧栏。
- 上下文文档查看。

#### Code 模式

- 打开本地项目目录。
- 文件树。
- 点击文件查看内容。
- 工作区搜索。
- AI 通过工具读取文件。
- AI 解释项目结构 / 文件作用 / 代码位置。
- 工具日志。

### 3.2 不做

第一阶段不做：

- 账号系统。
- 手机联动。
- 云同步。
- AI 直接写文件。
- 自动执行命令。
- Git commit。
- 多 Agent。
- 图片/视频生成。
- 提醒系统。
- 端到端加密。

---

## 4. UI / UX 方案

### 4.1 总体布局

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

### 4.2 Chat 模式

```text
左侧：会话列表 / 新建会话 / 设置入口
中间：对话流 + 输入框
右侧：任务计划 / 草稿纸 / 上下文文档 / 工具日志 tabs
```

Chat 模式目标是替代当前移动端个人助手的桌面工作台版本。

### 4.3 Code 模式

```text
左侧：Files / Search / Git tabs
中间：文件查看器 / Monaco 只读编辑器
右侧：AI 编程对话 / 工具日志 / 任务计划
```

Code 模式目标是让 AI 能看项目、搜代码、解释代码。

### 4.4 AI 动作可视化

工具调用以简洁状态条展示：

```text
✓ 读取 src/main.tsx
✓ 搜索 "auth"
✓ 找到 4 个相关文件
```

点击可展开原始参数和结果摘要。

### 4.5 上下文透明

Code 模式右侧显示当前 AI 上下文：

```text
Context
- Workspace: personal-agent-app
- Current file: src/App.tsx
- Selected text: none
- Git diff: disabled in MVP
```

用户始终知道 AI 这次会看到什么。

---

## 5. 本地数据结构

第一阶段全部本地存储，不做云同步。

建议路径：

```text
AppData/DWeisDesktop/
├─ settings.json
├─ chats/
│  └─ {sessionId}.json
├─ context/
│  ├─ SOUL.md
│  ├─ USER.md
│  ├─ MEMORY.md
│  └─ AGENT.md
├─ scratch/
│  └─ plan.json
└─ workspaces/
   └─ index.json
```

### 5.1 settings.json

保存：

- 模型厂商。
- Base URL。
- 默认模型。
- UI 主题。
- 最近工作区。

API Key 第一阶段只本地保存，不同步。

### 5.2 chats

每个会话单独 JSON 文件。

### 5.3 context

沿用当前移动端概念：

- SOUL.md：人格底线。
- USER.md：用户资料。
- MEMORY.md：长期记忆。
- AGENT.md：经验技巧。

### 5.4 scratch

临时草稿和 task_plan 持久化。

### 5.5 workspaces

只保存工作区元信息，不保存源码内容：

```json
{
  "id": "uuid",
  "name": "personal-agent-app",
  "path": "D:/program/personal_agent_app",
  "lastOpenedAt": "2026-06-25T00:00:00.000Z"
}
```

---

## 6. AI 工具协议

前端 TypeScript 维护统一工具注册表：

```ts
type ToolDefinition = {
  name: string
  description: string
  parameters: JsonSchema
  execute(args: unknown): Promise<ToolResult>
}
```

工具结果：

```ts
type ToolResult = {
  ok: boolean
  content: string
  data?: unknown
  warning?: string
}
```

MVP 工具：

### Chat 工具

- `task_plan`
- `context_doc`
- `scratch_fs`

### Code 工具

- `workspace_list`
- `workspace_read`
- `workspace_search`
- `workspace_current_file`

第一阶段所有 Code 工具只读。

---

## 7. Rust Tauri Commands

MVP Rust commands：

```rust
open_workspace() -> WorkspaceInfo
list_dir(path: String) -> Vec<FileNode>
read_file(path: String) -> String
search_files(root: String, query: String) -> Vec<SearchMatch>
get_app_data_dir() -> String
```

安全规则：

1. 所有文件访问必须在当前 workspace root 内。
2. 默认禁止读取 `.git`、`node_modules`、`build`、`dist`、`.dart_tool` 等目录。
3. 读取大文件前检查大小，超过阈值返回提示。
4. 写操作第一阶段不提供。

---

## 8. 前端目录结构

建议：

```text
src/
├─ app/
│  ├─ App.tsx
│  ├─ routes.tsx
│  └─ providers.tsx
├─ features/
│  ├─ chat/
│  │  ├─ ChatMode.tsx
│  │  ├─ ChatList.tsx
│  │  ├─ ChatThread.tsx
│  │  └─ ChatInput.tsx
│  ├─ code/
│  │  ├─ CodeMode.tsx
│  │  ├─ FileTree.tsx
│  │  ├─ FileViewer.tsx
│  │  ├─ WorkspaceSearch.tsx
│  │  └─ CodeAiPanel.tsx
│  ├─ task-plan/
│  ├─ context-doc/
│  └─ tools/
├─ services/
│  ├─ ai/
│  ├─ tools/
│  ├─ storage/
│  └─ tauri/
├─ stores/
│  ├─ appModeStore.ts
│  ├─ chatStore.ts
│  ├─ workspaceStore.ts
│  └─ settingsStore.ts
└─ components/
   ├─ layout/
   ├─ ui/
   └─ editor/
```

---

## 9. 状态管理

使用 Zustand。

核心 store：

### appModeStore

```ts
mode: 'chat' | 'code'
setMode(mode)
```

### chatStore

```ts
sessions
currentSessionId
messages
sendMessage()
```

### workspaceStore

```ts
currentWorkspace
fileTree
currentFile
openWorkspace()
openFile(path)
```

### toolStore

```ts
toolEvents
taskPlan
scratch
```

---

## 10. MVP 开发顺序

### 阶段 0：项目骨架

- 创建 Tauri + React + TS 项目。
- 配 Tailwind。
- 配基本窗口。
- 配 Zustand。

### 阶段 1：Shell UI

- 顶部栏。
- Chat / Code segmented control。
- 三栏布局。
- 空状态页面。

### 阶段 2：Chat 模式

- 本地会话列表。
- 对话流。
- 输入框。
- AI provider。
- 打字机效果。

### 阶段 3：工具系统

- ToolRegistry。
- 工具状态流。
- task_plan。
- context_doc。
- scratch。

### 阶段 4：Code 只读工作区

- Rust open_workspace。
- Rust list_dir。
- Rust read_file。
- Rust search_files。
- React 文件树。
- Monaco 只读文件查看。

### 阶段 5：Code AI 工具

- workspace_list。
- workspace_read。
- workspace_search。
- AI 可以解释项目/文件。

---

## 11. 验证标准

MVP 完成后应能完成这些任务：

### Chat

1. 新建会话。
2. 发送普通问题。
3. 看到打字机效果。
4. 调用 task_plan 并显示任务状态。
5. 追加 context_doc 记忆。

### Code

1. 打开 `personal_agent_app` 工作区。
2. 左侧显示文件树。
3. 点击 `lib/controllers/chat_controller.dart` 查看内容。
4. 问 AI：“这个文件负责什么？”
5. AI 调用 `workspace_read` 后给出解释。
6. 问 AI：“搜索 task_plan 在哪里实现。”
7. AI 调用 `workspace_search` 并返回文件位置。

---

## 12. 后续阶段

MVP 验证后再做：

1. Diff 预览。
2. 用户确认后写文件。
3. 撤销本轮修改。
4. 命令执行。
5. Git status / diff。
6. 测试失败自动分析。
7. 手机端联动。
8. 云同步。
9. 账号系统。

---

## 13. 不做联动的理由

手机端联动暂缓是正确选择。

原因：

- 同步会引入账号、冲突、加密、设备绑定等复杂度。
- 目前最关键是验证桌面端 Chat / Code 双模式是否好用。
- 只要本地数据模型设计清楚，未来可以在 Repository 外层增加 SyncAdapter。

第一阶段只做本地 MVP。