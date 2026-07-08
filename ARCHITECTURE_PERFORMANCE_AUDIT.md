# 架构与性能审计报告 — personal_agent_app (Flutter)

> 专家：掌中灵（Mobile App Builder / 移动应用开发工程师）
> 日期：2026-07-08
> 范围：lib/ 全量源码审计（架构分层 + 移动端性能）
> 基线：Flutter 3.41.9 / Dart 3.11.5，get_it + ChangeNotifier，自建双模设计体系

---

## 一、总体结论

底层健康度**中等偏上**：导航已集中（AppRouter 封装 Navigator.push）、dispose 规范、主消息列表用 `ListView.builder`、图片主路径用 `CachedNetworkImage` 且带 `memCacheWidth` 与 placeholder。

但有**两个直接影响真机体验的命门**（群聊流式整屏重建、媒体缩略图无解码约束），以及若干**全局 static 可变状态**带来的测试 flake 与运行时隐患。下面按优先级列出，均带文件:行号，可操作。

---

## 二、架构问题

### 1. 全局可变 static 状态（最该收口）
| 位置 | 字段 | 风险 |
|---|---|---|
| `tools/task_plan_tool.dart:20,21,23,26` | `_currentPlan` / `lastStatusText` / `_queue` static | 已知测试顺序 flake 源；`resetDependencies` 不清理 |
| `widgets/ai_settings.dart:14` | `static _builtIn = []` | 静态可变列表存"已注册内置 vendor"，测试间串扰 |
| `tools/reminder_tool.dart:38` | `static _channelCreated` | 跨测试泄漏 |
| `services/foreground_service.dart:10` | `static _isRunning` | 全局可变状态标记（Timer 本身在 stop 已 cancel，**非泄漏**） |

**根因**：`service_locator.dart` 的 `resetDependencies()` 只调 `getIt.reset()`，既不 dispose 单例（默认不触发 onDispose）、也不清这些类的 static 字段、更不重新 `configureDependencies()`。→ 测试间状态串扰、偶发 flake。

### 2. 群聊编排逻辑耦合在 UI State
`group_chat_screen.dart:199-363`（约 160 行 `_send` / `_handleRelay` / `_autoPickSpeaker` / `_runOneAgent`）把多 Agent 调度编排与界面混在一起。已有 `GroupChatCoordinator` 但只做 `autoPickSpeaker`，建议把接力调度抽到 Coordinator/Service，缩小 State 职责。

### 3. DI 重置不干净
`getIt.reset()` 默认**不 dispose 单例**（`dispose: true` 才触发 onDispose）；持有流/订阅的 `ConnectivityService` / `McpManager` / `NotificationService` / `ThemeService` 在测试 reset 后泄漏；重置后若只 reset 不 re-configure，`getIt<X>()` 抛 `StateError`。

---

## 三、性能优化（按移动端影响力排序）

### P0 — 直接决定真机流畅度 / 内存，建议立即修

**P0-1 群聊每 token 整屏 setState（最大卡顿源）**
- 位置：`group_chat_screen.dart:496-498, 508-510`
- 现象：流式中每个 token + 24ms 打字机心跳都 `setState(() {})`，重建**整个 GroupChatScreen + 所有可见 GroupMessageBubble 的 markdown 解析**。多 Agent 接力时（最多 5 轮 × N 个 Agent）最影响流畅度。
- 建议：把 `placeholder`（`ChatMessage`，本身已是 ChangeNotifier）作为细粒度数据源，`GroupMessageBubble` 用 `ListenableBuilder` 监听**单条消息**；`_runOneAgent` 内去掉整屏 `setState`，仅在「消息增删 / 状态栏变化」时 `setState`。单聊已用此模式（`_AIBubble` + 节流 + 解析缓存），群聊对齐即可。

**P0-2 媒体缩略图无解码尺寸约束（OOM 风险）**
- 位置：`media_page.dart:97` `Image.file(file, fit: BoxFit.cover)` 缺 `cacheWidth` / `cacheHeight`
- 现象：网格缩略图按**原图尺寸**解码，相册里的大图会瞬间吃大量内存，低端机 OOM / 卡顿。
- 建议：`Image.file(file, cacheWidth: 360, cacheHeight: 360, fit: BoxFit.cover)` 按显示尺寸约束解码（解码器会按目标尺寸缩采样，内存大幅下降）。

### P1 — 重要但不紧急

**P1-3 单聊 controller 流式双通知**
- 位置：`chat_controller.dart:459-461`
- `ChatMessage.text/steps` setter 已各自 `notifyListeners()`，`_onStreamEvent` 又调 `_notify()` → 一次 token 两次通知，可见气泡反复重建。
- 建议：文本增量只走 `ChatMessage` 监听（已有）；controller 仅在「消息增删 / 步骤变化 / isLoading 变化」时 `_notify()`（拆分 notifier 或条件化 `notifyListeners`）。

**P1-4 启动阻塞首屏**
- 位置：`main.dart`（`runApp` 前 `await McpManager.autoConnect()` / `ForegroundService.start()`）
- 建议：`unawaited` 或并行启动，不阻塞首帧，冷启动目标 < 3s。

**P1-5 FutureBuilder 的 future 在 build 内创建**
- 位置：`context_docs_panel.dart:57-58` `future: getIt<ContextDocService>().read(doc)`
- 现象：每次父级重建（含主题切换）重发磁盘读。
- 建议：移 `initState` 缓存，或改用 `FutureProvider` / 本地 state。

**P1-6 附件读取无保护（崩溃风险）**
- 位置：`chat_controller.dart:233-243` `await _pendingAttachment!.readAsBytes()` + `base64Encode` 无 try/catch
- 建议：包 try/catch，失败回退为错误气泡而非崩溃。

**P1-7 图片"清除缓存"功能名不副实**
- 位置：`image_cache_page.dart:42-78`
- 现象：只把 `_cacheSize` / `_imageCount` 置 0，**未删除任何文件、未清 CachedNetworkImage 缓存**。属功能正确性问题，直接影响存储/内存观感。
- 建议：真删 `MediaStorage` 中文件 + 调 `CachedNetworkImage` 缓存清理。

### P2 — 打磨

- **P2-8** 主题每次 build 新建 `ThemeData` / `TextTheme`（`app.dart`）：memoize，仅在 brightness 变化时重建。
- **P2-9** 静态小列表（`agent_contact_page.dart:59` 等）改 `ListView.builder` 防未来大列表。
- **P2-10** 长会话 `_messages` 全量常驻 + 每次 `saveSession` 全量读会话列表（`chat_controller.dart:159`）：增量保存 / 分页。
- **P2-11** 设置来源统一：群聊/agent 压缩用 `getIt<AISettings>()` 而非新建 `AISettings()`（`group_chat_screen.dart:249`），避免两套真相 + 多余磁盘读。

---

## 四、专家建议与下一步

- 真机体验提升**最猛的两刀**：**P0-1 群聊细粒度重建** + **P0-2 缩略图解码约束**。两项风险可控、改动局部，能直接消灭群聊卡顿与相册 OOM。
- 全局 static 状态（TaskPlanTool 等）建议一并收口，顺手消除测试 flake。
- 已做得好的点（导航集中、dispose 规范、主列表 builder、图片主路径尺寸约束）**不要过度优化**，避免引入回归。

> 注：本报告由 Explore 子代理通读 lib/ 后生成，关键 P0/P1 命中点已由主代理二次读码复核；其中「前台服务 Timer 泄漏」经复核为误报（stop() 已 cancel），已从泄漏清单移除。
