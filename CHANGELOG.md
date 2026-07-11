# Changelog

## v1.4.29 — 会话切换零延迟 + 回到底部平滑 + 切换去冗余序列化 (2026-07-11)

### 🔥 会话切换零延迟（治「点击要等会才能进入」/ 切换卡点）
- 撤销上轮误加的 260ms 骨架延迟方案：删除 `_loading` 骨架态 + `Future.delayed(260ms)` + `AnimatedSwitcher` 骨架↔列表交叉淡入（该方案反而让每次点会话先转圈 260ms 再进，且骨架切换本身有卡点）。
- 对齐 Operit「抽屉 GPU 动画期间内容不重组」真实机制：点会话**立即 `switchSession` + 立即 `closeDrawer`**。标准 Drawer 不透明、完全覆盖内容，切会话的列表重建在抽屉关闭动画背后发生、被遮挡不可见；抽屉收起时内容已就绪 → 零延迟、无转圈、无闪烁。
- `cacheExtent` 500→4000：滚出视口的长消息气泡不再被销毁/重建/重测 markdown（对齐 Operit 大缓存窗口，治切换后回看卡顿）。

### 🟢 「回到底部」平滑滚动（治回到底部不流畅）
- 删除旧 `_followBottom` 每帧 `jumpTo` 手动循环 + 整个 `AnimationController`（连带去掉 `SingleTickerProviderStateMixin`）。旧实现第一帧硬跳到底、动画时长形同虚设，用户感受为「瞬移 + 割裂」。
- 改用原生 `animateTo(max)`：距底 ≤ `cacheExtent×0.8`（≈3200px≈4 屏）**整体平滑滚动**（该范围气泡已被 cacheExtent 预构建，沿途无白屏、无突兀跳变）；仅极远处（>4 屏）点回到底部才先瞬跳最后一屏再收尾。预跳前先置 `_autoScrolling=true` 避免误判用户上滑。

### 🪶 switchSession 去冗余序列化（降切换主线程尖刺）
- 非流式态下不再每次 `saveSession()` 全量序列化当前会话所有消息（已收尾会话此前已落盘），仅流式中 `stopStream` 才存盘，其余仅轻量刷新会话列表。

### 🧹 消息列表页（治返回卡点）
- `_MessageTile` 删除 `FadeTransition`+`SlideTransition` 进入动画，静态直出，返回重建不重播动画。
- `_openChat` 返回后的 `_load()` 包进 `addPostFrameCallback`，延到 pop 转场结束后再跑，不与 IosSlideRoute 返回转场抢帧。

## v1.4.28 — 删除气泡进入动画，根治切会话卡顿 (2026-07-11)

### 🚀 删除气泡进入动画（根治切历史对话卡顿）
- 根因：从侧边栏点历史对话切换会话 / 加载历史时，首屏几百条气泡**同时播放淡入 + 滑入动画**，叠加 Drawer 关闭动画抢占主 isolate → 明显卡顿。
- `chat_bubble.dart`：① AI 气泡 `_AIBubbleState` 删除 `TickerProviderStateMixin` + `_enterCtrl`/`_enterOpacity`/`_enterOffset` 字段与 initState 动画构建，直接返回静态气泡；② 用户气泡删除 `TweenAnimationBuilder`（淡入 + 上滑 8px），直接返回静态气泡。群聊气泡本就无进入动画，无需改。
- 列表首屏现在静态直出、零进场动画抢占主 isolate，切会话/加载历史顺滑度明显提升。
- 流式增量富文本、200ms 令牌节流、块渲染缓存、骨架屏等既有流畅度优化全部保留不受影响。

## v1.4.27 — 会话加载骨架屏 + 白屏/键盘根治，侧边栏回滚 (2026-07-11)

### 💀 会话加载骨架屏（错峰重 build，消除冷启动首开卡顿）
- 新增 `lib/widgets/chat_skeleton.dart`：`ChatListSkeleton`——左右气泡形状交替 + 微光扫过 shimmer（复用现成 `AppDurations.shimmer` 与「思考中」文字同款高亮取法，视觉统一）。
- `chat_screen.dart` 加 `_loading` 态：`initialize()` 完成前显骨架、完成后 `AnimatedSwitcher` 淡入真实列表，把「转场动画帧」与「首帧 build 200 气泡帧」错峰。`_loading` 初始仅在「有会话 id 且控制器未就绪（冷启动）」时为 true，缓存命中直接显真实列表、不闪骨架。
- `chat_controller.dart` 加 `_initialized` 守卫：缓存命中的会话跳过 `initialize()` 全部 await，二次进入真正秒开。
- `chat_screen.dart` 列表 `cacheExtent` 1000→500，减少首帧不可见气泡的 build 压力（群聊/agent 屏保持 1000）。

### 🩹 「回到底部」白屏根治
- 根因：旧逻辑在 280ms 内逐帧 `jumpTo` 滚过整个列表，从很上面点时 `ListView.builder` 来不及构建沿途重气泡 → 一路白屏才落底。
- 根治：距底超过 1.2 屏时先瞬跳到「底部前一屏」（只构建最后一屏），再对最后一小段平滑动画收尾；1 屏内保持全程平滑不预跳。

### ⌨️ 键盘弹起不遮挡内容根治
- 根因：`resizeToAvoidBottomInset` 已抬输入框，但消息列表不自动上滚，最后一条被抬起的输入框盖住。
- 根治：将「键盘弹起→列表贴底」判断从脆弱的 `_userScrolledUp` 标志改为实时「距底 < 1 屏才贴底」，输入时最后一条永远露出、上翻看历史不打扰。

