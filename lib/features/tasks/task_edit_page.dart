import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/task.dart';
import '../../core/services/task_service.dart';

class TaskEditPage extends ConsumerStatefulWidget {
  final Task? task;

  const TaskEditPage({super.key, this.task});

  @override
  ConsumerState<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends ConsumerState<TaskEditPage> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _categoryController;
  
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _dueDate;

  bool get isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    
    if (widget.task != null) {
      final t = widget.task!;
      _titleController = TextEditingController(text: t.title);
      _descriptionController = TextEditingController(text: t.description ?? '');
      _categoryController = TextEditingController(text: t.category ?? '');
      _priority = t.priority;
      _dueDate = t.dueDate;
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _categoryController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑任务' : '新建任务'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '任务标题',
                hintText: '请输入任务标题',
                border: OutlineInputBorder(),
              ),
              autofocus: !isEditing,
            ),
            
            const SizedBox(height: 16),
            
            // 优先级
            Text(
              '优先级',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<TaskPriority>(
              segments: [
                ButtonSegment(
                  value: TaskPriority.low,
                  label: const Text('低'),
                  icon: Icon(Icons.arrow_downward, 
                    color: Colors.grey.shade600),
                ),
                ButtonSegment(
                  value: TaskPriority.medium,
                  label: const Text('中'),
                  icon: Icon(Icons.remove, 
                    color: Colors.blue.shade600),
                ),
                ButtonSegment(
                  value: TaskPriority.high,
                  label: const Text('高'),
                  icon: Icon(Icons.arrow_upward, 
                    color: Colors.orange.shade600),
                ),
                ButtonSegment(
                  value: TaskPriority.urgent,
                  label: const Text('紧急'),
                  icon: Icon(Icons.priority_high, 
                    color: Colors.red.shade600),
                ),
              ],
              selected: {_priority},
              onSelectionChanged: (Set<TaskPriority> selection) {
                setState(() {
                  _priority = selection.first;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // 截止日期
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('截止日期'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: _selectDueDate,
                    child: Text(
                      _dueDate != null
                          ? '${_dueDate!.month}月${_dueDate!.day}日'
                          : '选择日期',
                    ),
                  ),
                  if (_dueDate != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => setState(() => _dueDate = null),
                    ),
                ],
              ),
            ),
            
            const Divider(),
            
            // 分类
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: '分类',
                hintText: '如: 工作、学习、生活',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 描述
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '描述',
                hintText: '添加任务描述',
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            
            if (isEditing) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除任务'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    
    if (date != null) {
      setState(() => _dueDate = date);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入任务标题')),
      );
      return;
    }

    final notifier = ref.read(taskListProvider.notifier);

    if (isEditing) {
      final updated = widget.task!.copyWith(
        title: title,
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        priority: _priority,
        category: _categoryController.text.trim().isEmpty 
            ? null 
            : _categoryController.text.trim(),
        dueDate: _dueDate,
      );
      await notifier.updateTask(updated);
    } else {
      await notifier.createTask(
        title: title,
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        priority: _priority,
        category: _categoryController.text.trim().isEmpty 
            ? null 
            : _categoryController.text.trim(),
        dueDate: _dueDate,
      );
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个任务吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(taskListProvider.notifier).deleteTask(widget.task!.id);
      Navigator.pop(context);
    }
  }
}
