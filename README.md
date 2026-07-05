# DWeis - AI 助手

[![Flutter](https://img.shields.io/badge/Flutter-3.11+-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11+-blue.svg)](https://dart.dev)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

一个功能丰富的 Android AI 助理应用，支持多 Agent 团队协作、多后端 AI 对话、13 种工具调用、记忆系统等，基于 Flutter 构建（仅 Android 平台）。

---

## 功能特性

### Agent 群（多 Agent 协作）
- **混合协作模式** — 自动调度 + Agent 接力，无需手动 @ 也能触发回复
- **Agent 状态显示** — 实时显示思考中/已回复/待命状态
- **讨论进度** — 显示当前轮次和参与人数
- **身份隔离** — 每个 Agent 有独立的对话历史视图，避免身份混淆
- **自定义 Agent** — 自由创建 Agent，独立配置 system prompt、工具白名单、AI 后端
- **Agent 信息工牌** — 点击卡片查看 Agent 详细信息

### AI 对话
- 支持 **OpenAI / Anthropic / DeepSeek / Agnes** 等多种 AI 后端
- 流式输出 + 工具调用（Function Calling）
- 多会话管理，聊天记录本地持久化

### 工具调用
AI 可调用 13 个内置工具：
- 天气查询、网页搜索、网页内容抓取
- 图片生成、视频生成（Agnes AI）
- 笔记管理、记忆系统、定时提醒
- 日历集成、文件管理、剪贴板操作

### 记忆系统
- AI 记住用户偏好和重要事实
- 个性化回复风格（默认/简洁/详细/幽默/专业）
- 自定义指令

### 设计风格
- **Apple HIG 设计规范** — 遵循 Apple 人机界面指南
- 亮色/暗色主题
- SF Pro 字体栈
- 无边框输入框 + 胶囊形设计

---

## 快速开始

### 环境要求

- Flutter SDK >= 3.11.5
- Dart SDK >= 3.11.5

### 安装

```bash
# 克隆项目
git clone https://github.com/3d-jq/personal-agent-app.git
cd personal-agent-app

# 安装依赖
flutter pub get

# 运行
flutter run
```

### 配置 AI 后端

首次启动时在设置中配置 AI 后端。支持：

| 厂商 | Base URL | 说明 |
|------|----------|------|
| DeepSeek | `https://api.deepseek.com/v1` | 国内推荐，性价比高 |
| OpenAI | `https://api.openai.com/v1` | GPT-4o 等模型 |
| Anthropic | `https://api.anthropic.com` | Claude 系列 |
| Agnes | `https://apihub.agnes-ai.com/v1` | 图片/视频生成 |

也支持其他兼容 OpenAI API 格式的服务商。

---

## 架构

```
lib/
├── main.dart                      # 入口
├── app.dart                       # 应用根（Apple HIG 主题）
├── core/
│   └── agent_colors.dart          # 设计系统（Apple HIG 色板）
├── models/                        # 数据模型
├── services/                      # 服务层
│   ├── ai_service.dart            # AI 通信
│   ├── agent_runner.dart          # Agent 执行器
│   └── agent_storage.dart         # Agent 持久化
├── tools/                         # 13 个 Agent 工具
├── widgets/
│   └── agent_group/               # Agent 群模块
│       ├── group_chat_screen.dart     # 群聊主界面
│       ├── group_chat_coordinator.dart # 协作引擎
│       ├── group_status_bar.dart      # 状态栏组件
│       ├── group_list_page.dart       # 群列表
│       └── agent_manage_page.dart     # Agent 库
└── screens/
    └── chat_screen.dart           # 主聊天页
```

### 设计理念

- **混合协作** — 自动调度 + Agent 接力，平衡自动化和用户控制
- **身份隔离** — 每个 Agent 只看到自己和用户的消息，其他 Agent 消息作为上下文
- **本地优先** — 所有数据 JSON 文件本地存储
- **Apple HIG** — 遵循 Apple 人机界面指南，简洁优雅

---

## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter 3.11+ |
| 网络 | Dio |
| 本地存储 | path_provider + JSON |
| Markdown | flutter_markdown |
| 通知 | flutter_local_notifications |
| 文件选择 | file_picker |
| 网络状态 | connectivity_plus |
| 权限管理 | permission_handler |

---

## 构建发布

```bash
# Android APK
flutter build apk --release
```

---

## 更新日志

### v0.8.5
- 🎨 全面迁移到 Apple HIG 设计规范
- ✨ Agent 群：混合协作模式（自动调度 + 接力）
- ✨ Agent 状态显示和讨论进度
- ✨ Agent 信息工牌
- 🔧 Agent 身份隔离优化
- 🐛 修复 @ Agent 列表无法滚动
- 🐛 修复输入框聚焦时的边框问题

### v0.8.0
- ✨ 工具管道修复
- ✨ context_doc 简化
- 🔧 多处 bug 修复

### v0.6.6
- 🐛 修复检查更新无法识别新版本
- 🐛 修复下载失败问题

---

## 贡献

欢迎提交 Issue 和 PR！

## License

MIT

## 隐私说明

- 所有数据存储在本地设备上
- API Key 仅用于调用 AI 服务
- 聊天记录、笔记等不会被收集或上传