### ↩️ 侧边栏回滚为标准 Drawer
- 撤销 v1.4.26 的 `PushDrawer` 3D 推入：删除 `push_drawer.dart`，`agent_side_drawer.dart` / `agent_top_bar.dart` 还原至标准 `Drawer`，`chat_screen.dart` 恢复 `Scaffold.drawer` + 黑遮罩（0.38）+ 边缘拖拽开。（转场 scale 纵深增强保留）

## v1.4.26 — 侧边栏安全版 3D 推入 + 转场轻量增强（借鉴 Operit）(2026-07-11)

### 🎨 侧边栏安全版 3D 推入（借鉴 Operit 无遮罩推入式抽屉）
- 新增 `lib/widgets/push_drawer.dart`：`PushDrawer` 推入式抽屉容器。打开时主内容右移 82% + 缩放至 0.92 + 圆角 24 + 阴影 18，**无遮罩**（叠透明点击层关闭），打开用弹簧（轻微回弹）、关闭无回弹，支持左缘横滑手势开关。
- 刻意**不加 rotationY 3D 翻转**（即此前回滚的 3D 折叠效果），规避回归风险，取 Operit 推入式层次感而避其坑。
- `agent_side_drawer.dart`：去掉 Material `Drawer` 外壳，菜单项改用 `onRequestClose` 回调关闭——推入式抽屉是内联组件而非路由，原 `Navigator.pop()` 会误弹当前页。
- `agent_top_bar.dart`：菜单按钮新增 `onMenu` 回调驱动抽屉，保留对旧 `openDrawer()` 用法的回退兼容。
- `chat_screen.dart`：接入 `PushDrawer` 替换标准 `Scaffold.drawer` + 黑遮罩（0.38）。

### ✨ 转场轻量增强（IosSlideRoute 叠加 scale 纵深）
- `app_animations.dart`：在现有 iOS 横滑视差基础上叠加 `ScaleTransition`——进入页 0.98→1.0、旧页往后沉至 0.98。纯 GPU transform，**不引入整页 fade 离屏合成**，保留「聊天流畅度优先」取向。

### 🧹 其他
- 清理 Operit 源码研究残留 `op_research/`。

## v1.4.25 — 深度搜索 + 聊天流畅度（借鉴 Operit）(2026-07-11)

### 🔍 深度搜索工具（方案②：工具内 LLM 综合，借鉴 Operit）
- 新增 `lib/tools/deep_search_tool.dart` + `.txt` + `.g.dart`：`DeepSearchTool` 先 LLM 拆 3–5 个子问题，多轮（≤4）并行搜索（SearXNG 优先，失败/未配置回退 Tavily），取前 N 条 URL 去重 `WebFetch`(max_length 4000) 后 LLM 综合带 `[n]` 引用 + 「## 来源」。
- 全程 `ToolProgressBus.__SUMMARY__` 播整批进度；材料充足早停；无 LLM 配置时退化为资料罗列。
- `AIService.complete()` 新增（消费 `sendMessageStream` 收集 `TextChunkEvent`），工具内按当前厂商 `getIt<AISettings>` 构造，零侵入、不碰 `delegate_task` 内核。
- `PluginRegistry` 幂等注册 `deep_search`；`tools.dart` 导出。

### 💬 聊天流畅度专项（借鉴 Operit 流式批处理 + 节点缓存）
- `ChatMessage.text` 加 **200ms 流式节流层**（首包 leading-edge 即时上屏 + 200ms 边界 trailing flush，≤5Hz 重建）：逻辑文本 `_text` 始终即时更新（存取/复制正确），仅 `notifyListeners` 被节流，等价 Operit `RENDER_INTERVAL_MS=200` 批处理层；流结束 `isStreaming=false` 立即 flush 最终文本并取消残留定时器。
- 块渲染缓存**跨重建持久化**：原 `_AIBubble` 实例字段 `_frozenBlockWidgets` 移至 `_BlockRenderCache`（按 `msg.id` + 主题哈希 LRU 缓存，上限 60 条），气泡滚出 `cacheExtent` 再滚回时复用已渲染 widget（Flutter 对相同 widget 实例做 no-op update，不重解析、不重排版），消除回看长消息的跳动/卡顿；代码块(fenced)/图片块依赖 BuildContext 不缓存，每次重渲染。
- `chat_screen.dart` 列表 `cacheExtent` 500→1000（缓存窗口：视口外多保留 1000px 气泡，滚回不重建/重测）。
- **对齐至群聊与 agent 单聊**：群聊屏 `group_chat_screen.dart`、agent 单聊屏 `agent_chat_screen.dart` 的 `ListView.builder` 均补 `cacheExtent: 1000`；二者正文渲染复用 `ChatBubble`，故 200ms 节流与块渲染缓存已自动同步，仅缺缓存窗口一项。
- **「回到底部」平滑滚动修复**：旧 `_followBottom` 每帧直接 `jumpTo(maxScrollExtent)`＝第一帧硬跳到底、280ms 动画时长形同虚设（用户感受为「卡/突兀」）。改为在动画起点 offset 与「当前」max 间用 `Curves.easeOutCubic` 插值（等价 Operit `animateScrollTo` 的 spring 平滑滚动），每帧重读 max 兼顾未测量尾部/流式增长的自然跟随。主聊天屏 + 群聊屏同步修复。
- **键盘弹起不再遮挡内容**：三屏（`chat_screen` / `group_chat_screen` / `agent_chat_screen`）加 `WidgetsBindingObserver.didChangeMetrics` 监听：键盘弹起（`MediaQuery.viewInsets.bottom` 增大）时逐帧 `jumpTo` 跟随键盘上移贴底，消除 Scaffold resize 后最后一条消息被抬高的输入框遮挡；主/群聊在用户上滑看历史（`_userScrolledUp`）时不强制拽回底部，保持阅读位置。

