# Changelog

## v1.4.3 — 首次见面硬化 + SSE 解析修复 + 日志系统强化 (2026-07-09)

### 🔧 Bug 修复：首次见面流程「经常不触发」（脆弱性根因修复）
- 根因：原 `isFirstMeeting = !hasUserProfile() && _messages.isEmpty` 是「一次性门禁」——首条消息没完成引导就永久不再触发；且 `hasUserProfile()` 用正则要求 `语气风格：` 字段，但 USER.md 模板里根本没有该字段 → 判定永远「未完成」且不再引导，卡死在死区。
- 修复（对标 file-gate 思路，把「完成态」从推断改为显式哨兵）：
  - `chat_controller.dart`：去掉 `&& _messages.isEmpty`，只取决于 USER.md 是否完成，**没完成就一直引导**。
  - `context_doc_service.dart`：新增静态纯函数 `isProfileContentComplete(content)`，完成判定 = 占位符 `（待用户首次指定）` 消失 + `怎么称呼` 填实；**不再依赖任何中文字段名正则**，模板微调不会误判。
  - `assets/context/USER.md`：补 `- 语气风格：（待用户首次指定）` 字段，让语气有结构化落点。
  - `prompt_builder.dart`：`<first_meeting>` 明确让模型把昵称写进「怎么称呼」、语气写进「语气风格」、并移除占位符。

### 🐛 Bug 修复：SSE 流式解析 `RangeError`
- 现象：`[OpenAiProtocol] Parse SSE line error: RangeError (length): Valid value range is empty: 0`。
- 根因：`jsonDecode(data)['choices']?[0]` 的 `?` 只防 `choices` 为 null，未防空数组 `[]`；OpenAI 兼容接口开启 `stream_usage` 时最后一个分片 `{"choices":[],"usage":{...}}` → `[0]` 越界。
- 修复：抽出公开静态方法 `OpenAiProtocol.firstChoice(dynamic)`，统一取 `choices[0]`，兼容 null / 空数组 / 非 Map（均返回 null 不抛错）；替换 `stream()` 主循环、末尾缓冲分支、`callNonStreaming`，并硬化 `ai_service.dart` 历史压缩 `summarize` 接口同款隐患。Anthropic 协议无此结构未动。

### 📋 日志系统强化（默认开启）
- **默认开启**：`_enabled` 默认改为 `true`；`main.dart` 启动早期 `await log.setEnabled(true)` 打开文件 sink，确保默认就写盘（设置仍可手动关）。
- **时间戳加日期**：从 `HH:MM:SS.mmm` 升级为 `yyyy-MM-dd HH:mm:ss.mmm`，跨天日志不再糊在一起。
- **warn/error 带堆栈**：`w(tag, msg, [error, stack])` / `e(tag, msg, [error, stack])`，警告不再只有文字丢失堆栈。
- **自动轮转**：文件超 **5MB** 自动备份为 `dweis.log.1` 再清空当前文件（每 100 行检查，非阻塞 `unawaited`），长期开着不无限涨。
- **崩溃强制留痕**：新增 `recordFatal()`，并接进 `ErrorHandler._report`（`FlutterError` + zone 未捕获异常均写盘）。**关键点**：此路径**即使关闭「启用日志」开关也强制落盘**，补上「现场崩了崩因不进日志」的缺口。

### 🧪 测试
- 全量测试串行通过（`flutter test -j 1`）；新增 `context_doc_service_test`（哨兵判定组）、`ai_service_openai_test`（空 choices 分片 + `firstChoice` 四种分支）、`log_service_test`（默认开启 + 崩溃强制落盘）。

---

## v1.4.2 — 输出稳定性增强 + 计划面板极简化 (2026-07-09)

### 🐛 Bug 修复（输出稳定性）
- **单聊流式不刷新**：`chat_screen.dart` 漏给气泡套 `ListenableBuilder(listenable: msg)`，导致工具调用/思考步骤不显示、流结束才一次性吐出。已与 `agent_chat_screen` 一致逐条包裹，流式细粒度刷新恢复。
- **并发工具 ×N 显示乱**：批次并发时每步重复标 `×N`（N×N 错觉）+ 同名工具按名字错配。改为仅末步标 `×N`，并靠 `toolId` 精确匹配完成（新增 `ToolStartEvent.id` / `TimelineStep.toolId`）。
- **群聊退出即中断**：`GroupChatController.dispose()` 误取消进行中的对话/工具流，退出界面丢失整个回复。改为 dispose 仅清 listeners、不 cancel 流；后台流跑完自然存盘。
- **返回键也后台继续**：单 agent 界面与群聊的 `PopScope` 返回键原会 `stop()` 中断模型。改为 `canPop: true` + 返回只 `pop`，离开界面后台继续跑完（手动停止按钮仍真正 cancel）。`_runAgent` 的 `finally` 加 `if (mounted)` 守卫防崩溃。

