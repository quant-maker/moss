import 'package:flutter_test/flutter_test.dart';
import 'package:moss/core/models/task.dart';

void main() {
  group('Task Model', () {
    group('Creation', () {
      test('should create task with required fields', () {
        final task = Task(
          id: 'task-1',
          title: 'Buy groceries',
        );

        expect(task.id, 'task-1');
        expect(task.title, 'Buy groceries');
        expect(task.priority, TaskPriority.medium);
        expect(task.status, TaskStatus.pending);
        expect(task.isCompleted, false);
      });

      test('should create task with all fields', () {
        final dueDate = DateTime(2026, 1, 20);
        final task = Task(
          id: 'task-2',
          title: 'Complete project',
          description: 'Finish the Flutter project',
          priorityIndex: TaskPriority.high.index,
          statusIndex: TaskStatus.inProgress.index,
          category: 'Work',
          dueDate: dueDate,
          tags: ['flutter', 'mobile'],
        );

        expect(task.description, 'Finish the Flutter project');
        expect(task.priority, TaskPriority.high);
        expect(task.status, TaskStatus.inProgress);
        expect(task.category, 'Work');
        expect(task.dueDate, dueDate);
        expect(task.tags, contains('flutter'));
      });
    });

    group('Priority', () {
      test('should get and set priority', () {
        final task = Task(id: 'test', title: 'Test');

        expect(task.priority, TaskPriority.medium);

        task.priority = TaskPriority.urgent;
        expect(task.priority, TaskPriority.urgent);
        expect(task.priorityIndex, 3);
      });

      test('should return correct priority text', () {
        final testCases = {
          TaskPriority.low: '低',
          TaskPriority.medium: '中',
          TaskPriority.high: '高',
          TaskPriority.urgent: '紧急',
        };

        for (final entry in testCases.entries) {
          final task = Task(
            id: 'test',
            title: 'Test',
            priorityIndex: entry.key.index,
          );
          expect(task.priorityText, entry.value);
        }
      });
    });

    group('Status', () {
      test('should get and set status', () {
        final task = Task(id: 'test', title: 'Test');

        expect(task.status, TaskStatus.pending);

        task.status = TaskStatus.completed;
        expect(task.status, TaskStatus.completed);
        expect(task.statusIndex, 2);
      });

      test('should return correct status text', () {
        final testCases = {
          TaskStatus.pending: '待处理',
          TaskStatus.inProgress: '进行中',
          TaskStatus.completed: '已完成',
          TaskStatus.cancelled: '已取消',
        };

        for (final entry in testCases.entries) {
          final task = Task(
            id: 'test',
            title: 'Test',
            statusIndex: entry.key.index,
          );
          expect(task.statusText, entry.value);
        }
      });

      test('should detect completed status', () {
        final pending = Task(
          id: 'pending',
          title: 'Pending',
          statusIndex: TaskStatus.pending.index,
        );
        final completed = Task(
          id: 'completed',
          title: 'Completed',
          statusIndex: TaskStatus.completed.index,
        );

        expect(pending.isCompleted, false);
        expect(completed.isCompleted, true);
      });
    });

    group('Due Date and Overdue', () {
      test('should detect overdue task', () {
        final overdue = Task(
          id: 'overdue',
          title: 'Overdue Task',
          dueDate: DateTime.now().subtract(const Duration(days: 1)),
          statusIndex: TaskStatus.pending.index,
        );

        expect(overdue.isOverdue, true);
      });

      test('should not be overdue if completed', () {
        final task = Task(
          id: 'completed',
          title: 'Completed Task',
          dueDate: DateTime.now().subtract(const Duration(days: 1)),
          statusIndex: TaskStatus.completed.index,
        );

        expect(task.isOverdue, false);
      });

      test('should not be overdue if no due date', () {
        final task = Task(
          id: 'no-due',
          title: 'No Due Date',
          dueDate: null,
        );

        expect(task.isOverdue, false);
      });

      test('should not be overdue if due date is in future', () {
        final task = Task(
          id: 'future',
          title: 'Future Task',
          dueDate: DateTime.now().add(const Duration(days: 7)),
        );

        expect(task.isOverdue, false);
      });

      test('should format due date correctly', () {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        final todayTask = Task(
          id: 'today',
          title: 'Today',
          dueDate: today,
        );
        expect(todayTask.formattedDueDate, '今天');

        final tomorrowTask = Task(
          id: 'tomorrow',
          title: 'Tomorrow',
          dueDate: today.add(const Duration(days: 1)),
        );
        expect(tomorrowTask.formattedDueDate, '明天');

        final yesterdayTask = Task(
          id: 'yesterday',
          title: 'Yesterday',
          dueDate: today.subtract(const Duration(days: 1)),
        );
        expect(yesterdayTask.formattedDueDate, '昨天');
      });

      test('should return null formatted due date when no due date', () {
        final task = Task(id: 'no-due', title: 'No Due');
        expect(task.formattedDueDate, isNull);
      });
    });

    group('JSON Serialization', () {
      test('should convert to JSON', () {
        final task = Task(
          id: 'json-test',
          title: 'JSON Test',
          description: 'Test description',
          priorityIndex: TaskPriority.high.index,
          category: 'Testing',
          tags: ['test', 'json'],
        );

        final json = task.toJson();

        expect(json['id'], 'json-test');
        expect(json['title'], 'JSON Test');
        expect(json['priority'], 'high');
        expect(json['category'], 'Testing');
        expect(json['tags'], contains('test'));
      });

      test('should create from JSON', () {
        final json = {
          'id': 'from-json',
          'title': 'From JSON',
          'priority': 'urgent',
          'status': 'in_progress',
          'category': 'Work',
        };

        final task = Task.fromJson(json);

        expect(task.id, 'from-json');
        expect(task.title, 'From JSON');
        expect(task.priority, TaskPriority.urgent);
        expect(task.status, TaskStatus.inProgress);
        expect(task.category, 'Work');
      });

      test('should handle camelCase and snake_case keys', () {
        final json1 = {'dueDate': '2026-01-20T10:00:00'};
        final json2 = {'due_date': '2026-01-20T10:00:00'};

        final t1 = Task.fromJson({...json1, 'id': '1', 'title': 'Test'});
        final t2 = Task.fromJson({...json2, 'id': '2', 'title': 'Test'});

        expect(t1.dueDate?.day, 20);
        expect(t2.dueDate?.day, 20);
      });

      test('should parse priority from string or int', () {
        final fromString = Task.fromJson({
          'id': '1',
          'title': 'Test',
          'priority': 'high',
        });
        final fromInt = Task.fromJson({
          'id': '2',
          'title': 'Test',
          'priorityIndex': 2,
        });

        expect(fromString.priority, TaskPriority.high);
        expect(fromInt.priority, TaskPriority.high);
      });
    });

    group('copyWith', () {
      test('should copy with new values', () {
        final original = Task(
          id: 'original',
          title: 'Original Title',
          priorityIndex: TaskPriority.low.index,
          category: 'Personal',
        );

        final copied = original.copyWith(
          title: 'New Title',
          priority: TaskPriority.high,
        );

        expect(original.title, 'Original Title');
        expect(original.priority, TaskPriority.low);
        expect(copied.title, 'New Title');
        expect(copied.priority, TaskPriority.high);
        expect(copied.id, 'original');
        expect(copied.category, 'Personal');
      });

      test('should update status and completedAt', () {
        final task = Task(
          id: 'test',
          title: 'Test',
          statusIndex: TaskStatus.pending.index,
        );

        final completed = task.copyWith(
          status: TaskStatus.completed,
          completedAt: DateTime.now(),
        );

        expect(task.status, TaskStatus.pending);
        expect(task.completedAt, isNull);
        expect(completed.status, TaskStatus.completed);
        expect(completed.completedAt, isNotNull);
      });
    });
  });

  group('TaskPriority Enum', () {
    test('should have correct values', () {
      expect(TaskPriority.low.index, 0);
      expect(TaskPriority.medium.index, 1);
      expect(TaskPriority.high.index, 2);
      expect(TaskPriority.urgent.index, 3);
    });
  });

  group('TaskStatus Enum', () {
    test('should have correct values', () {
      expect(TaskStatus.pending.index, 0);
      expect(TaskStatus.inProgress.index, 1);
      expect(TaskStatus.completed.index, 2);
      expect(TaskStatus.cancelled.index, 3);
    });
  });
}
