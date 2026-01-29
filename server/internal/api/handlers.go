package api

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/xqli/moss-server/internal/models"
)

// === 聊天 API ===

// handleChat 处理聊天请求
func (s *Server) handleChat(c *gin.Context) {
	var req models.ChatRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errorResponse(c, http.StatusBadRequest, "请求参数错误: "+err.Error())
		return
	}

	if req.Provider == "" {
		errorResponse(c, http.StatusBadRequest, "请指定 LLM 提供商")
		return
	}

	resp, err := s.llm.Chat(c.Request.Context(), &req)
	if err != nil {
		errorResponse(c, http.StatusInternalServerError, "聊天失败: "+err.Error())
		return
	}

	success(c, resp)
}

// handleChatStream 处理流式聊天请求
func (s *Server) handleChatStream(c *gin.Context) {
	var req models.ChatRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errorResponse(c, http.StatusBadRequest, "请求参数错误: "+err.Error())
		return
	}

	if req.Provider == "" {
		errorResponse(c, http.StatusBadRequest, "请指定 LLM 提供商")
		return
	}

	c.Header("Content-Type", "text/event-stream")
	c.Header("Cache-Control", "no-cache")
	c.Header("Connection", "keep-alive")

	if err := s.llm.ChatStream(c.Request.Context(), &req, c.Writer); err != nil {
		c.SSEvent("error", err.Error())
	}

	c.SSEvent("done", "")
}

// === 日程 API ===

// listSchedules 获取日程列表
func (s *Server) listSchedules(c *gin.Context) {
	userID := c.GetHeader("X-User-ID")
	
	var start, end *time.Time
	if startStr := c.Query("start"); startStr != "" {
		if t, err := time.Parse(time.RFC3339, startStr); err == nil {
			start = &t
		}
	}
	if endStr := c.Query("end"); endStr != "" {
		if t, err := time.Parse(time.RFC3339, endStr); err == nil {
			end = &t
		}
	}

	schedules, err := s.storage.ListSchedules(userID, start, end)
	if err != nil {
		errorResponse(c, http.StatusInternalServerError, "获取日程失败: "+err.Error())
		return
	}

	success(c, schedules)
}

// createSchedule 创建日程
func (s *Server) createSchedule(c *gin.Context) {
	var schedule models.Schedule
	if err := c.ShouldBindJSON(&schedule); err != nil {
		errorResponse(c, http.StatusBadRequest, "请求参数错误: "+err.Error())
		return
	}

	schedule.UserID = c.GetHeader("X-User-ID")

	if err := s.storage.CreateSchedule(&schedule); err != nil {
		errorResponse(c, http.StatusInternalServerError, "创建日程失败: "+err.Error())
		return
	}

	// 广播更新
	s.wsHub.Broadcast([]byte(`{"type":"schedule_created","data":` + schedule.ID + `}`))

	success(c, schedule)
}

// getSchedule 获取单个日程
func (s *Server) getSchedule(c *gin.Context) {
	id := c.Param("id")
	
	schedule, err := s.storage.GetSchedule(id)
	if err != nil {
		errorResponse(c, http.StatusNotFound, "日程不存在")
		return
	}

	success(c, schedule)
}

// updateSchedule 更新日程
func (s *Server) updateSchedule(c *gin.Context) {
	id := c.Param("id")
	
	var schedule models.Schedule
	if err := c.ShouldBindJSON(&schedule); err != nil {
		errorResponse(c, http.StatusBadRequest, "请求参数错误: "+err.Error())
		return
	}

	schedule.ID = id
	if err := s.storage.UpdateSchedule(&schedule); err != nil {
		errorResponse(c, http.StatusInternalServerError, "更新日程失败: "+err.Error())
		return
	}

	s.wsHub.Broadcast([]byte(`{"type":"schedule_updated","data":"` + id + `"}`))

	success(c, schedule)
}

