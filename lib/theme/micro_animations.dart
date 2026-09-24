import 'package:flutter/material.dart';

import 'motion.dart';
import 'tokens.g.dart';

/// Cuatro micro-animaciones reutilizables del sistema de diseño de Kairós.
///
/// Todas las duraciones y curvas vienen de [MotionDurations] y [MotionCurves];
/// ninguna inventa valores propios. Todas respetan [MotionGuard]: bajo
/// reduced-motion se desactiva la animación vistosa y se conserva solo la
/// semántica (el botón sigue respondiendo al toque, etc.).

// ─────────────────────────────────────────────────────────────────────────────
// PressScaleButton
// ─────────────────────────────────────────────────────────────────────────────

/// Envuelve cualquier widget táctil con una escala 0.96 al presionar y 1.0 al
/// soltar. Usa [GestureDetector] para capturar los eventos de presión y
/// liberación, y un [AnimatedScale] con [MotionDurations.fast] y
/// [MotionCurves.easeOutCubic].
///
/// Bajo reduced-motion, la escala se omite por completo: el widget sigue
/// siendo totalmente interactivo.
///
/// ```dart
/// PressScaleButton(
///   pressedScale: 0.96,
///   child: FilledButton(onPressed: _doSomething, child: const Text('Ya voy')),
/// )
/// ```
class PressScaleButton extends StatefulWidget {
  const PressScaleButton({
    required this.child,
    this.pressedScale = 0.96,
    super.key,
  });

  final Widget child;

  /// Escala aplicada al presionar. El prototipo usa 0.96 para botones de acción
  /// principal y 0.97 para filas de lista.
  final double pressedScale;

  @override
  State<PressScaleButton> createState() => _PressScaleButtonState();
}

class _PressScaleButtonState extends State<PressScaleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final guard = MotionGuard.of(context);

    // Bajo reduced-motion devolvemos el hijo sin capas de animación.
    if (guard.reduced) return widget.child;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: guard.duration(MotionDurations.fast),
        curve: guard.curve(MotionCurves.easeOutCubic),
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NumberRollIn
// ─────────────────────────────────────────────────────────────────────────────

/// Anima un entero del valor anterior al nuevo con un slide+fade vertical, tipo
/// odómetro: si el número sube, el nuevo entra desde abajo; si baja, desde
/// arriba.
///
/// Usa [AnimatedSwitcher] con un [layoutBuilder] personalizado para que el
/// widget saliente y el entrante queden centrados verticalmente sin que el
/// contenedor salte de tamaño.
///
/// Duración: [MotionDurations.ring] (320 ms). Bajo reduced-motion, cambia el
/// valor instantáneamente con un fade corto.
class NumberRollIn extends StatefulWidget {
  const NumberRollIn({
    required this.value,
    required this.style,
    super.key,
  });

  final int value;
  final TextStyle? style;

  @override
  State<NumberRollIn> createState() => _NumberRollInState();
}

class _NumberRollInState extends State<NumberRollIn> {
  late int _previous;

  @override
  void initState() {
    super.initState();
    _previous = widget.value;
  }

  @override
  void didUpdateWidget(NumberRollIn old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _previous = old.value;
  }

  @override
  Widget build(BuildContext context) {
    final guard = MotionGuard.of(context);
    // El nuevo número sube si el valor aumentó, baja si disminuyó.
    final goingUp = widget.value > _previous;

    return AnimatedSwitcher(
      duration: guard.duration(MotionDurations.ring),
      switchInCurve: guard.curve(MotionCurves.easeOutCubic),
      switchOutCurve: guard.curve(MotionCurves.easeOutCubic),
      transitionBuilder: (child, animation) {
        // Bajo reduced-motion solo hacemos fade; sin desplazamiento.
        final offsetY = guard.reduced
            ? 0.0
            : (child.key == ValueKey(widget.value)
                ? (goingUp ? 1.0 : -1.0) // entrante
                : (goingUp ? -1.0 : 1.0)); // saliente

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: animation.drive(
              Tween(begin: Offset(0, offsetY * 0.4), end: Offset.zero),
            ),
            child: child,
          ),
        );
      },
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.center,
        children: [
          ...previousChildren,
          if (currentChild != null) currentChild,
        ],
      ),
      child: Text(
        '${widget.value}',
        key: ValueKey(widget.value),
        style: widget.style,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PulseHighlight
// ─────────────────────────────────────────────────────────────────────────────

/// Al pasar [highlighted] de `false` a `true`, hace un destello de fondo: el
/// color de acento con alpha 0x26 (≈ 15 %) aparece y desaparece en
/// [MotionDurations.urgentShift] (600 ms).
///
/// Es útil para señalar la fila «Siguiente» en la timeline cuando la clase
/// activa cambia. Bajo reduced-motion, no hay destello.
class PulseHighlight extends StatefulWidget {
  const PulseHighlight({
    required this.highlighted,
    required this.color,
    required this.child,
    super.key,
  });

  /// Cuando pasa a `true` dispara el pulso una sola vez.
  final bool highlighted;

  /// Color base del destello. Se usará con alpha 0x26 en el pico.
  final Color color;

  final Widget child;

  @override
  State<PulseHighlight> createState() => _PulseHighlightState();
}

class _PulseHighlightState extends State<PulseHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: MotionDurations.urgentShift,
      vsync: this,
    );
    // El destello sube rápido y baja suave.
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(PulseHighlight old) {
    super.didUpdateWidget(old);
    final guard = MotionGuard.of(context);
    if (!old.highlighted && widget.highlighted && guard.allows('pulseHighlight')) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guard = MotionGuard.of(context);
    if (guard.reduced) return widget.child;

    return AnimatedBuilder(
      animation: _fade,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          color: widget.color.withAlpha(
            (_fade.value * 0x26).round(), // 0x26 ≈ alpha 15 %
          ),
          borderRadius: BorderRadius.circular(RadiusTokens.control),
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ShimmerLoading
// ─────────────────────────────────────────────────────────────────────────────

/// Esqueleto de carga con un gradiente luminoso que recorre el contenedor en
/// bucle. Solo anima si [MediaQuery.disableAnimations] es `false`.
///
/// El gradiente tiene tres stops: opaco → translúcido → opaco. La duración del
/// loop es fija en 1400 ms (suficientemente suave para no llamar la atención).
///
/// No hay token de duración para shimmers; 1400 ms está entre
/// [MotionDurations.hero] (340 ms) y [MotionDurations.breathe] (4 000 ms), y
/// es el valor estándar de la industria para este patrón. Se declara aquí como
/// constante local, no como literal suelto en el build.
class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({
    required this.width,
    required this.height,
    this.borderRadius = RadiusTokens.card,
    super.key,
  });

  final double width;
  final double height;
  final double borderRadius;

  /// Duración del loop de shimmer. 1400 ms es el valor canónico de la industria
  /// para esqueletos de carga; no existe un token de proyecto para esto.
  static const Duration _loopDuration = Duration(milliseconds: 1400);

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: ShimmerLoading._loopDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guard = MotionGuard.of(context);
    final b = Theme.of(context).brightness;

    final baseColor = ColorTokens.surfaceRaised.of(b);
    final highlightColor = ColorTokens.surfaceBorder.of(b);

    // Sin animación: devolvemos solo el bloque de color base.
    if (guard.reduced) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        // El gradiente empieza fuera del widget a la izquierda y lo recorre
        // hasta salir por la derecha.
        final shimmerOffset = _ctrl.value * 2 - 0.5;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(shimmerOffset - 1, 0),
              end: Alignment(shimmerOffset + 1, 0),
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
