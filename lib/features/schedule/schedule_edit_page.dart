import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/schedule.dart';
import '../../core/services/schedule_service.dart';

class ScheduleEditPage extends ConsumerStatefulWidget {
  final Schedule? schedule;
  final DateTime? initialDate;

  const ScheduleEditPage({
    super.key,
    this.schedule,
    this.initialDate,
  });

  @override
  ConsumerState<ScheduleEditPage> createState() => _ScheduleEditPageState();
}

class _ScheduleEditPageState extends ConsumerState<ScheduleEditPage> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  
  late DateTime _startDate;
  late TimeOfDay _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _isAllDay = false;
  RepeatType _repeatType = RepeatType.none;
  ReminderTime _reminderTime = ReminderTime.none;
  
  // 冲突检测
  List<Schedule> _conflicts = [];
  bool _ignoreConflicts = false;

  bool get isEditing => widget.schedule != null;

  @override
  void initState() {
    super.initState();
    
    if (widget.schedule != null) {
      final s = widget.schedule!;
      _titleController = TextEditingController(text: s.title);
      _descriptionController = TextEditingController(text: s.description ?? '');
      _locationController = TextEditingController(text: s.location ?? '');
      _startDate = s.startTime;
      _startTime = TimeOfDay.fromDateTime(s.startTime);
      _endDate = s.endTime;
      _endTime = s.endTime != null ? TimeOfDay.fromDateTime(s.endTime!) : null;
      _isAllDay = s.isAllDay;
      _repeatType = s.repeatType;
      _reminderTime = s.reminderTime;
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _locationController = TextEditingController();
      _startDate = widget.initialDate ?? DateTime.now();
      _startTime = TimeOfDay.now();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑日程' : '新建日程'),
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
                labelText: '标题',
                hintText: '请输入日程标题',
                border: OutlineInputBorder(),
              ),
              autofocus: !isEditing,
            ),
            
            const SizedBox(height: 16),
            
            // 全天开关
            SwitchListTile(
              title: const Text('全天'),
              value: _isAllDay,
              onChanged: (value) {
                setState(() => _isAllDay = value);
                _checkConflicts();
              },
              contentPadding: EdgeInsets.zero,
            ),
            
            const Divider(),
            
            // 开始时间
            _buildDateTimeTile(
              theme,
              title: '开始',
              date: _startDate,
              time: _isAllDay ? null : _startTime,
              onDateTap: () => _selectDate(isStart: true),
              onTimeTap: _isAllDay ? null : () => _selectTime(isStart: true),
            ),
            
            // 结束时间
            _buildDateTimeTile(
              theme,
              title: '结束',
              date: _endDate,
              time: _isAllDay ? null : _endTime,
              onDateTap: () => _selectDate(isStart: false),
              onTimeTap: _isAllDay ? null : () => _selectTime(isStart: false),
              placeholder: '选择结束时间',
            ),
            
            // 冲突警告
            if (_conflicts.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildConflictWarning(theme),
            ],
            
            const Divider(),
            
            // 重复
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.repeat),
              title: const Text('重复'),
              trailing: DropdownButton<RepeatType>(
                value: _repeatType,
                underline: const SizedBox(),
                items: RepeatType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(_getRepeatTypeText(type)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _repeatType = value);
                },
              ),
            ),
            
            // 提醒
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('提醒'),
              trailing: DropdownButton<ReminderTime>(
                value: _reminderTime,
                underline: const SizedBox(),
                items: ReminderTime.values.map((time) {
                  return DropdownMenuItem(
                    value: time,
                    child: Text(_getReminderTimeText(time)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _reminderTime = value);
                },
              ),
            ),
            
            const Divider(),
            
            // 地点
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: '地点',
                hintText: '添加地点',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 描述
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '备注',
                hintText: '添加备注',
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            
            if (isEditing) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除日程'),
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

  Widget _buildDateTimeTile(
    ThemeData theme, {
    required String title,
    DateTime? date,
    TimeOfDay? time,
    VoidCallback? onDateTap,
    VoidCallback? onTimeTap,
    String? placeholder,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: onDateTap,
            child: Text(
              date != null
                  ? '${date.month}月${date.day}日'
                  : placeholder ?? '选择日期',
            ),
          ),
          if (!_isAllDay)
            TextButton(
              onPressed: onTimeTap,
              child: Text(
                time != null
                    ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                    : '选择时间',
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _selectDate({required bool isStart}) async {
    final initialDate = isStart ? _startDate : (_endDate ?? _startDate);
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    
    if (date != null) {
      setState(() {
        if (isStart) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      });
      _checkConflicts();
    }
  }

  Future<void> _selectTime({required bool isStart}) async {
    final initialTime = isStart 
        ? _startTime 
        : (_endTime ?? TimeOfDay.fromDateTime(
            DateTime.now().add(const Duration(hours: 1)),
          ));
    
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    
    if (time != null) {
      setState(() {
        if (isStart) {
          _startTime = time;
        } else {
          _endTime = time;
        }
      });
      _checkConflicts();
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入日程标题')),
      );
      return;
    }

    final startTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _isAllDay ? 0 : _startTime.hour,
      _isAllDay ? 0 : _startTime.minute,
    );

    DateTime? endTime;
    if (_endDate != null) {
      endTime = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        _isAllDay ? 23 : (_endTime?.hour ?? _startTime.hour),
        _isAllDay ? 59 : (_endTime?.minute ?? _startTime.minute),
      );
    }

    // 检查冲突
    if (!_isAllDay && _conflicts.isNotEmpty && !_ignoreConflicts) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('存在时间冲突，请勾选"忽略冲突"后再保存'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final notifier = ref.read(scheduleListProvider.notifier);

    if (isEditing) {
      final updated = widget.schedule!.copyWith(
        title: title,
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        startTime: startTime,
        endTime: endTime,
        isAllDay: _isAllDay,
        location: _locationController.text.trim().isEmpty 
            ? null 
            : _locationController.text.trim(),
        repeatType: _repeatType,
        reminderTime: _reminderTime,
      );
      await notifier.updateSchedule(updated);
    } else {
      await notifier.createSchedule(
        title: title,
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        startTime: startTime,
        endTime: endTime,
        isAllDay: _isAllDay,
        location: _locationController.text.trim().isEmpty 
            ? null 
            : _locationController.text.trim(),
        repeatType: _repeatType,
        reminderTime: _reminderTime,
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
        content: const Text('确定要删除这个日程吗？'),
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
      await ref.read(scheduleListProvider.notifier).deleteSchedule(widget.schedule!.id);
      Navigator.pop(context);
    }
  }

  String _getRepeatTypeText(RepeatType type) {
    switch (type) {
      case RepeatType.none:
        return '不重复';
      case RepeatType.daily:
        return '每天';
      case RepeatType.weekly:
        return '每周';
      case RepeatType.monthly:
        return '每月';
      case RepeatType.yearly:
        return '每年';
    }
  }

  String _getReminderTimeText(ReminderTime time) {
    switch (time) {
      case ReminderTime.none:
        return '不提醒';
      case ReminderTime.atTime:
        return '准时';
      case ReminderTime.minutes5:
        return '5分钟前';
      case ReminderTime.minutes15:
        return '15分钟前';
      case ReminderTime.minutes30:
        return '30分钟前';
      case ReminderTime.hour1:
        return '1小时前';
      case ReminderTime.day1:
        return '1天前';
    }
  }

  /// 检测日程冲突
  void _checkConflicts() {
    if (_isAllDay) {
      setState(() => _conflicts = []);
      return;
    }

    final startTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    DateTime endTime;
    if (_endDate != null && _endTime != null) {
      endTime = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        _endTime!.hour,
        _endTime!.minute,
      );
    } else {
      endTime = startTime.add(const Duration(hours: 1));
    }

    final service = ref.read(scheduleServiceProvider);
    final conflicts = service.checkConflicts(
      startTime: startTime,
      endTime: endTime,
      excludeId: widget.schedule?.id,
    );

    setState(() {
      _conflicts = conflicts;
      _ignoreConflicts = false;
    });
  }

  /// 构建冲突警告卡片
  Widget _buildConflictWarning(ThemeData theme) {
    if (_conflicts.isEmpty) return const SizedBox.shrink();

    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colorScheme.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '检测到时间冲突',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '以下日程与当前时间段存在冲突：',
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            ...(_conflicts.take(3).map((s) => Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.event,
                    size: 14,
                    color: theme.colorScheme.onErrorContainer.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${_formatTime(s.startTime)} - ${s.title}',
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ))),
            if (_conflicts.length > 3)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text(
                  '还有 ${_conflicts.length - 3} 个冲突...',
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _ignoreConflicts,
                  onChanged: (value) {
                    setState(() => _ignoreConflicts = value ?? false);
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                Text(
                  '忽略冲突并继续保存',
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