// deleteSchedule 删除日程
func (s *Server) deleteSchedule(c *gin.Context) {
	id := c.Param("id")
	
	if err := s.storage.DeleteSchedule(id); err != nil {
		errorResponse(c, http.StatusInternalServerError, "删除日程失败: "+err.Error())
		return
	}

	s.wsHub.Broadcast([]byte(`{"type":"schedule_deleted","data":"` + id + `"}`))

	success(c, gin.H{"deleted": id})
}

// === 任务 API ===

// listTasks 获取任务列表
func (s *Server) listTasks(c *gin.Context) {
	userID := c.GetHeader("X-User-ID")
	status := c.Query("status")

	tasks, err := s.storage.ListTasks(userID, status)
	if err != nil {
		errorResponse(c, http.StatusInternalServerError, "获取任务失败: "+err.Error())
		return
	}

	success(c, tasks)
}

// createTask 创建任务
func (s *Server) createTask(c *gin.Context) {
	var task models.Task
	if err := c.ShouldBindJSON(&task); err != nil {
		errorResponse(c, http.StatusBadRequest, "请求参数错误: "+err.Error())
		return
	}

	task.UserID = c.GetHeader("X-User-ID")

	if err := s.storage.CreateTask(&task); err != nil {
		errorResponse(c, http.StatusInternalServerError, "创建任务失败: "+err.Error())
		return
	}

	s.wsHub.Broadcast([]byte(`{"type":"task_created","data":"` + task.ID + `"}`))

	success(c, task)
}

// getTask 获取单个任务
func (s *Server) getTask(c *gin.Context) {
	id := c.Param("id")
	
	task, err := s.storage.GetTask(id)
	if err != nil {
		errorResponse(c, http.StatusNotFound, "任务不存在")
		return
	}

	success(c, task)
}

// updateTask 更新任务
func (s *Server) updateTask(c *gin.Context) {
	id := c.Param("id")
	
	var task models.Task
	if err := c.ShouldBindJSON(&task); err != nil {
		errorResponse(c, http.StatusBadRequest, "请求参数错误: "+err.Error())
		return
	}

	task.ID = id
	if err := s.storage.UpdateTask(&task); err != nil {
		errorResponse(c, http.StatusInternalServerError, "更新任务失败: "+err.Error())
		return
	}

	s.wsHub.Broadcast([]byte(`{"type":"task_updated","data":"` + id + `"}`))

	success(c, task)
}

// deleteTask 删除任务
func (s *Server) deleteTask(c *gin.Context) {
	id := c.Param("id")
	
	if err := s.storage.DeleteTask(id); err != nil {
		errorResponse(c, http.StatusInternalServerError, "删除任务失败: "+err.Error())
		return
	}

	s.wsHub.Broadcast([]byte(`{"type":"task_deleted","data":"` + id + `"}`))

	success(c, gin.H{"deleted": id})
}

// === 同步 API ===

// handleSync 处理数据同步
func (s *Server) handleSync(c *gin.Context) {
	var req models.SyncRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errorResponse(c, http.StatusBadRequest, "请求参数错误: "+err.Error())
		return
	}

	// 获取服务端更新的数据
	var since time.Time
	if req.LastSyncTime != nil {
		since = *req.LastSyncTime
	}

	resp, err := s.storage.GetModifiedSince(since)
	if err != nil {
		errorResponse(c, http.StatusInternalServerError, "同步失败: "+err.Error())
		return
	}

	// 保存客户端发来的数据
	for _, schedule := range req.Schedules {
		if existing, _ := s.storage.GetSchedule(schedule.ID); existing != nil {
			_ = s.storage.UpdateSchedule(&schedule)
		} else {
			_ = s.storage.CreateSchedule(&schedule)
		}
	}

	for _, task := range req.Tasks {
		if existing, _ := s.storage.GetTask(task.ID); existing != nil {
			_ = s.storage.UpdateTask(&task)
		} else {
			_ = s.storage.CreateTask(&task)
		}
	}

	success(c, resp)
}
