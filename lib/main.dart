// مُنظم - منظم حياة مدرس
// تصميم حازم حسن

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_state.dart';
import 'home.dart';
import 'onboarding.dart';
import 'ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MonazzemApp());
}

class MonazzemApp extends StatefulWidget {
  const MonazzemApp({super.key});
  @override
  State<MonazzemApp> createState() => _MonazzemAppState();
}

class _MonazzemAppState extends State<MonazzemApp> {
  final AppState st = AppState();

  @override
  void initState() {
    super.initState();
    st.load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: st,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'مُنظم',
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: C.school, surface: C.bg),
          scaffoldBackgroundColor: C.bg,
        ),
        home: const Root(),
      ),
    );
  }
}

class Root extends StatefulWidget {
  const Root({super.key});
  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  bool _minTime = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _minTime = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    Widget page;
    if (!_minTime || !st.loaded) {
      page = const Splash(key: ValueKey('splash'));
    } else if (!st.data.setupDone) {
      page = const Onboarding(key: ValueKey('onboarding'));
    } else {
      page = const Home(key: ValueKey('home'));
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 600), child: page);
  }
}

// ================= شاشة البداية: بيضاء =================
class Splash extends StatefulWidget {
  const Splash({super.key});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: c,
        builder: (_, __) {
          final t = c.value;
          double seg(double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0).toDouble();
          final title = Curves.easeOutCubic.transform(seg(.30, .65));
          final sub = Curves.easeOutCubic.transform(seg(.50, .80));
          final credit = Curves.easeOut.transform(seg(.70, 1.0));
          return SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: CustomPaint(painter: _OrbitPainter(t)),
                      ),
                      const SizedBox(height: 28),
                      Opacity(
                        opacity: title,
                        child: Transform.translate(
                          offset: Offset(0, 18 * (1 - title)),
                          child: const Text(
                            'مُنظم',
                            style: TextStyle(fontSize: 54, fontWeight: FontWeight.w900, color: C.ink, height: 1.1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Opacity(
                        opacity: sub,
                        child: Transform.translate(
                          offset: Offset(0, 14 * (1 - sub)),
                          child: const Text(
                            'منظم حياة مدرس',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.sub),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 28,
                  child: Opacity(
                    opacity: credit,
                    child: const Text(
                      'تصميم حازم حسن',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.sub),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  final double t;
  _OrbitPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const cols = [C.school, C.center, C.priv];
    for (int i = 0; i < 3; i++) {
      final r = size.width / 2 - i * 20.0 - 8;
      final grow = (t * 1.6 - i * .15).clamp(0.0, 1.0).toDouble();
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..color = cols[i];
      final start = -math.pi / 2 + t * math.pi * (i.isEven ? 1 : -1) + i * 1.1;
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), start, grow * math.pi * 1.5, false, paint);
    }
    final dot = 9 * Curves.elasticOut.transform(t.clamp(0.0, 1.0).toDouble());
    canvas.drawCircle(center, dot, Paint()..color = C.sum);
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) => old.t != t;
}
