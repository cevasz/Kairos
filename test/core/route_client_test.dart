import 'package:kairos/core/platform/route_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lee la duración de una respuesta Ok de OSRM', () {
    final json = {
      'code': 'Ok',
      'routes': [
        {'duration': 1266.5, 'distance': 1580.6},
      ],
    };
    expect(RouteClient.parseDuration(json), 1266.5);
  });

  test('sin ruta, con error o con basura devuelve null', () {
    expect(RouteClient.parseDuration({'code': 'NoRoute', 'routes': []}), isNull);
    expect(RouteClient.parseDuration({'code': 'Ok', 'routes': []}), isNull);
    expect(RouteClient.parseDuration({'code': 'Ok', 'routes': [{'duration': 0}]}), isNull);
    expect(RouteClient.parseDuration('nada'), isNull);
  });
}
