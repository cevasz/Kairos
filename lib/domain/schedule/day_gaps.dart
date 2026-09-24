import '../../core/time/minutes_of_day.dart';

/// Un hueco entre dos clases del día: empieza cuando termina una y acaba
/// cuando empieza la siguiente.
class DayGap {
  const DayGap({required this.afterIndex, required this.minutes});

  /// Índice, en la lista original, de la clase tras la que va el hueco.
  final int afterIndex;
  final int minutes;

  int get hours => minutes ~/ 60;
  int get remainderMinutes => minutes % 60;
}

/// Encuentra los huecos que vale la pena enseñar en la timeline de Hoy.
///
/// Dart puro: recibe horas, no filas de la BD, para que el umbral se pruebe
/// sin montar nada.
abstract final class DayGaps {
  /// Por debajo de esto no hay hueco: es el tiempo de cambiar de salón. La
  /// timeline no lo dibuja porque no hay nada que hacer con quince minutos.
  static const int minimumMinutes = 30;

  /// `ranges` va en orden de inicio. Las clases que se solapan o van pegadas
  /// no producen hueco. Una clase cancelada no debería entrar en `ranges`:
  /// quien llama decide si ese tiempo queda libre.
  static List<DayGap> find(
    List<({MinutesOfDay start, MinutesOfDay end})> ranges, {
    int minimumMinutes = minimumMinutes,
  }) {
    final gaps = <DayGap>[];
    for (var i = 0; i + 1 < ranges.length; i++) {
      final free = ranges[i].end.difference(ranges[i + 1].start);
      if (free >= minimumMinutes) {
        gaps.add(DayGap(afterIndex: i, minutes: free));
      }
    }
    return gaps;
  }
}
