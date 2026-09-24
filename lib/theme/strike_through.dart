import 'package:flutter/material.dart';

import 'motion.dart';
import 'tokens.g.dart';

/// Tachado que se dibuja de izquierda a derecha, con el texto perdiendo color
/// a la vez.
///
/// Una clase cancelada por el profe no desaparece: sigue siendo una clase que
/// existía, y el tachado es lo que cuenta esa historia. Aparecer de golpe la
/// convierte en un cambio de estilo; dibujarse la convierte en algo que acaba
/// de pasar, que es lo que de verdad ocurrió.
///
/// Vive en `theme/` y no en una feature porque la timeline de Hoy y la pestaña
/// de asistencia lo usan igual, y dos copias serían dos oportunidades de que
/// una se desincronice del contrato.
///
/// Bajo reduced-motion no se acorta el trazo: se salta. El `guard` colapsa la
/// duración al fade del contrato y la línea aparece entera, que es el estado
/// final correcto.
class StrikeThrough extends StatelessWidget {
  const StrikeThrough({
    required this.struck,
    required this.guard,
    required this.color,
    required this.struckColor,
    required this.child,
    super.key,
  });

  /// `true` mientras la clase esté cancelada. Al volver a `false` el trazo se
  /// deshace por donde vino.
  final bool struck;

  final MotionGuard guard;

  /// Color del texto sin tachar.
  final Color color;

  /// Color al que se desatura mientras el trazo avanza. Es también el color
  /// de la línea: el tachado no introduce un tono nuevo.
  final Color struckColor;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: struck ? 1.0 : 0.0),
      duration: guard.duration(MotionDurations.strike),
      curve: guard.curve(MotionCurves.easeOutCubic),
      builder: (context, t, child) {
        // El texto se apaga por delante del trazo, no después: cuando la línea
        // llega al final el color ya asentó.
        final faded = Color.lerp(color, struckColor, t) ?? color;
        return CustomPaint(
          foregroundPainter: _StrikePainter(progress: t, color: struckColor),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: faded),
            child: child!,
          ),
        );
      },
      child: child,
    );
  }
}

class _StrikePainter extends CustomPainter {
  const _StrikePainter({required this.progress, required this.color});

  /// 0 sin tachar, 1 tachado entero.
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    // A media altura de la caja del texto, que es donde cae un lineThrough.
    final y = size.height / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = BorderTokens.hairline
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, y),
      Offset(size.width * progress.clamp(0.0, 1.0), y),
      paint,
    );
  }

  @override
  bool shouldRepaint(_StrikePainter old) =>
      old.progress != progress || old.color != color;
}
