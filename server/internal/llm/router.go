package llm

import (
	"context"
	"fmt"
	"io"

	"github.com/xqli/moss-server/internal/config"
	"github.com/xqli/moss-server/internal/models"
)

// Provider LLM 提供商接口
type Provider interface {
	Name() string
	Chat(ctx context.Context, req *models.ChatRequest) (*models.ChatResponse, error)
	ChatStream(ctx context.Context, req *models.ChatRequest, callback func(delta string) error) error
}

// Router LLM 路由器
type Router struct {
	providers map[string]Provider
	cfg       *config.Config
}

// NewRouter 创建 LLM 路由器
func NewRouter(cfg *config.Config) *Router {
	r := &Router{
		providers: make(map[string]Provider),
		cfg:       cfg,
	}

	// 注册提供商
	if cfg.DeepSeekAPIKey != "" {
		r.providers["deepseek"] = NewDeepSeekProvider(cfg.DeepSeekAPIKey)
	}
	if cfg.QwenAPIKey != "" {
		r.providers["qwen"] = NewQwenProvider(cfg.QwenAPIKey)
	}
	if cfg.GLMAPIKey != "" {
		r.providers["glm"] = NewGLMProvider(cfg.GLMAPIKey)
	}
	if cfg.CopilotToken != "" {
		r.providers["copilot"] = NewCopilotProvider(cfg.CopilotToken)
	}

	return r
}

// GetProvider 获取指定提供商
func (r *Router) GetProvider(name string) (Provider, error) {
	if p, ok := r.providers[name]; ok {
		return p, nil
	}
	return nil, fmt.Errorf("提供商 %s 不存在或未配置", name)
}

// ListProviders 列出可用提供商
func (r *Router) ListProviders() []string {
	names := make([]string, 0, len(r.providers))
	for name := range r.providers {
		names = append(names, name)
	}
	return names
}

// Chat 执行聊天
func (r *Router) Chat(ctx context.Context, req *models.ChatRequest) (*models.ChatResponse, error) {
	provider, err := r.GetProvider(req.Provider)
	if err != nil {
		return nil, err
	}
	return provider.Chat(ctx, req)
}

// ChatStream 执行流式聊天
func (r *Router) ChatStream(ctx context.Context, req *models.ChatRequest, w io.Writer) error {
	provider, err := r.GetProvider(req.Provider)
	if err != nil {
		return err
	}

	return provider.ChatStream(ctx, req, func(delta string) error {
		_, err := fmt.Fprintf(w, "data: %s\n\n", delta)
		if flusher, ok := w.(interface{ Flush() }); ok {
			flusher.Flush()
		}
		return err
	})
}
