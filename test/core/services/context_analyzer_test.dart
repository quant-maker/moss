import 'package:flutter_test/flutter_test.dart';
import 'package:moss/core/services/context_analyzer.dart';

void main() {
  late ContextAnalyzer analyzer;

  setUp(() {
    analyzer = ContextAnalyzer();
  });

  group('ContextAnalyzer', () {
    group('DateTime Recognition', () {
      test('should recognize "今天"', () {
        final result = analyzer.analyze('今天下午开会');

        expect(result.hasDateTime, true);
        expect(result.recognizedDateTime?.day, DateTime.now().day);
      });

      test('should recognize "明天"', () {
        final result = analyzer.analyze('明天去医院');

        expect(result.hasDateTime, true);
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        expect(result.recognizedDateTime?.day, tomorrow.day);
      });

      test('should recognize "后天"', () {
        final result = analyzer.analyze('后天有约会');

        expect(result.hasDateTime, true);
        final dayAfterTomorrow = DateTime.now().add(const Duration(days: 2));
        expect(result.recognizedDateTime?.day, dayAfterTomorrow.day);
      });

      test('should recognize time pattern "3点"', () {
        final result = analyzer.analyze('今天3点开会');

        expect(result.hasDateTime, true);
        expect(result.recognizedDateTime?.hour, 3);
      });

      test('should recognize time pattern "15:30"', () {
        final result = analyzer.analyze('今天15:30开会');

        expect(result.hasDateTime, true);
        expect(result.recognizedDateTime?.hour, 15);
        expect(result.recognizedDateTime?.minute, 30);
      });

      test('should recognize "下午3点"', () {
        final result = analyzer.analyze('下午3点开会');

        expect(result.hasDateTime, true);
        expect(result.recognizedDateTime?.hour, 15);
      });

      test('should recognize "上午10点"', () {
        final result = analyzer.analyze('上午10点面试');

        expect(result.hasDateTime, true);
        expect(result.recognizedDateTime?.hour, 10);
      });

      test('should recognize "中午"', () {
        final result = analyzer.analyze('中午吃饭');

        expect(result.hasDateTime, true);
        expect(result.recognizedDateTime?.hour, 12);
      });

      test('should recognize month and day "3月15日"', () {
        final result = analyzer.analyze('3月15日开会');

        expect(result.hasDateTime, true);
        expect(result.recognizedDateTime?.month, 3);
        expect(result.recognizedDateTime?.day, 15);
      });
    });

    group('Task Intent Recognition', () {
      test('should recognize "提醒我" as task intent', () {
        final result = analyzer.analyze('提醒我明天交报告');

        expect(result.hasTaskIntent, true);
      });

      test('should recognize "记得" as task intent', () {
        final result = analyzer.analyze('记得买牛奶');

        expect(result.hasTaskIntent, true);
      });

      test('should recognize "需要" as task intent', () {
        final result = analyzer.analyze('需要准备材料');

        expect(result.hasTaskIntent, true);
      });

      test('should recognize "待办" as task intent', () {
        final result = analyzer.analyze('待办事项：写代码');

        expect(result.hasTaskIntent, true);
      });

      test('should recognize "买" as task intent', () {
        final result = analyzer.analyze('买一些水果');

        expect(result.hasTaskIntent, true);
      });
    });

    group('Schedule Intent Recognition', () {
      test('should recognize "约" as schedule intent', () {
        final result = analyzer.analyze('约朋友吃饭');

        expect(result.hasScheduleIntent, true);
      });

      test('should recognize "会议" as schedule intent', () {
        final result = analyzer.analyze('下午有个会议');

        expect(result.hasScheduleIntent, true);
      });

      test('should recognize "预约" as schedule intent', () {
        final result = analyzer.analyze('预约医生');

        expect(result.hasScheduleIntent, true);
      });

      test('should recognize "聚会" as schedule intent', () {
        final result = analyzer.analyze('周末聚会');

        expect(result.hasScheduleIntent, true);
      });

      test('should recognize "面试" as schedule intent', () {
        final result = analyzer.analyze('明天有面试');

        expect(result.hasScheduleIntent, true);
      });
    });

    group('Reminder Intent Recognition', () {
      test('should recognize "提醒" as reminder intent', () {
        final result = analyzer.analyze('提醒我喝水');

        expect(result.hasReminderIntent, true);
      });

      test('should recognize "闹钟" as reminder intent', () {
        final result = analyzer.analyze('设个闹钟');

        expect(result.hasReminderIntent, true);
      });

      test('should recognize "叫我" as reminder intent', () {
        final result = analyzer.analyze('8点叫我起床');

        expect(result.hasReminderIntent, true);
      });
    });

    group('Location Recognition', () {
      test('should recognize "在xxx开会" location', () {
        final result = analyzer.analyze('在会议室开会');

        expect(result.hasLocation, true);
        expect(result.recognizedLocation, contains('会议室'));
      });

      test('should recognize "去xxx" location', () {
        final result = analyzer.analyze('去公司');

        expect(result.hasLocation, true);
        expect(result.recognizedLocation, contains('公司'));
      });
    });

    group('Combined Analysis', () {
      test('should detect actionable intent with datetime', () {
        final result = analyzer.analyze('明天下午3点在公司开会');

        expect(result.hasActionableIntent, true);
        expect(result.hasDateTime, true);
        expect(result.hasScheduleIntent, true);
      });

      test('should generate suggestion text for schedule', () {
        final result = analyzer.analyze('明天下午3点约朋友');

        expect(result.suggestionText, isNotNull);
        expect(result.suggestionText, contains('日程'));
      });

      test('should generate suggestion text for task', () {
        final result = analyzer.analyze('明天之前需要完成报告');

        expect(result.hasTaskIntent, true);
        expect(result.hasDateTime, true);
      });

      test('should not have actionable intent for simple chat', () {
        final result = analyzer.analyze('你好，今天天气怎么样');

        expect(result.hasActionableIntent, false);
      });
    });

    group('Entity List', () {
      test('should add entities for recognized items', () {
        final result = analyzer.analyze('明天下午3点开会');

        expect(result.entities, isNotEmpty);
        expect(
          result.entities.any((e) => e.type == EntityType.dateTime),
          true,
        );
        expect(
          result.entities.any((e) => e.type == EntityType.scheduleIntent),
          true,
        );
      });

      test('should get dateTime entities', () {
        final result = analyzer.analyze('明天10点');

        expect(result.dateTimeEntities, isNotEmpty);
      });

      test('should get location entities', () {
        final result = analyzer.analyze('在咖啡厅见');

        expect(result.locationEntities, isNotEmpty);
      });
    });

    group('Edge Cases', () {
      test('should handle empty string', () {
        final result = analyzer.analyze('');

        expect(result.hasActionableIntent, false);
        expect(result.entities, isEmpty);
      });

      test('should handle string with no recognizable content', () {
        final result = analyzer.analyze('随便说点什么');

        expect(result.hasActionableIntent, false);
      });

      test('should handle special characters', () {
        final result = analyzer.analyze('明天@#\$%开会！');

        expect(result.hasDateTime, true);
        expect(result.hasScheduleIntent, true);
      });
    });
  });
}
