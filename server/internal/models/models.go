package models

import "time"

// Message 聊天消息
type Message struct {
	Role       string      `json:"role"`
	Content    string      `json:"content"`
	ToolCalls  []ToolCall  `json:"tool_calls,omitempty"`
	ToolCallID string      `json:"tool_call_id,omitempty"`
}

// ToolCall 工具调用
type ToolCall struct {
	ID       string       `json:"id"`
	Type     string       `json:"type"`
	Function FunctionCall `json:"function"`
}

// FunctionCall 函数调用
type FunctionCall struct {
	Name      string `json:"name"`
	Arguments string `json:"arguments"`
}

// Tool 工具定义
type Tool struct {
	Type     string   `json:"type"`
	Function Function `json:"function"`
}

// Function 函数定义
type Function struct {
	Name        string      `json:"name"`
	Description string      `json:"description"`
	Parameters  interface{} `json:"parameters"`
}

// ChatRequest 聊天请求
type ChatRequest struct {
	Provider string    `json:"provider"`
	Model    string    `json:"model,omitempty"`
	Messages []Message `json:"messages"`
	Tools    []Tool    `json:"tools,omitempty"`
	Stream   bool      `json:"stream"`
}

// ChatResponse 聊天响应
type ChatResponse struct {
	ID      string  `json:"id"`
	Model   string  `json:"model"`
	Message Message `json:"message"`
	Usage   *Usage  `json:"usage,omitempty"`
}

// Usage 使用量统计
type Usage struct {
	PromptTokens     int `json:"prompt_tokens"`
	CompletionTokens int `json:"completion_tokens"`
	TotalTokens      int `json:"total_tokens"`
}

// Schedule 日程
type Schedule struct {
	ID          string     `json:"id"`
	Title       string     `json:"title"`
	Description string     `json:"description,omitempty"`
	StartTime   time.Time  `json:"start_time"`
	EndTime     *time.Time `json:"end_time,omitempty"`
	IsAllDay    bool       `json:"is_all_day"`
	Location    string     `json:"location,omitempty"`
	RepeatType  string     `json:"repeat_type"`
	Reminder    int        `json:"reminder"`
	IsCompleted bool       `json:"is_completed"`
	Color       string     `json:"color,omitempty"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
	UserID      string     `json:"user_id"`
}

// Task 任务
type Task struct {
	ID          string     `json:"id"`
	Title       string     `json:"title"`
	Description string     `json:"description,omitempty"`
	Priority    string     `json:"priority"`
	Status      string     `json:"status"`
	Category    string     `json:"category,omitempty"`
	DueDate     *time.Time `json:"due_date,omitempty"`
	Tags        []string   `json:"tags,omitempty"`
	CompletedAt *time.Time `json:"completed_at,omitempty"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
	UserID      string     `json:"user_id"`
}

// SyncRequest 同步请求
type SyncRequest struct {
	LastSyncTime *time.Time  `json:"last_sync_time,omitempty"`
	Schedules    []Schedule  `json:"schedules,omitempty"`
	Tasks        []Task      `json:"tasks,omitempty"`
}

// SyncResponse 同步响应
type SyncResponse struct {
	SyncTime  time.Time  `json:"sync_time"`
	Schedules []Schedule `json:"schedules,omitempty"`
	Tasks     []Task     `json:"tasks,omitempty"`
}

// APIResponse 通用 API 响应
type APIResponse struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}
