import 'package:flutter/material.dart';

import '../../../../theme/motion.dart';
import '../../../../theme/tokens.g.dart';

/// El visto de «asististe», dibujado trazo a trazo.
///
/// No es un icono que aparece: es una línea que se traza, primero el brazo
/// corto y después el largo. El gesto de marcar asistencia es el más repetido
/// de la app y es lo único que confirma que la app te oyó.
///
/// Bajo reduced-motion no se dibuja: aparece completo con un fade. Congelarlo
/// en el primer fotograma dejaría un visto a medias, que se leería como error.
class CheckMark extends StatelessWidget {
  const CheckMark({
    required this.checked,
    required this.color,
    this.size = IconTokens.sizeL,
    super.key,
  });

  final bool checked;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final guard = MotionGuard.of(context);

    if (!checked) return SizedBox.square(dimension: size);

    if (guard.reduced) {
      return _Fade(
        duration: guard.duration(MotionDurations.base),
        child: CustomPaint(
          size: Size.square(size),
          painter: _CheckPainter(progress: 1, color: color),
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      key: ValueKey(checked),
      tween: Tween(begin: 0, end: 1),
      duration: MotionDurations.base,
      curve: MotionCurves.easeOutCubic,
      builder: (context, t, _) => CustomPaint(
        size: Size.square(size),
        painter: _CheckPainter(progress: t, color: color),
      ),
    );
  }
}

class _Fade extends StatelessWidget {
  const _Fade({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        builder: (context, t, child) => Opacity(opacity: t, child: child),
        child: child,
      );
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Proporciones del visto: entra por el 22 % del ancho, dobla en el 42 % y
    // sale por el 80 %. Es la forma del icono del prototipo.
    final start = Offset(w * 0.22, h * 0.52);
    final elbow = Offset(w * 0.42, h * 0.72);
    final end = Offset(w * 0.80, h * 0.28);

    final shortLeg = (elbow - start).distance;
    final longLeg = (end - elbow).distance;
    final total = shortLeg + longLeg;
    final drawn = total * progress.clamp(0.0, 1.0);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(start.dx, start.dy);

    if (drawn <= shortLeg) {
      final t = shortLeg == 0 ? 0.0 : drawn / shortLeg;
      final p = Offset.lerp(start, elbow, t)!;
      path.lineTo(p.dx, p.dy);
    } else {
      path.lineTo(elbow.dx, elbow.dy);
      final t = longLeg == 0 ? 0.0 : (drawn - shortLeg) / longLeg;
      final p = Offset.lerp(elbow, end, t)!;
      path.lineTo(p.dx, p.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) =>
      old.progress != progress || old.color != color;
}
