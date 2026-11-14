import 'package:flutter_test/flutter_test.dart';
import 'package:monazzem/app_state.dart';
import 'package:monazzem/models.dart';

void main() {
  group('school daily income', () {
    late AppState state;
    late DateTime today;

    setUp(() {
      today = dayOnly(DateTime.now());
      state = AppState();
      state.data.profile = Profile(
        workDays: [today.weekday],
        places: {'school', 'private'},
        schoolSalary: 1200,
        startDate: dateKey(today),
      );
      state.data.students.add(
        PrivateStudent(id: 'student', name: 'طالب', price: 80),
      );
    });

    test('adds confirmed private lessons to the daily amount only', () {
      state.data.logs[dateKey(today)] = DayLog(
        school: true,
        students: {'student'},
        confirmed: true,
      );

      expect(
        state.schoolDailyIncome(today),
        closeTo(state.schoolDaily(today) + 80, 0.001),
      );
      final totals = state.totals(today, today);
      expect(totals.school, closeTo(state.schoolDaily(today), 0.001));
      expect(totals.priv, 0);
    });

    test('does not count an unconfirmed private lesson', () {
      state.data.logs[dateKey(today)] = DayLog(
        school: true,
        students: {'student'},
      );

      expect(state.schoolDailyIncome(today),
          closeTo(state.schoolDaily(today), 0.001));
    });
  });

  test('supports different saved times for each weekday and legacy schedules',
      () {
    final old = Schedule.fromJson({
      'd': [6, 1],
      't': '16:00'
    });
    expect(old.timeFor(6), '16:00');
    expect(old.timeFor(1), '16:00');

    final custom = Schedule(
      days: [6, 1],
      times: {6: '15:30', 1: '17:00'},
    );
    final restored = Schedule.fromJson(custom.toJson());
    expect(restored.timeFor(6), '15:30');
    expect(restored.timeFor(1), '17:00');
  });

  test(
      'backfilled lessons are saved on their dates and counted before setup date',
      () {
    final today = dayOnly(DateTime.now());
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final state = AppState();
    state.data.profile = Profile(
      workDays: [yesterday.weekday],
      places: {'school', 'private', 'center'},
      schoolSalary: 1200,
      startDate: dateKey(today),
    );
    final student = PrivateStudent(id: 'student', name: 'طالب', price: 80);
    state.data.students.add(student);
    final stage = CenterStage(id: 'stage', name: 'مرحلة');
    state.data.center.stages.add(stage);

    state.setPrivateSessionDates(student.id, {dateKey(yesterday)});
    state.setCenterStageSessionDates(stage.id, {dateKey(yesterday)});

    expect(state.sessionsDone(student.id), 1);
    expect(state.logFor(yesterday)?.students, contains(student.id));
    expect(state.logFor(yesterday)?.stages, contains(stage.id));
    final totals = state.totals(yesterday, yesterday);
    expect(totals.privSessions, 1);
    expect(totals.centerSessions, 1);
    expect(totals.schoolDays, 0);
  });

  test('summary income follows confirmed lesson dates, not payment dates', () {
    final today = dayOnly(DateTime.now());
    final state = AppState();
    state.data.profile = Profile(
      workDays: [today.weekday],
      places: {'school', 'private', 'center'},
      schoolSalary: 1200,
      startDate: dateKey(today),
    );
    state.data.students.add(
      PrivateStudent(id: 'private', name: 'طالب', price: 80),
    );
    state.data.center.stages.add(
      CenterStage(
        id: 'center',
        name: 'مرحلة',
        price: 800,
        students: [
          CenterStudent(id: 'one', name: 'الأول'),
          CenterStudent(id: 'two', name: 'الثاني'),
        ],
      ),
    );
    state.data.logs[dateKey(today)] = DayLog(
      school: true,
      stages: {'center'},
      students: {'private'},
      confirmed: true,
    );
    state.data.payments.addAll([
      Payment(
        id: 'center-payment',
        kind: 'center',
        studentId: 'one',
        month: monthKey(today),
        date: dateKey(today),
        amount: 800,
      ),
      Payment(
        id: 'private-payment',
        kind: 'private',
        studentId: 'private',
        month: monthKey(today),
        date: dateKey(today),
        amount: 500,
      ),
    ]);

    final totals = state.totals(today, today);
    expect(totals.centerEarned, 200);
    expect(totals.privateEarned, 80);
    expect(totals.centerIn, 800);
    expect(totals.priv, 500);
    expect(totals.total, closeTo(state.schoolDaily(today) + 280, 0.001));
  });

  test(
      'period ranges advance independently while earlier periods remain reachable',
      () {
    final today = dayOnly(DateTime.now());
    final currentDay = rangeFor(Period.day, 0, today);
    final previousDay = rangeFor(Period.day, -1, today);
    expect(currentDay.from, today);
    expect(previousDay.from, DateTime(today.year, today.month, today.day - 1));

    final currentWeek = rangeFor(Period.week, 0, today);
    final previousWeek = rangeFor(Period.week, -1, today);
    expect(currentWeek.from.weekday, 6);
    expect(
        previousWeek.to,
        DateTime(currentWeek.from.year, currentWeek.from.month,
            currentWeek.from.day - 1));

    final currentMonth = rangeFor(Period.month, 0, today);
    final previousMonth = rangeFor(Period.month, -1, today);
    expect(currentMonth.from.day, 1);
    expect(previousMonth.to,
        DateTime(currentMonth.from.year, currentMonth.from.month, 0));
  });

  test('school workdays exclude Friday and Saturday', () {
    final profile = Profile(workDays: [5, 6, 1]);
    expect(profile.workDays, [1]);
  });

  test('legacy workday values cannot show or count Friday and Saturday', () {
    final today = dayOnly(DateTime.now());
    final state = AppState();
    state.data.profile = Profile(
      workDays: [1],
      places: {'school'},
      schoolSalary: 1200,
      startDate: '2000-01-01',
    );
    state.p.workDays = [1, 5, 6];
    final friday = DateTime(2026, 11, 13);
    final saturday = DateTime(2026, 11, 14);

    expect(state.isSchoolWorkday(5), isFalse);
    expect(state.isSchoolWorkday(6), isFalse);
    expect(state.schoolAttended(friday), isFalse);
    expect(state.schoolAttended(saturday), isFalse);
    expect(state.totals(friday, saturday).schoolDays, 0);
    expect(
        state.workdaysInMonth(today.year, today.month), lessThanOrEqualTo(23));
  });

  test(
      'registered scheduled classes are removed from the daily registration list',
      () {
    final today = dayOnly(DateTime.now());
    final state = AppState();
    state.data.profile = Profile(
      workDays: [today.weekday],
      places: {'school'},
      startDate: dateKey(today),
    );
    final stage = CenterStage(
      id: 'stage',
      name: 'مرحلة',
      schedule: Schedule(days: [today.weekday]),
    );
    final student = PrivateStudent(
      id: 'student',
      name: 'طالب',
      schedule: Schedule(days: [today.weekday]),
    );
    state.data.center.stages.add(stage);
    state.data.students.add(student);

    expect(state.unrecordedScheduledStages(today), contains(stage.id));
    expect(state.unrecordedScheduledStudents(today), contains(student.id));

    state.saveDayLog(
      today,
      school: false,
      stages: {stage.id},
      students: {student.id},
    );

    expect(state.unrecordedScheduledStages(today), isEmpty);
    expect(state.unrecordedScheduledStudents(today), isEmpty);
  });

  test(
      'monthly received income includes school salary only after receipt is recorded',
      () {
    final today = dayOnly(DateTime.now());
    final state = AppState();
    state.data.profile = Profile(
      workDays: [today.weekday],
      places: {'school'},
      schoolSalary: 1200,
      startDate: dateKey(today),
    );

    final beforeReceipt = state.totals(
      DateTime(today.year, today.month, 1),
      DateTime(today.year, today.month + 1, 0),
    );
    expect(beforeReceipt.schoolIn, 0);
    expect(beforeReceipt.receivedTotal, 0);

    state.toggleSchoolSalaryReceived(DateTime(today.year, today.month));
    final afterReceipt = state.totals(
      DateTime(today.year, today.month, 1),
      DateTime(today.year, today.month + 1, 0),
    );
    expect(afterReceipt.schoolIn, 1200);
    expect(afterReceipt.receivedTotal, 1200);
  });
}
