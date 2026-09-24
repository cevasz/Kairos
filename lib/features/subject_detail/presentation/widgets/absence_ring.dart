import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../domain/attendance/attendance.dart';
import '../../../../l10n/strings.g.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/motion.dart';
import '../../../../theme/tokens.g.dart';

/// El anillo de faltas: segmentado, un segmento por sesión de cupo.
///
/// Continuo es el de la cuenta regresiva; este va segmentado a propósito (1e).
/// Una falta es una unidad discreta y contarlas de un vistazo importa más que
/// ver una proporción.
///
/// Dos movimientos, los dos del contrato:
/// - al sumar una falta, el segmento entra con un rebote corto;
/// - al cruzar por primera vez a `risk`, el anillo entero da una sacudida de
///   4 px, una sola vez. El cruce lo decide `AttendanceCounter.shouldShake`,
///   no el widget: si lo decidiera el widget, se repetiría en cada rebuild.
class AbsenceRing extends StatefulWidget {
  const AbsenceRing({required this.tally, super.key});

  final AbsenceTally tally;

  @override
  State<AbsenceRing> createState() => _AbsenceRingState();
}

class _AbsenceRingState extends State<AbsenceRing> with SingleTickerProviderStateMixin {
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(vsync: this, duration: MotionDurations.strike);
  }

  @override
  void didUpdateWidget(covariant AbsenceRing old) {
    super.didUpdateWidget(old);
    if (AttendanceCounter.shouldShake(old.tally.state, widget.tally.state)) {
      final guard = MotionGuard.of(context);
      if (guard.allows('riskShake')) _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final guard = MotionGuard.of(context);
    final color = SemaphoreTokens.color[widget.tally.state]!.of(b);

    final ring = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: widget.tally.used.toDouble()),
      duration: guard.duration(MotionDurations.ring),
      curve: guard.curve(MotionCurves.easeOutBackBounce),
      builder: (context, filled, _) => CustomPaint(
        size: Size.square(RingTokens.absencesDiameter),
        painter: _AbsenceRingPainter(
          filled: filled,
          limit: widget.tally.limit,
          color: color,
          track: ColorTokens.surfaceRaised.of(b),
        ),
        child: SizedBox.square(
          dimension: RingTokens.absencesDiameter,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.tally.used}',
                  style: context.type(TypeTokens.displayM, color: color),
                ),
                Text(
                  SSubjectSheet.ofLimit(n: widget.tally.limit),
                  style: context.type(
                    TypeTokens.captionS,
                    color: ColorTokens.textTertiary.of(b),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) => Transform.translate(
          offset: Offset(_shakeOffset(_shake.value), 0),
          child: child,
        ),
        child: ring,
      ),
    );
  }

  /// Una sacudida amortiguada: dos idas y vueltas que se apagan. La amplitud
  /// sale de `motion.offsets.riskShake`.
  double _shakeOffset(double t) {
    if (t == 0 || t == 1) return 0;
    return math.sin(t * math.pi * 4) * MotionOffsets.riskShake * (1 - t);
  }
}

class _AbsenceRingPainter extends CustomPainter {
  const _AbsenceRingPainter({
    required this.filled,
    required this.limit,
    required this.color,
    required this.track,
  });

  /// Puede ser fraccionario mientras dura el rebote.
  final double filled;
  final int limit;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    if (limit <= 0) return;

    final stroke = RingTokens.absencesStroke;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    // El hueco entre segmentos se expresa en píxeles en el contrato; aquí se
    // convierte a radianes contra el radio real para que se vea igual en
    // cualquier densidad.
    final radius = rect.width / 2;
    final gap = RingTokens.absencesGap / radius;
    final segment = (2 * math.pi / limit) - gap;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    for (var i = 0; i < limit; i++) {
      // Se empieza arriba: la primera falta es la de las doce en punto.
      final start = -math.pi / 2 + i * (segment + gap);
      final progress = (filled - i).clamp(0.0, 1.0);

      paint.color = track;
      canvas.drawArc(rect, start, segment, false, paint);

      if (progress > 0) {
        paint.color = color;
        canvas.drawArc(rect, start, segment * progress, false, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AbsenceRingPainter old) =>
      old.filled != filled ||
      old.limit != limit ||
      old.color != color ||
      old.track != track;
}
