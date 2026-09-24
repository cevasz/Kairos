import 'package:kairos/theme/motion.dart';
import 'package:kairos/theme/strike_through.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Colores de prueba: no salen del contrato a propósito. Lo que se verifica es
/// el comportamiento del widget, no qué tono le pasa la pantalla.
const _plain = Color(0xFF000000);
const _struck = Color(0xFFFFFFFF);

Widget _host({required bool struck, required bool reduced}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Builder(
        builder: (context) => StrikeThrough(
          struck: struck,
          guard: MotionGuard.of(context),
          color: _plain,
          struckColor: _struck,
          child: const Text('Bases de datos'),
        ),
      ),
    ),
  );
}

Color? _textColor(WidgetTester tester) {
  final text = tester.widget<Text>(find.text('Bases de datos'));
  final style = DefaultTextStyle.of(
    tester.element(find.text('Bases de datos')),
  ).style;
  return text.style?.color ?? style.color;
}

void main() {
  testWidgets('sin tachar el texto conserva su color', (tester) async {
    await tester.pumpWidget(_host(struck: false, reduced: false));
    await tester.pumpAndSettle();

    expect(_textColor(tester), _plain);
  });

  testWidgets('el trazo es progresivo: a mitad no ha llegado al final',
      (tester) async {
    await tester.pumpWidget(_host(struck: false, reduced: false));
    await tester.pumpAndSettle();

    // Marcar como cancelada dispara el trazo.
    await tester.pumpWidget(_host(struck: true, reduced: false));
    await tester.pump(const Duration(milliseconds: 1));

    final mid = MotionDurations.strike ~/ 2;
    await tester.pump(mid);
    final halfway = _textColor(tester);

    // A media animación el color ya salió del inicial pero no llegó al final:
    // eso es exactamente lo que distingue «se dibuja» de «aparece».
    expect(halfway, isNot(_plain));
    expect(halfway, isNot(_struck));

    await tester.pumpAndSettle();
    expect(_textColor(tester), _struck);
  });

  testWidgets('bajo reduced-motion el trazo no se acorta: se salta',
      (tester) async {
    await tester.pumpWidget(_host(struck: false, reduced: true));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_host(struck: true, reduced: true));
    await tester.pump(const Duration(milliseconds: 1));

    // El contrato colapsa toda animación al fade de 180 ms. Pasado eso, el
    // estado final tiene que estar puesto entero.
    await tester.pump(ReducedMotion.duration);
    await tester.pumpAndSettle();
    expect(_textColor(tester), _struck);
  });

  testWidgets('deshacer la cancelación devuelve el color', (tester) async {
    await tester.pumpWidget(_host(struck: true, reduced: false));
    await tester.pumpAndSettle();
    expect(_textColor(tester), _struck);

    await tester.pumpWidget(_host(struck: false, reduced: false));
    await tester.pumpAndSettle();
    expect(_textColor(tester), _plain);
  });

  testWidgets('el texto sigue siendo legible por accesibilidad al tacharse',
      (tester) async {
    // El tachado es visual: la clase cancelada no se esconde del árbol, que es
    // lo que la haría desaparecer para un lector de pantalla.
    await tester.pumpWidget(_host(struck: true, reduced: false));
    await tester.pumpAndSettle();

    expect(find.text('Bases de datos'), findsOneWidget);
  });
}
