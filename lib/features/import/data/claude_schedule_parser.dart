import 'dart:convert';
import 'dart:io';

import '../../../core/time/minutes_of_day.dart';
import '../../../domain/import/schedule_parser.dart';

/// Falló la llamada a la API o la respuesta no fue un horario. Quien llama se
/// queda con el resultado heurístico: el importador nunca depende de la red.
class ClaudeParseException implements Exception {
  const ClaudeParseException(this.message);
  final String message;

  @override
  String toString() => 'ClaudeParseException: $message';
}

/// Segunda pasada sobre el texto del PDF con Claude, cuando hay clave.
///
/// El parser heurístico saca las filas claras; Claude entiende los layouts
/// raros —tablas con celdas combinadas, abreviaturas locales, nombres
/// partidos en dos líneas— y devuelve el mismo modelo, ya estructurado por
/// `output_config.format`. Se manda el texto extraído, nunca el archivo.
///
/// La clave entra solo por `--dart-define=ANTHROPIC_API_KEY`; sin ella,
/// `isConfigured` es falso y esta clase no se instancia.
class ClaudeScheduleParser {
  ClaudeScheduleParser({HttpClient? client}) : _client = client ?? HttpClient();

  static const String apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
  static bool get isConfigured => apiKey.isNotEmpty;

  static const String model = 'claude-opus-5';
  static final Uri _endpoint = Uri.parse('https://api.anthropic.com/v1/messages');
  static const Duration _timeout = Duration(seconds: 45);

  final HttpClient _client;

  static const String _system = '''
Eres el lector de horarios de Kairós, una app para estudiantes universitarios en Colombia.
Recibes el texto extraído del PDF de un horario académico y devuelves las clases que contiene.

Reglas:
- Una entrada por materia; si la misma materia aparece varias veces, une sus sesiones.
- Días en ISO 8601: 1 lunes, 2 martes, 3 miércoles, 4 jueves, 5 viernes, 6 sábado, 7 domingo.
- Horas en formato HH:MM de 24 horas. «1-3 pm» es 13:00–15:00; «7-9» sin marcador es 07:00–09:00.
- El salón es el código tal como aparece («604», «12-201», «Sala de Sistemas 2E»), sin la palabra «salón» ni el nombre de la sede. Si cambia según el día, ponlo en cada sesión.
- El texto conserva la disposición del PDF: en una retícula, la columna de cada celda dice el día.
- El profesor solo si el texto lo nombra; no lo deduzcas.
- No inventes. Si un dato no está, deja null. Si una materia te deja dudando (nombre incompleto, día ambiguo, hora rara), marca dudoso en true.
- Ignora encabezados, pies de página y rangos de fechas administrativos. El código de asignatura y los créditos sí, si aparecen.''';

