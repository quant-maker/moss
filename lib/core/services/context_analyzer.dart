import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 识别到的实体类型
enum EntityType {
  /// 日期时间
  dateTime,
  /// 任务意图
  taskIntent,
  /// 日程意图
  scheduleIntent,
  /// 提醒意图
  reminderIntent,
  /// 地点
  location,
  /// 联系人
  person,
  /// 时间段
  duration,
}

/// 识别到的实体
class RecognizedEntity {
  final EntityType type;
  final String text;
  final String? normalizedValue;
  final int startIndex;
  final int endIndex;
  final double confidence;
  
  RecognizedEntity({
    required this.type,
    required this.text,
    this.normalizedValue,
    required this.startIndex,
    required this.endIndex,
    this.confidence = 1.0,
  });
  
  @override
  String toString() {
    return 'RecognizedEntity(type: $type, text: $text, normalizedValue: $normalizedValue)';
  }
}

/// 上下文分析结果
class ContextAnalysisResult {
  final String originalText;
  final List<RecognizedEntity> entities;
  final bool hasTaskIntent;
  final bool hasScheduleIntent;
  final bool hasReminderIntent;
  final DateTime? recognizedDateTime;
  final String? recognizedLocation;
  final Duration? recognizedDuration;
  
  ContextAnalysisResult({
    required this.originalText,
    required this.entities,
    this.hasTaskIntent = false,
    this.hasScheduleIntent = false,
    this.hasReminderIntent = false,
    this.recognizedDateTime,
    this.recognizedLocation,
    this.recognizedDuration,
  });
  
  /// 是否有任何可操作的意图
  bool get hasActionableIntent => hasTaskIntent || hasScheduleIntent || hasReminderIntent;
  
  /// 是否识别到日期时间
  bool get hasDateTime => recognizedDateTime != null;
  
  /// 是否识别到地点
  bool get hasLocation => recognizedLocation != null;
  
  /// 获取所有日期时间实体
  List<RecognizedEntity> get dateTimeEntities => 
      entities.where((e) => e.type == EntityType.dateTime).toList();
  
  /// 获取所有地点实体
  List<RecognizedEntity> get locationEntities =>
      entities.where((e) => e.type == EntityType.location).toList();
  
  /// 生成建议文本
  String? get suggestionText {
    if (!hasActionableIntent) return null;
    
    final buffer = StringBuffer();
    
    if (hasScheduleIntent && hasDateTime) {
      buffer.write('检测到日程相关内容');
      if (recognizedDateTime != null) {
        buffer.write('，时间: ${_formatDateTime(recognizedDateTime!)}');
      }
      if (recognizedLocation != null) {
        buffer.write('，地点: $recognizedLocation');
      }
      buffer.write('。要帮你创建日程吗？');
    } else if (hasTaskIntent) {
      buffer.write('检测到任务相关内容');
      if (recognizedDateTime != null) {
        buffer.write('，截止时间: ${_formatDateTime(recognizedDateTime!)}');
      }
      buffer.write('。要帮你创建任务吗？');
    } else if (hasReminderIntent && hasDateTime) {
      buffer.write('要在 ${_formatDateTime(recognizedDateTime!)} 提醒你吗？');
    }
    
    return buffer.isEmpty ? null : buffer.toString();
  }
  
  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(dt.year, dt.month, dt.day);
    
    String dayStr;
    if (targetDay == today) {
      dayStr = '今天';
    } else if (targetDay == today.add(const Duration(days: 1))) {
      dayStr = '明天';
    } else if (targetDay == today.add(const Duration(days: 2))) {
      dayStr = '后天';
    } else {
      dayStr = '${dt.month}月${dt.day}日';
    }
    
    return '$dayStr ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// 上下文分析器
class ContextAnalyzer {
  // 任务意图关键词
  static final _taskIntentPatterns = [
    RegExp(r'(提醒我|记得|需要|要|得|待办|todo|任务|记住)'),
    RegExp(r'(买|购买|采购|准备|完成|做|写|发送|回复|联系|打电话)'),
  ];
  
  // 日程意图关键词
  static final _scheduleIntentPatterns = [
    RegExp(r'(约|预约|安排|日程|会议|见面|聚会|开会|约会|面试)'),
    RegExp(r'(参加|出席|赴约|拜访|去|到|抵达)'),
  ];
  
  // 提醒意图关键词
  static final _reminderIntentPatterns = [
    RegExp(r'(提醒|提示|通知|叫我|喊我|闹钟)'),
  ];
  
