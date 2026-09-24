import 'package:flutter/material.dart';

import '../../../../core/format/durations.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/motion.dart';
import '../../../../theme/tokens.g.dart';

/// Los minutos con roll tipo odómetro: al cambiar de minuto el carro de dígitos
/// se desplaza en vertical, no se reemplaza.
///
/// Bajo reduced-motion cae a un fade de 120 ms, que es lo que pide el contrato.
class OdometerMinutes extends StatelessWidget {
  const OdometerMinutes({
    required this.minutes,
    required this.color,
    super.key,
  });

  final int minutes;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final guard = MotionGuard.of(context);
    final style = AppTheme.styleOf(TypeTokens.displayM, color);
    // El tope es del componente, no de quien le pasa los minutos: por encima
    // de él el carro rompe el ancho del anillo. Pasada la hora se lee en
    // horas («4:05»), nunca «245».
    final shown = TimeSpans.compact(minutes.clamp(0, ComponentTokens.odometerMaxMinutes.round())).value;

    return AnimatedSwitcher(
      duration: guard.duration(MotionDurations.odometer),
      switchInCurve: guard.curve(MotionCurves.easeOutCubic),
      switchOutCurve: guard.curve(MotionCurves.easeOutCubic),
      transitionBuilder: (child, animation) {
        if (guard.reduced) return FadeTransition(opacity: animation, child: child);
        // El dígito entrante sube desde abajo y el saliente se va por arriba.
        final entering = animation.status != AnimationStatus.reverse;
        return ClipRect(
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, entering ? 1 : -1),
              end: Offset.zero,
            ).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
        );
      },
      child: Text(
        shown,
        key: ValueKey<String>(shown),
        style: style,
      ),
    );
  }
}
