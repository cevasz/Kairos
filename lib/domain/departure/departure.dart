import '../../core/time/minutes_of_day.dart';

enum TransportMode { walk, bus, car }

/// Urgencia de la salida. La UI mapea esto a color, anillo y háptica; la lógica
/// no sabe de ninguno de los tres.
enum DepartureUrgency {
  /// Falta bastante. Card en reposo.
  calm,

  /// Menos de un umbral de aviso. Se programa la notificación.
  soon,

  /// Ya deberías estar caminando.
  now,

  /// La clase ya empezó.
  late_,
}

class DeparturePlan {
  const DeparturePlan({
    required this.classStart,
    required this.leaveAt,
    required this.travelMinutes,
    required this.bufferMinutes,
    required this.minutesUntilLeave,
    required this.urgency,
    required this.mode,
    this.fromHome = true,
  });

  final MinutesOfDay classStart;

  /// Si se sale de casa. Falso cuando ya estás en la universidad por una
  /// clase anterior: entonces no hay trayecto, solo el margen.
  final bool fromHome;

  /// Hasta cuándo te dejan entrar sin falta.
  MinutesOfDay get toleranceEnd => classStart.plus(DeparturePlanner.lateToleranceMinutes);

  /// hora_clase − tiempo_ruta − buffer.
  final MinutesOfDay leaveAt;

  final int travelMinutes;
  final int bufferMinutes;

  /// Negativo cuando ya se pasó la hora de salir.
  final int minutesUntilLeave;

  final DepartureUrgency urgency;
  final TransportMode mode;

  /// Si ya se pasó la hora de salir: desde aquí la llegada cuenta desde
  /// ahora, no desde la hora ideal.
  bool get leavingLate => minutesUntilLeave < 0;

  /// A qué hora llegas. Si todavía no es hora de salir, llegas cuando lo
  /// planeado (inicio − margen). Si ya pasó, «si sales ya»: ahora + trayecto.
  /// Es la misma cuenta que hacen los widgets.
  MinutesOfDay get estimatedArrival =>
      leaveAt.plus(travelMinutes + (leavingLate ? -minutesUntilLeave : 0));

  /// Minutos entre la llegada estimada y el inicio: positivo si llegas antes,
  /// negativo si llegas tarde. Saliendo a tiempo es el buffer («llegas 4
  /// antes»); saliendo tarde se come primero el buffer y luego la clase.
  int get arrivalMargin => estimatedArrival.difference(classStart);

  bool get isUrgent =>
      urgency == DepartureUrgency.now || urgency == DepartureUrgency.late_;
}

abstract final class DeparturePlanner {
  /// Umbral a partir del cual la card deja de estar en reposo.
  static const int soonThresholdMinutes = 30;

  /// Casi todas las clases dejan entrar hasta quince minutos tarde sin falta.
  /// Pasado eso la clase ya no es «a la que hay que ir»: Hoy pasa a la
  /// siguiente, y si la ubicación dice que sigues en casa, cuenta la falta.
  static const int lateToleranceMinutes = 15;

  /// Lo mínimo que vale la pena quedarse en casa entre dos clases. Con menos
  /// hueco que ir, estar esto y volver, lo realista es que sigas en la U.
  static const int homeStayMinutes = 60;

  /// ¿Se sale de casa hacia la clase que empieza a [start]? Sí si es la
  /// primera del día ([previousEnd] null) o si el hueco desde la anterior da
  /// para ir a casa, estar [homeStayMinutes] y volver.
  static bool leavesFromHome({
    required MinutesOfDay? previousEnd,
    required MinutesOfDay start,
    required int travelMinutes,
  }) =>
      previousEnd == null || previousEnd.difference(start) >= 2 * travelMinutes + homeStayMinutes;

  /// Buffer por defecto cuando todavía no se han leído los ajustes. Coincide
  /// con el `withDefault` de `UserSettings.bufferMinutos`: si los dos números
  /// se separan, la pantalla dice una hora y la BD otra.
  static const int defaultBufferMinutes = 5;

  /// Rango que Ajustes deja escoger. Cero es válido: hay quien prefiere que la
  /// app no le añada nada. Más de media hora ya no es un buffer, es otra hora
  /// de clase.
  static const int minBufferMinutes = 0;
  static const int maxBufferMinutes = 30;

  /// Cuánto del margen ya se consumió, de 0 a 1, para el anillo de la cuenta
  /// atrás. `windowMinutes` lo pone quien llama —sale del contrato, no de
  /// aquí— porque es la escala del dibujo y no una regla del dominio.
  ///
  /// Devuelve 0 mientras falte más de una ventana entera: un anillo lleno
  /// durante tres horas no dice nada útil.
  static double ringProgress(DeparturePlan plan, {required int windowMinutes}) {
    if (windowMinutes <= 0) return 1;
    final left = plan.minutesUntilLeave.clamp(0, windowMinutes);
    return 1 - (left / windowMinutes);
  }

  static DeparturePlan plan({
    required MinutesOfDay classStart,
    required MinutesOfDay now,
    required int travelMinutes,
    required int bufferMinutes,
    required TransportMode mode,
    bool fromHome = true,
  }) {
    // Desde la U no hay trayecto: solo el margen para llegar al salón.
    final travel = fromHome ? travelMinutes : 0;
    final leaveAt = classStart.minus(travel + bufferMinutes);
    final until = now.difference(leaveAt);

    return DeparturePlan(
      classStart: classStart,
      leaveAt: leaveAt,
      travelMinutes: travel,
      bufferMinutes: bufferMinutes,
      minutesUntilLeave: until,
      urgency: _urgency(until, now, classStart),
      mode: mode,
      fromHome: fromHome,
    );
  }

  static DepartureUrgency _urgency(
    int minutesUntilLeave,
    MinutesOfDay now,
    MinutesOfDay classStart,
  ) {
    if (now >= classStart) return DepartureUrgency.late_;
    if (minutesUntilLeave <= 0) return DepartureUrgency.now;
    if (minutesUntilLeave <= soonThresholdMinutes) return DepartureUrgency.soon;
    return DepartureUrgency.calm;
  }

  /// Cuando no hay permiso de ubicación ni ruta calculada, la app sigue siendo
  /// útil: cae al tiempo estimado del modo de transporte configurado. No se
  /// bloquea la pantalla por un permiso denegado.
  static const Map<TransportMode, int> fallbackTravelMinutes =
      <TransportMode, int>{
    TransportMode.walk: 15,
    TransportMode.bus: 35,
    TransportMode.car: 20,
  };

  /// Rango del trayecto que la persona puede fijar en Ajustes. Por debajo de
  /// cinco minutos no hace falta una app; por encima de dos horas, tampoco.
  static const int minTravelMinutes = 5;
  static const int maxTravelMinutes = 120;

  /// El trayecto que manda: el que la persona midió, si lo puso; si no, el
  /// estimado del modo. Quien conoce su ruta sabe más que una tabla.
  static int travelMinutesFor(TransportMode mode, int? custom) =>
      custom ?? fallbackTravelMinutes[mode]!;
}
