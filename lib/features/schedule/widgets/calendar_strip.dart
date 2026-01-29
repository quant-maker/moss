import 'package:flutter/material.dart';

class CalendarStrip extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const CalendarStrip({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<CalendarStrip> createState() => _CalendarStripState();
}

class _CalendarStripState extends State<CalendarStrip> {
  late ScrollController _scrollController;
  late DateTime _startDate;
  
  static const int _daysToShow = 365;
  static const int _initialOffset = 182; // 显示前半年到后半年

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now().subtract(Duration(days: _initialOffset));
    _scrollController = ScrollController();
    
    // 滚动到选中日期
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToDate(widget.selectedDate, animate: false);
    });
  }

  @override
  void didUpdateWidget(CalendarStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _scrollToDate(widget.selectedDate);
    }
  }

  void _scrollToDate(DateTime date, {bool animate = true}) {
    final daysDiff = date.difference(_startDate).inDays;
    final offset = daysDiff * 56.0; // 每个日期项宽度
    
    if (animate) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _scrollController.jumpTo(offset);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _daysToShow,
        itemBuilder: (context, index) {
          final date = _startDate.add(Duration(days: index));
          final isSelected = _isSameDay(date, widget.selectedDate);
          final isToday = _isSameDay(date, today);
          
          return _buildDateItem(
            theme: theme,
            date: date,
            isSelected: isSelected,
            isToday: isToday,
          );
        },
      ),
    );
  }

  Widget _buildDateItem({
    required ThemeData theme,
    required DateTime date,
    required bool isSelected,
    required bool isToday,
  }) {
    final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final weekday = weekdays[date.weekday - 1];
    final isWeekend = date.weekday >= 6;

    return GestureDetector(
      onTap: () => widget.onDateSelected(date),
      child: Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 星期
            Text(
              weekday,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isWeekend
                    ? theme.colorScheme.error.withOpacity(0.7)
                    : theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            
            const SizedBox(height: 4),
            
            // 日期
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? theme.colorScheme.primary
                    : isToday
                        ? theme.colorScheme.primaryContainer
                        : null,
              ),
              alignment: Alignment.center,
              child: Text(
                date.day.toString(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: isSelected || isToday ? FontWeight.bold : null,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : isToday
                          ? theme.colorScheme.primary
                          : isWeekend
                              ? theme.colorScheme.error
                              : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
