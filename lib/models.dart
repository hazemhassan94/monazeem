// مُنظم - النماذج (Models) + دوال مساعدة
// تصميم حازم حسن

int _idc = 0;
String newId() => '${DateTime.now().microsecondsSinceEpoch}${_idc++}';

String two(int n) => n.toString().padLeft(2, '0');
String dateKey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
String monthKey(DateTime d) => '${d.year}-${two(d.month)}';
DateTime parseKey(String k) {
  final p = k.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime nextDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);
int daysIn(int y, int m) => DateTime(y, m + 1, 0).day;

/// ترتيب الأسبوع المصري (السبت أولاً). DateTime.weekday: الاثنين=1 ... الأحد=7
const List<int> weekOrder = [6, 7, 1, 2, 3, 4, 5];
const Set<int> schoolExcludedDays = {5, 6};
const Map<int, String> weekNames = {
  6: 'السبت',
  7: 'الأحد',
  1: 'الاثنين',
  2: 'الثلاثاء',
  3: 'الأربعاء',
  4: 'الخميس',
  5: 'الجمعة',
};
const Map<int, String> weekShort = {
  6: 'سبت',
  7: 'أحد',
  1: 'اثنين',
  2: 'ثلاثاء',
  3: 'أربعاء',
  4: 'خميس',
  5: 'جمعة',
};
const List<String> monthNames = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

String timeLabel(String t) {
  if (t.isEmpty) return '';
  final p = t.split(':');
  int h = int.parse(p[0]);
  final m = p[1];
  final suf = h >= 12 ? 'م' : 'ص';
  h = h % 12 == 0 ? 12 : h % 12;
  return '$h:$m $suf';
}

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;

class Schedule {
  List<int> days;
  String time;
  Map<int, String> times;
  Schedule({List<int>? days, this.time = '', Map<int, String>? times})
      : days = days ?? times?.keys.toList() ?? [],
        times = times ?? {};

  String timeFor(int day) => times[day] ?? time;

  Map<String, dynamic> toJson() => {
        'd': days,
        't': time,
        'times': times.map((day, value) => MapEntry(day.toString(), value)),
      };
  factory Schedule.fromJson(Map<String, dynamic>? j) {
    if (j == null) return Schedule();
    final times = Map<String, dynamic>.from(j['times'] ?? {});
    return Schedule(
      days: List<int>.from(j['d'] ?? []),
      time: (j['t'] ?? '') as String,
      times:
          times.map((day, value) => MapEntry(int.parse(day), value as String)),
    );
  }

  String get text {
    if (days.isEmpty) return 'بدون ميعاد';
    if (times.isEmpty) {
      final ds = weekOrder
          .where((d) => days.contains(d))
          .map((d) => weekNames[d]!)
          .join('، ');
      return time.isEmpty ? ds : '$ds • ${timeLabel(time)}';
    }
    return weekOrder
        .where(days.contains)
        .map((day) => timeFor(day).isEmpty
            ? weekNames[day]!
            : '${weekNames[day]} ${timeLabel(timeFor(day))}')
        .join('، ');
  }
}

class Profile {
  String name;
  String subject;
  List<int> workDays;
  Set<String> places; // school | center | private
  double schoolSalary;
  int remHour;
  int remMin;
  String startDate;

  Profile({
    this.name = '',
    this.subject = '',
    List<int>? workDays,
    Set<String>? places,
    this.schoolSalary = 0,
    this.remHour = 21,
    this.remMin = 0,
    String? startDate,
  })  : workDays = (workDays ?? [])
            .where((day) => !schoolExcludedDays.contains(day))
            .toList(),
        places = places ?? {},
        startDate = startDate ?? dateKey(DateTime.now());

  Map<String, dynamic> toJson() => {
        'name': name,
        'subject': subject,
        'workDays': workDays,
        'places': places.toList(),
        'salary': schoolSalary,
        'rh': remHour,
        'rm': remMin,
        'start': startDate,
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        name: (j['name'] ?? '') as String,
        subject: (j['subject'] ?? '') as String,
        workDays: List<int>.from(j['workDays'] ?? []),
        places: Set<String>.from(j['places'] ?? []),
        schoolSalary: _d(j['salary']),
        remHour: (j['rh'] ?? 21) as int,
        remMin: (j['rm'] ?? 0) as int,
        startDate: j['start'] as String?,
      );
}

class CenterStudent {
  String id;
  String name;
  CenterStudent({required this.id, required this.name});
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory CenterStudent.fromJson(Map<String, dynamic> j) =>
      CenterStudent(id: j['id'] as String, name: (j['name'] ?? '') as String);
}

