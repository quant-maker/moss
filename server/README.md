# Moss Server - 智能管家后端服务

## 功能

- **LLM 代理**: 支持 DeepSeek、通义千问、智谱GLM、GitHub Copilot
- **数据同步**: 日程和任务的云端存储与同步
- **WebSocket**: 实时消息推送
- **RESTful API**: 标准化的 API 接口

## 快速开始

### 环境要求

- Go 1.21+
- Docker (可选)

### 本地运行

```bash
# 1. 进入服务器目录
cd server

# 2. 复制环境变量配置
cp .env.example .env

# 3. 编辑 .env 文件，配置 API Keys
vim .env

# 4. 下载依赖
go mod tidy

# 5. 运行服务器
go run ./cmd/moss-server
```

### Docker 运行

```bash
# 1. 配置环境变量
cp .env.example .env
vim .env

# 2. 启动容器
docker-compose up -d

# 3. 查看日志
docker-compose logs -f
```

## API 文档

### 健康检查

```
GET /health
```

### LLM 聊天

```
POST /api/v1/chat
Content-Type: application/json

{
  "provider": "deepseek",
  "model": "deepseek-chat",
  "messages": [
    {"role": "user", "content": "你好"}
  ]
}
```

### 流式聊天

```
POST /api/v1/chat/stream
Content-Type: application/json

{
  "provider": "deepseek",
  "messages": [
    {"role": "user", "content": "你好"}
  ]
}
```

### 日程管理

```
GET    /api/v1/schedules          # 获取日程列表
POST   /api/v1/schedules          # 创建日程
GET    /api/v1/schedules/:id      # 获取单个日程
PUT    /api/v1/schedules/:id      # 更新日程
DELETE /api/v1/schedules/:id      # 删除日程
```

### 任务管理

```
GET    /api/v1/tasks              # 获取任务列表
POST   /api/v1/tasks              # 创建任务
GET    /api/v1/tasks/:id          # 获取单个任务
PUT    /api/v1/tasks/:id          # 更新任务
DELETE /api/v1/tasks/:id          # 删除任务
```

### 数据同步

```
POST /api/v1/sync
Content-Type: application/json

{
  "last_sync_time": "2024-01-01T00:00:00Z",
  "schedules": [...],
  "tasks": [...]
}
```

### WebSocket

```
ws://localhost:8080/ws?user_id=xxx
```

消息格式:
```json
{
  "type": "schedule_created",
  "data": "schedule_id"
}
```

## 项目结构

```
server/
├── cmd/
│   └── moss-server/
│       └── main.go          # 主入口
├── internal/
│   ├── api/
│   │   ├── server.go        # HTTP 服务器
│   │   └── handlers.go      # API 处理器
│   ├── config/
│   │   └── config.go        # 配置管理
│   ├── llm/
│   │   ├── router.go        # LLM 路由器
│   │   ├── deepseek.go      # DeepSeek 提供商
│   │   └── providers.go     # 其他提供商
│   ├── models/
│   │   └── models.go        # 数据模型
│   ├── storage/
│   │   └── storage.go       # 数据存储
│   └── ws/
│       └── hub.go           # WebSocket Hub
├── Dockerfile
├── docker-compose.yml
├── go.mod
└── README.md
```

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| PORT | 服务端口 | 8080 |
| HOST | 监听地址 | 0.0.0.0 |
| CORS_MODE | CORS 模式 | * |
| DB_PATH | 数据库路径 | ./data/moss.db |
| DEEPSEEK_API_KEY | DeepSeek API Key | - |
| QWEN_API_KEY | 通义千问 API Key | - |
| GLM_API_KEY | 智谱 GLM API Key | - |
| COPILOT_TOKEN | GitHub Copilot Token | - |
| JWT_SECRET | JWT 密钥 | - |
