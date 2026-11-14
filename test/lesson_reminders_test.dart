import 'package:flutter_test/flutter_test.dart';
import 'package:monazzem/lesson_reminders.dart';
import 'package:monazzem/models.dart';

void main() {
  test('reminder is 15 minutes early and carries registered student names', () {
    final data = AppData()
      ..setupDone = true
      ..profile = Profile(places: {'center', 'private'})
      ..center.stages.add(
            CenterStage(
              id: 'stage',
              name: 'ثالثة ثانوي',
              schedule: Schedule(days: [DateTime.monday], times: {1: '00:05'}),
              students: [
                CenterStudent(id: 'center-student', name: 'سارة'),
              ],
            ),
          )
      ..students.add(
        PrivateStudent(
          id: 'private-student',
          name: 'علي',
          schedule: Schedule(days: [DateTime.monday], times: {1: '00:05'}),
        ),
      );

    final slots = buildLessonReminderSlots(data);

    expect(slots, hasLength(1));
    expect(slots.single.weekday, DateTime.sunday);
    expect(slots.single.hour, 23);
    expect(slots.single.minute, 50);
    expect(slots.single.body, contains('سارة'));
    expect(slots.single.body, contains('علي'));
  });

  test('next upcoming lesson shows the scheduled student', () {
    final data = AppData()
      ..setupDone = true
      ..profile = Profile(places: {'private'})
      ..students.add(
        PrivateStudent(
          id: 'student',
          name: 'مريم',
          schedule: Schedule(days: [DateTime.monday], times: {1: '09:30'}),
        ),
      );

    final upcoming = nextUpcomingLesson(data, DateTime(2026, 1, 5, 9));

    expect(upcoming, isNotNull);
    expect(upcoming!.startsAt, DateTime(2026, 1, 5, 9, 30));
    expect(upcoming.description, contains('مريم'));
  });

  test('completed lessons are skipped from the next-lesson preview', () {
    final data = AppData()
      ..setupDone = true
      ..profile = Profile(places: {'private'})
      ..students.add(
        PrivateStudent(
          id: 'student',
          name: 'مريم',
          schedule: Schedule(days: [DateTime.monday], times: {1: '09:30'}),
        ),
      )
      ..logs[dateKey(DateTime(2026, 1, 5))] =
          DayLog(confirmed: true, students: {'student'});

    final upcoming = nextUpcomingLesson(data, DateTime(2026, 1, 5, 9));

    expect(upcoming, isNotNull);
    expect(upcoming!.startsAt, DateTime(2026, 1, 12, 9, 30));
  });
}
