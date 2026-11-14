// مُنظم - تبويبات المدرسة / السنتر / البرايفت
// تصميم حازم حسن

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'app_state.dart';
import 'models.dart';
import 'sheets.dart';
import 'ui.dart';

Widget _stat(String label, String value, Color color) => Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: C.sub, fontWeight: FontWeight.w600)),
        ],
      ),
    );

// ======================= المدرسة =======================
class SchoolTab extends StatefulWidget {
  const SchoolTab({super.key});

  @override
  State<SchoolTab> createState() => _SchoolTabState();
}

class _SchoolTabState extends State<SchoolTab> with WidgetsBindingObserver {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _unlocked = false;
  bool _authenticating = false;
  String? _authError;

  bool get _requiresFaceId =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _unlocked = !_requiresFaceId;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_requiresFaceId &&
        !_authenticating &&
        _unlocked &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused)) {
      setState(() => _unlocked = false);
    }
  }

  Future<bool> _unlockAmounts() async {
    if (!_requiresFaceId) return true;
    if (_authenticating) return false;
    setState(() {
      _authenticating = true;
      _authError = null;
    });
    try {
      final biometrics = await _auth.getAvailableBiometrics();
      if (!biometrics.contains(BiometricType.face)) {
        if (mounted) {
          setState(() {
            _authError = 'فعّل Face ID على الجهاز لعرض الأرقام.';
          });
        }
        return false;
      }
      final authenticated = await _auth.authenticate(
        localizedReason: 'تحقق من هويتك لعرض الدخل',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (!mounted) return false;
      setState(() {
        _unlocked = authenticated;
        if (!authenticated) _authError = 'لم يتم التحقق من Face ID.';
      });
      return authenticated;
    } on LocalAuthException catch (error) {
      if (mounted) {
        setState(() {
          _authError = 'تعذر التحقق من Face ID (${error.code.name}).';
        });
      }
      return false;
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final now = st.today;
    final schoolIncome = st.schoolAttended(now) ? st.schoolDaily(now) : 0.0;
    final privateIncome = st.privateDailyIncome(now);
    final daily = schoolIncome + privateIncome;
    final locked = _requiresFaceId && !_unlocked;
    final first = DateTime(now.year, now.month, 1);
    final workdays = <DateTime>[];
    for (int d = 1; d <= daysIn(now.year, now.month); d++) {
      final dt = DateTime(now.year, now.month, d);
      if (st.isSchoolWorkday(dt.weekday)) workdays.add(dt);
    }
    final t = st.totals(first, DateTime(now.year, now.month + 1, 0));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        Rise(
          child: Glass(
            tint: C.school.op(.10),
            child: Column(
              children: [
                const Text('دخل اليوم • المدرسة + حصص البرايفت',
                    style:
                        TextStyle(color: C.sub, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                if (locked)
                  Column(
                    children: [
                      const Icon(Icons.lock_rounded, color: C.school, size: 36),
                      const SizedBox(height: 8),
                      Pill(
                        label: _authenticating
                            ? 'جارٍ التحقق...'
                            : 'افتح الأرقام بـ Face ID',
                        icon: Icons.face_rounded,
                        color: C.school,
                        onTap: _authenticating ? null : _unlockAmounts,
                      ),
                      if (_authError != null) ...[
                        const SizedBox(height: 8),
                        Text(_authError!,
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(color: C.danger, fontSize: 12)),
                      ],
                    ],
                  )
                else ...[
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: daily),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => Text(
                      money(v),
                      style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          color: C.school,
                          height: 1.1),
                    ),
                  ),
                  const Text('جنيه في اليوم',
                      style:
                          TextStyle(color: C.sub, fontWeight: FontWeight.w600)),
                  Text(
                    'المدرسة ${money(schoolIncome)} ج + البرايفت ${money(privateIncome)} ج',
                    style: const TextStyle(color: C.sub, fontSize: 12),
                  ),
                  if (_requiresFaceId)
                    TextButton.icon(
                      onPressed: () => setState(() => _unlocked = false),
                      icon: const Icon(Icons.lock_outline_rounded, size: 16),
                      label: const Text('قفل الأرقام'),
                    ),
                ],
                const SizedBox(height: 14),
                Pill(
                  label:
                      'المرتب الشهري: ${locked ? '••••' : '${money(st.p.schoolSalary)} ج'}',
                  icon: Icons.edit_rounded,
                  color: C.school,
                  filled: false,
                  onTap: () async {
                    final authenticated = await _unlockAmounts();
                    if (!authenticated || !context.mounted) return;
                    await numberDialog(context, 'مرتب المدرسة الشهري',
                        st.p.schoolSalary, st.setSalary);
                  },
                ),
                const SizedBox(height: 8),
                Pill(
                  label: st.schoolSalaryReceived(monthKey(now))
                      ? 'تم تسجيل استلام مرتب الشهر'
                      : 'تسجيل استلام مرتب الشهر',
                  icon: st.schoolSalaryReceived(monthKey(now))
                      ? Icons.check_circle_rounded
                      : Icons.payments_rounded,
                  color: C.school,
                  filled: st.schoolSalaryReceived(monthKey(now)),
                  onTap: () => st.toggleSchoolSalaryReceived(
                    DateTime(now.year, now.month, 1),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Rise(
          i: 1,
          child: Glass(
            child: Row(
              children: [
                _stat('المقبوض الشهر ده',
                    locked ? '••••' : '${money(t.schoolIn)} ج', C.school),
                _stat('أيام حضور', '${t.schoolDays}', C.ok),
                _stat('أيام العمل في الشهر', '${workdays.length}', C.ink),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Rise(
          i: 2,
          child: Glass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('أيام ${monthNames[now.month - 1]}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: C.ink,
                        fontSize: 16)),
                const Text('اضغط على اليوم لو ماروحتش',
                    style: TextStyle(color: C.sub, fontSize: 12)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in workdays)
                      _DayDot(
                        date: d,
                        future: d.isAfter(now),
                        attended: st.schoolAttended(d),
                        onTap: d.isAfter(now) ? null : () => st.toggleSchool(d),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DayDot extends StatelessWidget {
  final DateTime date;
  final bool future;
  final bool attended;
  final VoidCallback? onTap;
  const _DayDot(
      {required this.date,
      required this.future,
      required this.attended,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color bg =
        future ? Colors.white.op(.5) : (attended ? C.school : C.danger.op(.12));
    final Color fg = future ? C.sub : (attended ? Colors.white : C.danger);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: future || attended ? Colors.transparent : C.danger.op(.5)),
        ),
        child: Column(
          children: [
            Text(weekShort[date.weekday]!,
                style: TextStyle(
                    fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
            Text('${date.day}',
                style: TextStyle(
                    fontSize: 18, color: fg, fontWeight: FontWeight.w900)),
            Icon(
              future
                  ? Icons.circle_outlined
                  : (attended ? Icons.check_rounded : Icons.close_rounded),
              size: 14,
              color: fg,
            ),
          ],
        ),
      ),
    );
  }
}

// ======================= السنتر =======================
class CenterTab extends StatefulWidget {
  const CenterTab({super.key});
  @override
  State<CenterTab> createState() => _CenterTabState();
}

class _CenterTabState extends State<CenterTab> {
  int off = 0;
  final Set<String> _open = {};
  bool _first = true;

  Future<void> _addStudents(AppState st, CenterStage s) async {
    final c = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('طلاب جدد في ${s.name}'),
        content: GField(c: c, label: 'اسم في كل سطر', lines: 4),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              st.addStudentsToStage(s, c.text.split('\n'));
              Navigator.pop(ctx);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    c.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final stages = st.data.center.stages;
    if (_first && stages.isNotEmpty) {
      _open.add(stages.first.id);
      _first = false;
    }
    final month = DateTime(st.today.year, st.today.month + off, 1);
    final mk = monthKey(month);
    double collected = 0;
    double expected = 0;
    for (final s in stages) {
      collected += st.paidCount(s, mk) * s.price;
      expected += s.students.length * s.price;
    }
    final exp = st.data.center.monthlyExpenses;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        Rise(
          child: Glass(
            tint: C.center.op(.10),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                        onPressed: () => setState(() => off--),
                        icon: const Icon(Icons.chevron_left_rounded)),
                    Text('${monthNames[month.month - 1]} ${month.year}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: C.ink)),
                    IconButton(
                      onPressed: off >= 0 ? null : () => setState(() => off++),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _stat('اتحصّل', '${money(collected)} ج', C.center),
                    _stat('المتوقع', '${money(expected)} ج', C.ink),
                    _stat('المصاريف', '${money(exp)} ج', C.danger),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('الصافي: ${money(collected - exp)} ج',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: collected - exp >= 0 ? C.ok : C.danger,
                            fontSize: 16)),
                    Pill(
                      label: 'المصاريف',
                      icon: Icons.tune_rounded,
                      color: C.center,
                      filled: false,
                      onTap: () => expensesSheet(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (stages.isEmpty)
          const Rise(
            i: 1,
            child: Glass(
                child: Text('لسه مفيش مراحل. ضيف أول مرحلة بالزرار تحت.',
                    style: TextStyle(color: C.sub))),
          ),
        for (int i = 0; i < stages.length; i++)
          Rise(
            i: i + 1,
            child: _StageCard(
              stage: stages[i],
              mk: mk,
              month: month,
              open: _open.contains(stages[i].id),
              onToggleOpen: () => setState(() {
                final id = stages[i].id;
                _open.contains(id) ? _open.remove(id) : _open.add(id);
              }),
              onAdd: () => _addStudents(st, stages[i]),
            ),
          ),
        const SizedBox(height: 6),
        Pill(
            label: 'إضافة مرحلة',
            icon: Icons.add_rounded,
            color: C.center,
            onTap: () => stageSheet(context)),
      ],
    );
  }
}

class _StageCard extends StatelessWidget {
  final CenterStage stage;
  final String mk;
  final DateTime month;
  final bool open;
  final VoidCallback onToggleOpen;
  final VoidCallback onAdd;
  const _StageCard({
    required this.stage,
    required this.mk,
    required this.month,
    required this.open,
    required this.onToggleOpen,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final total = stage.students.length;
    final paid = st.paidCount(stage, mk);
    final frac = total == 0 ? 0.0 : paid / total;

    return Glass(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(0),
      child: Column(
        children: [
          InkWell(
            onTap: onToggleOpen,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(stage.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                    color: C.ink)),
                            Text(
                                '${money(stage.price)} ج للطالب • $total طالب • ${stage.schedule.text}',
                                style: const TextStyle(
                                    color: C.sub, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => stageSheet(context, edit: stage),
                        icon: const Icon(Icons.edit_rounded,
                            size: 20, color: C.sub),
                      ),
                      Icon(
                          open
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: C.sub),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: frac),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, __) => LinearProgressIndicator(
                              value: v,
                              minHeight: 9,
                              backgroundColor: C.center.op(.14),
                              valueColor:
                                  const AlwaysStoppedAnimation(C.center),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('$paid / $total دفعوا',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: C.center,
                              fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      children: [
                        const Divider(height: 1),
                        for (final s in stage.students)
                          _StudentRow(
                            name: s.name,
                            paid: st.centerPaid(s.id, mk),
                            onToggle: () =>
                                st.toggleCenterPayment(stage, s, month),
                            onDelete: () async {
                              final ok = await confirmDialog(context,
                                  'حذف الطالب', 'حذف ${s.name} ومدفوعاته؟');
                              if (ok) st.deleteCenterStudent(stage, s);
                            },
                          ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Pill(
                              label: 'إضافة طلاب',
                              icon: Icons.person_add_alt_1_rounded,
                              color: C.center,
                              filled: false,
                              onTap: onAdd),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final String name;
  final bool paid;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  const _StudentRow(
      {required this.name,
      required this.paid,
      required this.onToggle,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      onLongPress: onDelete,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: paid ? C.center : Colors.transparent,
                border:
                    Border.all(color: paid ? C.center : C.sub.op(.4), width: 2),
              ),
              child: paid
                  ? const Icon(Icons.check_rounded,
                      size: 18, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: paid ? C.ink : C.ink.op(.85),
                  )),
            ),
            Text(paid ? 'دفع' : 'لم يدفع',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: paid ? C.ok : C.danger)),
          ],
        ),
      ),
    );
  }
}

// ======================= البرايفت =======================
class PrivateTab extends StatelessWidget {
  const PrivateTab({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final list = st.data.students;
    final now = st.today;
    final m = st.totals(
        DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0));
    int due = 0;
    for (final s in list) {
      final u = st.unpaidSessions(s);
      if (s.perPack ? u >= 8 : u > 0) due++;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        Rise(
          child: Glass(
            tint: C.priv.op(.10),
            child: Row(
              children: [
                _stat('الطلاب', '${list.length}', C.ink),
                _stat('اتحصّل الشهر ده', '${money(m.priv)} ج', C.priv),
                _stat('مستحقين دفع', '$due', due > 0 ? C.danger : C.ok),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (list.isEmpty)
          const Rise(
            i: 1,
            child: Glass(
                child: Text('لسه مفيش طلاب. ضيف أول طالب بالزرار تحت.',
                    style: TextStyle(color: C.sub))),
          ),
        for (int i = 0; i < list.length; i++)
          Rise(i: i + 1, child: _PrivateCard(s: list[i])),
        const SizedBox(height: 6),
        Pill(
            label: 'إضافة طالب',
            icon: Icons.add_rounded,
            color: C.priv,
            onTap: () => privateSheet(context)),
      ],
    );
  }
}

class _PrivateCard extends StatelessWidget {
  final PrivateStudent s;
  const _PrivateCard({required this.s});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final unpaid = st.unpaidSessions(s);
    final done = st.sessionsDone(s.id);
    final filled = unpaid.clamp(0, 8);
    final dueNow = s.perPack ? unpaid >= 8 : unpaid > 0;

    String status;
    Color statusColor;
    if (unpaid <= 0) {
      status = unpaid < 0 ? 'مدفوع • رصيد ${-unpaid} حصة' : 'مدفوع بالكامل';
      statusColor = C.ok;
    } else if (s.perPack && unpaid >= 8) {
      status = 'استحق دفع ٨ حصص';
      statusColor = C.danger;
    } else if (s.perPack) {
      status = '$unpaid من ٨ حصص';
      statusColor = C.priv;
    } else {
      status = '$unpaid حصة غير مدفوعة';
      statusColor = C.danger;
    }

    return Glass(
      margin: const EdgeInsets.only(bottom: 14),
      onTap: () => privateSheet(context, edit: s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: C.priv.op(.16),
                child: Text(s.name.isEmpty ? '؟' : s.name.substring(0, 1),
                    style: const TextStyle(
                        color: C.priv,
                        fontWeight: FontWeight.w900,
                        fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            color: C.ink)),
                    Text(
                        s.grade.isEmpty
                            ? s.schedule.text
                            : '${s.grade} • ${s.schedule.text}',
                        style: const TextStyle(color: C.sub, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${money(s.price)} ج',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, color: C.priv)),
                  Text(s.perPack ? 'لكل ٨ حصص' : 'للحصة',
                      style: const TextStyle(color: C.sub, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ٨ خانات = ٨ حصص
          Row(
            children: [
              for (int i = 0; i < 8; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 250 + i * 40),
                    height: 12,
                    margin: const EdgeInsetsDirectional.only(end: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: i < filled
                          ? (dueNow ? C.danger : C.priv)
                          : C.sub.op(.15),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text('$status  •  إجمالي الحصص: $done',
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
              Pill(
                label: s.perPack ? 'استلمت ٨ حصص' : 'استلمت الحصص',
                icon: Icons.payments_rounded,
                color: C.priv,
                onTap:
                    (s.perPack || unpaid > 0) ? () => st.payPrivate(s) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