  // 日期时间模式
  static final _dateTimePatterns = [
    // 相对日期
    (pattern: RegExp(r'今天'), resolver: _resolveToday),
    (pattern: RegExp(r'明天'), resolver: _resolveTomorrow),
    (pattern: RegExp(r'后天'), resolver: _resolveDayAfterTomorrow),
    (pattern: RegExp(r'大后天'), resolver: _resolveDayAfterDayAfterTomorrow),
    (pattern: RegExp(r'昨天'), resolver: _resolveYesterday),
    (pattern: RegExp(r'下周([一二三四五六日天])'), resolver: _resolveNextWeekday),
    (pattern: RegExp(r'周([一二三四五六日天])'), resolver: _resolveThisWeekday),
    (pattern: RegExp(r'这周([一二三四五六日天])'), resolver: _resolveThisWeekday),
    (pattern: RegExp(r'下个月'), resolver: _resolveNextMonth),
    // 绝对日期
    (pattern: RegExp(r'(\d{1,2})月(\d{1,2})[日号]'), resolver: _resolveMonthDay),
    // 时间
    (pattern: RegExp(r'(\d{1,2})[点时](\d{1,2})?分?'), resolver: _resolveTime),
    (pattern: RegExp(r'(\d{1,2}):(\d{2})'), resolver: _resolveTimeColon),
    (pattern: RegExp(r'(上午|早上|早晨|凌晨)(\d{1,2})[点时]'), resolver: _resolveAmTime),
    (pattern: RegExp(r'(下午|傍晚|晚上|夜里)(\d{1,2})[点时]'), resolver: _resolvePmTime),
    (pattern: RegExp(r'中午'), resolver: _resolveNoon),
    (pattern: RegExp(r'(半小时|一小时|两小时|\d+小时)[后之]?'), resolver: _resolveHoursLater),
    (pattern: RegExp(r'(\d+)分钟[后之]?'), resolver: _resolveMinutesLater),
  ];
  
  // 地点模式
  static final _locationPatterns = [
    RegExp(r'在(.{2,15}?)(见|开会|聚|碰面|集合|等)'),
    RegExp(r'去(.{2,15}?)($|[，,。.！!？?])'),
    RegExp(r'到(.{2,15}?)($|[，,。.！!？?])'),
    RegExp(r'(在|于)(.{2,15}?)($|[，,。.！!？?])'),
    RegExp(r'地[点址][：:是](.{2,30})'),
  ];
  
  // 时间段模式
  static final _durationPatterns = [
    RegExp(r'(\d+)小时'),
    RegExp(r'(\d+)分钟'),
    RegExp(r'半小时'),
    RegExp(r'一个小时'),
    RegExp(r'两个小时'),
  ];
  
  /// 分析文本内容
  ContextAnalysisResult analyze(String text) {
    final entities = <RecognizedEntity>[];
    DateTime? recognizedDateTime;
    String? recognizedLocation;
    Duration? recognizedDuration;
    
    try {
      // 识别日期时间
      final dateTimeResult = _extractDateTime(text);
      if (dateTimeResult != null) {
        entities.add(RecognizedEntity(
          type: EntityType.dateTime,
          text: dateTimeResult.$2,
          normalizedValue: dateTimeResult.$1.toIso8601String(),
          startIndex: 0,
          endIndex: dateTimeResult.$2.length,
        ));
        recognizedDateTime = dateTimeResult.$1;
      }
      
      // 识别地点
      recognizedLocation = _extractLocation(text);
      if (recognizedLocation != null) {
        entities.add(RecognizedEntity(
          type: EntityType.location,
          text: recognizedLocation,
          startIndex: 0,
          endIndex: recognizedLocation.length,
        ));
      }
      
      // 识别时间段
      recognizedDuration = _extractDuration(text);
      if (recognizedDuration != null) {
        entities.add(RecognizedEntity(
          type: EntityType.duration,
          text: '${recognizedDuration.inMinutes}分钟',
          normalizedValue: recognizedDuration.inMinutes.toString(),
          startIndex: 0,
          endIndex: 0,
        ));
      }
      
      // 识别意图
      final hasTaskIntent = _hasIntent(text, _taskIntentPatterns);
      final hasScheduleIntent = _hasIntent(text, _scheduleIntentPatterns);
      final hasReminderIntent = _hasIntent(text, _reminderIntentPatterns);
      
      if (hasTaskIntent) {
        entities.add(RecognizedEntity(
          type: EntityType.taskIntent,
          text: text,
          startIndex: 0,
          endIndex: text.length,
        ));
      }
      
      if (hasScheduleIntent) {
        entities.add(RecognizedEntity(
          type: EntityType.scheduleIntent,
          text: text,
          startIndex: 0,
          endIndex: text.length,
        ));
      }
      
      if (hasReminderIntent) {
        entities.add(RecognizedEntity(
          type: EntityType.reminderIntent,
          text: text,
          startIndex: 0,
          endIndex: text.length,
        ));
      }
      
      return ContextAnalysisResult(
        originalText: text,
        entities: entities,
        hasTaskIntent: hasTaskIntent,
        hasScheduleIntent: hasScheduleIntent,
        hasReminderIntent: hasReminderIntent,
        recognizedDateTime: recognizedDateTime,
        recognizedLocation: recognizedLocation,
        recognizedDuration: recognizedDuration,
      );
    } catch (e) {
      debugPrint('ContextAnalyzer: 分析失败 - $e');
      return ContextAnalysisResult(
        originalText: text,
        entities: [],
      );
    }
  }
  
