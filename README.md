# DWeis — 你的个人 AI 助手

[![Flutter](https://img.shields.io/badge/Flutter-3.27-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.9-blue.svg)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-green.svg)](https://www.android.com)
[![Version](https://img.shields.io/badge/Version-1.9.0-blue.svg)](https://github.com/3d-jq/personal-agent-app)

> 基于 Flutter 构建的 Android AI 助手 —— 多厂商大模型、40+ 内置工具、浏览器自动化、Agent 群聊、技能系统、记忆与上下文管理。

---

## 核心能力

### 🤖 多厂商 AI 对话
- 支持 **OpenAI / Anthropic / DeepSeek / Agnes** 及任意兼容接口的服务商
- 流式输出 + Function Calling 工具调用
- 多会话管理，对话记录本地 SQLite 持久化
- 上下文自动压缩（80% 窗口阈值，支持 256K token）
- 各厂商独立定价，Token 用量实时追踪（含缓存命中率）

### 🧰 40+ 内置工具
| 类别 | 工具 |
|------|------|
| 浏览器 | 导航、点击、输入、截图、快照、搜索、表单填充、Cookie、User-Agent |

| 搜索与知识 | 网页搜索（SearXNG/Tavily）、网页抓取、深度搜索 |
| 媒体 | 图片生成、视频生成（Agnes AI） |
| 文件系统 | 读写、目录遍历、创建/删除 |
| 笔记 | 创建、编辑、阅读、删除、搜索 |
| 计划 | 创建、更新、推进、验证、清空 |
| 技能 | 注册、匹配、读取、创建 |
| 提醒 | 定时提醒创建与管理 |
| 日历 | 添加、查询、删除日程 |
| 上下文文档 | SOUL.md（人格）、USER.md（偏好）、MEMORY.md（记忆）读写 |
| Agent 调度 | 委托任务给其他 Agent |
| 其他 | 天气、定位、剪贴板 |

### 🌐 内置浏览器
- WebView 驱动的内置浏览器，支持悬浮窗与工具双重模式
- 页面快照、可读文本提取、元素定位、表单自动填写
- 截图直接嵌入对话气泡，大模型可"看到"页面内容
- 支持自定义 User-Agent、Viewport、Cookie 管理

### 🧑‍🤝‍🧑 Agent 群聊
- 多 Agent 协作，混合调度（自动 + 接力）
- 每个 Agent 独立 personality、工具白名单、AI 后端
- 实时状态显示（思考中 / 已回复 / 待命）
- 讨论轮次追踪、身份隔离

### 🧠 技能系统（Skills）
- 渐进式技能目录：第 1 层摘要 + 按需读取详细手册
- 技能匹配：自然语言 → 最相关技能推荐
- 支持创建自定义技能（Cookbook 详细流程）

### 📝 上下文文档系统
- **SOUL.md**：AI 人格设定（名称、语气、风格、背景）
- **USER.md**：用户资料（称呼、偏好、习惯）
- **MEMORY.md**：跨会话长期记忆
- 首次见面引导：自然对话中收集偏好
- 写前必须 read 的硬约束，防止覆盖

### ⚡ 性能与缓存
- Prompt Caching：固定内容放 system prompt 前缀，变动内容放 messages 尾部
- Token 缓存命中率实时追踪
- 消息窗口分页（20 条/页），滚动性能优化
- 会话切换秒开（Controller 缓存 + 骨架屏过渡）

### 🎨 设计规范
- 遵循 Apple HIG（SF Pro 字体栈、圆角系统、间距梯度）
- 亮色 / 暗色主题
- iOS 风格滑动转场
- 无边框卡片 + 胶囊形 UI

---

## 架构

```
lib/
├── main.dart                     # 入口（dotenv、数据库、通知）
├── app.dart                      # 应用根（主题、路由、设计令牌）
├── core/
│   ├── design_tokens.dart        # 设计系统（颜色/字体/间距/圆角）
│   ├── service_locator.dart      # DI（get_it 单例）
│   └── prompt_builder.dart       # System Prompt 构建（XML 结构化）
├── controllers/
│   ├── chat_controller.dart      # 主聊天控制器（936 行，持续拆分中）
│   ├── message_window.dart       # 消息分页窗口
│   └── attachment_handler.dart   # 附件编码处理
├── models/                       # 数据模型（ChatMessage、VendorConfig、ToolCall）
├── services/
│   ├── ai_service.dart           # AI 通信主控（OpenAI/Anthropic 协议）
│   ├── ai_service_openai.dart    # OpenAI 协议实现
│   ├── ai_service_anthropic.dart # Anthropic 协议实现
│   ├── history_manager.dart      # 对话历史压缩管理
│   ├── token_usage_tracker.dart  # Token 用量追踪与计费
│   ├── chat_controller_cache.dart # Controller 实例缓存
│   └── context_doc_service.dart  # 上下文文档服务（SOUL/USER/MEMORY）
├── tools/
│   ├── browser/                  # 浏览器工具（6 文件，25 工具类）
│   │   ├── browser_base.dart     # BrowserBaseTool + 公共函数
│   │   ├── browser_plugin.dart   # 浏览器工具插件注册
│   │   ├── browser_nav_tools.dart    # 导航类（goto/back/close/scroll/wait）
│   │   ├── browser_interact_tools.dart # 交互类（click/type/select/hover/fillform/evaluate/screenshot）
│   │   ├── browser_data_tools.dart    # 数据类（snapshot/getText/search/cookies/config）
│   │   └── browser_core.dart     # 桶文件（re-export）
│   ├── skill_registry.dart       # 技能注册表
│   ├── plugin_registry.dart      # 插件注册编排
│   ├── tool_registry.dart        # 工具注册与执行
│   └── tool_execution_limits.dart # 工具执行限制与可观测
├── platform/
│   └── browser_channel.dart      # 浏览器原生通道
├── widgets/
│   ├── agent_group/              # Agent 群模块
│   │   ├── group_chat_screen.dart    # 群聊主界面
│   │   ├── group_chat_controller.dart # 群聊控制器
│   │   └── group_list_page.dart      # 群列表
│   ├── browser_overlay.dart      # 浏览器浮层
│   ├── token_usage_page.dart     # Token 用量统计页
│   ├── ai_settings.dart          # AI 供应商设置
│   └── chat_skeleton.dart        # 骨架屏组件
└── screens/
    ├── chat_screen.dart          # 主聊天界面
    ├── chat_helpers.dart         # 聊天辅助函数
    └── agent_chat_screen.dart    # Agent 单聊界面
```

---

## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter 3.27+ / Dart 3.9+ |
| 状态管理 | get_it（DI）+ ChangeNotifier（响应式） |
| 本地存储 | drift (SQLite) |
| HTTP | Dio（自建重试 + SSL 安全中间件） |
| Markdown | flutter_markdown（流式增量渲染） |
| 浏览器 | Android WebView（虚拟显示合成） |
| 通知 | flutter_local_notifications |
| 测试 | flutter_test（564 个测试用例） |

---

## 快速开始

### 环境要求
- Flutter SDK >= 3.27
- Android SDK >= 26
- JDK 21

```bash
# 安装依赖
flutter pub get

# 运行
flutter run

# 测试
flutter test

# 分析
flutter analyze
```

### 配置
1. 在应用内「设置 → AI 后端」配置 API Key 和 Base URL
2. 首次启动可选配置 .env（开发环境）或直接在设置界面填入密钥
3. 支持任意兼容 OpenAI/Anthropic API 格式的服务商

---

## 更新日志

### v1.9.0
- 🏗 浏览器工具拆分（1261 行单文件 → 6 文件）
- 🐛 修复对话加载跳动（骨架屏日志）
- 🔧 summarize 失败不回退空串（防 token 溢出）
- 🔧 HTTP 错误不再伪装正常回复
- 🔧 附件 handler 提取为独立服务
- 🔧 移除 registerMcpTools 重复函数
- 🔧 token 缓存 key 优化（hash 替代完整文本）
- 🔧 DB 加载加缓存（sendView 无重复查询）
- 🎨 对话加载跳动修复（骨架屏正确触发）

### v1.8.5
- ✨ Token 缓存命中率独立显示
- ✨ 时间注入改为 system role（不污染用户消息）
- 🔒 XOR 加密加固警告
- 🐛 翻页按钮根因修复（bindSession）
- 🐛 首次见面状态机
- 🐛 文档读前硬约束

### v1.8.0
- ✨ 浏览器友好错误提示
- ✨ 浏览器 UI 统一（搜索按钮、截图稳定化）
- 🎨 AppBar/AppTopBar 去阴影横线
- 🎨 笔记编辑器无边框
- 🎨 背景色统一为中性灰 #F2F2F2

### v1.7.8
- 🎨 全项目圆角统一（110 处硬编码 → RadiusToken）

### v1.6.1–1.7.0
- ✨ 浏览器截图工具 + 媒体进对话
- ✨ 插件化架构 + 工具可观测四件套
- ✨ 深度搜索（Deep Search）
- ✨ Prompt Caching 缓存优化

---

## 隐私说明
- 所有数据（对话、笔记、设置）存储在本地 SQLite
- API Key 经 XOR 加密后存储，仅用于调用 AI 服务
- 无第三方数据收集或上传
- 支持完全离线使用（浏览器、文件管理等本地工具）

---

## License
MIT
