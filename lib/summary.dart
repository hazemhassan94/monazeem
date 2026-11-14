// مُنظم - تبويب الملخص (يومي / أسبوعي / شهري / ترم)
// تصميم حازم حسن

import 'dart:async';
import 'package:flutter/material.dart';
import 'app_state.dart';
import 'models.dart';
import 'ui.dart';

class SummaryTab extends StatefulWidget {
  const SummaryTab({super.key});
  @override
  State<SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<SummaryTab> with WidgetsBindingObserver {
  Period period = Period.month;
  int off = 0;
  late DateTime _displayDate = DateTime.now();
  Timer? _dateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleDateRefresh();
  }

  @override
  void dispose() {
    _dateTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshDate();
  }

  void _scheduleDateRefresh() {
    _dateTimer?.cancel();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _dateTimer = Timer(midnight.difference(now), _refreshDate);
  }

  void _refreshDate() {
    if (!mounted) return;
    final now = DateTime.now();
    if (now.year != _displayDate.year ||
        now.month != _displayDate.month ||
        now.day != _displayDate.day) {
      setState(() => _displayDate = now);
    }
    _scheduleDateRefresh();
  }

  static const names = {
    Period.day: 'يومي',
    Period.week: 'أسبوعي',
    Period.month: 'شهري',
    Period.term: 'ترم',
  };