### 🎨 计划面板极简化
- 气泡内 `TaskPlanView` 由 callout（左侧蓝色 accent 竖线）改为纯「极浅中性底色 + 圆角」无边框引用块，去掉装饰性蓝竖线，更简约。

### ✨ 新功能：笔记「读正文」
- `manage_notes` 工具新增 `read` action：按 `note_id` 返回某篇笔记的**完整正文**（标题 + 创建/更新时间 + Markdown 内容）。此前模型只能写/列笔记、无法翻回去看内容；现在 `list`（看索引）→ `read`（看正文）→ `update`/`delete`（改/删）链路完整。

### 🧠 记忆系统维护规则（仅主聊）
- 系统提示新增规则 11/12：教模型**何时**主动维护 `MEMORY.md`（跨会话事实持久化）与 `AGENT.md`（任务经验沉淀）。此前这两份文档在系统提示中无任何「何时写入」的触发规则。记忆系统按设计仅作用于主界面单聊，agent 群不启用。

### 🎯 增强：人格一致性（语气/昵称始终遵守）
- 修复「SOUL.md 语气 / USER.md 昵称只在对话最开始遵守、后面偏离」的 persona drift 问题。系统提示虽每轮注入 persona，但模型长对话遵循度下降；现新增 `<persona_constraints>` 硬约束块 + 【人格一致性】规则 13，将语气/昵称钉为最高优先级约束，全程不得偏离（除非用户明确要求改变）。

### 🧪 测试
- 全量测试串行通过（`flutter test -j 1`）；新增 `manage_note_tool_test`、`prompt_builder_test`。

---

## v1.4.1 — 数据库初始化修复 + 性能优化 + 计划面板气泡化 (2026-07-09)

### 🐛 Bug 修复

- **群聊界面一直转圈**：`main.dart` 从未调用 `AppDatabase.instance.initialize()`，且 `DbMigration.run()` 用 `unawaited` 启动导致 UI 在迁移完成前读到空表并被 `CachedRepository` 永久缓存。`main.dart` 改为 `await initialize()` + `await DbMigration.run()`（均带 try-catch），彻底解决进群聊死转圈。

### ⚡ 性能优化

- **P0 流式整屏重建**：`agent_chat_screen.dart` 流式 `setState` 全去掉，改用 `ListenableBuilder` 包 `ChatBubble`，流式期间仅当前气泡重建，不再整屏重绘（最大卡顿源消除）。
- **P1 MarkdownStyleSheet 缓存**：`inline_content.dart` 按主题颜色哈希缓存，避免每帧重建 80 行样式表。
- **P1 BackdropFilter 降开销**：5 处毛玻璃 `sigma` 由 20 降到 12，GPU 模糊开销降约 40%，视觉几乎无差。
- **P1 chat_bubble 节流**：`_onChanged` 删掉冗余 `setState`（`ListenableBuilder` 已接管重建），避免双重重建。
- **P2**：`group_chat_input_bar` 加 `didUpdateWidget`；`group_chat_screen` 的 `GroupStatusBar` 外包 `RepaintBoundary`，消息滚动时不连带重绘。

### 🎨 计划面板气泡化

- **输入框上方悬浮面板移除**：删除只服务悬浮面板的 `TaskPlanPanel` 类，`chat_screen.dart` 不再挂悬浮面板；`ChatMessage` 新增 `plan` 字段，`TaskPlanEvent` 直接写入对应 AI 气泡。
- **气泡内嵌渲染**：`chat_bubble.dart` 的 AI 气泡内嵌入 `TaskPlanView` 卡片（processLine 之后、文本之前），支持折叠、随气泡局部刷新。
- **群聊也支持**：`group_chat_runner.dart` 的 `TaskPlanEvent` 改为写入 `placeholder.plan`；群聊空气泡守卫加 `msg.plan == null` 条件，确保「无文本纯 plan」气泡不被隐藏。

### 🧪 测试

- 全量 **307 个测试** 串行通过（`flutter test -j 1`）。
- 已知偶发 flake（`task_plan_state_machine_test`）已通过 getIt 隔离消除。

---

## v1.4.0 — 群聊协调者派活 + UI v2 + 架构优化 (2026-07-08)

### 🚀 群聊「协调者-子Agent」工具调用派活

- **delegate_task 工具**：协调者通过 `delegate_task(agent, brief)` 把任务分派给子 Agent，对齐 OpenCode 子代理架构。问用户（自然语言）与派活（工具调用）结构性分离，彻底告别靠解析 `@名字` 文本派活的脆弱机制。
- **子 Agent 隔离执行**：子 Agent 只在「用户原始需求 + 任务简报」的隔离上下文中执行，不看全量群历史，互不干扰。
- **串行锁 + 上限防护**：多个委派串行排队（`_SerialLock`），最多 5 次委派防止失控。
- **可读的派发 UI**：协调者派发气泡时间线显示「派发任务给「X」」，子 Agent 答案直接呈现，末尾有一两句简短收尾告诉用户任务完成。
- **调度权独占**：只有协调者拥有 delegate_task 工具，子 Agent 不能反向分派；协调者提问时不派活（先收集需求、用户回答后再派），杜绝"未答先派活"。

