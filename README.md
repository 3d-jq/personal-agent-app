# DWeis - Personal AI Agent

你的全能 AI 助手，支持聊天对话、工具调用、图片视频生成、笔记管理和提醒等功能。

## 功能特性

- **AI 对话** - 支持 OpenAI / Anthropic / DeepSeek 等多种 AI 后端
- **工具调用** - 天气查询、网页搜索、文件管理、剪贴板操作等
- **图片视频生成** - 通过 Agnes-AI 生成图片和视频
- **笔记管理** - 语音/文字记录笔记，支持导出
- **记忆系统** - AI 记住你的偏好和重要信息
- **定时提醒** - 设置提醒和定时任务
- **媒体库** - 管理生成的图片和视频
- **个性化** - 自定义 AI 回复风格和指令
- **主题切换** - 支持亮色/暗色主题
- **多会话管理** - 同时管理多个对话

## 快速开始

### 环境要求

- Flutter SDK >= 3.11.5
- Dart SDK >= 3.11.5

### 安装

1. 克隆项目
```bash
git clone <repository-url>
cd personal_agent_app
```

2. 安装依赖
```bash
flutter pub get
```

3. 配置环境变量

复制 `.env.example` 为 `.env`，填入你的 API Key：
```
AGNES_API_KEY=your_agnes_api_key_here
TAVILY_API_KEY=your_tavily_api_key_here
```

4. 运行项目
```bash
flutter run
```

## AI 后端配置

首次启动时会引导配置 AI 后端。支持以下厂商：

| 厂商 | Base URL | 说明 |
|------|----------|------|
| DeepSeek | https://api.deepseek.com/v1 | 国内推荐 |
| OpenAI | https://api.openai.com/v1 | 需要科学上网 |
| Anthropic | https://api.anthropic.com | 需要科学上网 |
| Agnes | https://apihub.agnes-ai.com/v1 | 图片视频生成 |

你也可以在设置中添加其他兼容 OpenAI API 格式的服务商。

## 项目结构

```
lib/
├── main.dart              # 入口文件
├── app.dart               # 应用配置
├── core/                  # 核心配置（颜色主题等）
├── models/                # 数据模型
├── screens/               # 页面
├── services/              # 服务层
│   ├── ai_service.dart    # AI 通信服务
│   ├── chat_storage.dart  # 聊天存储
│   ├── note_storage.dart  # 笔记存储
│   └── ...
├── tools/                 # AI 工具定义
│   ├── weather_tool.dart  # 天气查询
│   ├── web_search.dart    # 网页搜索
│   └── ...
└── widgets/               # UI 组件
```

## 可用工具

AI 可以调用以下工具来帮助你：

- `weather` - 查询天气
- `web_search` - 搜索网页
- `web_fetch` - 获取网页内容
- `reminder` - 设置提醒
- `file_manager` - 文件管理
- `clipboard` - 剪贴板操作
- `generate_image` - 生成图片（需要 Agnes API）
- `generate_video` - 生成视频（需要 Agnes API）
- `save_memory` - 保存记忆
- `save_note` - 保存笔记
- `get_current_time` - 获取当前时间

## 构建发布

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

## 隐私说明

- 所有数据存储在本地设备上
- API Key 仅用于调用 AI 服务，不会上传到第三方
- 聊天记录、笔记等数据不会被收集或上传

## License

MIT
