import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/schedule.dart';
import '../../core/services/schedule_service.dart';
import 'widgets/schedule_card.dart';
import 'widgets/calendar_strip.dart';
import 'schedule_edit_page.dart';

class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(scheduleListProvider);
    final notifier = ref.read(scheduleListProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('日程管理'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: '今天',
            onPressed: () => notifier.selectDate(DateTime.now()),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () => notifier.refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 日历条
          CalendarStrip(
            selectedDate: state.selectedDate,
            onDateSelected: (date) => notifier.selectDate(date),
          ),
          
          // 当前日期显示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.centerLeft,
            child: Text(
              DateFormat('yyyy年M月d日 EEEE', 'zh_CN').format(state.selectedDate),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          const Divider(height: 1),
          
          // 日程列表
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.schedules.isEmpty
                    ? _buildEmptyState(theme)
                    : _buildScheduleList(state.schedules, notifier),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddScheduleDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available,
            size: 80,
            color: theme.colorScheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '今日没有日程',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角按钮添加新日程',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList(List<Schedule> schedules, ScheduleListNotifier notifier) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: schedules.length,
      itemBuilder: (context, index) {
        final schedule = schedules[index];
        return ScheduleCard(
          schedule: schedule,
          onTap: () => _showEditScheduleDialog(context, schedule),
          onToggleComplete: () => notifier.toggleComplete(schedule.id),
          onDelete: () => _confirmDelete(context, schedule, notifier),
        );
      },
    );
  }

  void _showAddScheduleDialog(BuildContext context) {
    final selectedDate = ref.read(scheduleListProvider).selectedDate;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScheduleEditPage(
          initialDate: selectedDate,
        ),
      ),
    );
  }

  void _showEditScheduleDialog(BuildContext context, Schedule schedule) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScheduleEditPage(
          schedule: schedule,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Schedule schedule, ScheduleListNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除日程"${schedule.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              notifier.deleteSchedule(schedule.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