### 🧱 群聊架构重构

- **GroupChatScreen 彻底 controller 化**：状态与编排逻辑全部下沉到 `GroupChatController`（`ChangeNotifier`），页面退回纯渲染。可独立单元测，状态变更集中可预测。
- **runGroupAgentMessage 独立**：流式重逻辑抽取为 `group_chat_runner.dart` 顶层函数，与主屏解耦。`GroupChatScreen` 从 697 行降至约 520 行。
- **GroupChatInputBar 风格统一**：对齐单聊输入框（水平留白 + 毛玻璃背景 + 柔性胶囊），消除宽/高/样式割裂。
- **长会话 UI 分页**：只渲染末尾 30 条，"查看更早的消息"按钮加载历史，滚动位置保持不跳动。

### 🎨 UI v2 全面重设计

- **苹果原生极简风格**：浅色/暗色双模，柔白 off-white 层次（`#FAFAFA` 页面底 + `#F2F2F7` 卡片/输入框），层次清晰不刺眼。
- **统一 AppTopBar**：毛玻璃效果 + 真实状态栏高度 + 0.5px 发丝分隔线 + iOS 返回箭头（`Center`+`Stack` 整宽居中、返回键不被长标题遮挡），全库 13+ 页面统一。
- **全库图标从 Phosphor 迁到 Material Icons**：彻底解决 Phosphor 字体在设备上特定字形渲染为 tofu（方块）的系统性问题。Material Icons 字体 100% 可靠。
- **设计令牌集中**：`design_tokens.dart`（Radius/Space/Font/Weight/Motion 全集中），消除散落 magic number。
- **统一组件**：`ElevatedCard`（阴影浮起卡片）、`AppListTile`（iOS 按压高亮无波纹）、`AppButton`、`AppAvatar`。

### ⚡ 性能优化 (P0/P1)

- **群聊细粒度重建**：`ListenableBuilder(listenable: m)` 包裹每条消息，流式期间只重建对应气泡，不再整屏 `setState`（最大卡顿源消除）。
- **单聊双通知消除**：移除 `_onStreamEvent` 末尾冗余 `notifyListeners()`，文本/步骤已走 `ChatMessage(ChangeNotifier)` 局部通知。
- **TaskPlanTool 静态状态降级**：`_currentPlan`/`lastStatusText`/`_queue` 从 `static` 改为实例字段，消除跨测试/跨对话静态状态泄漏（测试顺序 flake 真根因）。
- **启动不阻塞**：`autoConnect()` 和 `ForegroundService.start()` 改为 `unawaited(...)`，不阻塞首屏冷启动。
- **媒体缩略图解码优化**：`Image.file` 加 `cacheWidth/cacheHeight:360`，避免大图原尺寸解码 OOM。
- **其余**：FutureBuilder → StatefulWidget initState 去重；附件读取崩溃 try/catch 兜底；清除缓存真实现（`imageCache.clear()` + `MediaStorage.remove`）。

### 🐛 Bug 修复

- **群聊"未答先派活"**：协调者向用户提问的同一轮不再同时 @ 子 Agent 开工，等用户回答后下轮再派。调度权收归主 Agent，子 Agent 的 @ 不触发接力。
- **返回键方块图标**：Phosphor 字体设备端部分 codepoint 渲染异常 → 全库迁到 Material Icons 彻底根治。
- **AppTopBar 标题遮挡返回键**：长标题 `Stack` 层叠遮盖 → 改为标题底层绘制 + `Positioned` leading/actions 浮层。
- **对话 markdown 链接点不动**：`selectable:true` 下 `onTapLink` 被吞 → 去掉 selectable，恢复可点。
- **Agent 工具勾选无反馈**：`_tools` 集合修改后缺 `setState` → 补上立即刷新选中态。
- **群聊 `[[reply_to_current]]` 泄漏**：模型生成的控制标记落库 → 流式结束 + 加载历史时剥离。
- **主 Prompt 残留"代码执行"板块**：shell 沙箱已移除但 prompt 仍教 Agent 用 shell → 删除 5 条遗留规则。

### 🧪 测试

- 全量 **279 个测试** 串行通过（`flutter test -j 1`）。
- 新增：`delegate_task` 工具契约测试、群聊端到端派活测试、AppTopBar 返回键测试、空气泡守卫测试。
- golden 测试覆盖 GroupMessageBubble（Agent 气泡 / 系统消息 / 流式占位）。
- 已知偶发 flake：`task_plan_state_machine_test` 的 static 泄漏已在 v1.4.0 修复，确认不再复发。

---

*历史版本记录请查看 git log。*
