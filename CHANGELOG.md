# Changelog

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