## v1.4.24 — 插件化架构 + 工具可观测性（借鉴 Operit）(2026-07-11)

### 🔌 PluginRegistry 插件骨架
- 新增 `lib/tools/plugin_registry.dart`：单例 `PluginRegistry` 编排能力插件，`registerCapabilities(registry)` 向每会话 `ToolRegistry` 注入工具；`AppPlugin` 接口（`id` + `init()` + `provideTools`），内置 CoreTools/Skill/Mcp 三插件，幂等按 id 去重。

### 🧰 工具四件套（core/tools 细化）
- `ToolExecutionLimits`：统一护栏常量（最大结果字符 20000 / 单工具连续调用 10 / 并发 8 / 超时告警 30s）。
- `ToolProgressBus`：单例进度总线，`__SUMMARY__` 优先级 1000 做整批进度，工具级实时进度广播。
- `ToolHook`：sealed 拦截决策 + 7 生命周期钩子（before/after/异常/完成），`ToolHookChain` 串跑。
- `ToolResultData`：sealed 结构化结果（文本/错误/列表/键值），`ToolResult.structured` 工厂。

### 📊 内核可观测性增强（不碰 delegate_task 阻塞内核）
- `ToolRegistry.execute()` 接入钩子链 + 进度总线（调用前可拦截、频率硬阻止、全周期打点）。
- `executeAllTools`(`ai_service_base.dart`) 加批次计时 + 每工具耗时日志，保持 `Future.wait` 并发结构不变。
- `chat_helpers` 的 `registerAllTools`/`registerMcpTools` 委托给 `PluginRegistry`（6 处调用点零改动）。

### ⚠️ 注意
- 本版本为纯架构重构（插件化 + 工具可观测性），无 UI/行为变更；`delegate_task` 阻塞式内核保持不动（此前已评估否决大重构）。

## v1.4.23 — 微信级聊天性能架构（分页存储 + 内存窗口 + 页面缓存）(2026-07-11)

### 🚀 流式占位行平滑收起（P0 · 修复气泡高度回跳）
- `chat_bubble` 的「思考中」/工具进度占位行改用 `AnimatedSize(160ms easeOut)` 包裹，首 token 到达时占位行**平滑收起**而非瞬间 pop。
- 消除流式回复末尾气泡高度骤降导致的列表回跳（微信级「高度稳定」原则）。

### 🗄️ 消息分页存储（P1 · 打开会话不再加载全量）
- 新增 `messages` 表（`session_id, msg_id, seq, data`，PK=(session_id,msg_id)，索引 (session_id,seq)），`AppDatabase` 版本 1→2，`onUpgrade` 补建。
- `ChatStorage` 重构：消息走 `messages` 表**游标分页**读取；`chat_sessions` 仅存元数据（标题/时间/类型 + `preview`/`messageCount`）。
- 保存时**增量 upsert**（按 msg_id 覆盖、绝不 DELETE 其他消息），窗口之外的历史始终安全；`ChatMessage` 新增全局 `seq` 字段保证排序稳定。
- `DbMigration` 新增迁移：把已有 `chat_sessions` blob 的消息体拆分进 `messages` 表，并把 `chat_sessions` 重写为元数据（幂等，仅执行一次）。
- `loadAll`/导出/搜索/列表改为读元数据或 `loadSession(full:true)`，不再反序列化整包历史。

### 🪟 内存滑动窗口 + 上滑分页（P2 · 长会话内存有界）
- 打开会话默认只取最近 200 条（`ChatStorage.defaultWindow`）注入内存；`_messages` 仅持窗口，长会话内存不再无限增长。
- `ChatController.loadOlderMessages()` 游标分页 prepend 更早消息；`ChatScreen` 列表顶部加「加载更早消息」入口。
- 新消息分配全局 `seq`（`_appendMessage`），删除单条同步删表行（`deleteMessage`）。

### 📱 页面/控制器缓存（P3 · 进出会话不再重载）
- 新增 `ChatControllerCache` 单例：同一会话的控制器跨页面进出**复用**，消息已在内存、进入无白屏/重载闪烁。
- `ChatScreen` 退出时记录滚动位置（`lastScrollOffset`），再次进入 `jumpTo` 恢复（微信级 L8 页面缓存）。
- `onNeedScroll` 改为可重绑，复用控制器时回调指向新页面；删除会话时 `evict` 缓存。

### ⚠️ 破坏性/注意
- `ChatSession` 新增 `preview`/`messageCount` 字段；`ChatMessage` 新增 `seq` 字段（序列化兼容旧数据）。
- 数据库结构变更（v2），旧版数据库经 `DbMigration` 自动拆分迁移，无需手动处理。

## v1.4.22 — 上下文管理全面优化（Prompt Cache + 纯压缩 + 工具结果截断对齐）(2026-07-10)

### 🔌 Prompt Cache 命中优化（省 token）
- **根因**: system 末尾每轮注入「当前时间（精确到秒）」→ 前缀逐 token 变化；两协议层均无 `cache_control` → 缓存永远失效，命中率≈0。
- **A · system 稳定化**: 「当前时间」从 system 移入历史末尾 user 消息（`buildMessageHistory` / `_buildHistory`），system 主体恒定为可缓存前缀。
- **B · 双协议 cache_control**: Anthropic system 标 `[{type:text,text,cache_control:{type:ephemeral}}]`；OpenAI system 的 String content 转同结构 block。命中后 system 只计 cache_read 价（约 1/10）。
- **日志打点**: Anthropic 解析 `message_start.usage.cache_read_input_tokens`；OpenAI 加 `stream_options.include_usage` 解析 `cached_tokens`——厂商返回的真实命中数字，非估算。
- 覆盖主聊 + 子 Agent/群聊成员；群聊 N 个 Agent 各发 system → 收益放大 N 倍。

