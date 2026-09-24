import '../../l10n/strings.g.dart';

/// Minutos escritos como los diría una persona: «45 min», «2 h», «1 h 20 min».
///
/// Nunca «300 min»: pasada la hora, cuentan las horas. Es prosa, no un reloj,
/// así que sin ceros de relleno. Un negativo se escribe como cero: «hace −3
/// min» no lo dice nadie.
abstract final class TimeSpans {
  static String minutes(int total) {
    final m = total < 0 ? 0 : total;
    if (m < 60) return '$m ${SToday.countdownUnit}';
    final h = m ~/ 60;
    final rest = m % 60;
    if (rest == 0) return '$h ${SToday.hoursUnit}';
    return '$h ${SToday.hoursUnit} $rest ${SToday.countdownUnit}';
  }

  /// Para el anillo de la cuenta atrás, donde cabe poco: «45» con «min»
  /// debajo, o «4:05» con «h» debajo.
  static ({String value, String unit}) compact(int total) {
    final m = total < 0 ? 0 : total;
    if (m < 60) return (value: '$m', unit: SToday.countdownUnit);
    final rest = (m % 60).toString().padLeft(2, '0');
    return (value: '${m ~/ 60}:$rest', unit: SToday.hoursUnit);
  }
}
