import 'package:flutter/widgets.dart';

import 'tokens.g.dart';

/// Clase de tamaño de la ventana, con los cortes del contrato.
///
/// El prototipo se dibujó a 360 dp. Lo que cambia por encima no es el dibujo
/// de cada pieza sino cómo se reparten: riel lateral en vez de barra inferior
/// a partir de `medium`, y dos paneles a partir de `expanded`.
enum SizeClass {
  compact,
  medium,
  expanded;

  static SizeClass forWidth(double width) {
    if (width >= LayoutTokens.breakpointExpanded) return SizeClass.expanded;
    if (width >= LayoutTokens.breakpointMedium) return SizeClass.medium;
    return SizeClass.compact;
  }

  bool get isCompact => this == SizeClass.compact;

  /// A partir de aquí la navegación es un riel lateral.
  bool get hasRail => this != SizeClass.compact;

  /// A partir de aquí las pantallas se parten en dos paneles.
  bool get isExpanded => this == SizeClass.expanded;
}

extension SizeClassX on BuildContext {
  SizeClass get sizeClass => SizeClass.forWidth(MediaQuery.sizeOf(this).width);
}

/// Limita el ancho de una columna de contenido en pantallas anchas.
///
/// Un formulario o una lista de ajustes a 1 000 dp de ancho no se lee: el ojo
/// tiene que viajar demasiado entre etiqueta y control. El tope sale del
/// contrato y el contenido se centra.
class ContentWidth extends StatelessWidget {
  const ContentWidth({required this.child, this.maxWidth = LayoutTokens.contentMaxWidth, super.key});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}
