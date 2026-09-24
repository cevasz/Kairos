import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Un punto en el mapa, sin depender de `latlong2` en el dominio.
typedef GeoPoint = ({double lat, double lng});

/// Cuánto se tarda por calles entre dos puntos, según OSRM sobre los datos
/// de OpenStreetMap. Sin clave ni cuenta: el servidor público de
/// routing.openstreetmap.de tiene perfiles a pie y en carro.
///
/// Es solo el número de partida del trayecto: no sabe de trancones ni de
/// buses, y por eso el estimador lo corrige con los viajes reales.
class RouteClient {
  RouteClient({HttpClient? client}) : _client = client ?? HttpClient();

  static const _base = 'https://routing.openstreetmap.de';
  static const Duration _timeout = Duration(seconds: 12);

  /// OSRM da el carro a velocidad de vía libre. En una ciudad colombiana en
  /// hora de clase eso no pasa: se infla un tercio y se suman minutos para
  /// parquear y caminar hasta la entrada.
  static const double carTrafficFactor = 1.35;
  static const int carParkingMinutes = 4;

  final HttpClient _client;

  /// Minutos a pie, o null sin red o sin ruta.
  Future<int?> walkMinutes(GeoPoint from, GeoPoint to) async {
    final seconds = await _duration('routed-foot', from, to);
    return seconds == null ? null : (seconds / 60).ceil();
  }

  /// Minutos en carro con el ajuste de ciudad, o null sin red o sin ruta.
  Future<int?> carMinutes(GeoPoint from, GeoPoint to) async {
    final seconds = await _duration('routed-car', from, to);
    if (seconds == null) return null;
    return (seconds / 60 * carTrafficFactor).ceil() + carParkingMinutes;
  }

  Future<double?> _duration(String profile, GeoPoint from, GeoPoint to) async {
    final url = Uri.parse(
      '$_base/$profile/route/v1/driving/${from.lng},${from.lat};${to.lng},${to.lat}?overview=false',
    );
    try {
      final request = await _client.getUrl(url).timeout(_timeout);
      request.headers.set(HttpHeaders.userAgentHeader, 'Kairos (github.com/cevasz/Kairos)');
      final response = await request.close().timeout(_timeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return null;
      }
      final body = await response.transform(utf8.decoder).join().timeout(_timeout);
      return parseDuration(jsonDecode(body));
    } on Object {
      return null;
    }
  }

  /// La duración en segundos de la primera ruta, o null si la respuesta no
  /// es un `Ok` con ruta.
  static double? parseDuration(Object? json) {
    if (json is! Map || json['code'] != 'Ok') return null;
    final routes = json['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final first = routes.first;
    if (first is! Map) return null;
    final d = first['duration'];
    return d is num && d > 0 ? d.toDouble() : null;
  }
}
