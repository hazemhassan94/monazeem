import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

class LessonReminderSlot {
  final int weekday;
  final int hour;
  final int minute;
  final List<String> lessons;

  const LessonReminderSlot({
    required this.weekday,
    required this.hour,
    required this.minute,
    required this.lessons,
  });

  int get id => weekday * 1440 + hour * 60 + minute + 1;
  String get body => lessons.join(' • ');
}

class UpcomingLesson {
  final DateTime startsAt;
  final String description;

  const UpcomingLesson(this.startsAt, this.description);
}

List<LessonReminderSlot> buildLessonReminderSlots(AppData data) {
  final profile = data.profile;
  if (profile == null || !data.setupDone) return [];

  final slots = <String, List<String>>{};
  void addLesson(int weekday, String time, String description) {
    final parts = _parseTime(time);
    if (parts == null) return;
    final lessonTime = DateTime(2020, 1, 1, parts.$1, parts.$2);
    final reminderTime = lessonTime.subtract(const Duration(minutes: 15));
    final reminderWeekday = reminderTime.day == lessonTime.day
        ? weekday
        : (weekday == DateTime.monday ? DateTime.sunday : weekday - 1);
    final key = '$reminderWeekday-${reminderTime.hour}-${reminderTime.minute}';
    slots.putIfAbsent(key, () => []).add(description);
  }

  if (profile.places.contains('center')) {
    for (final stage in data.center.stages) {
      final names = stage.students.map((student) => student.name).join('، ');
      final description = names.isEmpty
          ? 'السنتر • ${stage.name}'
          : 'السنتر • ${stage.name} • $names';
      for (final day in stage.schedule.days) {
        addLesson(day, stage.schedule.timeFor(day), description);
      }
    }
  }

  if (profile.places.contains('private')) {
    for (final student in data.students) {
      for (final day in student.schedule.days) {
        addLesson(
            day, student.schedule.timeFor(day), 'برايفت • ${student.name}');
      }
    }
  }

  final result = <LessonReminderSlot>[];
  for (final entry in slots.entries) {
    final parts = entry.key.split('-').map(int.parse).toList();
    result.add(LessonReminderSlot(
      weekday: parts[0],
      hour: parts[1],
      minute: parts[2],
      lessons: List.unmodifiable(entry.value),
    ));
  }
  result.sort((a, b) {
    final day = a.weekday.compareTo(b.weekday);
    if (day != 0) return day;
    final hour = a.hour.compareTo(b.hour);
    return hour != 0 ? hour : a.minute.compareTo(b.minute);
  });
  return result;
}

UpcomingLesson? nextUpcomingLesson(AppData data, DateTime now) {
  final profile = data.profile;
  if (profile == null || !data.setupDone) return null;

  final lessons = <String, List<String>>{};
  final times = <String, DateTime>{};
  void addLesson(
      DateTime date, String time, String description, bool recorded) {
    if (recorded) return;
    final parts = _parseTime(time);
    if (parts == null) return;
    final startsAt =
        DateTime(date.year, date.month, date.day, parts.$1, parts.$2);
    if (!startsAt.isAfter(now)) return;
    final key = '${dateKey(date)}-${parts.$1}-${parts.$2}';
    times[key] = startsAt;
    lessons.putIfAbsent(key, () => []).add(description);
  }

  for (int offset = 0; offset <= 7; offset++) {
    final date = DateTime(now.year, now.month, now.day + offset);
    final log = data.logs[dateKey(date)];
    if (profile.places.contains('center')) {
      for (final stage in data.center.stages) {
        if (!stage.schedule.days.contains(date.weekday)) continue;
        final names = stage.students.map((student) => student.name).join('، ');
        final description = names.isEmpty
            ? 'السنتر • ${stage.name}'
            : 'السنتر • ${stage.name} • $names';
        addLesson(
          date,
          stage.schedule.timeFor(date.weekday),
          description,
          log?.confirmed == true && log!.stages.contains(stage.id),
        );
      }
    }
    if (profile.places.contains('private')) {
      for (final student in data.students) {
        if (!student.schedule.days.contains(date.weekday)) continue;
        addLesson(
          date,
          student.schedule.timeFor(date.weekday),
          'برايفت • ${student.name}',
          log?.confirmed == true && log!.students.contains(student.id),
        );
      }
    }
  }

  if (lessons.isEmpty) return null;
  final keys = lessons.keys.toList()
    ..sort((a, b) => times[a]!.compareTo(times[b]!));
  final key = keys.first;
  return UpcomingLesson(times[key]!, lessons[key]!.join(' • '));
}

String lessonReminderFingerprint(AppData data) => buildLessonReminderSlots(data)
    .map((slot) => '${slot.weekday}:${slot.hour}:${slot.minute}:${slot.body}')
    .join('|');

class LessonReminderService {
  LessonReminderService._();
  static final LessonReminderService instance = LessonReminderService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<bool> sync(AppData data) async {
    if (kIsWeb) return false;
    final slots = buildLessonReminderSlots(data);
    await _initialize();
    if (slots.isEmpty) {
      await _notifications.cancelAll();
      return true;
    }

    final granted = await _notifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
    if (!granted) {
      await _notifications.cancelAll();
      return false;
    }

    await _notifications.cancelAll();
    final now = DateTime.now();
    for (final slot in slots) {
      var firstReminder =
          DateTime(now.year, now.month, now.day, slot.hour, slot.minute);
      while (firstReminder.weekday != slot.weekday ||
          !firstReminder.isAfter(now)) {
        firstReminder = firstReminder.add(const Duration(days: 1));
      }
      await _notifications.zonedSchedule(
        slot.id,
        'الحصة القادمة',
        slot.body,
        tz.TZDateTime.from(firstReminder, tz.local),
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
    return true;
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    final timeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZone));
    await _notifications.initialize(
      const InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }
}

(int, int)? _parseTime(String time) {
  final parts = time.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return null;
  }
  return (hour, minute);
}