### 🪟 移除滑动窗口截断（回归纯压缩）
- 主聊 `maxMessages:20` 与子 Agent `maxMsgs:50` 是早期无压缩时的遗留截断——如今 `compressIfNeeded` 已在单聊/群聊两层兜底（阈值按 `contextWindowSize` 动态算），窗口纯属冗余且与压缩「保留记忆」目标冲突。全面移除，回归 opencode 纯压缩模式。

### 📏 工具结果截断 6000→20000 + 面板估算对齐
- `ToolResultTruncator.maxChars` 6000→20000，`HistoryManager.toolOutputMaxChars` 2000→20000——身份牌估算与真实发送内容完全一致，不再偏低。

### 🔧 压缩阈值动态同步修复
- 修复 `HistoryManager.contextWindowSize` 构造时固化 → 用户改设置后阈值/节点不刷的 bug。

### 🐞 其他修复
- 流式首帧空文本红屏（`blocks=[]` 致负长度 RangeError）；上下文占用「对话中不刷新」（缓存只认列表引用替换、不认 `add`）。
- 视频系统播放器 OPEN_ERROR（`file_paths.xml` 包名过期）。

## v1.4.21 — 会话信息面板去除滚动 (2026-07-10)

### 🎨 UI 优化
- 会话信息面板内容固定，移除上下滑动（`SingleChildScrollView`），改为按内容自然高度一次性完整显示，更利落。