  /// 检查是否匹配意图模式
  bool _hasIntent(String text, List<RegExp> patterns) {
    for (final pattern in patterns) {
      if (pattern.hasMatch(text)) {
        return true;
      }
    }
    return false;
  }
  
  /// 提取日期时间
  (DateTime, String)? _extractDateTime(String text) {
    DateTime? date;
    DateTime? time;
    String matchedText = '';
    
    for (final item in _dateTimePatterns) {
      final match = item.pattern.firstMatch(text);
      if (match != null) {
        final result = item.resolver(match);
        if (result != null) {
          // 区分日期和时间
          if (_isDatePattern(item.pattern)) {
            date = result;
          } else {
            time = result;
          }
          matchedText += match.group(0) ?? '';
        }
      }
    }
    
    if (date == null && time == null) return null;
    
    // 组合日期和时间
    final now = DateTime.now();
    if (date != null && time != null) {
      return (DateTime(date.year, date.month, date.day, time.hour, time.minute), matchedText);
    } else if (date != null) {
      return (date, matchedText);
    } else if (time != null) {
      // 只有时间，假设是今天
      return (DateTime(now.year, now.month, now.day, time.hour, time.minute), matchedText);
    }
    
    return null;
  }
  
  /// 判断是否是日期模式（而非时间模式）
  bool _isDatePattern(RegExp pattern) {
    final patternStr = pattern.pattern;
    return patternStr.contains('今天') ||
           patternStr.contains('明天') ||
           patternStr.contains('后天') ||
           patternStr.contains('大后天') ||
           patternStr.contains('昨天') ||
           patternStr.contains('周') ||
           patternStr.contains('月');
  }
  
  /// 提取地点
  String? _extractLocation(String text) {
    for (final pattern in _locationPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        // 获取捕获组
        if (match.groupCount >= 1) {
          final location = match.group(match.groupCount == 1 ? 1 : 2);
          if (location != null && location.isNotEmpty) {
            // 过滤常见的非地点词
            if (!_isCommonWord(location)) {
              return location.trim();
            }
          }
        }
      }
    }
    return null;
  }
  
  /// 过滤常见的非地点词
  bool _isCommonWord(String text) {
    final commonWords = ['那里', '这里', '哪里', '什么', '怎么', '为什么', '你', '我', '他', '她'];
    return commonWords.contains(text.trim());
  }
  
