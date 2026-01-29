package main

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/xqli/moss-server/internal/api"
	"github.com/xqli/moss-server/internal/config"
)

func main() {
	fmt.Println("🌱 Moss Server - 智能管家后端服务")
	fmt.Println("================================")

	// 加载配置
	cfg := config.Load()

	// 显示配置信息
	fmt.Printf("端口: %d\n", cfg.Port)
	fmt.Printf("CORS: %s\n", cfg.CORSMode)
	fmt.Printf("数据库: %s\n", cfg.DBPath)

	providers := []string{}
	if cfg.DeepSeekAPIKey != "" {
		providers = append(providers, "DeepSeek")
	}
	if cfg.QwenAPIKey != "" {
		providers = append(providers, "Qwen")
	}
	if cfg.GLMAPIKey != "" {
		providers = append(providers, "GLM")
	}
	if cfg.CopilotToken != "" {
		providers = append(providers, "Copilot")
	}
	if len(providers) > 0 {
		fmt.Printf("LLM 提供商: %v\n", providers)
	} else {
		fmt.Println("⚠️  未配置 LLM API Key")
	}
	fmt.Println()

	// 创建服务器
	server, err := api.NewServer(cfg)
	if err != nil {
		fmt.Printf("❌ 创建服务器失败: %v\n", err)
		os.Exit(1)
	}
	defer server.Close()

	// 优雅关闭
	go func() {
		quit := make(chan os.Signal, 1)
		signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
		<-quit
		fmt.Println("\n👋 正在关闭服务器...")
		server.Close()
		os.Exit(0)
	}()

	// 启动服务器
	if err := server.Run(); err != nil {
		fmt.Printf("❌ 服务器启动失败: %v\n", err)
		os.Exit(1)
	}
}
