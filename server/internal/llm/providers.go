package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	"github.com/xqli/moss-server/internal/models"
)

// QwenProvider 通义千问提供商
type QwenProvider struct {
	apiKey  string
	baseURL string
	model   string
}

// NewQwenProvider 创建 Qwen 提供商
func NewQwenProvider(apiKey string) *QwenProvider {
	return &QwenProvider{
		apiKey:  apiKey,
		baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
		model:   "qwen-turbo",
	}
}

func (p *QwenProvider) Name() string { return "qwen" }

func (p *QwenProvider) Chat(ctx context.Context, req *models.ChatRequest) (*models.ChatResponse, error) {
	model := req.Model
	if model == "" {
		model = p.model
	}

	body := map[string]interface{}{
		"model":    model,
		"messages": req.Messages,
	}
	if len(req.Tools) > 0 {
		body["tools"] = req.Tools
	}

	data, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}

	httpReq, err := http.NewRequestWithContext(ctx, "POST", p.baseURL+"/chat/completions", bytes.NewReader(data))
	if err != nil {
		return nil, err
	}

	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+p.apiKey)

	resp, err := http.DefaultClient.Do(httpReq)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("API 错误: %s - %s", resp.Status, string(respBody))
	}

	var result struct {
		ID      string `json:"id"`
		Model   string `json:"model"`
		Choices []struct {
			Message models.Message `json:"message"`
		} `json:"choices"`
		Usage *models.Usage `json:"usage"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}

	if len(result.Choices) == 0 {
		return nil, fmt.Errorf("无响应")
	}

	return &models.ChatResponse{
		ID:      result.ID,
		Model:   result.Model,
		Message: result.Choices[0].Message,
		Usage:   result.Usage,
	}, nil
}

func (p *QwenProvider) ChatStream(ctx context.Context, req *models.ChatRequest, callback func(delta string) error) error {
	model := req.Model
	if model == "" {
		model = p.model
	}

	body := map[string]interface{}{
		"model":         model,
		"messages":      req.Messages,
		"stream":        true,
		"stream_options": map[string]interface{}{"include_usage": true},
	}

	data, err := json.Marshal(body)
	if err != nil {
		return err
	}

	httpReq, err := http.NewRequestWithContext(ctx, "POST", p.baseURL+"/chat/completions", bytes.NewReader(data))
	if err != nil {
		return err
	}

	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+p.apiKey)
	httpReq.Header.Set("Accept", "text/event-stream")

	resp, err := http.DefaultClient.Do(httpReq)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("API 错误: %s - %s", resp.Status, string(respBody))
	}

	return processSSE(resp.Body, callback)
}

// GLMProvider 智谱 GLM 提供商
type GLMProvider struct {
	apiKey  string
	baseURL string
	model   string
}

// NewGLMProvider 创建 GLM 提供商
func NewGLMProvider(apiKey string) *GLMProvider {
	return &GLMProvider{
		apiKey:  apiKey,
		baseURL: "https://open.bigmodel.cn/api/paas/v4",
		model:   "glm-4-flash",
	}
}

func (p *GLMProvider) Name() string { return "glm" }

func (p *GLMProvider) Chat(ctx context.Context, req *models.ChatRequest) (*models.ChatResponse, error) {
	model := req.Model
	if model == "" {
		model = p.model
	}

	body := map[string]interface{}{
		"model":    model,
		"messages": req.Messages,
	}
	if len(req.Tools) > 0 {
		body["tools"] = req.Tools
	}

	data, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}

	httpReq, err := http.NewRequestWithContext(ctx, "POST", p.baseURL+"/chat/completions", bytes.NewReader(data))
	if err != nil {
		return nil, err
	}

	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+p.apiKey)

	resp, err := http.DefaultClient.Do(httpReq)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("API 错误: %s - %s", resp.Status, string(respBody))
	}

	var result struct {
		ID      string `json:"id"`
		Model   string `json:"model"`
		Choices []struct {
			Message models.Message `json:"message"`
		} `json:"choices"`
		Usage *models.Usage `json:"usage"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}

	if len(result.Choices) == 0 {
		return nil, fmt.Errorf("无响应")
	}

	return &models.ChatResponse{
		ID:      result.ID,
		Model:   result.Model,
		Message: result.Choices[0].Message,
		Usage:   result.Usage,
	}, nil
}