  /// 提取时间段
  Duration? _extractDuration(String text) {
    for (final pattern in _durationPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final patternStr = pattern.pattern;
        
        if (patternStr.contains('小时')) {
          if (patternStr.contains('半')) {
            return const Duration(minutes: 30);
          } else if (patternStr.contains('一个')) {
            return const Duration(hours: 1);
          } else if (patternStr.contains('两个')) {
            return const Duration(hours: 2);
          } else if (match.groupCount >= 1) {
            final hours = int.tryParse(match.group(1) ?? '');
            if (hours != null) {
              return Duration(hours: hours);
            }
          }
        } else if (patternStr.contains('分钟') && match.groupCount >= 1) {
          final minutes = int.tryParse(match.group(1) ?? '');
          if (minutes != null) {
            return Duration(minutes: minutes);
          }
        }
      }
    }
    return null;
  }
  
  // 日期解析函数
  static DateTime? _resolveToday(RegExpMatch match) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
  
  static DateTime? _resolveTomorrow(RegExpMatch match) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  }
  
  static DateTime? _resolveDayAfterTomorrow(RegExpMatch match) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(const Duration(days: 2));
  }
  
  static DateTime? _resolveDayAfterDayAfterTomorrow(RegExpMatch match) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(const Duration(days: 3));
  }
  
  static DateTime? _resolveYesterday(RegExpMatch match) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
  }
  
  static DateTime? _resolveNextWeekday(RegExpMatch match) {
    final dayStr = match.group(1);
    if (dayStr == null) return null;
    
    final targetDay = _weekdayFromChinese(dayStr);
    if (targetDay == null) return null;
    
    final now = DateTime.now();
    final currentWeekday = now.weekday;
    var daysToAdd = targetDay - currentWeekday;
    if (daysToAdd <= 0) daysToAdd += 7;
    daysToAdd += 7; // 下周
    
    return DateTime(now.year, now.month, now.day).add(Duration(days: daysToAdd));
  }
  
  static DateTime? _resolveThisWeekday(RegExpMatch match) {
    final dayStr = match.group(1);
    if (dayStr == null) return null;
    
    final targetDay = _weekdayFromChinese(dayStr);
    if (targetDay == null) return null;
    
    final now = DateTime.now();
    final currentWeekday = now.weekday;
    var daysToAdd = targetDay - currentWeekday;
    if (daysToAdd < 0) daysToAdd += 7;
    
    return DateTime(now.year, now.month, now.day).add(Duration(days: daysToAdd));
  }
  
  static DateTime? _resolveNextMonth(RegExpMatch match) {
    final now = DateTime.now();
    if (now.month == 12) {
      return DateTime(now.year + 1, 1, 1);
    }
    return DateTime(now.year, now.month + 1, 1);
  }
  
  static DateTime? _resolveMonthDay(RegExpMatch match) {
    final monthStr = match.group(1);
    final dayStr = match.group(2);
    if (monthStr == null || dayStr == null) return null;
    
    final month = int.tryParse(monthStr);
    final day = int.tryParse(dayStr);
    if (month == null || day == null) return null;
    
    final now = DateTime.now();
    var year = now.year;
    
    // 如果月份已过，假设是明年
    if (month < now.month || (month == now.month && day < now.day)) {
      year++;
    }
    
    return DateTime(year, month, day);
  }
  
  static DateTime? _resolveTime(RegExpMatch match) {
    final hourStr = match.group(1);
    final minuteStr = match.group(2);
    if (hourStr == null) return null;
    
    final hour = int.tryParse(hourStr);
    final minute = int.tryParse(minuteStr ?? '0') ?? 0;
    if (hour == null || hour > 23 || minute > 59) return null;
    
    return DateTime(2000, 1, 1, hour, minute);
  }
  
  static DateTime? _resolveTimeColon(RegExpMatch match) {
    final hourStr = match.group(1);
    final minuteStr = match.group(2);
    if (hourStr == null || minuteStr == null) return null;
    
    final hour = int.tryParse(hourStr);
    final minute = int.tryParse(minuteStr);
    if (hour == null || minute == null || hour > 23 || minute > 59) return null;
    
    return DateTime(2000, 1, 1, hour, minute);
  }
  
  static DateTime? _resolveAmTime(RegExpMatch match) {
    final hourStr = match.group(2);
    if (hourStr == null) return null;
    
    var hour = int.tryParse(hourStr);
    if (hour == null || hour > 12) return null;
    
    if (hour == 12) hour = 0;
    
    return DateTime(2000, 1, 1, hour, 0);
  }
  
  static DateTime? _resolvePmTime(RegExpMatch match) {
    final hourStr = match.group(2);
    if (hourStr == null) return null;
    
    var hour = int.tryParse(hourStr);
    if (hour == null || hour > 12) return null;
    
    if (hour != 12) hour += 12;
    
    return DateTime(2000, 1, 1, hour, 0);
  }
  
  static DateTime? _resolveNoon(RegExpMatch match) {
    return DateTime(2000, 1, 1, 12, 0);
  }
  
  static DateTime? _resolveHoursLater(RegExpMatch match) {
    final text = match.group(0) ?? '';
    int hours;
    
    if (text.contains('半小时')) {
      hours = 0;
      final now = DateTime.now();
      return now.add(const Duration(minutes: 30));
    } else if (text.contains('一小时')) {
      hours = 1;
    } else if (text.contains('两小时')) {
      hours = 2;
    } else {
      final match2 = RegExp(r'(\d+)小时').firstMatch(text);
      if (match2 != null) {
        hours = int.tryParse(match2.group(1) ?? '') ?? 1;
      } else {
        hours = 1;
      }
    }
    
    return DateTime.now().add(Duration(hours: hours));
  }
  
  static DateTime? _resolveMinutesLater(RegExpMatch match) {
    final minuteStr = match.group(1);
    if (minuteStr == null) return null;
    
    final minutes = int.tryParse(minuteStr);
    if (minutes == null) return null;
    
    return DateTime.now().add(Duration(minutes: minutes));
  }
  
  static int? _weekdayFromChinese(String day) {
    switch (day) {
      case '一':
        return DateTime.monday;
      case '二':
        return DateTime.tuesday;
      case '三':
        return DateTime.wednesday;
      case '四':
        return DateTime.thursday;
      case '五':
        return DateTime.friday;
      case '六':
        return DateTime.saturday;
      case '日':
      case '天':
        return DateTime.sunday;
      default:
        return null;
    }
  }
}

/// 上下文分析器 Provider
final contextAnalyzerProvider = Provider<ContextAnalyzer>((ref) {
  return ContextAnalyzer();
});