### 🐞 修正
- **根治上下文占用数字对话中不刷新**：`estimatedContextTokens` 的缓存只在消息**列表引用变更**时才重算，但消息是 `_messages.add(...)` 追加的、引用始终不变，导致正常对话中数字纹丝不动（只有压缩/切会话才更新）。修法：缓存失效条件改为「引用 + 条数 + 最后一条内容长度」，新增一轮问答与流式增长都会实时重算（单聊 / 群聊同步修复）。
- 占用数字显示由整 K（`12K`）改为一位小数（`12.3K`，≥100K 仍用整数），几百 token 的变化也能直观看到。
- **根治面板「AI 草稿纸」贴底 / 底部留白改了不生效**：真因是 `showModalBottomSheet` 未开 `isScrollControlled`，默认最大高度被限制在屏幕 9/16（约 56%），面板内容超出后底部被**裁剪**，任何底部留白调整都落在被裁区域里、真机上看不出变化。修法：开 `isScrollControlled: true` 让面板按内容自适应高度（`Column` 改 `mainAxisSize: MainAxisSize.min`），并用 `SafeArea(top:false)` 正确避开底部系统手势条。「AI 草稿纸」不再贴底。
- **根治上下文占用阈值 / 节点位置「不随窗口变化」（非动态）**：`HistoryManager.contextWindowSize` 原为 `final`，在 controller 首次懒加载时被**固化**为当时的窗口值；而面板里「阈值比例 = 固化阈值 ÷ 动态窗口（来自 `_aiSettings`）」，切换窗口后 —— 小窗口时比值 >1、节点被 `markX<w` 条件裁掉（看不到），大窗口时节点被挤到左侧（位置不对）；且真实压缩时机也因此错误。修法：`HistoryManager` 的 `contextWindowSize` / `maxOutputTokens` 改为可变字段，单聊与群聊两个 controller 的 `_historyManagerInstance` getter 在返回前把最新 `_aiSettings.contextWindowSize` 同步进去；面板写死的「80%」文案改为动态百分比（`占用约达 X% 时自动压缩`，大窗口 80%、小窗口显示真实 <80% 值）。新增回归测试锁定该行为，防止字段被改回 `final` 或遗忘同步。
- 同步 `AppConfig._version` / `_buildNumber` 硬编码默认值至 `1.4.21` / `17`（原为 `1.0.0` / `1`，与 pubspec 脱节、易误读为版本未更新；运行时已由 `PackageInfo` 覆盖，此处仅作正确 fallback）。
- **修复视频「用系统播放器打开」失败（`OPEN_ERROR: Failed to find configured root`）**：原生 `MainActivity.openFile` 用动态 `${packageName}.fileprovider` 取授权（正确 = `com.dweis.app.fileprovider`），但 `res/xml/file_paths.xml` 里 `flutter_docs` 这条 `root-path` 写死的是**旧包名 `com.example.personal_agent_app`**，导致 `FileProvider.getUriForFile` 在所有配置的 root 里都找不到能覆盖 `/data/data/com.dweis.app/app_flutter/` 的目录，视频（存于 `getApplicationDocumentsDirectory` = `app_flutter`）无法生成 content URI 调起系统播放器。修法：把该 `root-path` 的包名更正为 `com.dweis.app`。
- **修复流式输出时主界面卡顿（点侧边栏 / 进入子页面掉帧）**：根因有二 —— ① 流式期间 `_AIBubble` 每个 token 都**全量解析整条 markdown**（原有 32ms 节流仍每帧重解析长文本），占满主 isolate，Drawer 打开 / 进入子页面时后台解析与界面渲染抢主线程；② 流式自动贴底每帧 `jumpTo` 与 Drawer 打开动画抢主 isolate。修法：① **增量富文本渲染**（见下条升级）；② Drawer 打开时（`onDrawerChanged` 置 `_drawerOpen`）暂停自动贴底滚动，消除每帧 `jumpTo` 抢占。
- **升级流式渲染为「增量富文本」（与 ChatGPT / DeepSeek 同级流畅度）**：上一版为快速止血，流式期间退化为**纯文本**渲染，丢了富文本。现改为：把流式文本按 markdown 块边界（空行分段、` ``` ` 围栏跨空行成整块）切分，**已完成块冻结缓存、仅重解析最后一个仍在生长的块**；配合 `ListenableBuilder` 每帧最多重建一次（Flutter 把同帧多个 token 的 `notifyListeners` 合并），单帧成本从「全量重解析整条 O(N)」降为「仅当前块 O(块大小)」。未闭合代码块先以原始态显示、闭合后就地升级为带复制按钮的高亮块。回归测试改为断言流式期间已渲染 `MarkdownBody` 与代码块（复制按钮），锁定富文本不再退化。
- **修复发消息瞬间红屏闪一下再恢复（流式首帧空文本崩溃）**：AI 占位消息创建时 `text=''` 且 `isStreaming=true`，首帧 `build` 走 `_rebuildStreaming('')` → `_splitBlocks('')` 返回空列表 → `completedCount = blocks.length - 1 = -1` → 执行 `_frozenBlockWidgets.length = -1` 抛 `RangeError`，整屏红屏；第一个 token 到达后 `text` 非空、`completedCount ≥ 0` 又正常渲染，故表现为"闪一次红屏、数据正常"。修法：`_rebuildStreaming` 在 `blocks.isEmpty` 时直接返回空列表，由「思考中」状态行占位。新增回归测试锁定该首帧场景（此前 9 个流式测试均用非空文本、未覆盖此崩点，故本地未暴露）。
- **运行日志可一键导出为 Markdown 文档并分享（直击"只能复制 500 行控制台、看不到红色异常类型"）**：`LogService` 新增 `formatMarkdownReport`（纯函数，把 `dweis.log` 的 `[时间][级别][tag]消息` 解析为结构化条目，将 `[F]` 致命错误**单独高亮成「## 致命错误」章节、自动提取异常类型**，完整日志原文附在「## 完整日志」）与 `exportMarkdownReport`（读全文、生成 `dweis_log_report_YYYYMMDD_HHmmss.md` 到文档目录、返回路径）。「运行日志」页（`设置 → 运行日志`）右上角新增**分享按钮**，调起系统分享面板（微信 / 文件管理器等）发送 `.md`；`ExportService` 新增复用的 `shareFileByPath`（沿用原生 `com.example/share_file` 通道）。`ErrorHandler.buildErrorWidget` 报错页**始终展示异常类型与信息**（不再仅 debug 模式），并加「导出运行日志并分享」按钮——崩溃后一键把 Markdown 报告发开发者，无需再手抄 500 行。新增 `formatMarkdownReport` 单测锁定 Fatal 章节与异常类型提取。
- **根治上下文压缩「历史永久丢失 + 摘要被滑动窗口砍掉」双缺陷**：原 `compressIfNeeded` 结果直接 `_messages = [...compressed]` **原地替换并落盘**，小窗口下早期对话永久消失、且每次压缩对摘要再做摘要（渐进信息丢失）；更严重的是 `buildMessageHistory(..., maxMessages:20)` 从**尾部**保留最近 20 条，而压缩后 `[摘要, ...recent]` 的摘要在**头部**——长对话时摘要被砍掉、压缩彻底失效。修法：**压缩只生成「发送时视图」**——单聊 `sendView` 仅喂 `buildMessageHistory`，不替换 `_messages`、不落盘（`saveSession` 仍存完整历史，用户可随时回溯）；群聊新增 `_historyView` 字段，非隔离 Agent 通过它引用压缩视图（`_runOneAndAppend` 的 `history` 改用 `(_historyView ?? _messages)`），`saveGroup` 仍存完整 `_messages`。压缩后 `maxMessages` 改为 `null`（不再二次截断摘要）。
- **压缩失败补日志 + 群聊复用 AISettings 单例**：单聊 / 群聊压缩 `catch(_)` 改为 `catch(e)` 并 `log.w('Xxx','Compression failed', e)`（此前静默吞异常，开发者无从排查）；群聊压缩处去掉 `final ai = AISettings(); await ai.load()`（每次压缩多一次磁盘读且与全局单例可能不同步），改用构造注入的 `_aiSettings`。
- **压缩判断计入 systemPrompt 开销**：`HistoryManager.shouldCompress` 新增 `systemPromptTokens` 参数（消息 token + systemPrompt token 再比阈值），单聊传 `estimateTokens(systemPrompt)`、群聊传 `_groupSystemPromptEstimate()` 估算（群名/描述/成员角色），避免「消息估算刚过阈值、加上 systemPrompt 后实际超窗」的漏判（阈值已有 4000 安全边际，但 systemPrompt 超 4000 仍会漏）。
- **token 估算 Unicode 精度修正**：`estimateTokens` 由 `text.codeUnits` 改 `text.runes` 遍历码点（避免 emoji 等补充平面字符被拆成两个 UTF-16 代理对多算）；CJK 范围覆盖扩展 A（U+3400-4DBF）与主要平面（U+4E00-9FFF，临界值由 `> 0x4E00` 修正为 `>= 0x4E00` 含「一」），补充平面 CJK（U+20000-2FA1F）；其余非 ASCII 文字（阿拉伯 / 西里尔 / 泰文 / emoji 等）按英文比率估算，不再被误算作中文。
- **token 缓存防累积**：`HistoryManager._tokenCache` 原以消息序列化全文为 key 且永不清理，常驻 controller 生命周期会随长对话增长；改为 `compressIfNeeded` 进入时 `_tokenCache.clear()`。
- **身份牌面板「流式结束后漏算整条 AI 回复」根治（用户深度审查发现）**：`estimatedContextTokens` 的缓存三条件（引用/条数/最后一条长度）在「流式收尾 `isStreaming` 翻 false 但文本长度恰好未变」时**不会失效**——缓存仍是流式期间算的（当时 AI 回复被 `if (m.isStreaming) continue` 跳过），导致面板数字比真实少整条 AI 回复，直到下次发消息才自我修正。修法：缓存新增**第 4 个失效条件「最后一条消息的流式状态翻转」**，单聊/群聊对称修复；该条件覆盖所有收尾终点（正常完成/错误/终止），无需逐个 `isStreaming=false` 调用点打补丁。新增回归测试锁定「仅翻转 isStreaming（长度不变）即触发重算并纳入 AI 回复」。
- **身份牌面板纳入 systemPrompt 占用**：`estimatedContextTokens` 原只算消息 token，漏算 SOUL/USER/rules/skill catalog（约 2k~4k），面板显示偏乐观；现复用 `sendMessage` 已构建的 systemPrompt 估算（`_systemPromptTokens`），单聊传 `estimateTokens(systemPrompt)`、群聊传 `_groupSystemPromptEstimate()`，返回值 = 消息估算 + systemPrompt 估算。
- **修正过期单测**：`error_handler_test` 断言的错误页正文文案仍是旧版，fcc6d58 改为「请重启应用或返回上一页重试。完整错误已记录，可一键导出日志。」后未同步测试 → 改为 `find.textContaining('请重启应用或返回上一页重试')` 鲁棒匹配；该失败此前被误归因为 task_plan flake。

### 🚀 性能优化（全面流畅度升级，对齐 ChatGPT / DeepSeek 等主流 APP）
- **回到底部 FAB 去实时模糊**：原 `BackdropFilter(blur)` 每帧 GPU 采样，长列表滚动时与主线程争抢 → 改为**实心底 + `boxShadow`**（对齐微信 / Telegram 做法，去掉实时模糊）。主聊天屏 + 群聊屏统一修改。
- **长列表 / 网格 / 气泡重绘隔离**：主聊天屏消息项、群聊屏消息气泡、消息列表页列表项、媒体页网格项、笔记详情 `Column` 全面外包 `RepaintBoundary`，滚动时只重绘进出视口的条目，不再连带头像 / 背景整屏重绘。
- **笔记详情 markdown 解析缓存**：`_NoteDetail` 由 `StatelessWidget` 改为 `StatefulWidget`，解析结果缓存到 `late final` 字段仅在 `initState` 计算一次、`build` 直接复用，根治"笔记点开长文重复全量解析"卡顿。
- 路由转场（`IosSlideRoute` 纯横滑无整页 fade）、主聊天列表虚拟化（`ListView.builder`）、群聊入口双帧校正动画、markdown 样式表主题色哈希缓存等**经排查已处于较优状态**，本轮未改动、非卡顿源。

### 🔌 Prompt Cache 命中优化（省 token）
- **根治 prompt cache 命中率≈0**：此前两协议层（`AnthropicProtocol` / `OpenAiProtocol`）请求体均未加 `cache_control`，且 system 末尾每轮注入「当前时间（精确到秒）」使 system 前缀逐 token 变化，缓存永远失效，每轮全量重发 SOUL/USER/rules/skill catalog（约 2k~4k+ token）；群聊 N 个 Agent 各发一份、浪费放大 N 倍。
- **稳定化（前提）**：`PromptBuilder.buildMainPrompt` 与 `agent_runner._buildSystemPrompt` 移除 system 内的「当前时间」块；时间改由调用方注入到历史**末尾**的 user 消息（`chat_helpers.buildMessageHistory` / `agent_runner._buildHistory` 增 `now` 参数，return 前追加 `当前时间：…`）。system 主体恒定 → 前缀可缓存。
- **双协议加缓存断点**：Anthropic 把 `system` 改为带 `cache_control:{type:'ephemeral'}` 的 block 数组（流式 + 摘要两处）；OpenAI 把 system message 的 `content` 转为同结构 block 数组（端点不支持显式标记时无害，且稳定前缀仍触发 OpenAI 自动前缀缓存）。命中后 system 块只计 cache_read 价（约 1/10）。
- **运行日志打 cache 统计**：Anthropic 解析 SSE `message_start` 的 `usage`（cache_read/creation token）、OpenAI 流式加 `stream_options.include_usage` 并解析 `prompt_tokens_details.cached_tokens`，均打到运行日志，方便不依赖厂商后台验证命中。
- 新增回归测试锁定：system 不含「当前时间」、`buildMessageHistory` 在 `now` 非空时末尾追加时间消息。

### 🪟 移除滑动窗口截断（回归纯压缩，对齐 opencode）
- **背景**：滑动窗口（`maxMessages:20` / 子 Agent `maxMsgs:50`）是当年「还没有上下文压缩」时临时管长度的遗留手段；如今 `compressIfNeeded` 已在单聊（`chat_controller`）与群聊（`group_chat_controller`）两层兜底（阈值按 `contextWindowSize` 动态算），窗口纯属冗余，且会让中段对话每轮只发最近 N 条、AI 对更早内容失忆。
- **改动**：主聊 `buildMessageHistory` 移除 `maxMessages` 参数与截断逻辑（`chat_helpers.dart`），`chat_controller` 不再传窗口；子 Agent / 群聊成员 `agent_runner._buildHistory` 移除 `maxMsgs:50` 截断，统一由 group 层 `compressIfNeeded` 先压缩、子 Agent 拿压缩视图兜底。
- **现状行为**：短/中对话每轮发完整历史（token 成本随对话递增，直到接近窗口上限才压缩）；长对话压缩触发、头部变 `[历史摘要]`，AI 不忘早年内容。system 缓存（Prompt Cache 优化）不受影响——system 是恒定前缀，独立于对话体。

## v1.4.20 — 上下文占用收进身份牌面板 (2026-07-10)

### 🎨 UI 优化
- 输入框上方的常驻「上下文占用细条」反馈突兀，已移除；改为**点击右上角身份牌（badge）弹出底部面板**按需查看。
- 面板（`SessionInfoButton` / `SessionInfoSheet`）含：上下文窗口占用卡片（细条 + 「约 12K / 256K」数字 + 绿/琥珀/红状态说明 + 估算提示）+ 原有文档入口（SOUL / USER / AGENT / AI 草稿纸）。
- 单聊屏与群聊屏统一同款；群聊屏 `AppTopBar` 新增同款身份牌入口。
- 删除原 `ChatIdentityButton`（PopupMenu 文档菜单），功能迁入面板，不污染代码。
- 说明：面板支持实时刷新（对话进行中打开也跟手）。

---

## v1.4.19 — 上下文窗口占用可视化 + 压缩阈值改 80% (2026-07-10)

### ✨ 新功能：上下文窗口占用可视化
- 输入框上方新增极简细条，实时显示当前对话的**估算 token 占用 / 窗口大小**（如 `42K / 256K`）。
- 三色状态：绿（宽松）→ 琥珀（接近阈值）→ 红（到/过压缩线），条上标出**真实压缩阈值**位置。
- 单聊屏与群聊屏统一同款，监听 controller 用量变更刷新；数据现成（`HistoryManager.estimateMessagesTokens` + 窗口大小），零新依赖。
- 说明：token 数为字符启发式估算（非真实分词），细条为「大致占用」指示。

### 🔧 压缩阈值逻辑修正
- 原阈值 `contextWindowSize - 20000`（固定缓冲）**不是 80%**：256K 窗实际 ~92% 才压，而 32K 小窗仅用 37% 就压、浪费大半上下文；设置页「达到 80% 时自动压缩」文案与实现不符。
- 改为 **80% 百分比 + 绝对下限（取两者较小值）**：`min(contextWindowSize*0.8, contextWindowSize-(maxOutputTokens+余量))` —— 大窗用满 80%，小窗自动后退为输出预留空间、避免下一轮生成溢出窗口。
- 同步修正设置页文案为「占用约达 80% 时自动压缩（小窗口会预留输出空间，更早压缩）」。

---

## v1.4.18 — 模型选择器默认「自动选择」(2026-07-10)

### 🐛 Bug 修复
- **首次打开模型选择器默认选中「手动输入」**：根因 `_fetch()` 拉完模型列表后，若当前默认模型不在列表里会被强制掰到「手动输入」，导致体感"默认手动"。
- **修复**：默认保持「自动选择」；仅在自动列表里当前模型不在列表中时，顶部显示轻提示「当前模型「X」不在列表中，改用手动输入」，点击才切换——既默认自动、又不丢自定义模型的可发现性。

## v1.4.17 — 删除无用的 terminate_subagent 工具 (2026-07-10)

### 🧹 代码清理
- **删除摆设工具**：`terminate_subagent` 在阻塞式 `delegate_task` 下，协调者当轮被卡住根本调不到它，实为摆设；用户「停止」按钮的 abort 信号已能实时中断所有在跑子 Agent，功能完全覆盖。
- 删除 `terminate_subagent_tool.dart`，清理控制器 `import` / `_terminateChild` / `_coordinatorDispatchTools` 引用及三处注释残留，净删 74 行，不污染代码表面积。

## v1.4.16 — 根治「回到底部」按钮可见跳变 (2026-07-10)

### 🐛 Bug 修复
- **回到底部按钮点下去"跳一下"**：旧 `_scrollToBottom` 先 `animateTo(固定估算 max)` 再 `jumpTo` 兜底。长列表/未布局底部 item 时，动画期间真实 max 才被推出、比动画目标更大，结束落点在错误（偏高）底部 → 末尾 snap 到真底部 = 可见 teleport。
- **修复（主聊天屏 + 群聊屏统一同款）**：改**跟随式动画**——动画期间每一帧 `jumpTo(当前 maxScrollExtent)`，底部 item 随布局完成把 max 自然推高，滚动平滑跟随到底，无二次跳动。两处皆加 `SingleTickerProviderStateMixin` + `AnimationController`。

## v1.4.15 — 群聊工具上限语义 + 子 Agent 可控可观测 (2026-07-10)

### 🐛 Bug 修复：工具调用上限语义
- **现象**：群聊里经常碰到"工具调用达到上限"，但分不清是每 Agent 10 还是全群 10。
- **根因**：`ToolRegistry.maxConsecutiveCalls=10` 本是"同一工具连续调用"上限；但 scoped registry 按权限缓存（权限相同的子 Agent 共用同一实例计数），且群聊从不 `resetCallCounts()`（单聊才会）→ 配额**跨 Agent、跨轮次累积**触顶。
- **修复**：每个 Agent 每次执行前 `resetCallCounts()`，语义变为「**每个 Agent 每轮独立配额**」。

### ✨ 增强：子 Agent 可控可观测
- **状态可见**：`AgentStatus` 扩展 `error` / `timeout` / `cancelled`，状态栏分别红色/灰色渲染 —— 看得见哪个子 Agent 挂了。
- **短超时**：子 Agent 执行超时由 **5 分钟** 砍到 **90 秒**，不再体感永久卡死。
- **停止真生效**：此前 `stop()` 只 cancel 流、不解锁 completer，协调者永远死等；现 abort 信号会一并中断所有在跑子 Agent。
- （注：`terminate_subagent` 工具于 v1.4.17 删除，因阻塞式派活下协调者当轮调不到它。）

---

## v1.4.5 — 愉悦体验打磨（克制精致基调）(2026-07-09)

### ✨ 体验升级（四包全落地，基调：Apple HIG 风、微动画、留白、克制不喧哗）

**A · 开场惊艳**
- 主聊天空态：品牌 Logo 脉冲呼吸 + 欢迎语「嗨，我是 DWeis ✨」+ 可点击示例问题 chips（点击即填充并发送）。
- 用户 / AI 气泡进场弹簧淡入 + 微上滑；AI 思考首 token 前三点跳动 typing 指示（替代纯扫光）。
- 滚动到底按钮 `AnimatedOpacity` 淡入；发送 / 附件按钮按压缩放 + 颜色过渡。

**B · 加载与反馈**
- 点亮死代码骨架屏：通讯录 / 消息列表首帧由 `StatePlaceholder.loading()` 升级为 `AgentListSkeleton` / `MessageListSkeleton`。
- 统一 `AppToast` 替代散落的 `showSnackBar`（圆角、轻阴影、2s 自动消失、root Overlay 渲染）；覆盖笔记 / 媒体 / 内联 / 编辑页等 10+ 处。

**C · 容错优雅**
- 聊天报错从「把原始异常塞进气泡」升级为内联报错卡（浅红底 + 红图标 + 友好文案 + 重试按钮），保留在对话流不污染正常消息。
- `ErrorHandler.humanizeError` 把网络 / 超时 / 配额 / 密钥异常映射为友好中文文案；`ChatMessage.isError` 标记 + `ChatController.resendLast` 重试。

**D · 完成时刻**
- 任务计划完成：标题对勾 `_PopCheck` 弹簧缩放微动效 + 轻触觉；`AppToast.success` 统一触发一次轻量 `HapticFeedback`。
- 气泡长按菜单（复制 / 重新生成 / 删除）：`ChatController.deleteMessage` / `regenerate` 支撑删除与重生成。

### ✅ 测试
- 新增 `test/widgets/app_toast_test.dart`、`test/widgets/chat_bubble_test.dart`、`test/controllers/chat_controller_delight_test.dart`（共 9 用例，全过）。
- **修复**：`AppToast` 消失逻辑此前只 null 静态引用而未真正 `entry.remove()`，导致 toast 永远残留在 Overlay；现已修正并在测试中验证自动消失。

### 🔧 复核微调（用户验收后）
- 撤回 A1 主聊天空态、A3 AI 思考三点跳动（改回原 `ShimmerText`「思考中」）；气泡长按菜单改在按下位置 `showMenu` 弹出（原底部 sheet 不符直觉）；`AppToast` 改为贴合主题（`nc.surface` 卡片 + 细边 + 轻阴影）。
- 修复「回到底部」按钮偶尔回过头：滚动状态机增加 `_autoScrolling` 守卫，区分程序自身滚动与用户上滑。
- 聊天主路径放大一圈（正文 / 输入栏 / 气泡 / 列表留白），顶部图标同步放大；基调仍「克制极简」，不加新视觉元素。
- 输入框与全局系统灰去紫：原 iOS 系统灰 `#F2F2F7` 蓝通道偏高显冷紫；输入框容器改纯白 `surface`，并把 `surfaceSecondary` / `bgSubtle` / `primarySurface` / `cardBackground` 统一中性化为 `#F4F4F4`（深色模式同步），全项目二级背景一次治本。

