/// Una hora del día sin fecha, guardada como minutos desde medianoche.
///
/// La BD guarda un `int`. Se eligió esto sobre `DateTime` porque una clase de
/// «martes 10:00» no tiene fecha propia: la fecha la pone la SessionInstance.
/// Un `DateTime` con fecha falsa arrastra zona horaria y horario de verano a un
/// dato que no los tiene.
extension type const MinutesOfDay(int raw) implements Object {
  factory MinutesOfDay.of(int hour, int minute) {
    if (hour < 0 || hour > 23) {
      throw RangeError.range(hour, 0, 23, 'hour');
    }
    if (minute < 0 || minute > 59) {
      throw RangeError.range(minute, 0, 59, 'minute');
    }
    return MinutesOfDay(hour * 60 + minute);
  }

  int get hour => raw ~/ 60;
  int get minute => raw % 60;

  MinutesOfDay minus(int minutes) => MinutesOfDay(raw - minutes);
  MinutesOfDay plus(int minutes) => MinutesOfDay(raw + minutes);

  bool operator <(MinutesOfDay other) => raw < other.raw;
  bool operator >(MinutesOfDay other) => raw > other.raw;
  bool operator <=(MinutesOfDay other) => raw <= other.raw;
  bool operator >=(MinutesOfDay other) => raw >= other.raw;

  /// Minutos entre esta hora y otra. Negativo si la otra ya pasó.
  int difference(MinutesOfDay other) => other.raw - raw;

  /// Ancla esta hora a un día concreto. Fechas absolutas, no offsets: el
  /// resultado es hora local del dispositivo en ese día calendario.
  DateTime onDay(DateTime day) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  /// `10:00`, `8:05`. El formato de 12 h con «a. m.» es cosa de la capa de
  /// presentación, que tiene acceso a la locale.
  String get hhmm => '$hour:${minute.toString().padLeft(2, '0')}';
}
