import 'package:flutter/material.dart';

import 'tokens.g.dart';

export 'tokens.g.dart'
    show MotionCurves, MotionDurations, MotionOffsets, MotionStagger, ReducedMotion;

/// Toda animación de la app pasa por aquí.
///
/// Regla del proyecto: ningún `Duration` ni `Curve` mágico suelto en un widget.
/// Si ves `Duration(milliseconds: 300)` dentro de un widget, es un bug.
///
/// `MotionGuard` resuelve además el degradado por accesibilidad: cuando el
/// sistema pide menos movimiento, toda animación se convierte en un fade corto.
/// No es opcional y no se decide widget por widget.
class MotionGuard {
  const MotionGuard({required this.reduced});

  /// Lee `MediaQuery.disableAnimations`, que en Android refleja el ajuste
  /// «Quitar animaciones» y en iOS «Reducir movimiento».
  factory MotionGuard.of(BuildContext context) =>
      MotionGuard(reduced: MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  final bool reduced;

  /// Duración efectiva. Bajo reduced-motion todo colapsa al fade del contrato.
  Duration duration(Duration desired) => reduced ? ReducedMotion.duration : desired;

  /// Curva efectiva. Un fade no debe llevar rebote.
  Curve curve(Curve desired) => reduced ? Curves.linear : desired;

  /// Desplazamiento efectivo. Bajo reduced-motion nada se mueve en el eje:
  /// entra por opacidad y ya.
  double offset(double desired) => reduced ? 0 : desired;

  /// Escalonado efectivo. La cascada se vuelve una sola aparición conjunta.
  Duration stagger(Duration desired) => reduced ? Duration.zero : desired;

  /// ¿Puede correr esta animación? Las de la lista `disable` del contrato se
  /// omiten por completo, no se acortan.
  bool allows(String animationName) =>
      !reduced || !ReducedMotion.disabled.contains(animationName);

  /// Un loop bajo reduced-motion se congela en su primer fotograma. Aplica a la
  /// respiración del anillo y a las poses de la mascota.
  bool get allowsLoops => !reduced;
}

/// Retraso de la enésima tarjeta en una cascada.
///
/// La timeline entra con 40 ms de escalonado y 12 px de subida; el revelado del
/// PDF con 80 ms y 8 px. Los dos números salen del contrato.
Duration staggerDelay(Duration step, int index, {int cap = 12}) =>
    step * index.clamp(0, cap);

/// El estado urgente del anillo. Se expone como par duración/curva para que el
/// AnimationController de la cuenta regresiva no invente los suyos.
abstract final class RingMotion {
  static const Duration breathe = MotionDurations.breathe;
  static const Duration breatheUrgent = MotionDurations.breatheUrgent;
  static const Duration drain = MotionDurations.strike;
  static const Duration toUrgent = MotionDurations.urgentShift;

  static const Curve breatheCurve = MotionCurves.easeInOutSine;
  static const Curve urgentCurve = MotionCurves.easeOutBackSoft;

  /// Radios dibujados en el prototipo, no los de la prosa. easeOutBackSoft
  /// sobrepasa por debajo del radio urgente y asienta ahí, que reproduce el
  /// contrae-y-asienta descrito sin inventar una escala que el SVG no tiene.
  ///
  /// Los dos números salen del contrato; repetirlos aquí los dejaría fuera de
  /// sincronía la primera vez que cambien en `design/tokens.json`.
  static const double radiusNormal = RingTokens.countdownRadiusNormal;
  static const double radiusUrgent = RingTokens.countdownRadiusUrgent;
}
