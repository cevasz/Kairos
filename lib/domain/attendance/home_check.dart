import '../departure/departure.dart';
import 'attendance.dart';

/// «¿Sigues en casa a la hora de clase?»: cuándo se pregunta, qué cuenta
/// como casa y qué se hace con la respuesta.
///
/// Dart puro. La ubicación la mira Android con la app cerrada; aquí solo
/// viven las reglas, para poder probarlas.
abstract final class HomeCheck {
  /// A menos de esto de la casa, sigues en casa. Holgado a propósito: el GPS
  /// en interiores se desvía decenas de metros.
  static const int radiusMeters = 200;

  /// Una ubicación con más error que esto no sirve para afirmar nada: mejor
  /// no anotar una falta que anotarla mal.
  static const int maxAccuracyMeters = 250;

  /// Se comprueba al acabar la tolerancia: antes todavía podías llegar.
  static DateTime checkAt(DateTime day, int startMinute) => DateTime(day.year, day.month, day.day)
      .add(Duration(minutes: startMinute + DeparturePlanner.lateToleranceMinutes));

  /// Qué estado queda al llegar un veredicto de Android sobre una sesión que
  /// ahora está en [current]. Null: no se toca.
  ///
  /// - «Sigue en casa» ([SessionStatus.falto]) solo pisa una sesión sin
  ///   resolver: si ya marcaste que fuiste o la cancelaron, manda eso.
  /// - «Sí fui» ([SessionStatus.asistio], el botón de la notificación) deshace
  ///   la falta automática, o resuelve una pendiente.
  static SessionStatus? apply({required SessionStatus current, required SessionStatus verdict}) {
    switch (verdict) {
      case SessionStatus.falto:
        return current.isResolved ? null : SessionStatus.falto;
      case SessionStatus.asistio:
        final undoable = !current.isResolved || current == SessionStatus.falto;
        return undoable ? SessionStatus.asistio : null;
      default:
        return null;
    }
  }
}
