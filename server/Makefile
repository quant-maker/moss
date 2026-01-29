# Makefile for Moss Server

.PHONY: build run dev test clean docker

# 变量
BINARY_NAME=moss-server
BUILD_DIR=./bin

# 构建
build:
	@echo "🔨 Building..."
	@mkdir -p $(BUILD_DIR)
	go build -o $(BUILD_DIR)/$(BINARY_NAME) ./cmd/moss-server
	@echo "✅ Build complete: $(BUILD_DIR)/$(BINARY_NAME)"

# 运行
run: build
	@echo "🚀 Running..."
	$(BUILD_DIR)/$(BINARY_NAME)

# 开发模式 (需要 air)
dev:
	@if command -v air > /dev/null; then \
		air; \
	else \
		echo "⚠️  请安装 air: go install github.com/cosmtrek/air@latest"; \
		$(MAKE) run; \
	fi

# 测试
test:
	@echo "🧪 Testing..."
	go test -v ./...

# 清理
clean:
	@echo "🧹 Cleaning..."
	rm -rf $(BUILD_DIR)
	go clean

# 依赖
deps:
	@echo "📦 Downloading dependencies..."
	go mod tidy
	go mod download

# Docker 构建
docker:
	@echo "🐳 Building Docker image..."
	docker build -t moss-server:latest .

# Docker 运行
docker-run:
	docker-compose up -d

# Docker 停止
docker-stop:
	docker-compose down

# Docker 日志
docker-logs:
	docker-compose logs -f

# 生成文档
docs:
	@echo "📚 Generating docs..."
	@if command -v swag > /dev/null; then \
		swag init -g cmd/moss-server/main.go -o docs; \
	else \
		echo "⚠️  请安装 swag: go install github.com/swaggo/swag/cmd/swag@latest"; \
	fi

# 帮助
help:
	@echo "Moss Server - 可用命令:"
	@echo ""
	@echo "  make build       - 构建二进制文件"
	@echo "  make run         - 构建并运行"
	@echo "  make dev         - 开发模式 (热重载)"
	@echo "  make test        - 运行测试"
	@echo "  make clean       - 清理构建文件"
	@echo "  make deps        - 下载依赖"
	@echo "  make docker      - 构建 Docker 镜像"
	@echo "  make docker-run  - Docker 运行"
	@echo "  make docker-stop - Docker 停止"
	@echo "  make docker-logs - 查看 Docker 日志"
