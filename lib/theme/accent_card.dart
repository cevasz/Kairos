import 'package:flutter/material.dart';

import 'tokens.g.dart';

/// Tarjeta con la franja de color de la materia a la izquierda y un filete
/// fino en los otros tres lados.
///
/// No se puede hacer con un solo `Border(left: acento, top/right/bottom:
/// filete)` más `borderRadius`: Flutter no pinta esquinas redondeadas con lados
/// de colores distintos. En debug revienta al pintar y en release sale con las
/// esquinas cuadradas. Aquí el filete es uniforme y va con el radio, y la franja
/// se pinta por dentro y se recorta con el mismo radio.
class AccentCard extends StatelessWidget {
  const AccentCard({
    super.key,
    required this.accent,
    required this.child,
    this.padding,
    this.color,
    this.shadow,
  });

  final Color accent;
  final Widget child;

  /// Por defecto, el relleno de tarjeta del contrato.
  final EdgeInsetsGeometry? padding;

  /// Fondo; `null` deja ver lo que haya debajo (p. ej. un `Material` con tinta).
  final Color? color;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final radius = BorderRadius.circular(RadiusTokens.card);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(color: ColorTokens.surfaceBorder.of(b), width: BorderTokens.hairline),
        boxShadow: shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RadiusTokens.card - BorderTokens.hairline),
        child: Container(
          padding: padding ?? EdgeInsets.all(SpaceTokens.cardPadding),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent, width: BorderTokens.subjectAccent)),
          ),
          child: child,
        ),
      ),
    );
  }
}
