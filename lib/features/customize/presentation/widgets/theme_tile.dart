import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../theme/motion.dart';
import '../../../../theme/palette.dart';
import '../../../../theme/tokens.g.dart';

/// Un tema en miniatura: la mitad izquierda en claro y la derecha en oscuro,
/// cada una con su fondo, una tarjeta de Hoy y el botón de acento.
class ThemeTile extends StatelessWidget {
  const ThemeTile({required this.name, required this.palette, required this.selected, required this.onTap});

  final String name;
  final AppPalette? palette;
  final bool selected;
  final VoidCallback onTap;

  Color _c(ThemedColor t, Brightness b) => palette?.resolve(t.role!, b) ?? (b == Brightness.dark ? t.dark : t.light);

  @override
  Widget build(BuildContext context) {
    final ink = context.themed(ColorTokens.textPrimary);
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RadiusTokens.card),
        child: AnimatedContainer(
          duration: MotionGuard.of(context).duration(MotionDurations.fast),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RadiusTokens.card),
            border: Border.all(
              color: selected ? ink : context.themed(ColorTokens.surfaceBorder),
              width: selected ? BorderTokens.subjectAccent : BorderTokens.hairline,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 92,
                child: Row(
                  children: [
                    for (final b in const [Brightness.light, Brightness.dark])
                      Expanded(
                        child: Container(
                          color: _c(ColorTokens.surfaceBase, b),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _c(ColorTokens.surfaceCard, b),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border(
                                      left: BorderSide(color: SubjectPalette.values[0], width: 3),
                                    ),
                                  ),
                                  padding: const EdgeInsets.fromLTRB(6, 6, 4, 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _Bar(color: _c(ColorTokens.textPrimary, b), width: 36),
                                      const SizedBox(height: 4),
                                      _Bar(color: _c(ColorTokens.textSecondary, b), width: 26),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                height: 14,
                                width: 44,
                                decoration: BoxDecoration(
                                  color: _c(ColorTokens.accentPrimary, b),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                alignment: Alignment.center,
                                child: _Bar(color: _c(ColorTokens.textOnAccent, b), width: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: SpaceTokens.m, vertical: SpaceTokens.s),
                child: Row(
                  children: [
                    Expanded(child: Text(name, style: context.type(TypeTokens.bodyM))),
                    if (selected) Icon(Icons.check_circle, size: 18, color: context.themed(ColorTokens.accentPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.color, required this.width});
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 4,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
      );
}

