import 'dart:math' as math;
import 'dart:ui';

import 'package:kairos/features/shell/presentation/widgets/radial_menu.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final geo = RadialGeometry(center: const Offset(180, 700), width: 360);

  Offset at(double angleDeg, double radius) {
    final a = angleDeg * math.pi / 180;
    return geo.center + Offset(math.cos(a), math.sin(a)) * radius;
  }

  int? hit(Offset p) => geo.hit(p, inner: 4, outerCount: 4);
  final innerMid = (geo.innerIn + geo.innerOut) / 2;
  final outerMid = (geo.outerIn + geo.outer) / 2;

  test('el anillo interior va de izquierda a derecha: Hoy, Semana, Materias, Mapa', () {
    expect(hit(at(180 + 22, innerMid)), 0);
    expect(hit(at(180 + 67, innerMid)), 1);
    expect(hit(at(180 + 112, innerMid)), 2);
    expect(hit(at(180 + 157, innerMid)), 3);
  });

  test('el exterior son las acciones, después de las pantallas', () {
    expect(hit(at(180 + 22, outerMid)), 4);
    expect(hit(at(180 + 157, outerMid)), 7);
  });

  test('el centro, debajo del botón y fuera de los anillos no eligen nada', () {
    expect(hit(geo.center), isNull);
    expect(hit(geo.center + const Offset(0, 80)), isNull);
    expect(hit(at(270, geo.outer + 60)), isNull);
  });
}
