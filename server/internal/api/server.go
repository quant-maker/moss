package api

import (
	"fmt"
	"net/http"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/xqli/moss-server/internal/config"
	"github.com/xqli/moss-server/internal/llm"
	"github.com/xqli/moss-server/internal/models"
	"github.com/xqli/moss-server/internal/storage"
	"github.com/xqli/moss-server/internal/ws"
)

// Server HTTP 服务器
type Server struct {
	cfg     *config.Config
	router  *gin.Engine
	llm     *llm.Router
	storage *storage.Storage
	wsHub   *ws.Hub
}

// NewServer 创建服务器
func NewServer(cfg *config.Config) (*Server, error) {
	// 初始化存储
	store, err := storage.New(cfg.DBPath)
	if err != nil {
		return nil, fmt.Errorf("初始化存储失败: %w", err)
	}

	// 初始化 LLM 路由
	llmRouter := llm.NewRouter(cfg)

	// 初始化 WebSocket Hub
	wsHub := ws.NewHub()
	go wsHub.Run()

	s := &Server{
		cfg:     cfg,
		llm:     llmRouter,
		storage: store,
		wsHub:   wsHub,
	}

	s.setupRouter()
	return s, nil
}

// setupRouter 配置路由
func (s *Server) setupRouter() {
	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(gin.Logger())

	// CORS 配置
	corsConfig := cors.DefaultConfig()
	corsConfig.AllowAllOrigins = s.cfg.CORSMode == "*"
	if !corsConfig.AllowAllOrigins {
		corsConfig.AllowOrigins = []string{s.cfg.CORSMode}
	}
	corsConfig.AllowHeaders = append(corsConfig.AllowHeaders, "Authorization")
	r.Use(cors.New(corsConfig))

	// 健康检查
	r.GET("/health", s.healthCheck)

	// API v1
	v1 := r.Group("/api/v1")
	{
		// LLM 代理
		v1.POST("/chat", s.handleChat)
		v1.POST("/chat/stream", s.handleChatStream)

		// 日程管理
		schedules := v1.Group("/schedules")
		{
			schedules.GET("", s.listSchedules)
			schedules.POST("", s.createSchedule)
			schedules.GET("/:id", s.getSchedule)
			schedules.PUT("/:id", s.updateSchedule)
			schedules.DELETE("/:id", s.deleteSchedule)
		}

		// 任务管理
		tasks := v1.Group("/tasks")
		{
			tasks.GET("", s.listTasks)
			tasks.POST("", s.createTask)
			tasks.GET("/:id", s.getTask)
			tasks.PUT("/:id", s.updateTask)
			tasks.DELETE("/:id", s.deleteTask)
		}

		// 数据同步
		v1.POST("/sync", s.handleSync)
	}

	// WebSocket
	r.GET("/ws", func(c *gin.Context) {
		ws.HandleConnection(s.wsHub, c.Writer, c.Request)
	})

	s.router = r
}

// Run 启动服务器
func (s *Server) Run() error {
	addr := fmt.Sprintf("%s:%d", s.cfg.Host, s.cfg.Port)
	fmt.Printf("🚀 Moss Server 启动于 http://%s\n", addr)
	return s.router.Run(addr)
}

// Close 关闭服务器
func (s *Server) Close() error {
	return s.storage.Close()
}

// healthCheck 健康检查
func (s *Server) healthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data: gin.H{
			"status":  "ok",
			"service": "moss-server",
			"version": "1.0.0",
		},
	})
}

// success 成功响应
func success(c *gin.Context, data interface{}) {
	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data:    data,
	})
}

// errorResponse 错误响应
func errorResponse(c *gin.Context, code int, err string) {
	c.JSON(code, models.APIResponse{
		Success: false,
		Error:   err,
	})
}
