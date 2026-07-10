# Changelog

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

### 🚀 性能优化（全面流畅度升级，对齐 ChatGPT / DeepSeek 等主流 APP）
- **回到底部 FAB 去实时模糊**：原 `BackdropFilter(blur)` 每帧 GPU 采样，长列表滚动时与主线程争抢 → 改为**实心底 + `boxShadow`**（对齐微信 / Telegram 做法，去掉实时模糊）。主聊天屏 + 群聊屏统一修改。
- **长列表 / 网格 / 气泡重绘隔离**：主聊天屏消息项、群聊屏消息气泡、消息列表页列表项、媒体页网格项、笔记详情 `Column` 全面外包 `RepaintBoundary`，滚动时只重绘进出视口的条目，不再连带头像 / 背景整屏重绘。
- **笔记详情 markdown 解析缓存**：`_NoteDetail` 由 `StatelessWidget` 改为 `StatefulWidget`，解析结果缓存到 `late final` 字段仅在 `initState` 计算一次、`build` 直接复用，根治"笔记点开长文重复全量解析"卡顿。
- 路由转场（`IosSlideRoute` 纯横滑无整页 fade）、主聊天列表虚拟化（`ListView.builder`）、群聊入口双帧校正动画、markdown 样式表主题色哈希缓存等**经排查已处于较优状态**，本轮未改动、非卡顿源。

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
