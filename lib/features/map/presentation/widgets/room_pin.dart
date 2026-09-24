import 'package:flutter/material.dart';

import '../../../../l10n/strings.g.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/motion.dart';
import '../../../../theme/tokens.g.dart';

/// El pin de un salón: una etiqueta con su código, del color de la materia,
/// con un pico que apunta al punto exacto. Se lee sin tocarlo, que es lo que
/// un pin genérico no permite.
class RoomPin extends StatelessWidget {
  const RoomPin({
    required this.label,
    required this.color,
    required this.isNext,
    required this.focused,
    super.key,
  });

  /// Caja del marcador. La base del pico queda en el borde inferior.
  static const double width = 148;
  static const double height = 58;

  final String label;
  final Color color;

  /// Es el salón de tu próxima clase: lleva anillo de acento.
  final bool isNext;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final ring = isNext ? ColorTokens.accentPrimary.of(b) : ColorTokens.surfaceCard.of(b);
    return AnimatedScale(
      scale: focused ? 1.12 : 1,
      alignment: Alignment.bottomCenter,
      duration: MotionGuard.of(context).duration(MotionDurations.fast),
      curve: MotionCurves.easeOutBackBounce,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: width),
            padding: EdgeInsets.symmetric(
              horizontal: SpaceTokens.s + SpaceTokens.xs / 2,
              vertical: SpaceTokens.xs + SpaceTokens.xs / 2,
            ),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(RadiusTokens.full),
              border: Border.all(color: ring, width: BorderTokens.tabIndicator),
              boxShadow: ElevationTokens.raised(b),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isNext) ...[
                  Icon(Icons.school, size: IconTokens.sizeXs, color: ColorTokens.textOnSubject.of(b)),
                  SizedBox(width: SpaceTokens.xs),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type(TypeTokens.caption, color: ColorTokens.textOnSubject.of(b)),
                  ),
                ),
              ],
            ),
          ),
          CustomPaint(
            size: Size(SpaceTokens.m, SpaceTokens.s),
            painter: _Beak(color: color),
          ),
        ],
      ),
    );
  }
}

class _Beak extends CustomPainter {
  const _Beak({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_Beak old) => old.color != color;
}

/// «Tú»: punto de acento con halo, como en cualquier mapa, para no tener que
/// explicarlo.
class UserDot extends StatelessWidget {
  const UserDot({super.key});

  static const double size = 28;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final accent = ColorTokens.accentPrimary.of(b);
    return Semantics(
      label: SMap.you,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.22)),
        child: Container(
          width: size / 2,
          height: size / 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent,
            border: Border.all(color: ColorTokens.surfaceCard.of(b), width: BorderTokens.tabIndicator),
          ),
        ),
      ),
    );
  }
}
