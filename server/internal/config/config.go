package config

import (
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

// Config 服务配置
type Config struct {
	// 服务器配置
	Port     int
	Host     string
	CORSMode string

	// LLM 提供商 API Keys
	DeepSeekAPIKey string
	QwenAPIKey     string
	GLMAPIKey      string
	CopilotToken   string

	// 数据库配置
	DBPath string

	// JWT 密钥
	JWTSecret string
}

// 默认配置
var defaultConfig = Config{
	Port:     8080,
	Host:     "0.0.0.0",
	CORSMode: "*",
	DBPath:   "./data/moss.db",
}

// Load 加载配置
func Load() *Config {
	// 尝试加载 .env 文件
	_ = godotenv.Load()

	cfg := defaultConfig

	// 服务器配置
	if port := os.Getenv("PORT"); port != "" {
		if p, err := strconv.Atoi(port); err == nil {
			cfg.Port = p
		}
	}
	if host := os.Getenv("HOST"); host != "" {
		cfg.Host = host
	}
	if cors := os.Getenv("CORS_MODE"); cors != "" {
		cfg.CORSMode = cors
	}

	// LLM API Keys
	cfg.DeepSeekAPIKey = os.Getenv("DEEPSEEK_API_KEY")
	cfg.QwenAPIKey = os.Getenv("QWEN_API_KEY")
	cfg.GLMAPIKey = os.Getenv("GLM_API_KEY")
	cfg.CopilotToken = os.Getenv("COPILOT_TOKEN")

	// 数据库
	if dbPath := os.Getenv("DB_PATH"); dbPath != "" {
		cfg.DBPath = dbPath
	}

	// JWT
	cfg.JWTSecret = os.Getenv("JWT_SECRET")
	if cfg.JWTSecret == "" {
		cfg.JWTSecret = "moss-secret-key-change-in-production"
	}

	return &cfg
}
