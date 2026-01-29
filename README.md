# Moss - 智能管家助手

一个基于 Flutter + Go 的智能管家助手应用，支持多 LLM 提供商，具备工具调用能力。

## 功能特性

- **多 LLM 支持**: DeepSeek, 通义千问, 智谱GLM, GitHub Copilot
- **工具调用**: 打开APP、创建日程、搜索、播放音乐、点外卖等
- **跨平台**: Android APP + Web 版本
- **后端代理**: Go 后端服务，统一管理 API 调用
- **本地存储**: 对话历史、设置持久化
- **语音交互**: 语音识别 + 语音合成

## 项目结构

```
moss/
├── lib/                    # Flutter 前端代码
│   ├── app/               # 应用入口和路由
│   ├── core/              # 核心模块
│   │   ├── llm/          # LLM 提供商抽象
│   │   ├── tools/        # 工具调用框架
│   │   ├── services/     # 服务层
│   │   └── storage/      # 本地存储
│   └── features/          # 功能模块
│       ├── chat/         # 聊天界面
│       ├── schedule/     # 日程管理
│       ├── tasks/        # 任务管理
│       └── settings/     # 设置页面
├── server/                 # Go 后端服务
│   ├── cmd/              # 入口
│   ├── internal/         # 内部模块
│   └── Makefile          # 构建脚本
├── android/               # Android 配置
├── web/                   # Web 配置
└── test/                  # 测试代码
```

## 快速开始

### 环境要求

- Flutter 3.5+
- Go 1.21+
- Android SDK (可选，用于构建 APK)

### 安装依赖

```bash
# Flutter 依赖
flutter pub get

# Go 后端依赖
cd server && make deps
```

### 运行开发环境

```bash
# 运行 Flutter Web
flutter run -d web-server --web-port=3000

# 运行 Go 后端
cd server && make run
```

### 构建发布版本

```bash
# 构建 Web
flutter build web --release

# 构建 Android APK
flutter build apk --release

# 构建 Go 后端
cd server && make build
```

## 配置

### LLM 提供商配置

在应用设置中配置 API Key：

| 提供商 | 配置项 |
|--------|--------|
| DeepSeek | API Key |
| 通义千问 | API Key |
| 智谱GLM | API Key |
| Copilot | 通过后端代理 |

### 后端服务配置

创建 `server/.env` 文件：

```env
PORT=8080
DEEPSEEK_API_KEY=your_key
QWEN_API_KEY=your_key
GLM_API_KEY=your_key
```

## 技术栈

### 前端
- **框架**: Flutter 3.5+
- **状态管理**: Riverpod
- **路由**: go_router
- **本地存储**: Hive
- **网络请求**: Dio

### 后端
- **语言**: Go 1.21+
- **框架**: Gin
- **存储**: BoltDB
- **WebSocket**: gorilla/websocket

## 许可证

MIT License
