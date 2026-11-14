// مُنظم - الحالة العامة + التخزين الداخلي (shared_preferences)
// تصميم حازم حسن

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

enum Period { day, week, month, term }

class PeriodRange {
  final DateTime from;
  final DateTime to;
  final String label;
  PeriodRange(this.from, this.to, this.label);
}

PeriodRange rangeFor(Period p, int off, DateTime today) {
  switch (p) {
    case Period.day:
      {
        final d = DateTime(today.year, today.month, today.day + off);
        return PeriodRange(d, d,
            '${weekNames[d.weekday]} ${d.day} ${monthNames[d.month - 1]}');
      }
    case Period.week:
      {
        final back = (today.weekday - 6 + 7) % 7;
        final s = DateTime(today.year, today.month, today.day - back + 7 * off);
        final e = DateTime(s.year, s.month, s.day + 6);
        return PeriodRange(s, e,
            '${s.day} ${monthNames[s.month - 1]} - ${e.day} ${monthNames[e.month - 1]}');
      }
    case Period.month:
      {
        final m = DateTime(today.year, today.month + off, 1);
        final e = DateTime(m.year, m.month + 1, 0);
        return PeriodRange(m, e, '${monthNames[m.month - 1]} ${m.year}');
      }
    case Period.term:
      {
        int y;
        int t;
        if (today.month >= 9) {
          y = today.year;
          t = 0;
        } else if (today.month == 1) {
          y = today.year - 1;
          t = 0;
        } else {
          y = today.year - 1;
          t = 1;
        }
        final n = 2 * y + t + off;
        final yy = n ~/ 2;
        final tt = n - yy * 2;
        if (tt == 0) {
          return PeriodRange(DateTime(yy, 9, 1), DateTime(yy + 1, 1, 31),
              'الترم الأول $yy/${yy + 1}');
        }
        return PeriodRange(DateTime(yy + 1, 2, 1), DateTime(yy + 1, 6, 30),
            'الترم الثاني $yy/${yy + 1}');
      }
  }
}

class Totals {
  double school = 0;
  double schoolIn = 0;
  double centerEarned = 0;
  double centerIn = 0;
  double centerOut = 0;
  double priv = 0;
  double privateEarned = 0;
  int schoolDays = 0;
  int centerSessions = 0;
  int privSessions = 0;
  double get center => centerEarned - centerOut;
  double get earnedTotal => school + centerEarned + privateEarned - centerOut;
  double get receivedTotal => schoolIn + centerIn + priv - centerOut;
  double get total => earnedTotal;
  double get schoolDifference => school - schoolIn;
  double get centerDifference => centerEarned - centerIn;
  double get privateDifference => privateEarned - priv;
  bool get hasReconciliationDifference =>
      schoolDifference.abs() >= .01 ||
      centerDifference.abs() >= .01 ||
      privateDifference.abs() >= .01;
  double get reconciliationDifference =>
      schoolDifference + centerDifference + privateDifference;
}

