import 'absence_state.g.dart';

/// Estado de una sesión concreta de clase.
///
/// `pendiente` existe porque una clase futura ya es una fila en la BD pero
/// todavía no tiene resultado. `posibleFalta` es el pre-marcado del geofence
/// (Fase 4): la app cree que faltaste, pero no lo afirma hasta preguntarte.
enum SessionStatus {
  pendiente,
  asistio,
  falto,
  canceladaProfe,
  justificada,
  posibleFalta;

  /// La regla de negocio central del contador: solo `falto` gasta cupo.
  /// Una cancelación del profesor no es tuya, y una justificada tampoco.
  bool get countsAsAbsence => this == SessionStatus.falto;

  /// Una sesión resuelta ya no admite cambios automáticos.
  bool get isResolved => this != SessionStatus.pendiente && this != SessionStatus.posibleFalta;
}

/// Resultado del conteo de faltas de una materia.
class AbsenceTally {
  const AbsenceTally({
    required this.used,
    required this.limit,
    required this.state,
    required this.remaining,
    required this.cancelledByProfessor,
  });

  /// Faltas que sí gastaron cupo.
  final int used;

  /// Límite de la materia. Puede diferir del global de ajustes.
  final int limit;

  final AbsenceState state;

  /// Cuántas faltas quedan antes de perder. Nunca negativo.
  final int remaining;

  /// Se cuentan aparte para poder decir «las canceladas por el profe no cuentan»
  /// con un número detrás.
  final int cancelledByProfessor;

  double get ratio => limit == 0 ? 1 : used / limit;

  bool get isLost => state == AbsenceState.lost;
}

/// Contador de faltas. Dart puro: no sabe qué es un widget.
abstract final class AttendanceCounter {
  /// Rango del límite por defecto que Ajustes deja escoger. Coincide con lo
  /// que el formulario de materia acepta («1 o más»); el techo es el de los
  /// reglamentos más laxos que se han visto.
  static const int minLimit = 1;
  static const int maxLimit = 20;

  /// Límite cuando no hay otro dato. Coincide con el `withDefault` de las dos
  /// columnas de la BD que lo guardan; si se separan, la app dirá una cosa y
  /// la base otra.
  static const int defaultLimit = 6;

  static AbsenceTally tally({
    required Iterable<SessionStatus> sessions,
    required int limit,
  }) {
    var used = 0;
    var cancelled = 0;
    for (final s in sessions) {
      if (s.countsAsAbsence) used++;
      if (s == SessionStatus.canceladaProfe) cancelled++;
    }

    final ratio = limit <= 0 ? 1.0 : used / limit;
    return AbsenceTally(
      used: used,
      limit: limit,
      state: stateFor(ratio),
      remaining: (limit - used).clamp(0, limit),
      cancelledByProfessor: cancelled,
    );
  }

  /// Umbrales generados desde design/tokens.json. Son fracción del límite, no
  /// conteo absoluto, porque el límite varía por materia.
  static AbsenceState stateFor(double ratio) {
    if (ratio >= AbsenceThresholds.lostFrom) return AbsenceState.lost;
    if (ratio >= AbsenceThresholds.riskFrom) return AbsenceState.risk;
    if (ratio >= AbsenceThresholds.attentionFrom) return AbsenceState.attention;
    return AbsenceState.ok;
  }

  /// El shake de 4 px se dispara una sola vez, en el primer cruce hacia riesgo.
  /// Quien llama guarda `previous`; sin eso el shake se repetiría en cada
  /// reconstrucción del widget.
  static bool shouldShake(AbsenceState previous, AbsenceState next) =>
      previous != next &&
      next == AbsenceState.risk &&
      previous.index < AbsenceState.risk.index;
}
