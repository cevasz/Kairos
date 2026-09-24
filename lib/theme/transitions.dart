import 'package:flutter/material.dart';

import 'motion.dart';

/// Transición de ruta de la app: opacidad más una subida corta.
///
/// Sustituye al deslizamiento lateral de Android, que arrastra 400 ms y no
/// existe en el prototipo. Bajo reduced-motion se queda en el fade del
/// contrato, sin desplazamiento: el `MotionGuard` lo resuelve igual que en
/// cualquier otro sitio.
class FadeRiseTransitionsBuilder extends PageTransitionsBuilder {
  const FadeRiseTransitionsBuilder();

  @override
  Duration get transitionDuration => MotionDurations.hero;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final guard = MotionGuard.of(context);
    final curved = CurvedAnimation(
      parent: animation,
      curve: guard.curve(MotionCurves.easeOutCubic),
      reverseCurve: guard.curve(MotionCurves.easeOutCubic),
    );
    final rise = guard.offset(MotionOffsets.pdfRowRise);
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, rise * (1 - curved.value)),
          child: child,
        ),
        child: child,
      ),
    );
  }
}

/// Cambio de estado de una card: el saliente se va por arriba, el entrante
/// sube. Es lo que usa Hoy cuando la card pasa de «sal en N» a «cancelada» o
/// a «nada más», y el panel de detalle en tablet al cambiar de materia.
///
/// El `child` tiene que llevar una `Key` distinta por estado; sin ella el
/// switcher no ve el cambio.
class StateSwitcher extends StatelessWidget {
  const StateSwitcher({
    required this.child,
    this.rise = MotionOffsets.timelineRise,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  final Widget child;
  final double rise;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final guard = MotionGuard.of(context);
    final offset = guard.offset(rise);
    return AnimatedSwitcher(
      duration: guard.duration(MotionDurations.base),
      switchInCurve: guard.curve(MotionCurves.easeOutCubic),
      switchOutCurve: guard.curve(MotionCurves.easeOutCubic),
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) {
        // El que entra sube desde abajo; el que sale se retira hacia arriba.
        final slide = Tween<Offset>(
          begin: Offset(0, offset),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: AnimatedBuilder(
            animation: slide,
            builder: (context, child) => Transform.translate(
              offset: slide.value * (animation.status == AnimationStatus.reverse ? -1 : 1),
              child: child,
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