class AppState extends ChangeNotifier {
  AppData data = AppData();
  bool loaded = false;
  SharedPreferences? _prefs;
  static const _key = 'monazzem_v1';

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final s = _prefs!.getString(_key);
    if (s != null) {
      try {
        data = AppData.fromJson(Map<String, dynamic>.from(jsonDecode(s)));
      } catch (_) {
        data = AppData();
      }
    }
    loaded = true;
    notifyListeners();
  }

  void save() {
    _prefs?.setString(_key, jsonEncode(data.toJson()));
    notifyListeners();
  }

  Future<void> resetAll() async {
    data = AppData();
    await _prefs?.remove(_key);
    notifyListeners();
  }

  // ---------- أساسيات ----------
  DateTime get today => dayOnly(DateTime.now());
  Profile get p => data.profile!;
  bool has(String place) => data.profile?.places.contains(place) ?? false;

  // ---------- المدرسة ----------
  int workdaysInMonth(int y, int m) {
    int n = 0;
    for (int d = 1; d <= daysIn(y, m); d++) {
      if (isSchoolWorkday(DateTime(y, m, d).weekday)) n++;
    }
    return n;
  }

  bool isSchoolWorkday(int weekday) =>
      !schoolExcludedDays.contains(weekday) && p.workDays.contains(weekday);

  double schoolDaily(DateTime d) {
    final n = workdaysInMonth(d.year, d.month);
    return n == 0 ? 0 : p.schoolSalary / n;
  }

  double privateDailyIncome(DateTime d) {
    final log = logFor(d);
    if (log == null || !log.confirmed) return 0;
    return data.students
        .where((student) => log.students.contains(student.id))
        .fold<double>(0, (total, student) => total + student.perSession);
  }

  double schoolDailyIncome(DateTime d) =>
      (schoolAttended(d) ? schoolDaily(d) : 0) + privateDailyIncome(d);

  DayLog? logFor(DateTime d) => data.logs[dateKey(d)];

  DayLog ensureLog(DateTime d) {
    final k = dateKey(d);
    return data.logs
        .putIfAbsent(k, () => DayLog(school: isSchoolWorkday(d.weekday)));
  }

  bool schoolAttended(DateTime d) {
    if (!isSchoolWorkday(d.weekday)) return false;
    final l = logFor(d);
    return l == null ? true : l.school;
  }

  void toggleSchool(DateTime d) {
    final l = ensureLog(d);
    l.school = !l.school;
    save();
  }

  void setSalary(double v) {
    p.schoolSalary = v;
    save();
  }

  bool schoolSalaryReceived(String mk) => data.payments
      .any((payment) => payment.kind == 'school' && payment.month == mk);

  void toggleSchoolSalaryReceived(DateTime monthStart) {
    final mk = monthKey(monthStart);
    if (schoolSalaryReceived(mk)) {
      data.payments.removeWhere(
          (payment) => payment.kind == 'school' && payment.month == mk);
    } else {
      data.payments.add(Payment(
        id: newId(),
        kind: 'school',
        studentId: 'school',
        month: mk,
        date: dateKey(today),
        amount: p.schoolSalary,
      ));
    }
    save();
  }

  // ---------- السنتر ----------
  void setExpenses(
      {double? rent, double? secretary, double? water, double? electricity}) {
    final c = data.center;
    if (rent != null) c.rent = rent;
    if (secretary != null) c.secretary = secretary;
    if (water != null) c.water = water;
    if (electricity != null) c.electricity = electricity;
    save();
  }

  void addStudentsToStage(CenterStage s, List<String> names) {
    for (final n in names) {
      final t = n.trim();
      if (t.isNotEmpty) s.students.add(CenterStudent(id: newId(), name: t));
    }
    save();
  }

  void deleteStage(CenterStage s) {
    final ids = s.students.map((e) => e.id).toSet();
    data.payments
        .removeWhere((x) => x.kind == 'center' && ids.contains(x.studentId));
    for (final log in data.logs.values) {
      log.stages.remove(s.id);
    }
    data.center.stages.removeWhere((x) => x.id == s.id);
    save();
  }

  void deleteCenterStudent(CenterStage s, CenterStudent st) {
    s.students.removeWhere((x) => x.id == st.id);
    data.payments
        .removeWhere((x) => x.kind == 'center' && x.studentId == st.id);
    save();
  }

  bool centerPaid(String studentId, String mk) => data.payments.any(
      (x) => x.kind == 'center' && x.studentId == studentId && x.month == mk);

  void toggleCenterPayment(
      CenterStage stage, CenterStudent st, DateTime monthStart) {
    final mk = monthKey(monthStart);
    if (centerPaid(st.id, mk)) {
      data.payments.removeWhere(
          (x) => x.kind == 'center' && x.studentId == st.id && x.month == mk);
    } else {
      data.payments.add(Payment(
        id: newId(),
        kind: 'center',
        studentId: st.id,
        month: mk,
        date: dateKey(today),
        amount: stage.price,
      ));
    }
    save();
  }

  int paidCount(CenterStage s, String mk) =>
      s.students.where((x) => centerPaid(x.id, mk)).length;

  // ---------- البرايفت ----------
  int sessionsDone(String studentId) {
    final t = dateKey(today);
    var n = 0;
    data.logs.forEach((k, v) {
      if (k.compareTo(t) <= 0 &&
          v.confirmed &&
          v.students.contains(studentId)) {
        n++;
      }
    });
    return n;
  }

  int unpaidSessions(PrivateStudent s) => sessionsDone(s.id) - s.paidSessions;

  Set<String> privateSessionDates(String studentId) => data.logs.entries
      .where((entry) =>
          entry.value.confirmed && entry.value.students.contains(studentId))
      .map((entry) => entry.key)
      .toSet();

  void setPrivateSessionDates(String studentId, Set<String> dates) {
    final todayKey = dateKey(today);
    for (final entry in data.logs.entries) {
      if (entry.value.students.contains(studentId)) {
        entry.value.students.remove(studentId);
      }
    }
    for (final key in dates) {
      if (key.compareTo(todayKey) > 0) continue;
      final log = ensureLog(parseKey(key));
      log.students.add(studentId);
      log.confirmed = true;
    }
    save();
  }

  void deletePrivate(PrivateStudent s) {
    data.students.removeWhere((x) => x.id == s.id);
    data.payments
        .removeWhere((x) => x.kind == 'private' && x.studentId == s.id);
    for (final l in data.logs.values) {
      l.students.remove(s.id);
    }
    save();
  }

  void payPrivate(PrivateStudent s) {
    final unpaid = unpaidSessions(s);
    double amount;
    if (s.perPack) {
      amount = s.price;
      s.paidSessions += 8;
    } else {
      if (unpaid <= 0) return;
      amount = unpaid * s.price;
      s.paidSessions += unpaid;
    }
    data.payments.add(Payment(
      id: newId(),
      kind: 'private',
      studentId: s.id,
      month: monthKey(today),
      date: dateKey(today),
      amount: amount,
    ));
    save();
  }

  // ---------- تسجيل اليوم ----------
  bool dayConfirmed(DateTime d) => logFor(d)?.confirmed ?? false;

  Set<String> scheduledStages(DateTime d) => data.center.stages
      .where((s) => s.schedule.days.contains(d.weekday))
      .map((s) => s.id)
      .toSet();

  Set<String> unrecordedScheduledStages(DateTime d) {
    final recorded = logFor(d)?.stages ?? const <String>{};
    return scheduledStages(d).difference(recorded);
  }

  Set<String> centerStageSessionDates(String stageId) => data.logs.entries
      .where((entry) =>
          entry.value.confirmed && entry.value.stages.contains(stageId))
      .map((entry) => entry.key)
      .toSet();

  void setCenterStageSessionDates(String stageId, Set<String> dates) {
    final todayKey = dateKey(today);
    for (final entry in data.logs.entries) {
      entry.value.stages.remove(stageId);
    }
    for (final key in dates) {
      if (key.compareTo(todayKey) > 0) continue;
      final log = ensureLog(parseKey(key));
      log.stages.add(stageId);
      log.confirmed = true;
    }
    save();
  }

  Set<String> scheduledStudents(DateTime d) => data.students
      .where((s) => s.schedule.days.contains(d.weekday))
      .map((s) => s.id)
      .toSet();

  Set<String> unrecordedScheduledStudents(DateTime d) {
    final recorded = logFor(d)?.students ?? const <String>{};
    return scheduledStudents(d).difference(recorded);
  }

  void saveDayLog(DateTime d,
      {required bool school,
      required Set<String> stages,
      required Set<String> students}) {
    final l = ensureLog(d);
    l.school = school;
    l.stages = Set<String>.from(stages);
    l.students = Set<String>.from(students);
    l.confirmed = true;
    save();
  }

  bool get reminderDue {
    if (data.profile == null || !data.setupDone) return false;
    final now = DateTime.now();
    final at = DateTime(now.year, now.month, now.day, p.remHour, p.remMin);
    return !now.isBefore(at) && !dayConfirmed(today);
  }

  // ---------- الإجماليات ----------
  Totals totals(DateTime from, DateTime to) {
    final t = Totals();
    final pr = data.profile;
    if (pr == null) return t;
    final start = parseKey(pr.startDate);
    final tdy = today;
    final a = dayOnly(from);
    final b = dayOnly(to);
    final end = b.isAfter(tdy) ? tdy : b;
    if (end.isBefore(a)) return t;
    final fk = dateKey(a);
    final tk = dateKey(end);
    for (final pay in data.payments) {
      if (pay.date.compareTo(fk) >= 0 && pay.date.compareTo(tk) <= 0) {
        if (pay.kind == 'center') {
          t.centerIn += pay.amount;
        } else if (pay.kind == 'school') {
          t.schoolIn += pay.amount;
        } else {
          t.priv += pay.amount;
        }
      }
    }
    final hasSchool = pr.places.contains('school');
    final hasCenter = pr.places.contains('center');
    for (DateTime d = a; !d.isAfter(end); d = nextDay(d)) {
      final log = data.logs[dateKey(d)];
      if (!d.isBefore(start) &&
          hasSchool &&
          isSchoolWorkday(d.weekday) &&
          (log == null || log.school)) {
        t.school += schoolDaily(d);
        t.schoolDays++;
      }
      if (!d.isBefore(start) && hasCenter) {
        t.centerOut += data.center.monthlyExpenses / daysIn(d.year, d.month);
      }
      if (log != null && log.confirmed) {
        for (final stage in data.center.stages) {
          if (log.stages.contains(stage.id)) {
            t.centerSessions++;
            t.centerEarned += stage.price * stage.students.length / 8;
          }
        }
        for (final student in data.students) {
          if (log.students.contains(student.id)) {
            t.privSessions++;
            t.privateEarned += student.perSession;
          }
        }
      }
    }
    return t;
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  static AppState read(BuildContext c) =>
      c.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
