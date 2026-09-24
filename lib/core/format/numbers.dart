import 'package:intl/intl.dart';

/// Formatos de número de la app, en un solo sitio.
///
/// Colombia escribe el decimal con coma: «3,4», no «3.4». El prototipo lo hace
/// así en todas sus pantallas, y una sola coma fuera de sitio delata que el
/// número lo escribió el código y no una persona.
abstract final class Numbers {
  /// Una nota de la escala 0,0–5,0, siempre con un decimal.
  static String grade(double value) =>
      NumberFormat('0.0', 'es_CO').format(value);

  /// Una fracción de peso (0.30) como porcentaje entero: «30».
  ///
  /// Sin decimales cuando no hacen falta: un 12,5 % se escribe «12,5» y un
  /// 30 % se escribe «30», no «30,0».
  static String percent(double fraction) =>
      NumberFormat('0.##', 'es_CO').format(fraction * 100);
}
