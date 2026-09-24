import '../../core/time/minutes_of_day.dart';

/// Lo que un importador (hoy solo el de calendario .ics) leyó, antes de
/// guardarlo: actividades con sus bloques semanales.
///
/// Por qué el importador duda de una actividad. La pantalla de revisión lo
/// marca con «Revisa esto». No es un porcentaje: es una lista de motivos, para
/// que la persona sepa qué mirar.
enum ParseDoubt {
  /// El evento no traía nombre.
  missingName,

  /// Hay hora pero ningún día reconocible.
  missingDays,

  /// La hora de fin no va después de la de inicio.
  badRange,
}

class ParsedSession {
  const ParsedSession({
    required this.diaSemana,
    required this.inicio,
    required this.fin,
    this.salon,
  });

  /// ISO 8601: 1 = lunes … 7 = domingo.
  final int diaSemana;
  final MinutesOfDay inicio;
  final MinutesOfDay fin;

  /// El lugar de este bloque. Una misma actividad puede tener lugares
  /// distintos según el día. `null` si no se supo.
  final String? salon;

  ParsedSession copyWith({int? diaSemana, MinutesOfDay? inicio, MinutesOfDay? fin, String? salon}) =>
      ParsedSession(
        diaSemana: diaSemana ?? this.diaSemana,
        inicio: inicio ?? this.inicio,
        fin: fin ?? this.fin,
        salon: salon ?? this.salon,
      );

  @override
  bool operator ==(Object other) =>
      other is ParsedSession &&
      other.diaSemana == diaSemana &&
      other.inicio == inicio &&
      other.fin == fin &&
      other.salon == salon;

  @override
  int get hashCode => Object.hash(diaSemana, inicio, fin, salon);

  @override
  String toString() =>
      'ParsedSession($diaSemana ${inicio.hhmm}\u2013${fin.hhmm}${salon == null ? '' : ' @$salon'})';
}

class ParsedClass {
  const ParsedClass({
    required this.nombre,
    required this.sessions,
    this.profesor,
    this.salon,
    this.doubts = const {},
  });

  final String nombre;
  final String? profesor;

  /// Lugar representativo de la actividad: el del primer bloque que lo trae.
  /// El lugar exacto de cada bloque vive en `ParsedSession.salon`.
  final String? salon;

  final List<ParsedSession> sessions;
  final Set<ParseDoubt> doubts;

  bool get isLowConfidence => doubts.isNotEmpty;

  ParsedClass copyWith({
    String? nombre,
    String? profesor,
    String? salon,
    List<ParsedSession>? sessions,
    Set<ParseDoubt>? doubts,
    bool clearProfesor = false,
    bool clearSalon = false,
  }) =>
      ParsedClass(
        nombre: nombre ?? this.nombre,
        profesor: clearProfesor ? null : (profesor ?? this.profesor),
        salon: clearSalon ? null : (salon ?? this.salon),
        sessions: sessions ?? this.sessions,
        doubts: doubts ?? this.doubts,
      );
}