  static const Map<String, Object> _schema = {
    'type': 'object',
    'properties': {
      'clases': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'nombre': {'type': 'string'},
            'profesor': {
              'type': ['string', 'null'],
            },
            'salon': {
              'type': ['string', 'null'],
            },
            'codigo': {
              'type': ['string', 'null'],
            },
            'creditos': {
              'type': ['integer', 'null'],
            },
            'dudoso': {'type': 'boolean'},
            'sesiones': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'dia': {'type': 'integer', 'minimum': 1, 'maximum': 7},
                  'inicio': {'type': 'string'},
                  'fin': {'type': 'string'},
                  'salon': {
                    'type': ['string', 'null'],
                  },
                },
                'required': ['dia', 'inicio', 'fin', 'salon'],
                'additionalProperties': false,
              },
            },
          },
          'required': ['nombre', 'profesor', 'salon', 'codigo', 'creditos', 'dudoso', 'sesiones'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['clases'],
    'additionalProperties': false,
  };

  Future<List<ParsedClass>> parse(String text) async {
    if (!isConfigured) throw const ClaudeParseException('Sin clave de API');

    final body = jsonEncode({
      'model': model,
      'max_tokens': 16000,
      // Si un clasificador de seguridad rechaza la petición, la API la
      // reintenta sola en un modelo de respaldo dentro de la misma llamada.
      'fallbacks': 'default',
      'system': _system,
      'messages': [
        {'role': 'user', 'content': text},
      ],
      'output_config': {
        // Leer un horario es extracción, no razonamiento largo: con `low` la
        // respuesta llega en segundos y no en un minuto, y la calidad aguanta.
        'effort': 'low',
        'format': {'type': 'json_schema', 'schema': _schema},
      },
    });

    final HttpClientResponse response;
    final String payload;
    try {
      final request = await _client.postUrl(_endpoint).timeout(_timeout);
      request.headers
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..set('x-api-key', apiKey)
        ..set('anthropic-version', '2023-06-01')
        ..set('anthropic-beta', 'server-side-fallback-2026-07-01');
      request.write(body);
      response = await request.close().timeout(_timeout);
      payload = await response.transform(utf8.decoder).join().timeout(_timeout);
    } on SocketException catch (e) {
      throw ClaudeParseException('Sin red: ${e.message}');
    } on HttpException catch (e) {
      throw ClaudeParseException(e.message);
    }

    if (response.statusCode != HttpStatus.ok) {
      throw ClaudeParseException('HTTP ${response.statusCode}: $payload');
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(payload) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw ClaudeParseException('Respuesta ilegible: ${e.message}');
    }

    if (json['stop_reason'] == 'refusal') {
      throw const ClaudeParseException('La API declinó la petición');
    }

    final text0 = (json['content'] as List?)
        ?.cast<Map<String, dynamic>>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join();
    if (text0 == null || text0.isEmpty) {
      throw const ClaudeParseException('Respuesta sin contenido');
    }

    return decode(text0);
  }

  /// Convierte el JSON estructurado en el modelo del dominio. Público para
  /// poder probarlo sin red.
  static List<ParsedClass> decode(String jsonText) {
    final Map<String, dynamic> root;
    try {
      root = jsonDecode(jsonText) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw ClaudeParseException('JSON inválido: ${e.message}');
    }

    final out = <ParsedClass>[];
    for (final raw in (root['clases'] as List? ?? const [])) {
      final c = raw as Map<String, dynamic>;
      final sessions = <ParsedSession>[];
      var badRange = false;
      for (final s in (c['sesiones'] as List? ?? const [])) {
        final m = s as Map<String, dynamic>;
        final inicio = _hhmm(m['inicio'] as String?);
        final fin = _hhmm(m['fin'] as String?);
        final dia = m['dia'] as int? ?? 0;
        if (inicio == null || fin == null) continue;
        if (fin <= inicio) badRange = true;
        sessions.add(ParsedSession(
          diaSemana: dia,
          inicio: inicio,
          fin: fin,
          salon: _nullable(m['salon']),
        ));
      }
      final nombre = (c['nombre'] as String? ?? '').trim();
      out.add(ParsedClass(
        nombre: nombre,
        profesor: _nullable(c['profesor']),
        salon: _nullable(c['salon']),
        codigo: _nullable(c['codigo']),
        creditos: c['creditos'] is int ? c['creditos'] as int : null,
        sessions: sessions,
        doubts: {
          if (nombre.isEmpty) ParseDoubt.missingName,
          if (sessions.any((s) => s.diaSemana < 1 || s.diaSemana > 7)) ParseDoubt.missingDays,
          if (badRange) ParseDoubt.badRange,
          // «dudoso» sin un motivo concreto se registra como nombre por
          // revisar: es la duda más común y la que la persona corrige antes.
          if (c['dudoso'] == true && nombre.isNotEmpty) ParseDoubt.nameFromPreviousLine,
        },
      ));
    }
    return out;
  }

  static String? _nullable(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  static MinutesOfDay? _hhmm(String? v) {
    if (v == null) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(v.trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return null;
    return MinutesOfDay.of(h, min);
  }
}