func (p *GLMProvider) ChatStream(ctx context.Context, req *models.ChatRequest, callback func(delta string) error) error {
	model := req.Model
	if model == "" {
		model = p.model
	}

	body := map[string]interface{}{
		"model":    model,
		"messages": req.Messages,
		"stream":   true,
	}

	data, err := json.Marshal(body)
	if err != nil {
		return err
	}

	httpReq, err := http.NewRequestWithContext(ctx, "POST", p.baseURL+"/chat/completions", bytes.NewReader(data))
	if err != nil {
		return err
	}

	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+p.apiKey)
	httpReq.Header.Set("Accept", "text/event-stream")

	resp, err := http.DefaultClient.Do(httpReq)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("API 错误: %s - %s", resp.Status, string(respBody))
	}

	return processSSE(resp.Body, callback)
}

// CopilotProvider GitHub Copilot 提供商 (使用 OpenAI 兼容接口)
type CopilotProvider struct {
	token   string
	baseURL string
	model   string
}

// NewCopilotProvider 创建 Copilot 提供商
func NewCopilotProvider(token string) *CopilotProvider {
	return &CopilotProvider{
		token:   token,
		baseURL: "https://api.githubcopilot.com",
		model:   "gpt-4o",
	}
}

func (p *CopilotProvider) Name() string { return "copilot" }

func (p *CopilotProvider) Chat(ctx context.Context, req *models.ChatRequest) (*models.ChatResponse, error) {
	model := req.Model
	if model == "" {
		model = p.model
	}

	body := map[string]interface{}{
		"model":    model,
		"messages": req.Messages,
	}
	if len(req.Tools) > 0 {
		body["tools"] = req.Tools
	}

	data, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}

	httpReq, err := http.NewRequestWithContext(ctx, "POST", p.baseURL+"/chat/completions", bytes.NewReader(data))
	if err != nil {
		return nil, err
	}

	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+p.token)
	httpReq.Header.Set("Editor-Version", "vscode/1.85.0")
	httpReq.Header.Set("Editor-Plugin-Version", "copilot-chat/0.11.0")

	resp, err := http.DefaultClient.Do(httpReq)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("API 错误: %s - %s", resp.Status, string(respBody))
	}

	var result struct {
		ID      string `json:"id"`
		Model   string `json:"model"`
		Choices []struct {
			Message models.Message `json:"message"`
		} `json:"choices"`
		Usage *models.Usage `json:"usage"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}

	if len(result.Choices) == 0 {
		return nil, fmt.Errorf("无响应")
	}

	return &models.ChatResponse{
		ID:      result.ID,
		Model:   result.Model,
		Message: result.Choices[0].Message,
		Usage:   result.Usage,
	}, nil
}

func (p *CopilotProvider) ChatStream(ctx context.Context, req *models.ChatRequest, callback func(delta string) error) error {
	model := req.Model
	if model == "" {
		model = p.model
	}

	body := map[string]interface{}{
		"model":    model,
		"messages": req.Messages,
		"stream":   true,
	}

	data, err := json.Marshal(body)
	if err != nil {
		return err
	}

	httpReq, err := http.NewRequestWithContext(ctx, "POST", p.baseURL+"/chat/completions", bytes.NewReader(data))
	if err != nil {
		return err
	}

	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+p.token)
	httpReq.Header.Set("Editor-Version", "vscode/1.85.0")
	httpReq.Header.Set("Editor-Plugin-Version", "copilot-chat/0.11.0")
	httpReq.Header.Set("Accept", "text/event-stream")

	resp, err := http.DefaultClient.Do(httpReq)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("API 错误: %s - %s", resp.Status, string(respBody))
	}

	return processSSE(resp.Body, callback)
}
