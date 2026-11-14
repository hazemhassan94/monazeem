// مُنظم - مكونات التصميم (زجاجي + حركة)
// تصميم حازم حسن

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class C {
  static const ink = Color(0xFF1B1F3B);
  static const sub = Color(0xFF6B7094);
  static const school = Color(0xFF5B5BD6);
  static const center = Color(0xFF12A594);
  static const priv = Color(0xFFFF7A59);
  static const sum = Color(0xFFF2A516);
  static const danger = Color(0xFFE5484D);
  static const ok = Color(0xFF30A46C);
  static const bg = Color(0xFFF7F7FD);
}

extension ColorA on Color {
  Color op(double o) => withAlpha((o * 255).round());
}

double parseNum(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in s.trim().split('')) {
    final i = ar.indexOf(ch);
    b.write(i >= 0 ? i.toString() : (ch == '٫' || ch == '،' ? '.' : ch));
  }
  return double.tryParse(b.toString()) ?? 0;
}

String money(double v) {
  final neg = v < 0;
  final s = v.abs().round().toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${neg ? '-' : ''}$b';
}

String numText(double v) => v == 0
    ? ''
    : (v == v.roundToDouble() ? v.round().toString() : v.toString());

/// خلفية بيضاء هادئة مع هالات ألوان تتحرك ببطء
class Backdrop extends StatefulWidget {
  final Widget child;
  const Backdrop({super.key, required this.child});
  @override
  State<Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<Backdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 16))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _blob(double x, double y, Color c, double size) => Align(
        alignment: Alignment(x, y),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [c.op(.30), c.op(0)]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: C.bg),
        AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final t = _c.value * 2 * math.pi;
            return Stack(
              fit: StackFit.expand,
              children: [
                _blob(-0.9 + 0.25 * math.sin(t), -0.85 + 0.15 * math.cos(t),
                    C.school, 380),
                _blob(1.0 + 0.1 * math.cos(t), -0.2 + 0.25 * math.sin(t),
                    C.center, 340),
                _blob(-0.3 + 0.3 * math.cos(t), 0.95 + 0.1 * math.sin(t),
                    C.priv, 400),
              ],
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

/// بطاقة زجاجية
class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? tint;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.tint,
    this.radius = 26,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [
          BoxShadow(
              color: C.ink.op(.07), blurRadius: 26, offset: const Offset(0, 12))
        ],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: (tint ?? Colors.white).op(.58),
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  borderRadius: br,
                  border: Border.all(color: Colors.white.op(.95), width: 1.2),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ظهور متدرج (حركة دخول)
class Rise extends StatelessWidget {
  final int i;
  final Widget child;
  const Rise({super.key, this.i = 0, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + i * 90),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 26 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

class Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback? onTap;
  final bool filled;
  const Pill({
    super.key,
    required this.label,
    this.icon,
    this.color = C.school,
    this.onTap,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = filled ? Colors.white : color;
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient:
                filled ? LinearGradient(colors: [color, color.op(.78)]) : null,
            color: filled ? null : color.op(.12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6)
              ],
              Text(label,
                  style: TextStyle(
                      color: fg, fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

class GField extends StatelessWidget {
  final TextEditingController c;
  final String label;
  final bool number;
  final int lines;
  final IconData? icon;
  const GField({
    super.key,
    required this.c,
    required this.label,
    this.number = false,
    this.lines = 1,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: c,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : (lines > 1 ? TextInputType.multiline : TextInputType.text),
      minLines: lines,
      maxLines: lines,
      style: const TextStyle(color: C.ink, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon, color: C.sub),
        filled: true,
        fillColor: Colors.white.op(.75),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none),
      ),
    );
  }
}

class DayChips extends StatelessWidget {
  final List<int> selected;
  final ValueChanged<List<int>> onChanged;
  final Color color;
  final Set<int> excludedDays;
  const DayChips({
    super.key,
    required this.selected,
    required this.onChanged,
    this.color = C.school,
    this.excludedDays = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: weekOrderList.where((d) => !excludedDays.contains(d)).map((d) {
        final on = selected.contains(d);
        return ChoiceChip(
          label: Text(weekNamesMap[d]!),
          selected: on,
          showCheckmark: false,
          selectedColor: color,
          backgroundColor: Colors.white.op(.75),
          side: BorderSide.none,
          shape: const StadiumBorder(),
          labelStyle: TextStyle(
              color: on ? Colors.white : C.ink, fontWeight: FontWeight.w700),
          onSelected: (v) {
            final l = List<int>.from(selected);
            if (v) {
              l.add(d);
            } else {
              l.remove(d);
            }
            onChanged(l);
          },
        );
      }).toList(),
    );
  }
}

// مرجع للقيم من models (لتفادي استيراد دائري في هذا الملف)
const List<int> weekOrderList = [6, 7, 1, 2, 3, 4, 5];
const Map<int, String> weekNamesMap = {
  6: 'السبت',
  7: 'الأحد',
  1: 'الاثنين',
  2: 'الثلاثاء',
  3: 'الأربعاء',
  4: 'الخميس',
  5: 'الجمعة',
};

Future<T?> glassSheet<T>(
    BuildContext context, Widget Function(BuildContext) builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .92),
        decoration: const BoxDecoration(
          color: C.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
        ),
        child: SafeArea(top: false, child: builder(ctx)),
      ),
    ),
  );
}

class SheetBody extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const SheetBody({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                  color: C.sub.op(.3), borderRadius: BorderRadius.circular(3)),
            ),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: C.ink)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class Label extends StatelessWidget {
  final String text;
  const Label(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: C.sub, fontSize: 13)),
      );
}

Future<void> numberDialog(BuildContext context, String title, double initial,
    ValueChanged<double> onSave) async {
  final c = TextEditingController(text: numText(initial));
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(title),
      content: GField(
          c: c, label: 'المبلغ', number: true, icon: Icons.payments_rounded),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            onSave(parseNum(c.text));
            Navigator.pop(ctx);
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
}

Future<bool> confirmDialog(
    BuildContext context, String title, String body) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لأ')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: C.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('أيوه'),
        ),
      ],
    ),
  );
  return r ?? false;
}
