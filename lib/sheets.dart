// مُنظم - النماذج المنبثقة: مرحلة السنتر، طالب برايفت، تسجيل اليوم، الإعدادات
// تصميم حازم حسن

import 'package:flutter/material.dart';
import 'app_state.dart';
import 'models.dart';
import 'ui.dart';

class TimeButton extends StatelessWidget {
  final String time;
  final ValueChanged<String> onChanged;
  const TimeButton({super.key, required this.time, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        TimeOfDay init = const TimeOfDay(hour: 16, minute: 0);
        if (time.isNotEmpty) {
          final p = time.split(':');
          init = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
        }
        final t = await showTimePicker(context: context, initialTime: init);
        if (t != null) onChanged('${two(t.hour)}:${two(t.minute)}');
      },
      icon: const Icon(Icons.schedule_rounded),
      label: Text(time.isEmpty ? 'حدد الميعاد' : timeLabel(time)),
      style: OutlinedButton.styleFrom(
        foregroundColor: C.ink,
        backgroundColor: Colors.white.op(.7),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

class _ScheduleEditor extends StatelessWidget {
  final String title;
  final Color color;
  final Map<int, String> times;
  final ValueChanged<Map<int, String>> onChanged;

  const _ScheduleEditor({
    required this.title,
    required this.color,
    required this.times,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = weekOrder.where(times.containsKey).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Label(title),
        DayChips(
          selected: selected,
          color: color,
          onChanged: (days) {
            onChanged({
              for (final day in days) day: times[day] ?? '',
            });
          },
        ),
        for (final day in selected)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    weekNames[day]!,
                    style: const TextStyle(
                        color: C.ink, fontWeight: FontWeight.w700),
                  ),
                ),
                TimeButton(
                  time: times[day] ?? '',
                  onChanged: (time) => onChanged({...times, day: time}),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ================= مرحلة السنتر =================
Future<void> stageSheet(BuildContext context, {CenterStage? edit}) {
  final st = AppScope.read(context);
  return glassSheet<void>(context, (ctx) => _StageForm(st: st, edit: edit));
}

class _StageForm extends StatefulWidget {
  final AppState st;
  final CenterStage? edit;
  const _StageForm({required this.st, this.edit});
  @override
  State<_StageForm> createState() => _StageFormState();
}

class _StageFormState extends State<_StageForm> {
  late final TextEditingController name =
      TextEditingController(text: widget.edit?.name ?? '');
  late final TextEditingController price = TextEditingController(
      text: widget.edit == null ? '' : numText(widget.edit!.price));
  final TextEditingController names = TextEditingController();
  late Map<int, String> times = {
    for (final day in widget.edit?.schedule.days ?? [])
      day: widget.edit!.schedule.timeFor(day),
  };
  late Set<String> sessionDates = widget.edit == null
      ? {}
      : widget.st.centerStageSessionDates(widget.edit!.id);

  @override
  void dispose() {
    name.dispose();
    price.dispose();
    names.dispose();
    super.dispose();
  }

  void _save() {
    if (name.text.trim().isEmpty) return;
    final st = widget.st;
    CenterStage stage;
    if (widget.edit != null) {
      stage = widget.edit!;
      stage.name = name.text.trim();
      stage.price = parseNum(price.text);
      stage.schedule = Schedule(days: times.keys.toList(), times: times);
      st.setCenterStageSessionDates(stage.id, sessionDates);
    } else {
      stage = CenterStage(
        id: newId(),
        name: name.text.trim(),
        price: parseNum(price.text),
        schedule: Schedule(days: times.keys.toList(), times: times),
      );
      st.data.center.stages.add(stage);
      st.setCenterStageSessionDates(stage.id, sessionDates);
    }
    st.addStudentsToStage(stage, names.text.split('\n')); // يعمل save()
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.edit != null;
    return SheetBody(
      title: editing ? 'تعديل المرحلة' : 'مرحلة جديدة في السنتر',
      children: [
        GField(
            c: name,
            label: 'اسم المرحلة (مثال: تالتة ثانوي)',
            icon: Icons.layers_rounded),
        const SizedBox(height: 12),
        GField(
            c: price,
            label: 'سعر الطالب في الشهر',
            number: true,
            icon: Icons.payments_rounded),
        _ScheduleEditor(
          title: 'مواعيد المرحلة',
          color: C.center,
          times: times,
          onChanged: (v) => setState(() => times = v),
        ),
        const Label('الحصص السابقة'),
        const Text(
          'اختر التواريخ التي أُخذت فيها حصص المرحلة قبل بدء استخدام البرنامج.',
          style: TextStyle(color: C.sub, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Pill(
            label: '${sessionDates.length} حصة مسجلة • تعديل التواريخ',
            icon: Icons.event_available_rounded,
            color: C.center,
            filled: false,
            onTap: () async {
              final selected = await showDialog<Set<String>>(
                context: context,
                builder: (_) => _SessionHistoryPicker(
                  initialDates: sessionDates,
                  today: widget.st.today,
                ),
              );
              if (selected != null && mounted) {
                setState(() => sessionDates = selected);
              }
            },
          ),
        ),
        const Label('أضف الطلاب (اسم في كل سطر) - اختياري'),
        GField(c: names, label: 'أسماء الطلاب', lines: 4),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
                child: Pill(
                    label: 'حفظ',
                    icon: Icons.check_rounded,
                    color: C.center,
                    onTap: _save)),
            if (editing) ...[
              const SizedBox(width: 10),
              Pill(
                label: 'حذف',
                icon: Icons.delete_outline_rounded,
                color: C.danger,
                filled: false,
                onTap: () async {
                  final nav = Navigator.of(context);
                  final ok = await confirmDialog(context, 'حذف المرحلة',
                      'هيتم حذف المرحلة وطلابها ومدفوعاتهم. متأكد؟');
                  if (ok) {
                    widget.st.deleteStage(widget.edit!);
                    nav.pop();
                  }
                },
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ================= طالب برايفت =================
Future<void> privateSheet(BuildContext context, {PrivateStudent? edit}) {
  final st = AppScope.read(context);
  return glassSheet<void>(context, (ctx) => _PrivateForm(st: st, edit: edit));
}

class _PrivateForm extends StatefulWidget {
  final AppState st;
  final PrivateStudent? edit;
  const _PrivateForm({required this.st, this.edit});
  @override
  State<_PrivateForm> createState() => _PrivateFormState();
}

class _PrivateFormState extends State<_PrivateForm> {
  late final TextEditingController name =
      TextEditingController(text: widget.edit?.name ?? '');
  late final TextEditingController grade =
      TextEditingController(text: widget.edit?.grade ?? '');
  late final TextEditingController price = TextEditingController(
      text: widget.edit == null ? '' : numText(widget.edit!.price));
  late bool pack = widget.edit?.perPack ?? false;
  late Map<int, String> times = {
    for (final day in widget.edit?.schedule.days ?? [])
      day: widget.edit!.schedule.timeFor(day),
  };
  late Set<String> sessionDates =
      widget.edit == null ? {} : widget.st.privateSessionDates(widget.edit!.id);

  @override
  void dispose() {
    name.dispose();
    grade.dispose();
    price.dispose();
    super.dispose();
  }

  void _save() {
    if (name.text.trim().isEmpty) return;
    final st = widget.st;
    if (widget.edit != null) {
      final s = widget.edit!;
      s.name = name.text.trim();
      s.grade = grade.text.trim();
      s.price = parseNum(price.text);
      s.perPack = pack;
      s.schedule = Schedule(days: times.keys.toList(), times: times);
      st.setPrivateSessionDates(s.id, sessionDates);
    } else {
      final student = PrivateStudent(
        id: newId(),
        name: name.text.trim(),
        grade: grade.text.trim(),
        price: parseNum(price.text),
        perPack: pack,
        schedule: Schedule(days: times.keys.toList(), times: times),
      );
      st.data.students.add(student);
      st.setPrivateSessionDates(student.id, sessionDates);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.edit != null;
    return SheetBody(
      title: editing ? 'تعديل الطالب' : 'طالب برايفت جديد',
      children: [
        GField(c: name, label: 'الاسم', icon: Icons.person_rounded),
        const SizedBox(height: 12),
        GField(c: grade, label: 'الصف', icon: Icons.class_rounded),
        const Label('طريقة الحساب'),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: false, label: Text('بالحصة')),
            ButtonSegment(value: true, label: Text('كل ٨ حصص')),
          ],
          selected: {pack},
          onSelectionChanged: (s) => setState(() => pack = s.first),
        ),
        const SizedBox(height: 12),
        GField(
            c: price,
            label: pack ? 'ثمن الـ ٨ حصص' : 'ثمن الحصة',
            number: true,
            icon: Icons.payments_rounded),
        _ScheduleEditor(
          title: 'مواعيد الحصص',
          color: C.priv,
          times: times,
          onChanged: (v) => setState(() => times = v),
        ),
        const Label('الحصص السابقة'),
        const Text(
          'اختر التواريخ التي أُخذت فيها الحصص قبل بدء استخدام البرنامج. ستُضاف لسجل كل يوم.',
          style: TextStyle(color: C.sub, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Pill(
            label: '${sessionDates.length} حصة مسجلة • تعديل التواريخ',
            icon: Icons.event_available_rounded,
            color: C.priv,
            filled: false,
            onTap: () async {
              final selected = await showDialog<Set<String>>(
                context: context,
                builder: (_) => _SessionHistoryPicker(
                  initialDates: sessionDates,
                  today: widget.st.today,
                ),
              );
              if (selected != null && mounted) {
                setState(() => sessionDates = selected);
              }
            },
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
                child: Pill(
                    label: 'حفظ',
                    icon: Icons.check_rounded,
                    color: C.priv,
                    onTap: _save)),
            if (editing) ...[
              const SizedBox(width: 10),
              Pill(
                label: 'حذف',
                icon: Icons.delete_outline_rounded,
                color: C.danger,
                filled: false,
                onTap: () async {
                  final nav = Navigator.of(context);
                  final ok = await confirmDialog(
                      context, 'حذف الطالب', 'هيتم حذف الطالب وسجله. متأكد؟');
                  if (ok) {
                    widget.st.deletePrivate(widget.edit!);
                    nav.pop();
                  }
                },
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _SessionHistoryPicker extends StatefulWidget {
  final Set<String> initialDates;
  final DateTime today;

  const _SessionHistoryPicker({
    required this.initialDates,
    required this.today,
  });

  @override
  State<_SessionHistoryPicker> createState() => _SessionHistoryPickerState();
}

class _SessionHistoryPickerState extends State<_SessionHistoryPicker> {
  late DateTime month = DateTime(widget.today.year, widget.today.month);
  late final Set<String> selected = widget.initialDates
      .where((key) => key.compareTo(dateKey(widget.today)) <= 0)
      .toSet();

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final leadingDays = (firstDay.weekday + 1) % 7;
    final count = daysIn(month.year, month.month);
    final cells = <Widget>[
      for (int i = 0; i < leadingDays; i++) const SizedBox(height: 40),
      for (int day = 1; day <= count; day++)
        _dayCell(DateTime(month.year, month.month, day)),
    ];

    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('تسجيل الحصص السابقة'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => setState(
                    () => month = DateTime(month.year, month.month - 1),
                  ),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text(
                  '${monthNames[month.month - 1]} ${month.year}',
                  style: const TextStyle(
                      color: C.ink, fontWeight: FontWeight.w800),
                ),
                IconButton(
                  onPressed: month.year == widget.today.year &&
                          month.month == widget.today.month
                      ? null
                      : () => setState(
                            () => month = DateTime(month.year, month.month + 1),
                          ),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            Row(
              children: [
                for (final day in weekOrder)
                  Expanded(
                    child: Center(
                      child: Text(
                        weekShort[day]!,
                        style: const TextStyle(
                            color: C.sub,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: cells,
            ),
            const SizedBox(height: 8),
            Text(
              'تم اختيار ${selected.length} حصة',
              style: const TextStyle(color: C.sub, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(selected.clear),
          child: const Text('مسح التحديد'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, Set<String>.from(selected)),
          child: const Text('تم'),
        ),
      ],
    );
  }

  Widget _dayCell(DateTime date) {
    final key = dateKey(date);
    final disabled = date.isAfter(widget.today);
    final isSelected = selected.contains(key);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        onTap: disabled
            ? null
            : () => setState(() {
                  if (isSelected) {
                    selected.remove(key);
                  } else {
                    selected.add(key);
                  }
                }),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? C.priv : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${date.day}',
            style: TextStyle(
              color: disabled
                  ? C.sub.op(.35)
                  : isSelected
                      ? Colors.white
                      : C.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ================= مصاريف السنتر =================
Future<void> expensesSheet(BuildContext context) {
  final st = AppScope.read(context);
  return glassSheet<void>(context, (ctx) => _ExpensesForm(st: st));
}

class _ExpensesForm extends StatefulWidget {
  final AppState st;
  const _ExpensesForm({required this.st});
  @override
  State<_ExpensesForm> createState() => _ExpensesFormState();
}

class _ExpensesFormState extends State<_ExpensesForm> {
  late final c = widget.st.data.center;
  late final rent = TextEditingController(text: numText(c.rent));
  late final sec = TextEditingController(text: numText(c.secretary));
  late final water = TextEditingController(text: numText(c.water));
  late final elec = TextEditingController(text: numText(c.electricity));

  @override
  void dispose() {
    rent.dispose();
    sec.dispose();
    water.dispose();
    elec.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetBody(
      title: 'مصاريف السنتر الشهرية',
      children: [
        GField(
            c: rent,
            label: 'الإيجار',
            number: true,
            icon: Icons.home_work_rounded),
        const SizedBox(height: 12),
        GField(
            c: sec,
            label: 'السكرتارية',
            number: true,
            icon: Icons.support_agent_rounded),
        const SizedBox(height: 12),
        GField(
            c: water,
            label: 'المياه',
            number: true,
            icon: Icons.water_drop_rounded),
        const SizedBox(height: 12),
        GField(
            c: elec, label: 'الكهرباء', number: true, icon: Icons.bolt_rounded),
        const SizedBox(height: 20),
        Pill(
          label: 'حفظ',
          icon: Icons.check_rounded,
          color: C.center,
          onTap: () {
            widget.st.setExpenses(
              rent: parseNum(rent.text),
              secretary: parseNum(sec.text),
              water: parseNum(water.text),
              electricity: parseNum(elec.text),
            );
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

// ================= تسجيل حصص اليوم =================
Future<void> openDayLog(BuildContext context, DateTime date) {
  final st = AppScope.read(context);
  return glassSheet<void>(context, (ctx) => _DayLogForm(st: st, date: date));
}

class _DayLogForm extends StatefulWidget {
  final AppState st;
  final DateTime date;
  const _DayLogForm({required this.st, required this.date});
  @override
  State<_DayLogForm> createState() => _DayLogFormState();
}

class _DayLogFormState extends State<_DayLogForm> {
  late DateTime date = widget.date;
  late bool school;
  late Set<String> stages;
  late Set<String> students;

  AppState get st => widget.st;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final l = st.logFor(date);
    if (l != null && l.confirmed) {
      school = l.school;
      stages = Set<String>.from(l.stages);
      students = Set<String>.from(l.students);
    } else {
      school = st.has('school') && st.isSchoolWorkday(date.weekday);
      stages = st.scheduledStages(date);
      students = st.scheduledStudents(date);
    }
  }

  void _move(int delta) {
    final n = DateTime(date.year, date.month, date.day + delta);
    if (n.isAfter(st.today)) return;
    setState(() {
      date = n;
      _load();
    });
  }

  Widget _check(
      String title, String sub, bool v, Color color, ValueChanged<bool> on) {
    return CheckboxListTile(
      value: v,
      onChanged: (x) => setState(() => on(x ?? false)),
      activeColor: color,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w700, color: C.ink)),
      subtitle: sub.isEmpty
          ? null
          : Text(sub, style: const TextStyle(color: C.sub, fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isToday = dateKey(date) == dateKey(st.today);
    final schedStages = st.scheduledStages(date);
    final schedStudents = st.scheduledStudents(date);
    final unrecordedStages = st.unrecordedScheduledStages(date);
    final unrecordedStudents = st.unrecordedScheduledStudents(date);
    final stageList = st.data.center.stages
        .where((s) => unrecordedStages.contains(s.id))
        .toList()
      ..sort((a, b) =>
          (schedStages.contains(b.id) ? 1 : 0) -
          (schedStages.contains(a.id) ? 1 : 0));
    final studentList = st.data.students
        .where((s) => unrecordedStudents.contains(s.id))
        .toList()
      ..sort((a, b) =>
          (schedStudents.contains(b.id) ? 1 : 0) -
          (schedStudents.contains(a.id) ? 1 : 0));

    return SheetBody(
      title: 'سجّل حصص اليوم',
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
                onPressed: () => _move(-1),
                icon: const Icon(Icons.chevron_left_rounded)),
            Text(
              '${isToday ? 'النهاردة • ' : ''}${weekNames[date.weekday]} ${date.day} ${monthNames[date.month - 1]}',
              style: const TextStyle(fontWeight: FontWeight.w800, color: C.ink),
            ),
            IconButton(
              onPressed: isToday ? null : () => _move(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        if (st.has('school') && st.isSchoolWorkday(date.weekday)) ...[
          const Label('المدرسة'),
          Glass(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child:
                _check('رحت المدرسة', '', school, C.school, (v) => school = v),
          ),
        ],
        if (st.has('center') && stageList.isNotEmpty) ...[
          const Label('السنتر'),
          Glass(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                for (final s in stageList)
                  _check(
                    s.name,
                    schedStages.contains(s.id)
                        ? 'ميعادها النهاردة • ${s.schedule.timeFor(date.weekday).isEmpty ? 'الوقت غير محدد' : timeLabel(s.schedule.timeFor(date.weekday))}'
                        : s.schedule.text,
                    stages.contains(s.id),
                    C.center,
                    (v) => v ? stages.add(s.id) : stages.remove(s.id),
                  ),
              ],
            ),
          ),
        ],
        if (st.has('center') && stageList.isEmpty && schedStages.isNotEmpty)
          const Text(
            'تم تسجيل حصص السنتر لهذا اليوم.',
            style: TextStyle(color: C.sub, fontWeight: FontWeight.w600),
          ),
        if (st.has('private') && studentList.isNotEmpty) ...[
          const Label('البرايفت'),
          Glass(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                for (final s in studentList)
                  _check(
                    s.name,
                    schedStudents.contains(s.id)
                        ? 'ميعاده النهاردة • ${s.schedule.timeFor(date.weekday).isEmpty ? 'الوقت غير محدد' : timeLabel(s.schedule.timeFor(date.weekday))}'
                        : s.schedule.text,
                    students.contains(s.id),
                    C.priv,
                    (v) => v ? students.add(s.id) : students.remove(s.id),
                  ),
              ],
            ),
          ),
        ],
        if (st.has('private') &&
            studentList.isEmpty &&
            schedStudents.isNotEmpty)
          const Text(
            'تم تسجيل حصص البرايفت لهذا اليوم.',
            style: TextStyle(color: C.sub, fontWeight: FontWeight.w600),
          ),
        const SizedBox(height: 20),
        Pill(
          label: 'تأكيد وحفظ',
          icon: Icons.check_circle_rounded,
          color: C.sum,
          onTap: () {
            st.saveDayLog(date,
                school: school, stages: stages, students: students);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

// ================= الإعدادات =================
Future<void> settingsSheet(BuildContext context) {
  final st = AppScope.read(context);
  return glassSheet<void>(context, (ctx) => _SettingsForm(st: st));
}

class _SettingsForm extends StatefulWidget {
  final AppState st;
  const _SettingsForm({required this.st});
  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  late final Profile p = widget.st.p;
  late final name = TextEditingController(text: p.name);
  late final subject = TextEditingController(text: p.subject);
  late List<int> days =
      p.workDays.where((day) => !schoolExcludedDays.contains(day)).toList();
  late Set<String> places = Set<String>.from(p.places);
  late String rem = '${two(p.remHour)}:${two(p.remMin)}';

  @override
  void dispose() {
    name.dispose();
    subject.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetBody(
      title: 'الإعدادات',
      children: [
        GField(c: name, label: 'الاسم', icon: Icons.person_rounded),
        const SizedBox(height: 12),
        GField(c: subject, label: 'المادة', icon: Icons.menu_book_rounded),
        const Label('أيام العمل (بدون الجمعة والسبت)'),
        DayChips(
          selected: days,
          excludedDays: schoolExcludedDays,
          onChanged: (v) => setState(() => days = v),
        ),
        const Label('بتشتغل فين؟'),
        Wrap(
          spacing: 8,
          children: [
            for (final e in const {
              'school': 'مدرسة',
              'center': 'سنتر',
              'private': 'برايفت'
            }.entries)
              FilterChip(
                label: Text(e.value),
                selected: places.contains(e.key),
                showCheckmark: false,
                selectedColor: C.school,
                backgroundColor: Colors.white.op(.75),
                side: BorderSide.none,
                labelStyle: TextStyle(
                  color: places.contains(e.key) ? Colors.white : C.ink,
                  fontWeight: FontWeight.w700,
                ),
                onSelected: (v) => setState(
                    () => v ? places.add(e.key) : places.remove(e.key)),
              ),
          ],
        ),
        const Label('منبه تسجيل الحصص آخر اليوم'),
        Align(
          alignment: Alignment.centerRight,
          child:
              TimeButton(time: rem, onChanged: (v) => setState(() => rem = v)),
        ),
        const SizedBox(height: 20),
        Pill(
          label: 'حفظ',
          icon: Icons.check_rounded,
          onTap: () {
            if (name.text.trim().isEmpty || places.isEmpty) return;
            p.name = name.text.trim();
            p.subject = subject.text.trim();
            p.workDays =
                days.where((day) => !schoolExcludedDays.contains(day)).toList();
            p.places = places;
            final r = rem.split(':');
            p.remHour = int.parse(r[0]);
            p.remMin = int.parse(r[1]);
            widget.st.save();
            Navigator.pop(context);
          },
        ),
        const SizedBox(height: 10),
        Pill(
          label: 'مسح كل البيانات',
          icon: Icons.delete_forever_rounded,
          color: C.danger,
          filled: false,
          onTap: () async {
            final nav = Navigator.of(context);
            final ok = await confirmDialog(context, 'مسح كل البيانات',
                'كل بياناتك هتتمسح من الجهاز ومش هترجع. متأكد؟');
            if (ok) {
              await widget.st.resetAll();
              nav.pop();
            }
          },
        ),
      ],
    );
  }
}
