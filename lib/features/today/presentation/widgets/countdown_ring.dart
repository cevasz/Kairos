import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme/motion.dart';
import '../../../../theme/tokens.g.dart';

/// El anillo de cuenta regresiva. Es la única animación en loop de la app y por
/// eso va envuelta en RepaintBoundary y se pausa cuando la pantalla no se ve.
///
/// Respira a 4 s en normal y a 1,5 s en urgente. El paso entre los dos estados
/// dura 600 ms con easeOutBackSoft, que contrae el radio por debajo del destino
/// y lo deja asentar: es el «fotograma más apretado» del prototipo.
class CountdownRing extends StatefulWidget {
  const CountdownRing({
    required this.progress,
    required this.urgent,
    required this.child,
    this.active = true,
    super.key,
  });

  /// 0..1. Cuánto del margen se ha consumido.
  final double progress;
  final bool urgent;

  /// El contenido central: el odómetro de minutos y su unidad.
  final Widget child;

  /// Falso cuando la pantalla no está visible. Detiene el loop.
  final bool active;

  @override
  State<CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<CountdownRing> with TickerProviderStateMixin {
  late final AnimationController _breathe;
  late final AnimationController _urgency;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(vsync: this, duration: RingMotion.breathe);
    _urgency = AnimationController(
      vsync: this,
      duration: RingMotion.toUrgent,
      value: widget.urgent ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(CountdownRing old) {
    super.didUpdateWidget(old);
    if (old.urgent != widget.urgent) {
      _breathe.duration = widget.urgent ? RingMotion.breatheUrgent : RingMotion.breathe;
      if (widget.urgent) {
        _urgency.forward();
      } else {
        _urgency.reverse();
      }
    }
    if (old.active != widget.active) _syncLoop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoop();
  }

  void _syncLoop() {
    final guard = MotionGuard.of(context);
    // Bajo reduced-motion el anillo queda estático, no acelerado.
    if (!guard.allows('ring.breathe') || !widget.active) {
      _breathe.stop();
      _breathe.value = 0;
      return;
    }
    if (!_breathe.isAnimating) _breathe.repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathe.dispose();
    _urgency.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final guard = MotionGuard.of(context);

    return RepaintBoundary(
      child: SizedBox.square(
        dimension: RingTokens.countdownDiameter,
        child: AnimatedBuilder(
          animation: Listenable.merge([_breathe, _urgency]),
          builder: (context, child) {
            final t = guard.curve(RingMotion.urgentCurve).transform(_urgency.value);
            // La curva sobrepasa: el radio baja de 43 antes de asentar ahí.
            final radius = RingMotion.radiusNormal +
                (RingMotion.radiusUrgent - RingMotion.radiusNormal) * t;
            final scale = 1 +
                RingTokens.countdownBreatheScale *
                    RingMotion.breatheCurve.transform(_breathe.value);

            return Transform.scale(
              scale: guard.reduced ? 1.0 : scale,
              child: CustomPaint(
                painter: _RingPainter(
                  progress: widget.progress,
                  radius: radius,
                  track: ColorTokens.surfaceRaised.of(b),
                  progressColor: Color.lerp(
                    ColorTokens.accentPrimary.of(b),
                    ColorTokens.accentUrgent.of(b),
                    t,
                  )!,
                ),
                child: Center(child: child),
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.radius,
    required this.track,
    required this.progressColor,
  });

  final double progress;
  final double radius;
  final Color track;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = RingTokens.countdownStroke
        ..color = track,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = RingTokens.countdownStroke
        ..strokeCap = StrokeCap.round
        ..color = progressColor,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.radius != radius ||
      old.progressColor != progressColor;
}