class CenterStage {
  String id;
  String name;
  double price; // سعر الطالب في الشهر
  Schedule schedule;
  List<CenterStudent> students;
  CenterStage({
    required this.id,
    required this.name,
    this.price = 0,
    Schedule? schedule,
    List<CenterStudent>? students,
  })  : schedule = schedule ?? Schedule(),
        students = students ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'schedule': schedule.toJson(),
        'students': students.map((e) => e.toJson()).toList(),
      };
  factory CenterStage.fromJson(Map<String, dynamic> j) => CenterStage(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        price: _d(j['price']),
        schedule: Schedule.fromJson(j['schedule'] == null
            ? null
            : Map<String, dynamic>.from(j['schedule'])),
        students: ((j['students'] ?? []) as List)
            .map((e) => CenterStudent.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class CenterInfo {
  double rent;
  double secretary;
  double water;
  double electricity;
  List<CenterStage> stages;
  CenterInfo({
    this.rent = 0,
    this.secretary = 0,
    this.water = 0,
    this.electricity = 0,
    List<CenterStage>? stages,
  }) : stages = stages ?? [];

  double get monthlyExpenses => rent + secretary + water + electricity;

  Map<String, dynamic> toJson() => {
        'rent': rent,
        'secretary': secretary,
        'water': water,
        'electricity': electricity,
        'stages': stages.map((e) => e.toJson()).toList(),
      };
  factory CenterInfo.fromJson(Map<String, dynamic> j) => CenterInfo(
        rent: _d(j['rent']),
        secretary: _d(j['secretary']),
        water: _d(j['water']),
        electricity: _d(j['electricity']),
        stages: ((j['stages'] ?? []) as List)
            .map((e) => CenterStage.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class PrivateStudent {
  String id;
  String name;
  String grade;
  double price; // سعر الحصة أو سعر ٨ حصص حسب perPack
  bool perPack;
  Schedule schedule;
  int paidSessions;
  PrivateStudent({
    required this.id,
    required this.name,
    this.grade = '',
    this.price = 0,
    this.perPack = false,
    Schedule? schedule,
    this.paidSessions = 0,
  }) : schedule = schedule ?? Schedule();

  double get perSession => perPack ? price / 8 : price;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'grade': grade,
        'price': price,
        'pack': perPack,
        'schedule': schedule.toJson(),
        'paid': paidSessions,
      };
  factory PrivateStudent.fromJson(Map<String, dynamic> j) => PrivateStudent(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        grade: (j['grade'] ?? '') as String,
        price: _d(j['price']),
        perPack: (j['pack'] ?? false) as bool,
        schedule: Schedule.fromJson(j['schedule'] == null
            ? null
            : Map<String, dynamic>.from(j['schedule'])),
        paidSessions: (j['paid'] ?? 0) as int,
      );
}

class Payment {
  String id;
  String kind; // center | private
  String studentId;
  String month; // yyyy-MM (للسنتر)
  String date; // yyyy-MM-dd
  double amount;
  Payment({
    required this.id,
    required this.kind,
    required this.studentId,
    required this.month,
    required this.date,
    required this.amount,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'sid': studentId,
        'month': month,
        'date': date,
        'amount': amount
      };
  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: j['id'] as String,
        kind: j['kind'] as String,
        studentId: j['sid'] as String,
        month: (j['month'] ?? '') as String,
        date: j['date'] as String,
        amount: _d(j['amount']),
      );
}

class DayLog {
  bool school;
  Set<String> stages;
  Set<String> students;
  bool confirmed;
  DayLog(
      {this.school = true,
      Set<String>? stages,
      Set<String>? students,
      this.confirmed = false})
      : stages = stages ?? {},
        students = students ?? {};
  Map<String, dynamic> toJson() => {
        'school': school,
        'stages': stages.toList(),
        'students': students.toList(),
        'ok': confirmed,
      };
  factory DayLog.fromJson(Map<String, dynamic> j) => DayLog(
        school: (j['school'] ?? true) as bool,
        stages: Set<String>.from(j['stages'] ?? []),
        students: Set<String>.from(j['students'] ?? []),
        confirmed: (j['ok'] ?? false) as bool,
      );
}

class AppData {
  Profile? profile;
  bool setupDone = false;
  CenterInfo center = CenterInfo();
  List<PrivateStudent> students = [];
  List<Payment> payments = [];
  Map<String, DayLog> logs = {};

  AppData();

  Map<String, dynamic> toJson() => {
        'profile': profile?.toJson(),
        'setup': setupDone,
        'center': center.toJson(),
        'students': students.map((e) => e.toJson()).toList(),
        'payments': payments.map((e) => e.toJson()).toList(),
        'logs': logs.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory AppData.fromJson(Map<String, dynamic> j) {
    final d = AppData();
    if (j['profile'] != null) {
      d.profile = Profile.fromJson(Map<String, dynamic>.from(j['profile']));
    }
    d.setupDone = (j['setup'] ?? false) as bool;
    if (j['center'] != null) {
      d.center = CenterInfo.fromJson(Map<String, dynamic>.from(j['center']));
    }
    d.students = ((j['students'] ?? []) as List)
        .map((e) => PrivateStudent.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    d.payments = ((j['payments'] ?? []) as List)
        .map((e) => Payment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final logs = Map<String, dynamic>.from(j['logs'] ?? {});
    d.logs = logs.map(
        (k, v) => MapEntry(k, DayLog.fromJson(Map<String, dynamic>.from(v))));
    return d;
  }
}
