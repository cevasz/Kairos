import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../l10n/strings.g.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/motion.dart';
import '../../../../theme/tokens.g.dart';

/// Una entrada del menú radial: una pantalla (anillo interior) o una acción
/// (anillo exterior).
class RadialItem {
  const RadialItem({required this.icon, required this.label, required this.onSelect, this.activeIcon});
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final VoidCallback onSelect;
}

/// Radios del menú para un tamaño de pantalla. La usan el dibujo y el toque:
/// lo que se ve es lo que se toca.
class RadialGeometry {
  RadialGeometry({required this.center, required double width})
      : outer = math.min(width / 2 - SpaceTokens.s, 188);

  final Offset center;
  final double outer;

  double get hub => ComponentTokens.buttonMinTouchTarget * 0.62;
  double get innerIn => hub + SpaceTokens.s;
  double get innerOut => innerIn + (outer - innerIn) * 0.52;
  double get outerIn => innerOut + SpaceTokens.xs;

  /// Semicírculo hacia arriba: de la izquierda (π) a la derecha (2π).
  static const double start = math.pi;
  static const double sweep = math.pi;

  /// Índice del sector bajo [p]: 0..inner−1 en el anillo interior, luego los
  /// del exterior. Null fuera de los anillos.
  int? hit(Offset p, {required int inner, required int outerCount}) {
    final d = p - center;
    final r = d.distance;
    if (d.dy > SpaceTokens.l) return null; // debajo del botón no hay menú
    var a = math.atan2(d.dy, d.dx);
    if (a < 0) a += 2 * math.pi;
    // Un poco de holgura en los bordes: el dedo no apunta a 180° exactos.
    final rel = ((a - start) / sweep).clamp(0.0, 0.9999);
    if (d.dy > 0) {
      // Por debajo del horizonte, solo si está cerca de los extremos.
      if (d.dx.abs() < innerIn) return null;
    }
    if (r >= innerIn && r < innerOut) return (rel * inner).floor();
    if (r >= innerOut && r <= outer + SpaceTokens.m) return inner + (rel * outerCount).floor();
    return null;
  }
}

/// El menú abierto: velo, dos anillos y las etiquetas. [progress] va de 0 a
/// 1 con la apertura; [hover] es el sector bajo el dedo al arrastrar.
class RadialMenuLayer extends StatelessWidget {
  const RadialMenuLayer({
    required this.geometry,
    required this.screens,
    required this.actions,
    required this.current,
    required this.hover,
    required this.progress,
    required this.onTapAt,
    super.key,
  });

