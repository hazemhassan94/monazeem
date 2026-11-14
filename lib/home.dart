// مُنظم - الشاشة الرئيسية + شريط التنقل الزجاجي + تذكيرات الحصص
// تصميم حازم حسن

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_state.dart';
import 'lesson_reminders.dart';
import 'models.dart';
import 'sheets.dart';
import 'summary.dart';
import 'tabs.dart';
import 'ui.dart';

class _TabDef {
  final String title;
  final IconData icon;
  final Color color;
  final Widget page;
  const _TabDef(this.title, this.icon, this.color, this.page);
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  int tab = 0;
  Timer? _timer;
  bool _prompted = false;
  String? _notificationFingerprint;
  bool _notificationWarningShown = false;
  bool _notificationSyncInProgress = false;
  bool _lessonNotificationsGranted = false;
  final Set<String> _upcomingReminderKeys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (mounted && s == AppLifecycleState.resumed) {
      _check();
      _syncNotifications(AppScope.read(context).data, force: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncNotifications(AppScope.of(context).data);
  }

  void _syncNotifications(AppData data, {bool force = false}) {
    final fingerprint = lessonReminderFingerprint(data);
    if (!force && fingerprint == _notificationFingerprint) return;
    if (_notificationSyncInProgress) return;
    _notificationFingerprint = fingerprint;
    if (kIsWeb) return;
    _notificationSyncInProgress = true;
    unawaited(
      LessonReminderService.instance.sync(data).then((granted) {
        if (mounted) setState(() => _lessonNotificationsGranted = granted);
        if (!mounted || granted || _notificationWarningShown) return;
        _notificationWarningShown = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'فعّل إشعارات مُنظم من إعدادات الجهاز لتصلك مواعيد الحصص.'),
          ),
        );
      }).catchError((Object error, StackTrace stack) {
        debugPrint('تعذر إعداد إشعارات الحصص: $error');
        _notificationWarningShown = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'تعذر إعداد إشعارات الحصص. راجع إعدادات الإشعارات بالجهاز.'),
            ),
          );
        }
        return null;
      }).whenComplete(() {
        _notificationSyncInProgress = false;
        if (!mounted) return;
        final latest = AppScope.read(context).data;
        if (lessonReminderFingerprint(latest) != _notificationFingerprint) {
          _syncNotifications(latest);
        }
      }),
    );
  }

  /// المنبه: لو عدّى ميعاد التذكير واليوم لسه ما اتسجلش، نفتح شاشة التسجيل مرة واحدة.
  void _check() {
    if (!mounted) return;
    final st = AppScope.read(context);
    setState(() {}); // لتحديث شريط التذكير
    _checkUpcomingLesson(st);
    if (st.reminderDue && !_prompted) {
      _prompted = true;
      openDayLog(context, st.today);
    }
    if (!st.reminderDue) _prompted = false;
  }

  void _checkUpcomingLesson(AppState st) {
    if (!kIsWeb && _lessonNotificationsGranted) return;
    final now = DateTime.now();
    final lesson = nextUpcomingLesson(st.data, now);
    if (lesson == null) return;
    final remindAt = lesson.startsAt.subtract(const Duration(minutes: 15));
    if (now.isBefore(remindAt) || !now.isBefore(lesson.startsAt)) return;
    final key =
        '${dateKey(lesson.startsAt)}-${lesson.startsAt.hour}:${lesson.startsAt.minute}-${lesson.description}';
    if (!_upcomingReminderKeys.add(key)) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('الحصة القادمة: ${lesson.description}'),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  List<_TabDef> _tabs(AppState st) => [
        if (st.has('school'))
          const _TabDef('المدرسة', Icons.school_rounded, C.school, SchoolTab()),
        if (st.has('center'))
          const _TabDef(
              'السنتر', Icons.apartment_rounded, C.center, CenterTab()),
        if (st.has('private'))
          const _TabDef('البرايفت', Icons.person_pin_circle_rounded, C.priv,
              PrivateTab()),
        const _TabDef('ملخص', Icons.insights_rounded, C.sum, SummaryTab()),
      ];

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final tabs = _tabs(st);
    if (tab >= tabs.length) tab = tabs.length - 1;
    final due = st.reminderDue;
    final now = DateTime.now();
    final upcoming = nextUpcomingLesson(st.data, now);

    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'أهلاً أ. ${st.p.name}',
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: C.ink),
                              ),
                              Text(
                                '${st.p.subject.isEmpty ? '' : '${st.p.subject} • '}${weekNames[now.weekday]} ${now.day} ${monthNames[now.month - 1]}',
                                style: const TextStyle(
                                    color: C.sub, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        Stack(
                          children: [
                            IconButton(
                              tooltip: 'سجّل حصص اليوم',
                              onPressed: () => openDayLog(context, st.today),
                              icon: const Icon(Icons.edit_calendar_rounded,
                                  color: C.ink),
                            ),
                            if (due)
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                      color: C.danger, shape: BoxShape.circle),
                                ),
                              ),
                          ],
                        ),
                        IconButton(
                          tooltip: 'الإعدادات',
                          onPressed: () => settingsSheet(context),
                          icon:
                              const Icon(Icons.settings_rounded, color: C.ink),
                        ),
                      ],
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: due
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                            child: Glass(
                              tint: C.sum.op(.25),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              radius: 22,
                              onTap: () => openDayLog(context, st.today),
                              child: const Row(
                                children: [
                                  Icon(Icons.alarm_rounded, color: C.ink),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                        'لسه ماسجلتش حصص النهاردة. اضغط وسجّلها.',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: C.ink)),
                                  ),
                                  Icon(Icons.chevron_right_rounded,
                                      color: C.ink),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  if (upcoming != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Glass(
                        tint: C.priv.op(.14),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        radius: 22,
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active_rounded,
                                color: C.priv),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'الحصة القادمة',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: C.ink),
                                  ),
                                  Text(
                                    '${upcoming.description} • ${upcoming.startsAt.day == now.day && upcoming.startsAt.month == now.month ? 'النهاردة' : weekNames[upcoming.startsAt.weekday]} ${timeLabel('${two(upcoming.startsAt.hour)}:${two(upcoming.startsAt.minute)}')}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: C.sub),
                                  ),
                                  const Text(
                                    kIsWeb
                                        ? 'التذكير داخل التطبيق أثناء فتحه'
                                        : 'هيجيلك إشعار قبل الحصة بربع ساعة',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: C.sub),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      switchInCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                                  begin: const Offset(0, .03), end: Offset.zero)
                              .animate(anim),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                          key: ValueKey(tabs[tab].title),
                          child: tabs[tab].page),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Glass(
                    radius: 34,
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        for (int i = 0; i < tabs.length; i++)
                          Expanded(
                            flex: i == tab ? 3 : 2,
                            child: _NavItem(
                              def: tabs[i],
                              active: i == tab,
                              onTap: () => setState(() => tab = i),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _TabDef def;
  final bool active;
  final VoidCallback onTap;
  const _NavItem(
      {required this.def, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: active
              ? LinearGradient(colors: [def.color, def.color.op(.75)])
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(def.icon, color: active ? Colors.white : C.sub, size: 24),
            if (active) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  def.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
