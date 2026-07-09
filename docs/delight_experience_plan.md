# 愉悦体验设计方案 · v1（克制精致基调）

> 角色：惊喜喜（Delightful Experience Designer）
> 基调：**克制精致（Apple HIG 风）** —— 微动画、留白、细节打磨，愉悦但不喧宾夺主。
> 范围：personal_agent_app（Flutter Android AI 助手）

## 设计原则

1. **接上现有资产优先**：骨架屏 `skeleton.dart`、底部上滑路由 `SlideUpRoute`、设计 token 都已写好却没接上，先复用再新增。
2. **统一动效语言**：弹簧曲线 `ExpressiveSpring` + `AppDurations`，时长 150–300ms；不滥用长动画。
3. **克制不喧哗**：不加花哨彩蛋/背景音效；"完成时刻"仅用轻量触觉 + 微缩放。
4. **错误体验升级**：从"把原始异常塞进气泡"升级为优雅内联报错卡 + 重试。
5. **尊重既有审美**：延续极简、无边框、无装饰性彩色的约定（参考 `TaskPlanView` 视觉）。

## 四个体验包

### 包 A · 开场惊艳
- **A1 主聊天空态**：`chat_screen.dart` 的 `_MessageList` 消息为空时（当前纯背景），改为品牌 Logo 脉冲 + 欢迎语「嗨，我是 DWeis ✨」+ 2–3 个**可点击示例问题 chips**（点击即填充输入框并发送）。
- **A2 气泡进出场动画**：`chat_bubble.dart` 用户/AI 气泡加 300ms 弹簧淡入 + 微上滑（`ExpressiveSpring` + `AppDurations.bubble`）。
- **A3 AI 思考三点跳动**：`chat_bubble.dart` 的 `_buildProcessLine` 在首 token 前显示三点跳动的 typing 指示（品牌色），替代/补充纯文字扫光。

### 包 B · 加载与反馈
- **B1 点亮骨架屏**：把 `skeleton.dart` 的 `MessageListSkeleton`/`ChatBubbleSkeleton`/`AgentListSkeleton` 接进笔记列表、消息列表、群聊/单聊首帧、Agent 通讯录，替换静态转圈。
- **B2 滚动到底按钮淡入**：`chat_screen.dart` 的滚动到底 FAB 用 `AnimatedOpacity`/`AnimatedScale` 替代硬显隐。
- **B3 发送按钮按压缩放**：`chat_input_bar.dart` 发送/停止按钮包 `PressableScale` + 颜色过渡（`AnimatedSwitcher`）。
- **B4 统一 AppToast**：封装 `AppToast` 替代散落的 `showSnackBar`（圆角、轻阴影、2s 自动消失），统一复制/保存/错误反馈。

### 包 C · 容错优雅
- **C1 内联报错卡**：聊天错误从「塞正文气泡」改为内联 `ChatErrorMessageBubble`（错误图标 + 友好文案 + 「重试」内联按钮），保留在对话流但不污染正常消息。
- **C2 humanizeError**：`error_handler.dart` 抽 `humanizeError(e)`，把网络/超时/配额/密钥异常映射为友好文案，不再把原始 `$e` 抛给用户。
- **C3 统一错误视觉**：`StatePlaceholder.error` 风格贯穿聊天内外。

### 包 D · 完成时刻
- **D1 完成庆祝微动效**：任务计划完成（`TaskPlanView`）、笔记保存成功、图片/生成完成，加一次对勾描边绘制 + 微缩放 + 轻量 `HapticFeedback`。
- **D2 气泡长按复制菜单**：`chat_bubble.dart` 用户/AI 文本气泡加长按 → 复制 / 重新生成 / 删除菜单（复用代码块已有的复制 + 震动模式）。

## 实现批次（控制编译成本）

- **批 1（聊天主路径质感）**：A1 + A2 + A3 + B2 + B3 —— 集中在 `chat_screen.dart` / `chat_bubble.dart` / `chat_input_bar.dart`，编译一次验证。✅ 已完成
- **批 2（加载与反馈）**：B1 + B4。✅ 已完成（B1 接进通讯录 / 消息列表首帧；B4 统一 AppToast 替代 10+ 处 showSnackBar）
- **批 3（容错优雅）**：C1 + C2 + C3。✅ 已完成（humanizeError + 内联报错卡 + 重试）
- **批 4（完成时刻）**：D1 + D2。✅ 已完成（_PopCheck + AppToast.success 触觉 + 气泡长按菜单 + deleteMessage/regenerate）

## 进度与范围说明（v1.4.5 落地）

- **B1 范围收敛**：骨架屏接进了存在「真实异步加载缺口」的两处（通讯录 `agent_contact_page`、消息列表 `message_list_page`，原 `StatePlaceholder.loading()` 升级为 `AgentListSkeleton`/`MessageListSkeleton`）。笔记列表 / 群聊 / 单聊首帧经评估为同步或瞬时加载，无真实 gap，强行加骨架屏会造成「闪一下」反效果，故**未接入**（符合「克制不喧哗」原则）。
- **D2 接线范围**：长按菜单已在 `chat_bubble.dart` 通用实现（复制始终可用；重新生成 / 删除由回调注入）。主聊 `chat_screen` 已注入 `deleteMessage` / `regenerate`；`agent_chat_screen` 的 `ChatBubble` 暂未注入（仅长按复制），避免触碰单聊不同的消息流模型。
- **顺带修复**：`AppToast` 消失逻辑原只 null 静态引用而未真正 `entry.remove()`，toast 会永远残留在 Overlay，已在测试中暴露并修正。

## 验证计划

每批结束跑 `flutter analyze` + 相关 widget 测试；全部完成后跑全套测试回归，确认 0 失败。
预期提交版本：**v1.4.5**（体验打磨版）。✅ 已提交（analyze 全绿；新增 9 个 delight 回归用例全过；既有 chat 相关测试全过；`group_message_bubble` golden 的 0.21% 像素差为本环境既有漂移，与本次改动无关——`ChatBubble` 仅外包透明 `GestureDetector`，无像素影响）。