### 🧹 终检清理（发布前收口，定为最终版本）
- 删除 4 个零引用死亡文件：`quick_action_chips.dart`、`json_file_data_source.dart`、`clipboard_tool.dart`(+.g)、`file_tool.dart`(+.g)，以及根目录陈旧产物 `analyze_p1.log`（全项目无任何引用，编译/运行无影响；对应 3 个测试引用一并改为用 `WeatherTool` 等存活工具）。
- 修复主聊 `ChatController.sendMessage` 潜伏竞争：`_isLoading` 原在第 308 行（首个 `await` 之后）才置位，窗口期内重复触发会开第二条流覆盖 `_aiStream`；现提到所有提前返回之后、首个 `await` 之前同步置位（群聊 `GroupChatController.send` 同构：`_busy` 提前置位并在提前返回路径复位）。
- 三处 `unawaited` future 补 `onError`：`chat_screen` 切换会话、`app.dart` 主题加载、`app_toast` 消失回调，避免异常被 zone 静默吞掉。
- `dart analyze` 仅余 1 条既有 `pubspec.yaml` 的 `path` dev 依赖冗余警告（非本次引入，不影响运行）；全套 338 测试通过。

## v1.4.4 — 群聊重新打开自动贴底（修复停在首条消息）(2026-07-09)

