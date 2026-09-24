/// Comparaciones a nivel de día calendario. Dart puro: no sabe qué es un widget
/// y no llama a `DateTime.now()` por su cuenta.
///
/// El «ahora» siempre entra por parámetro. Una función que lo lee del reloj del
/// sistema no se puede probar sin esperar a mañana, y dentro de un `build`
/// además rompe la regla de que la hora la reparte el `clockProvider`.
library;

/// Medianoche local del día de `moment`. Fecha absoluta, no offset.
DateTime startOfDay(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

/// ¿`day` cae después del día calendario de `now`?
///
/// Hoy no es futuro: una clase de esta tarde ya cuenta como del día en curso,
/// que es lo que necesita el historial de asistencia para no esconderla.
bool isFutureDay(DateTime day, {required DateTime now}) =>
    startOfDay(day).isAfter(startOfDay(now));
