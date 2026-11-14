// مُنظم - شاشة التسجيل وجمع بيانات الشغل
// تصميم حازم حسن

import 'package:flutter/material.dart';
import 'app_state.dart';
import 'models.dart';
import 'sheets.dart';
import 'ui.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  int step = 0;
  final name = TextEditingController();
  final subject = TextEditingController();
  List<int> days = [];
  Set<String> places = {};
  final salary = TextEditingController();
  final rent = TextEditingController();
  final sec = TextEditingController();
  final water = TextEditingController();
  final elec = TextEditingController();
  bool _inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    final st = AppScope.read(context);
    final p = st.data.profile;
    if (p != null) {
      name.text = p.name;
      subject.text = p.subject;
      days = p.workDays.where((d) => !schoolExcludedDays.contains(d)).toList();
      places = Set<String>.from(p.places);
      salary.text = numText(p.schoolSalary);
    }
    final c = st.data.center;
    rent.text = numText(c.rent);
    sec.text = numText(c.secretary);
    water.text = numText(c.water);
    elec.text = numText(c.electricity);
  }

  @override
  void dispose() {
    for (final c in [name, subject, salary, rent, sec, water, elec]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get steps => [
        'basics',
        for (final k in const ['school', 'center', 'private'])
          if (places.contains(k)) k,
      ];

  void _applyStep(AppState st) {
    final key = steps[step];
    if (key == 'basics') {
      final old = st.data.profile;
      st.data.profile = Profile(
        name: name.text.trim(),
        subject: subject.text.trim(),
        workDays: List<int>.from(days),
        places: Set<String>.from(places),
        schoolSalary: old?.schoolSalary ?? 0,
        remHour: old?.remHour ?? 21,
        remMin: old?.remMin ?? 0,
        startDate: old?.startDate,
      );
    } else if (key == 'school') {
      st.p.schoolSalary = parseNum(salary.text);
    } else if (key == 'center') {
      final c = st.data.center;
      c.rent = parseNum(rent.text);
      c.secretary = parseNum(sec.text);
      c.water = parseNum(water.text);
      c.electricity = parseNum(elec.text);
    }
    st.save();
  }

  void _next(AppState st) {
    if (step == 0) {
      if (name.text.trim().isEmpty || days.isEmpty || places.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('اكتب الاسم واختار أيام العمل ومكان واحد على الأقل')),
        );
        return;
      }
    }
    _applyStep(st);
    if (step == steps.length - 1) {
      st.data.setupDone = true;
      st.save();
    } else {
      setState(() => step++);
    }
  }

  void _back() {
    if (step > 0) setState(() => step--);
  }

  Widget _basics() {
    Widget tile(String key, String title, IconData icon, Color color) {
      final on = places.contains(key);
      return Expanded(
        child: GestureDetector(
          onTap: () =>
              setState(() => on ? places.remove(key) : places.add(key)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: on
                  ? LinearGradient(
                      colors: [color, color.op(.7)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft)
                  : null,
              color: on ? null : Colors.white.op(.7),
            ),
            child: Column(
              children: [
                Icon(icon, color: on ? Colors.white : color, size: 28),
                const SizedBox(height: 6),
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: on ? Colors.white : C.ink)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Rise(
            child: GField(c: name, label: 'الاسم', icon: Icons.person_rounded)),
        const SizedBox(height: 12),
        Rise(
            i: 1,
            child: GField(
                c: subject, label: 'المادة', icon: Icons.menu_book_rounded)),
        const Label('أيام العمل'),
        Rise(
          i: 2,
          child: DayChips(
            selected: days,
            excludedDays: schoolExcludedDays,
            onChanged: (v) => setState(() => days = v),
          ),
        ),
        const Label('بتشتغل فين؟ (اختار واحد أو أكتر)'),
        Rise(
          i: 3,
          child: Row(
            children: [
              tile('school', 'مدرسة', Icons.school_rounded, C.school),
              const SizedBox(width: 10),
              tile('center', 'سنتر', Icons.apartment_rounded, C.center),
              const SizedBox(width: 10),
              tile(
                  'private', 'برايفت', Icons.person_pin_circle_rounded, C.priv),
            ],
          ),
        ),
      ],
    );
  }

  Widget _school(AppState st) {
    final sal = parseNum(salary.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Rise(
          child: GField(
              c: salary,
              label: 'مرتب المدرسة الشهري',
              number: true,
              icon: Icons.payments_rounded),
        ),
        const SizedBox(height: 14),
        Rise(
          i: 1,
          child: Glass(
            tint: C.school.op(.12),
            child: Text(
              sal > 0
                  ? 'هيتحسب لك مرتب اليوم الواحد تلقائي حسب عدد أيام عملك في الشهر.'
                  : 'اكتب مرتبك وهنحسب لك اليومية تلقائي.',
              style: const TextStyle(color: C.ink, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _center(AppState st) {
    final stages = st.data.center.stages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Rise(
            child: GField(
                c: rent,
                label: 'الإيجار (شهري)',
                number: true,
                icon: Icons.home_work_rounded)),
        const SizedBox(height: 10),
        Rise(
            i: 1,
            child: GField(
                c: sec,
                label: 'السكرتارية',
                number: true,
                icon: Icons.support_agent_rounded)),
        const SizedBox(height: 10),
        Rise(
            i: 2,
            child: GField(
                c: water,
                label: 'المياه',
                number: true,
                icon: Icons.water_drop_rounded)),
        const SizedBox(height: 10),
        Rise(
            i: 3,
            child: GField(
                c: elec,
                label: 'الكهرباء',
                number: true,
                icon: Icons.bolt_rounded)),
        const Label('المراحل اللي بتشتغلها'),
        for (final s in stages)
          Glass(
            margin: const EdgeInsets.only(bottom: 10),
            onTap: () => stageSheet(context, edit: s),
            child: Row(
              children: [
                const Icon(Icons.layers_rounded, color: C.center),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, color: C.ink)),
                      Text(
                        '${money(s.price)} ج • ${s.students.length} طالب • ${s.schedule.text}',
                        style: const TextStyle(color: C.sub, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Pill(
            label: 'إضافة مرحلة',
            icon: Icons.add_rounded,
            color: C.center,
            filled: false,
            onTap: () => stageSheet(context)),
      ],
    );
  }

  Widget _private(AppState st) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Label('طلاب البرايفت'),
        for (final s in st.data.students)
          Glass(
            margin: const EdgeInsets.only(bottom: 10),
            onTap: () => privateSheet(context, edit: s),
            child: Row(
              children: [
                const Icon(Icons.person_rounded, color: C.priv),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, color: C.ink)),
                      Text(
                        '${s.grade.isEmpty ? '' : '${s.grade} • '}${money(s.price)} ج ${s.perPack ? 'لكل ٨ حصص' : 'للحصة'} • ${s.schedule.text}',
                        style: const TextStyle(color: C.sub, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Pill(
            label: 'إضافة طالب',
            icon: Icons.add_rounded,
            color: C.priv,
            filled: false,
            onTap: () => privateSheet(context)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final key = steps[step];
    final titles = {
      'basics': 'نبدأ بالتعارف',
      'school': 'المدرسة',
      'center': 'السنتر',
      'private': 'البرايفت',
    };
    final subs = {
      'basics': 'بياناتك الأساسية',
      'school': 'مرتبك من المدرسة',
      'center': 'مصاريف السنتر والمراحل',
      'private': 'ضيف طلابك واحد واحد',
    };
    Widget body;
    switch (key) {
      case 'school':
        body = _school(st);
        break;
      case 'center':
        body = _center(st);
        break;
      case 'private':
        body = _private(st);
        break;
      default:
        body = _basics();
    }
    final last = step == steps.length - 1;

    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (int i = 0; i < steps.length; i++)
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 6,
                              margin: const EdgeInsetsDirectional.only(end: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                color: i <= step ? C.school : C.sub.op(.2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(titles[key]!,
                        style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: C.ink)),
                    Text(subs[key]!,
                        style: const TextStyle(
                            color: C.sub, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: KeyedSubtree(key: ValueKey(key), child: body),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                child: Row(
                  children: [
                    if (step > 0) ...[
                      Pill(
                          label: 'السابق',
                          icon: Icons.arrow_back_rounded,
                          color: C.sub,
                          filled: false,
                          onTap: _back),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Pill(
                        label: last ? 'ابدأ استخدام مُنظم' : 'التالي',
                        icon: last
                            ? Icons.rocket_launch_rounded
                            : Icons.arrow_forward_rounded,
                        color: C.school,
                        onTap: () => _next(st),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
