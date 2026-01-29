package storage

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/google/uuid"
	"github.com/xqli/moss-server/internal/models"
	bolt "go.etcd.io/bbolt"
)

// Bucket 名称
var (
	bucketSchedules = []byte("schedules")
	bucketTasks     = []byte("tasks")
)

// Storage 存储服务
type Storage struct {
	db *bolt.DB
}

// New 创建存储服务
func New(dbPath string) (*Storage, error) {
	// 确保目录存在
	dir := filepath.Dir(dbPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return nil, fmt.Errorf("创建数据目录失败: %w", err)
	}

	db, err := bolt.Open(dbPath, 0600, &bolt.Options{Timeout: 1 * time.Second})
	if err != nil {
		return nil, fmt.Errorf("打开数据库失败: %w", err)
	}

	// 初始化 buckets
	err = db.Update(func(tx *bolt.Tx) error {
		if _, err := tx.CreateBucketIfNotExists(bucketSchedules); err != nil {
			return err
		}
		if _, err := tx.CreateBucketIfNotExists(bucketTasks); err != nil {
			return err
		}
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("初始化 bucket 失败: %w", err)
	}

	return &Storage{db: db}, nil
}

// Close 关闭数据库
func (s *Storage) Close() error {
	return s.db.Close()
}

// === 日程操作 ===

// ListSchedules 获取日程列表
func (s *Storage) ListSchedules(userID string, start, end *time.Time) ([]models.Schedule, error) {
	var schedules []models.Schedule

	err := s.db.View(func(tx *bolt.Tx) error {
		b := tx.Bucket(bucketSchedules)
		return b.ForEach(func(k, v []byte) error {
			var schedule models.Schedule
			if err := json.Unmarshal(v, &schedule); err != nil {
				return nil // 跳过无效数据
			}

			// 过滤用户
			if userID != "" && schedule.UserID != userID {
				return nil
			}

			// 过滤时间范围
			if start != nil && schedule.StartTime.Before(*start) {
				return nil
			}
			if end != nil && schedule.StartTime.After(*end) {
				return nil
			}

			schedules = append(schedules, schedule)
			return nil
		})
	})

	return schedules, err
}

// GetSchedule 获取单个日程
func (s *Storage) GetSchedule(id string) (*models.Schedule, error) {
	var schedule models.Schedule

	err := s.db.View(func(tx *bolt.Tx) error {
		b := tx.Bucket(bucketSchedules)
		v := b.Get([]byte(id))
		if v == nil {
			return fmt.Errorf("日程不存在")
		}
		return json.Unmarshal(v, &schedule)
	})

	if err != nil {
		return nil, err
	}
	return &schedule, nil
}

// CreateSchedule 创建日程
func (s *Storage) CreateSchedule(schedule *models.Schedule) error {
	if schedule.ID == "" {
		schedule.ID = uuid.New().String()
	}
	now := time.Now()
	schedule.CreatedAt = now
	schedule.UpdatedAt = now

	return s.db.Update(func(tx *bolt.Tx) error {
		b := tx.Bucket(bucketSchedules)
		data, err := json.Marshal(schedule)
		if err != nil {
			return err
		}
		return b.Put([]byte(schedule.ID), data)
	})
}

// UpdateSchedule 更新日程
func (s *Storage) UpdateSchedule(schedule *models.Schedule) error {
	schedule.UpdatedAt = time.Now()

	return s.db.Update(func(tx *bolt.Tx) error {
		b := tx.Bucket(bucketSchedules)
		if b.Get([]byte(schedule.ID)) == nil {
			return fmt.Errorf("日程不存在")
		}
		data, err := json.Marshal(schedule)
		if err != nil {
			return err
		}
		return b.Put([]byte(schedule.ID), data)
	})
}

// DeleteSchedule 删除日程
func (s *Storage) DeleteSchedule(id string) error {
	return s.db.Update(func(tx *bolt.Tx) error {
		b := tx.Bucket(bucketSchedules)
		return b.Delete([]byte(id))
	})
}

// === 任务操作 ===

// ListTasks 获取任务列表
func (s *Storage) ListTasks(userID string, status string) ([]models.Task, error) {
	var tasks []models.Task

	err := s.db.View(func(tx *bolt.Tx) error {
		b := tx.Bucket(bucketTasks)
		return b.ForEach(func(k, v []byte) error {
			var task models.Task
			if err := json.Unmarshal(v, &task); err != nil {
				return nil
			}

			if userID != "" && task.UserID != userID {
				return nil
			}

			if status != "" && task.Status != status {
				return nil
			}

			tasks = append(tasks, task)
			return nil
		})
	})

	return tasks, err
}

// GetTask 获取单个任务
func (s *Storage) GetTask(id string) (*models.Task, error) {
	var task models.Task

	err := s.db.View(func(tx *bolt.Tx) error {
		b := tx.Bucket(bucketTasks)
		v := b.Get([]byte(id))
		if v == nil {
			return fmt.Errorf("任务不存在")
		}
		return json.Unmarshal(v, &task)
	})

	if err != nil {
		return nil, err
	}
	return &task, nil
}

// CreateTask 创建任务
func (s *Storage) CreateTask(task *models.Task) error {
	if task.ID == "" {
		task.ID = uuid.New().String()
	}
	now := time.Now()
	task.CreatedAt = now
	task.UpdatedAt = now

	return s.db.Update(func(tx *bolt.Tx) error {
		b := tx.Bucket(bucketTasks)
		data, err := json.Marshal(task)
		if err != nil {
			return err
		}
		return b.Put([]byte(task.ID), data)
	})
}

// UpdateTask 更新任务
func (s *Storage) UpdateTask(task *models.Task) error {
	task.UpdatedAt = time.Now()

	return s.db.Update(func(tx *bolt.Tx) error {
		b := tx.Bucket(bucketTasks)
		if b.Get([]byte(task.ID)) == nil {
			return fmt.Errorf("任务不存在")
		}
		data, err := json.Marshal(task)
		if err != nil {
			return err
		}
		return b.Put([]byte(task.ID), data)
	})
}

// DeleteTask 删除任务
func (s *Storage) DeleteTask(id string) error {
	return s.db.Update(func(tx *bolt.Tx) error {
		b := tx.Bucket(bucketTasks)
		return b.Delete([]byte(id))
	})
}

// GetModifiedSince 获取指定时间后修改的数据
func (s *Storage) GetModifiedSince(since time.Time) (*models.SyncResponse, error) {
	resp := &models.SyncResponse{
		SyncTime: time.Now(),
	}

	err := s.db.View(func(tx *bolt.Tx) error {
		// 获取修改的日程
		sb := tx.Bucket(bucketSchedules)
		sb.ForEach(func(k, v []byte) error {
			var schedule models.Schedule
			if err := json.Unmarshal(v, &schedule); err == nil {
				if schedule.UpdatedAt.After(since) {
					resp.Schedules = append(resp.Schedules, schedule)
				}
			}
			return nil
		})

		// 获取修改的任务
		tb := tx.Bucket(bucketTasks)
		tb.ForEach(func(k, v []byte) error {
			var task models.Task
			if err := json.Unmarshal(v, &task); err == nil {
				if task.UpdatedAt.After(since) {
					resp.Tasks = append(resp.Tasks, task)
				}
			}
			return nil
		})

		return nil
	})

	return resp, err
}
