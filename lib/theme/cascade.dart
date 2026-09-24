import 'package:flutter/material.dart';

import 'motion.dart';

/// Entrada en cascada: opacidad más una subida corta, escalonada por índice.
///
/// Es la misma animación que el contrato describe para la timeline de Hoy
/// (40 ms de escalonado, 12 px de subida, easeOutExpo). Vive aquí y no dentro
/// de una feature porque tres listas distintas la usan y tres copias serían
/// tres oportunidades de que una se desincronice del contrato.
///
/// El escalonado se topa a las primeras filas: más allá el retraso acumulado
/// deja de leerse como cascada y empieza a leerse como lentitud.
class CascadeIn extends StatelessWidget {
  const CascadeIn({
    required this.index,
    required this.guard,
    required this.child,
    this.step = MotionStagger.timeline,
    this.rise = MotionOffsets.timelineRise,
    this.scale = 1.0,
    super.key,
  });

  final int index;
  final MotionGuard guard;
  final Widget child;

  /// Escalonado entre filas. `MotionStagger.pdfRows` para el revelado del PDF.
  final Duration step;

  /// Subida en píxeles. Bajo reduced-motion la resuelve el guard a cero.
  final double rise;

  /// Escala inicial de la entrada. Cuando es menor que 1.0, el widget crece de
  /// [scale] a 1.0 simultáneamente con el fade+rise, produciendo un efecto de
  /// «pop» que realza cards importantes. En 1.0 el comportamiento es idéntico
  /// al anterior. Bajo reduced-motion se ignora (el guard ya colapsa el rise a
  /// cero, y la escala sería imperceptible de todos modos).
  final double scale;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration:
          guard.duration(MotionDurations.base) + guard.stagger(staggerDelay(step, index)),
      curve: guard.curve(MotionCurves.easeOutExpo),
      builder: (context, t, child) {
        // Escala efectiva: interpolamos de [scale] a 1.0 siguiendo la misma t.
        // Bajo reduced-motion el guard colapsa el rise, pero la escala también
        // debe apagarse para no introducir movimiento no deseado.
        final effectiveScale = guard.reduced ? 1.0 : (scale + (1.0 - scale) * t);
        return Opacity(
          opacity: t,
          child: Transform.scale(
            scale: effectiveScale,
            child: Transform.translate(
              offset: Offset(0, guard.offset(rise) * (1 - t)),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}