### 🐛 Bug 修复：群聊重新打开不显示最新消息
- **现象**：agent 群聊聊完后，每次重新打开界面都停在**最开始那条消息**，需手动往下滚才能看到最新回复。
- **根因**：`group_chat_screen.dart` 仅在 `initState` 的 `addPostFrameCallback` 里 `await _controller.load()`，加载完成后 `ListView` 的 `ScrollController` 默认停在顶部（offset 0），消息列表按时间正序排列 → 停在 index 0（首条）。发送消息时靠 `_scrollDown` 贴底，但**重新进入界面没有做贴底**。存档本身无问题（`AgentGroup.messages` 正确序列化、`saveGroup` 每条回复后全量落盘）。
- **修复**：
  - 加载完成并触发重建后新增 `_scrollToBottom()`：`jumpTo(maxScrollExtent)` 立即贴底。
  - **两阶段校正**：首跳让底部未测量项完成布局（`ListView.builder` 动态 item 高度下首跳时 `maxScrollExtent` 偏小，只跳一次会差约 50px 没完全贴底），下一帧再跳一次到真实最大处。
- **回归测试**：`test/widgets/group_chat_screen_test.dart` 新增 `reopen scrolls to the latest message (bottom)`，用 40 条消息大群（超过分页窗口 30）覆盖 Fake 存储，`pumpAndSettle` 后断言最新消息可见 + 滚动位置接近最大处，20 个用例全过。

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
