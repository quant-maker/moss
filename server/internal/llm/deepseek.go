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

// DeepSeekProvider DeepSeek 提供商
type DeepSeekProvider struct {
	apiKey  string
	baseURL string
	model   string
}

// NewDeepSeekProvider 创建 DeepSeek 提供商
func NewDeepSeekProvider(apiKey string) *DeepSeekProvider {
	return &DeepSeekProvider{
		apiKey:  apiKey,
		baseURL: "https://api.deepseek.com/v1",
		model:   "deepseek-chat",
	}
}

func (p *DeepSeekProvider) Name() string { return "deepseek" }

func (p *DeepSeekProvider) Chat(ctx context.Context, req *models.ChatRequest) (*models.ChatResponse, error) {
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

func (p *DeepSeekProvider) ChatStream(ctx context.Context, req *models.ChatRequest, callback func(delta string) error) error {
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

// processSSE 处理 SSE 流
func processSSE(reader io.Reader, callback func(delta string) error) error {
	buf := make([]byte, 4096)
	var buffer bytes.Buffer

	for {
		n, err := reader.Read(buf)
		if n > 0 {
			buffer.Write(buf[:n])

			// 处理完整的行
			for {
				line, err := buffer.ReadString('\n')
				if err != nil {
					buffer.WriteString(line)
					break
				}

				line = line[:len(line)-1] // 去掉换行符
				if len(line) > 6 && line[:6] == "data: " {
					data := line[6:]
					if data == "[DONE]" {
						return nil
					}

					var chunk struct {
						Choices []struct {
							Delta struct {
								Content string `json:"content"`
							} `json:"delta"`
						} `json:"choices"`
					}

					if err := json.Unmarshal([]byte(data), &chunk); err == nil {
						if len(chunk.Choices) > 0 && chunk.Choices[0].Delta.Content != "" {
							if err := callback(chunk.Choices[0].Delta.Content); err != nil {
								return err
							}
						}
					}
				}
			}
		}

		if err == io.EOF {
			return nil
		}
		if err != nil {
			return err
		}
	}
}
