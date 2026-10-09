import 'package:flutter/material.dart';
import '../theme/dash_themes.dart';

/// Shared physical-feeling UI kit for Tap Dash: chunky beveled buttons,
/// cards with soft shadows, section labels. Matches the arcade-toy art
/// direction (no neon, no generic Material look).
class DashKit {
  static TextStyle display(double size, DashThemeDef t,
      {Color? color, double? height}) {
    return TextStyle(
      fontSize: size,
      height: height,
      fontWeight: FontWeight.w900,
      color: color ?? t.onCard,
      letterSpacing: -0.5,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.18),
          offset: const Offset(0, 2),
          blurRadius: 0,
        ),
      ],
    );
  }

  static TextStyle label(double size, DashThemeDef t, {Color? color}) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: color ?? t.onCard.withValues(alpha: 0.75),
      letterSpacing: 0.6,
    );
  }

  /// Chunky arcade button with bevel + press squash.
  static Widget button({
    required DashThemeDef t,
    required String text,
    required VoidCallback onTap,
    Color? color,
    Color? textColor,
    double fontSize = 20,
    EdgeInsets padding =
        const EdgeInsets.symmetric(horizontal: 34, vertical: 16),
    bool enabled = true,
  }) {
    final c = color ?? t.accent;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: _SquashOnPress(
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: Colors.black.withValues(alpha: 0.22), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  offset: const Offset(0, 5),
                  blurRadius: 0,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.35),
                  offset: const Offset(0, 2),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                color: textColor ?? Colors.white,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    offset: const Offset(0, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget card({
    required DashThemeDef t,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    Color? color,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: Colors.black.withValues(alpha: 0.14), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            offset: const Offset(0, 6),
            blurRadius: 12,
          ),
        ],
      ),
      child: child,
    );
  }

  static Widget sectionTitle(String text, DashThemeDef t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Text(text.toUpperCase(), style: label(13, t)),
    );
  }
}

class _SquashOnPress extends StatefulWidget {
  final Widget child;
  const _SquashOnPress({required this.child});

  @override
  State<_SquashOnPress> createState() => _SquashOnPressState();
}

class _SquashOnPressState extends State<_SquashOnPress> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DasherPainter: the little toy runner character, drawn per style.
// Physical toy feel: soft ground shadow, body highlight, painted details.
// ---------------------------------------------------------------------------
class DasherPainter extends CustomPainter {
  final DasherStyleDef style;
  final double bounce; // 0..1 run-cycle offset for liveliness