  List<MapEntry<String, double>> _buckets(AppState st, PeriodRange r) {
    final out = <MapEntry<String, double>>[];
    switch (period) {
      case Period.day:
        break;
      case Period.week:
        for (int i = 0; i < 7; i++) {
          final d = DateTime(r.from.year, r.from.month, r.from.day + i);
          if (d.isAfter(st.today)) break;
          out.add(MapEntry(weekShort[d.weekday]!, st.totals(d, d).earnedTotal));
        }
        break;
      case Period.month:
        final last =
            r.to.isAfter(st.today) && off == 0 ? st.today.day : r.to.day;
        int s = 1;
        while (s <= last) {
          final first = DateTime(r.from.year, r.from.month, s);
          final daysUntilFriday = (5 - first.weekday + 7) % 7;
          final e = (s + daysUntilFriday) > last ? last : s + daysUntilFriday;
          out.add(MapEntry(
            '$s-$e',
            st
                .totals(
                  DateTime(r.from.year, r.from.month, s),
                  DateTime(r.from.year, r.from.month, e),
                )
                .receivedTotal,
          ));
          s = e + 1;
        }
        break;
      case Period.term:
        DateTime m = DateTime(r.from.year, r.from.month, 1);
        while (!m.isAfter(r.to) && !m.isAfter(st.today)) {
          out.add(MapEntry(
            monthNames[m.month - 1],
            st.totals(m, DateTime(m.year, m.month + 1, 0)).earnedTotal,
          ));
          m = DateTime(m.year, m.month + 1, 1);
        }
        break;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final r = rangeFor(period, off, st.today);
    final t = st.totals(r.from, r.to);
    final monthly = period == Period.month;
    final displayedTotal = monthly ? t.receivedTotal : t.earnedTotal;
    final reconciliationRange =
        monthly && off == 0 ? rangeFor(Period.month, -1, st.today) : r;
    final reconciliationTotals = monthly
        ? st.totals(reconciliationRange.from, reconciliationRange.to)
        : t;
    final showReconciliation = monthly &&
        reconciliationRange.to.isBefore(st.today) &&
        reconciliationTotals.hasReconciliationDifference;
    final buckets = _buckets(st, r);

    double maxB = 1;
    for (final b in buckets) {
      if (b.value > maxB) maxB = b.value;
    }

    final parts = <_Part>[
      if (st.has('school'))
        _Part('المدرسة', monthly ? t.schoolIn : t.school, C.school),
      if (st.has('center'))
        _Part(
            'السنتر',
            (monthly ? t.centerIn : t.centerEarned) > 0
                ? (monthly ? t.centerIn : t.centerEarned)
                : 0,
            C.center),
      if (st.has('private'))
        _Part('البرايفت', monthly ? t.priv : t.privateEarned, C.priv),
    ];
    final sumParts = parts.fold<double>(0, (a, b) => a + b.value);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        Rise(
          child: Glass(
            padding: const EdgeInsets.all(6),
            radius: 30,
            child: Row(
              children: [
                for (final p in Period.values)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        period = p;
                        off = 0;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: period == p ? C.sum : Colors.transparent,
                        ),
                        child: Center(
                          child: Text(
                            names[p]!,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: period == p ? Colors.white : C.ink,
                            ),
                          ),
                        ),
                      ),
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
            tint: C.sum.op(.10),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                        onPressed: () => setState(() => off--),
                        icon: const Icon(Icons.chevron_left_rounded)),
                    Flexible(
                      child: Text(r.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, color: C.ink)),
                    ),
                    IconButton(
                      onPressed: off >= 0 ? null : () => setState(() => off++),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                Text(monthly ? 'صافي المقبوض في الشهر' : 'الدخل المكتسب',
                    style: const TextStyle(
                        color: C.sub, fontWeight: FontWeight.w700)),
                TweenAnimationBuilder<double>(
                  key: ValueKey('${period.name}$off'),
                  tween: Tween(begin: 0, end: displayedTotal),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Text(
                    money(v),
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      color: displayedTotal >= 0 ? C.ink : C.danger,
                    ),
                  ),
                ),
                const Text('جنيه',
                    style:
                        TextStyle(color: C.sub, fontWeight: FontWeight.w700)),
                if (sumParts > 0) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 14,
                      child: Row(
                        children: [
                          for (final p in parts)
                            if (p.value > 0)
                              Expanded(
                                flex: (p.value / sumParts * 1000)
                                    .round()
                                    .clamp(1, 1000)
                                    .toInt(),
                                child: Container(color: p.color),
                              ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (showReconciliation)
          Rise(
            i: 2,
            child: Glass(
              tint: C.danger.op(.08),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تنبيه فرق نهاية الشهر',
                    style:
                        TextStyle(color: C.danger, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    reconciliationRange.label,
                    style: const TextStyle(color: C.sub, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  for (final difference in <MapEntry<String, double>>[
                    MapEntry('المدرسة', reconciliationTotals.schoolDifference),
                    MapEntry('السنتر', reconciliationTotals.centerDifference),
                    MapEntry(
                        'البرايفت', reconciliationTotals.privateDifference),
                  ])
                    if (difference.value.abs() >= .01)
                      Text(
                        difference.value > 0
                            ? '${difference.key}: مستحق ${money(difference.value)} ج لم يتم تحصيلها.'
                            : '${difference.key}: المقبوض زائد عن المسجل بـ ${money(difference.value.abs())} ج.',
                        style: const TextStyle(
                            color: C.ink, fontWeight: FontWeight.w700),
                      ),
                  const SizedBox(height: 4),
                  Text(
                    'قيمة الشغل ${money(reconciliationTotals.school + reconciliationTotals.centerEarned + reconciliationTotals.privateEarned)} ج • المقبوض ${money(reconciliationTotals.schoolIn + reconciliationTotals.centerIn + reconciliationTotals.priv)} ج',
                    style: const TextStyle(color: C.sub, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        if (st.has('school'))
          Rise(
            i: 3,
            child: _Line(
              color: C.school,
              icon: Icons.school_rounded,
              title: 'المدرسة',
              value: monthly ? t.schoolIn : t.school,
              sub: monthly
                  ? 'مقبوض • قيمة الحضور ${money(t.school)} ج • ${t.schoolDays} يوم'
                  : '${t.schoolDays} يوم حضور',
            ),
          ),
        if (st.has('center'))
          Rise(
            i: 4,
            child: _Line(
              color: C.center,
              icon: Icons.apartment_rounded,
              title: 'السنتر (صافي دخل الحصص)',
              value: monthly ? t.centerIn - t.centerOut : t.center,
              sub:
                  'دخل الحصص ${money(t.centerEarned)} − مصاريف ${money(t.centerOut)} • مقبوض ${money(t.centerIn)} • ${t.centerSessions} حصة',
            ),
          ),
        if (st.has('private'))
          Rise(
            i: 5,
            child: _Line(
              color: C.priv,
              icon: Icons.person_pin_circle_rounded,
              title: 'البرايفت (قيمة الحصص)',
              value: monthly ? t.priv : t.privateEarned,
              sub:
                  'دخل الحصص ${money(t.privateEarned)} • مقبوض ${money(t.priv)} • ${t.privSessions} حصة',
            ),
          ),
        if (buckets.isNotEmpty) ...[
          const SizedBox(height: 4),
          Rise(
            i: 6,
            child: Glass(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('توزيع الدخل',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, color: C.ink)),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 150,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final b in buckets)
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(b.value == 0 ? '' : money(b.value),
                                    style: const TextStyle(
                                        fontSize: 9,
                                        color: C.sub,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                TweenAnimationBuilder<double>(
                                  key: ValueKey('${period.name}$off${b.key}'),
                                  tween: Tween(
                                      begin: 0,
                                      end: b.value <= 0 ? 0 : b.value / maxB),
                                  duration: const Duration(milliseconds: 700),
                                  curve: Curves.easeOutCubic,
                                  builder: (_, v, __) => Container(
                                    height: 4 + 90 * v,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [C.sum, C.sum.op(.45)],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(b.key,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: C.ink,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Part {
  final String name;
  final double value;
  final Color color;
  _Part(this.name, this.value, this.color);
}

class _Line extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final double value;
  final String sub;
  const _Line(
      {required this.color,
      required this.icon,
      required this.title,
      required this.value,
      required this.sub});

  @override
  Widget build(BuildContext context) {
    return Glass(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: color.op(.15), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: C.ink)),
                Text(sub, style: const TextStyle(color: C.sub, fontSize: 11)),
              ],
            ),
          ),
          Text('${money(value)} ج',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: value >= 0 ? color : C.danger)),
        ],
      ),
    );
  }
}