  final RadialGeometry geometry;
  final List<RadialItem> screens;
  final List<RadialItem> actions;
  final int current;
  final int? hover;
  final double progress;
  final ValueChanged<Offset> onTapAt;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final colors = _RadialColors(
      card: ColorTokens.surfaceCard.of(b),
      raised: ColorTokens.surfaceRaised.of(b),
      border: ColorTokens.surfaceBorder.of(b),
      accent: ColorTokens.accentPrimary.of(b),
      onAccent: ColorTokens.textOnAccent.of(b),
      ink: ColorTokens.textPrimary.of(b),
      secondary: ColorTokens.textSecondary.of(b),
    );
    final all = [...screens, ...actions];

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => onTapAt(d.localPosition),
            child: ColoredBox(color: ColorTokens.surfaceScrim.of(b).withValues(alpha: 0.6 * progress)),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _RadialPainter(
                geo: geometry,
                inner: screens.length,
                outerCount: actions.length,
                current: current,
                hover: hover,
                progress: progress,
                colors: colors,
              ),
            ),
          ),
        ),
        // Íconos y etiquetas como widgets: así usan la fuente y el tamaño del
        // contrato y el lector de pantalla los encuentra.
        for (var i = 0; i < all.length; i++) _label(context, all[i], i, colors),
        if (progress > 0.6)
          Positioned(
            left: 0,
            right: 0,
            top: geometry.center.dy - geometry.outer - SpaceTokens.xl,
            child: IgnorePointer(
              child: Opacity(
                opacity: ((progress - 0.6) / 0.4).clamp(0.0, 1.0),
                child: Text(
                  hover == null ? SNav.hint : all[hover!].label,
                  textAlign: TextAlign.center,
                  style: context.type(TypeTokens.titleS, color: colors.ink),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _label(BuildContext context, RadialItem item, int i, _RadialColors c) {
    final isInner = i < screens.length;
    final count = isInner ? screens.length : actions.length;
    final idx = isInner ? i : i - screens.length;
    final g = geometry;
    final rIn = isInner ? g.innerIn : g.outerIn;
    final rOut = isInner ? g.innerOut : g.outer;
    // Cada sector entra con un pequeño retraso respecto al anterior.
    final delay = i / (screens.length + actions.length) * 0.4;
    final t = Curves.easeOutBack.transform(((progress - delay) / (1 - delay)).clamp(0.0, 1.0));
    final angle = RadialGeometry.start + RadialGeometry.sweep * (idx + 0.5) / count;
    final radius = (rIn + (rOut - rIn) / 2) * (0.4 + 0.6 * t);
    final p = g.center + Offset(math.cos(angle), math.sin(angle)) * radius;
    final active = isInner && i == current;
    final hovered = i == hover;
    final color = active ? c.onAccent : (hovered ? c.accent : c.ink);
    // Estrecho a propósito: «Importar horario» se parte en dos líneas y no
    // invade el sector vecino.
    const w = 72.0;
    return Positioned(
      left: p.dx - w / 2,
      top: p.dy - 26,
      width: w,
      child: IgnorePointer(
        child: Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Semantics(
            button: true,
            selected: active,
            label: item.label,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(active ? (item.activeIcon ?? item.icon) : item.icon, color: color),
                SizedBox(height: SpaceTokens.xs / 2),
                Text(
                  item.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: context.type(TypeTokens.captionS, color: active ? c.onAccent : c.secondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadialColors {
  const _RadialColors({
    required this.card,
    required this.raised,
    required this.border,
    required this.accent,
    required this.onAccent,
    required this.ink,
    required this.secondary,
  });
  final Color card, raised, border, accent, onAccent, ink, secondary;
}

class _RadialPainter extends CustomPainter {
  _RadialPainter({
    required this.geo,
    required this.inner,
    required this.outerCount,
    required this.current,
    required this.hover,
    required this.progress,
    required this.colors,
  });

  final RadialGeometry geo;
  final int inner;
  final int outerCount;
  final int current;
  final int? hover;
  final double progress;
  final _RadialColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    const gap = 0.018;
    void ring(int count, double rIn, double rOut, int offset) {
      final slice = RadialGeometry.sweep / count;
      for (var i = 0; i < count; i++) {
        final index = offset + i;
        final delay = index / (inner + outerCount) * 0.4;
        final t = Curves.easeOutCubic.transform(((progress - delay) / (1 - delay)).clamp(0.0, 1.0));
        if (t <= 0) continue;
        final start = RadialGeometry.start + i * slice + gap;
        final sweep = (slice - 2 * gap) * t;
        final out = rIn + (rOut - rIn) * t;
        final path = Path()
          ..arcTo(Rect.fromCircle(center: geo.center, radius: out), start, sweep, true)
          ..arcTo(Rect.fromCircle(center: geo.center, radius: rIn), start + sweep, -sweep, false)
          ..close();
        final isCurrent = offset == 0 && i == current;
        final isHover = index == hover;
        final fill = isCurrent ? colors.accent : (isHover ? colors.raised : colors.card);
        canvas.drawPath(path, Paint()..color = fill.withValues(alpha: fill.a * t));
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isHover ? BorderTokens.subjectAccent : BorderTokens.hairline
            ..color = (isHover ? colors.accent : colors.border).withValues(alpha: t),
        );
      }
    }

    ring(inner, geo.innerIn, geo.innerOut, 0);
    ring(outerCount, geo.outerIn, geo.outer, inner);
  }

  @override
  bool shouldRepaint(_RadialPainter old) =>
      old.progress != progress ||
      old.hover != hover ||
      old.current != current ||
      old.colors.accent != colors.accent ||
      old.colors.card != colors.card ||
      old.geo.center != geo.center;
}

/// El botón central del dock: el ícono de la pantalla actual. Tocar abre o
/// cierra el menú; mantener y arrastrar elige sin soltar el dedo.
class RadialHub extends StatelessWidget {
  const RadialHub({
    required this.icon,
    required this.open,
    required this.onTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    super.key,
  });

  final IconData icon;
  final bool open;
  final VoidCallback onTap;
  final ValueChanged<Offset> onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final size = ComponentTokens.buttonMinTouchTarget * 1.25;
    final guard = MotionGuard.of(context);
    return Semantics(
      button: true,
      label: open ? SNav.close : SNav.open,
      child: GestureDetector(
        onTap: onTap,
        onPanStart: (d) => onDragStart(d.globalPosition),
        onPanUpdate: (d) => onDragUpdate(d.globalPosition),
        onPanEnd: (_) => onDragEnd(),
        child: AnimatedContainer(
          duration: guard.duration(MotionDurations.fast),
          curve: guard.curve(MotionCurves.easeOutCubic),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: open ? ColorTokens.surfaceCard.of(b) : ColorTokens.accentPrimary.of(b),
            border: Border.all(color: ColorTokens.surfaceBorder.of(b), width: BorderTokens.hairline),
            boxShadow: ElevationTokens.card(b),
          ),
          child: AnimatedSwitcher(
            duration: guard.duration(MotionDurations.fast),
            transitionBuilder: (child, a) => RotationTransition(
              turns: Tween(begin: 0.75, end: 1.0).animate(a),
              child: FadeTransition(opacity: a, child: child),
            ),
            child: Icon(
              open ? Icons.close : icon,
              key: ValueKey(open ? 'close' : icon.codePoint),
              color: open ? ColorTokens.textPrimary.of(b) : ColorTokens.textOnAccent.of(b),
            ),
          ),
        ),
      ),
    );
  }
}