  DasherPainter({required this.style, this.bounce = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Ground shadow.
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, h * 0.92), width: w * 0.62, height: h * 0.10),
      shadowPaint,
    );

    final hop = -h * 0.05 * bounce.abs();
    final bodyTop = h * 0.30 + hop;
    final bodyH = h * 0.58;
    final bodyW = w * 0.62;
    final r = (bodyW / 2) * style.roundness;

    // Body.
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx, bodyTop + bodyH / 2), width: bodyW, height: bodyH),
      Radius.circular(r),
    );
    canvas.drawRRect(
        bodyRect, Paint()..color = style.bodyDark); // outline-ish base
    final inner = RRect.fromRectAndRadius(
      bodyRect.outerRect.deflate(w * 0.045),
      Radius.circular(r * 0.9),
    );
    canvas.drawRRect(inner, Paint()..color = style.body);

    // Belly patch.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, bodyTop + bodyH * 0.66),
          width: bodyW * 0.52,
          height: bodyH * 0.34),
      Paint()..color = style.belly.withValues(alpha: 0.85),
    );

    // Racing stripes.
    if (style.stripes) {
      final stripe = Paint()..color = style.hat.withValues(alpha: 0.75);
      for (int i = -1; i <= 1; i++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(cx + i * bodyW * 0.18, bodyTop + bodyH * 0.32),
                width: bodyW * 0.07,
                height: bodyH * 0.5),
            const Radius.circular(4),
          ),
          stripe,
        );
      }
    }

    // Top highlight (glossy toy sheen).
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx - bodyW * 0.16, bodyTop + bodyH * 0.22),
          width: bodyW * 0.34,
          height: bodyH * 0.16),
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );

    // Eyes.
    final eyeY = bodyTop + bodyH * 0.42 + hop * 0.3;
    final eyePaint = Paint()..color = const Color(0xFF2B2118);
    canvas.drawCircle(Offset(cx - bodyW * 0.15, eyeY), w * 0.055, eyePaint);
    canvas.drawCircle(Offset(cx + bodyW * 0.15, eyeY), w * 0.055, eyePaint);
    final glint = Paint()..color = Colors.white;
    canvas.drawCircle(
        Offset(cx - bodyW * 0.15 + w * 0.018, eyeY - w * 0.018), w * 0.018, glint);
    canvas.drawCircle(
        Offset(cx + bodyW * 0.15 + w * 0.018, eyeY - w * 0.018), w * 0.018, glint);

    // Smile.
    final smile = Paint()
      ..color = const Color(0xFF2B2118)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(cx, eyeY + bodyH * 0.10),
          width: bodyW * 0.34,
          height: bodyH * 0.20),
      0.35,
      3.14 - 0.7,
      false,
      smile,
    );

    // Beanie hat.
    final hatPaint = Paint()..color = style.hat;
    final hatH = h * 0.20;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, bodyTop + hop * 0.3 - hatH * 0.28),
            width: bodyW * 0.78,
            height: hatH),
        Radius.circular(hatH * 0.45),
      ),
      hatPaint,
    );
    // Hat ribbing.
    final rib = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..strokeWidth = w * 0.02;
    for (int i = -2; i <= 2; i++) {
      canvas.drawLine(
        Offset(cx + i * bodyW * 0.14, bodyTop - hatH * 0.62),
        Offset(cx + i * bodyW * 0.14, bodyTop + hatH * 0.06),
        rib,
      );
    }
    // Pom-pom.
    canvas.drawCircle(
        Offset(cx, bodyTop - hatH * 0.72), w * 0.075, hatPaint);
    canvas.drawCircle(
        Offset(cx - w * 0.02, bodyTop - hatH * 0.75),
        w * 0.045,
        Paint()..color = Colors.white.withValues(alpha: 0.5));

    // Little running legs.
    final legPaint = Paint()
      ..color = style.bodyDark
      ..strokeWidth = w * 0.07
      ..strokeCap = StrokeCap.round;
    final legY = bodyTop + bodyH;
    final swing = bounce * w * 0.10;
    canvas.drawLine(Offset(cx - w * 0.14, legY - h * 0.02),
        Offset(cx - w * 0.14 - swing, h * 0.90), legPaint);
    canvas.drawLine(Offset(cx + w * 0.14, legY - h * 0.02),
        Offset(cx + w * 0.14 + swing, h * 0.90), legPaint);

    // Waving arms.
    final armPaint = Paint()
      ..color = style.bodyDark
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round;
    final armY = bodyTop + bodyH * 0.5;
    canvas.drawLine(Offset(cx - bodyW * 0.48, armY),
        Offset(cx - bodyW * 0.48 - w * 0.10, armY - h * 0.10 + swing), armPaint);
    canvas.drawLine(Offset(cx + bodyW * 0.48, armY),
        Offset(cx + bodyW * 0.48 + w * 0.10, armY - h * 0.10 - swing), armPaint);
  }

  @override
  bool shouldRepaint(covariant DasherPainter old) =>
      old.style != style || old.bounce != bounce;
}

/// Animated dasher widget (gentle idle bounce).
class Dasher extends StatefulWidget {
  final DasherStyleDef style;
  final double size;
  const Dasher({super.key, required this.style, this.size = 120});

  @override
  State<Dasher> createState() => _DasherState();
}

class _DasherState extends State<Dasher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(
        size: Size(widget.size, widget.size * 1.15),
        painter: DasherPainter(style: widget.style, bounce: _c.value * 2 - 1),
      ),
    );
  }
}
