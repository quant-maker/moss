import 'package:flutter_test/flutter_test.dart';
import 'package:moss/core/models/schedule.dart';

void main() {
  group('Schedule Model', () {
    group('Creation', () {
      test('should create schedule with required fields', () {
        final schedule = Schedule(
          id: 'test-1',
          title: 'Test Meeting',
          startTime: DateTime(2026, 1, 15, 10, 0),
        );

        expect(schedule.id, 'test-1');
        expect(schedule.title, 'Test Meeting');
        expect(schedule.startTime.hour, 10);
        expect(schedule.isCompleted, false);
      });

      test('should create schedule with all fields', () {
        final schedule = Schedule(
          id: 'test-2',
          title: 'Full Meeting',
          description: 'A detailed meeting',
          startTime: DateTime(2026, 1, 15, 14, 0),
          endTime: DateTime(2026, 1, 15, 15, 30),
          isAllDay: false,
          location: 'Conference Room A',
          repeatTypeIndex: RepeatType.weekly.index,
          reminderTimeIndex: ReminderTime.minutes15.index,
          color: '#FF5733',
        );

        expect(schedule.description, 'A detailed meeting');
        expect(schedule.endTime?.hour, 15);
        expect(schedule.location, 'Conference Room A');
        expect(schedule.repeatType, RepeatType.weekly);
        expect(schedule.reminderTime, ReminderTime.minutes15);
        expect(schedule.color, '#FF5733');
      });
    });

    group('RepeatType', () {
      test('should get and set repeat type', () {
        final schedule = Schedule(
          id: 'test',
          title: 'Test',
          startTime: DateTime.now(),
        );

        expect(schedule.repeatType, RepeatType.none);

        schedule.repeatType = RepeatType.daily;
        expect(schedule.repeatType, RepeatType.daily);
        expect(schedule.repeatTypeIndex, 1);
      });

      test('should return correct repeat type text', () {
        final schedule = Schedule(
          id: 'test',
          title: 'Test',
          startTime: DateTime.now(),
          repeatTypeIndex: RepeatType.weekly.index,
        );

        expect(schedule.repeatTypeText, '每周');
      });
    });

    group('ReminderTime', () {
      test('should get and set reminder time', () {
        final schedule = Schedule(
          id: 'test',
          title: 'Test',
          startTime: DateTime.now(),
        );

        expect(schedule.reminderTime, ReminderTime.none);

        schedule.reminderTime = ReminderTime.hour1;
        expect(schedule.reminderTime, ReminderTime.hour1);
      });

      test('should return correct reminder minutes', () {
        final testCases = {
          ReminderTime.none: 0,
          ReminderTime.atTime: 0,
          ReminderTime.minutes5: 5,
          ReminderTime.minutes15: 15,
          ReminderTime.minutes30: 30,
          ReminderTime.hour1: 60,
          ReminderTime.day1: 1440,
        };

        for (final entry in testCases.entries) {
          final schedule = Schedule(
            id: 'test',
            title: 'Test',
            startTime: DateTime.now(),
            reminderTimeIndex: entry.key.index,
          );
          expect(schedule.reminderMinutes, entry.value);
        }
      });

      test('should return correct reminder time text', () {
        final schedule = Schedule(
          id: 'test',
          title: 'Test',
          startTime: DateTime.now(),
          reminderTimeIndex: ReminderTime.minutes30.index,
        );

        expect(schedule.reminderTimeText, '30分钟前');
      });
    });

    group('Formatting', () {
      test('should format time correctly', () {
        final schedule = Schedule(
          id: 'test',
          title: 'Test',
          startTime: DateTime(2026, 1, 15, 9, 5),
        );

        expect(schedule.formattedTime, '09:05');
      });

      test('should return "全天" for all-day events', () {
        final schedule = Schedule(
          id: 'test',
          title: 'Test',
          startTime: DateTime(2026, 1, 15),
          isAllDay: true,
        );

        expect(schedule.formattedTime, '全天');
      });

      test('should format date correctly', () {
        final schedule = Schedule(
          id: 'test',
          title: 'Test',
          startTime: DateTime(2026, 1, 5),
        );

        expect(schedule.formattedDate, '2026-01-05');
      });
    });

    group('JSON Serialization', () {
      test('should convert to JSON', () {
        final schedule = Schedule(
          id: 'json-test',
          title: 'JSON Test',
          startTime: DateTime(2026, 1, 15, 10, 0),
          location: 'Office',
        );

        final json = schedule.toJson();

        expect(json['id'], 'json-test');
        expect(json['title'], 'JSON Test');
        expect(json['location'], 'Office');
        expect(json['start_time'], contains('2026-01-15'));
      });

      test('should create from JSON', () {
        final json = {
          'id': 'from-json',
          'title': 'From JSON',
          'start_time': '2026-02-20T14:30:00',
          'location': 'Meeting Room',
          'is_all_day': false,
        };

        final schedule = Schedule.fromJson(json);

        expect(schedule.id, 'from-json');
        expect(schedule.title, 'From JSON');
        expect(schedule.startTime.month, 2);
        expect(schedule.startTime.day, 20);
        expect(schedule.location, 'Meeting Room');
      });

      test('should handle camelCase and snake_case keys', () {
        final json1 = {'startTime': '2026-01-15T10:00:00'};
        final json2 = {'start_time': '2026-01-15T10:00:00'};

        final s1 = Schedule.fromJson({...json1, 'id': '1', 'title': 'Test'});
        final s2 = Schedule.fromJson({...json2, 'id': '2', 'title': 'Test'});

        expect(s1.startTime.hour, 10);
        expect(s2.startTime.hour, 10);
      });
    });

    group('copyWith', () {
      test('should copy with new values', () {
        final original = Schedule(
          id: 'original',
          title: 'Original Title',
          startTime: DateTime(2026, 1, 15, 10, 0),
          location: 'Room A',
        );

        final copied = original.copyWith(
          title: 'New Title',
          location: 'Room B',
        );

        expect(original.title, 'Original Title');
        expect(original.location, 'Room A');
        expect(copied.title, 'New Title');
        expect(copied.location, 'Room B');
        expect(copied.id, 'original');
        expect(copied.startTime.hour, 10);
      });

      test('should update isCompleted', () {
        final schedule = Schedule(
          id: 'test',
          title: 'Test',
          startTime: DateTime.now(),
          isCompleted: false,
        );

        final completed = schedule.copyWith(isCompleted: true);

        expect(schedule.isCompleted, false);
        expect(completed.isCompleted, true);
      });
    });
  });

  group('RepeatType Enum', () {
    test('should have correct values', () {
      expect(RepeatType.none.index, 0);
      expect(RepeatType.daily.index, 1);
      expect(RepeatType.weekly.index, 2);
      expect(RepeatType.monthly.index, 3);
      expect(RepeatType.yearly.index, 4);
    });
  });

  group('ReminderTime Enum', () {
    test('should have correct values', () {
      expect(ReminderTime.none.index, 0);
      expect(ReminderTime.atTime.index, 1);
      expect(ReminderTime.minutes5.index, 2);
      expect(ReminderTime.minutes15.index, 3);
      expect(ReminderTime.minutes30.index, 4);
      expect(ReminderTime.hour1.index, 5);
      expect(ReminderTime.day1.index, 6);
    });
  });
}
