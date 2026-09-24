import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/daos/subjects_dao.dart';
import '../../../core/db/database.dart';
import '../../../core/providers.dart';
import '../../../domain/attendance/attendance.dart';
import '../../../domain/streaks/streaks.dart';

/// Una actividad lista para pintar: los cálculos ya hechos por el dominio.
///
/// La pantalla no llama a `AttendanceCounter` ni a `StreakCounter`: los pide
/// resueltos. Así la UI no puede contar saltos de dos maneras distintas en
/// dos sitios.
class SubjectCard {
  const SubjectCard({
    required this.subject,
    required this.weeklyClasses,
    required this.tally,
    required this.streak,
    this.evaluations = const [],
  });

  final Subject subject;
  final int weeklyClasses;
  final AbsenceTally tally;

  /// Semanas seguidas cumplidas, la actual y la mejor.
  final Streak streak;

  /// Herencia de Cátedra: filas de la tabla de evaluaciones, que Kairós ya no
  /// llena. Se conserva porque la mascota todavía la lee.
  final List<Evaluation> evaluations;
}

SubjectCard buildCard(SubjectOverview o, {required DateTime today}) => SubjectCard(
      subject: o.subject,
      weeklyClasses: o.weeklyClasses,
      tally: AttendanceCounter.tally(
        sessions: o.statuses,
        limit: o.subject.limiteFaltas,
      ),
      streak: StreakCounter.compute(o.history, today: today),
      evaluations: o.evaluations,
    );

final subjectsOverviewProvider = StreamProvider<List<SubjectCard>>((ref) {
  final today = ref.watch(todayProvider);
  return ref.watch(subjectsDaoProvider).watchOverview().map(
        (rows) => [for (final o in rows) buildCard(o, today: today)],
      );
});

/// Actividad abierta en el panel de detalle de tablet. Null cuando nada está
/// seleccionado; la pantalla entonces abre la primera de la lista, porque un
/// panel vacío con una lista al lado es una pregunta sin responder.
final selectedSubjectProvider = StateProvider<int?>((ref) => null);

/// Mantiene el periodo corriendo: al abrir y con cada cambio de día hay
/// [kDefaultSemesterWeeks] semanas de bloques por delante.
final horizonSyncProvider = Provider<void>((ref) {
  final day = ref.watch(todayProvider);
  unawaited(ref.read(subjectsDaoProvider).rollHorizon(day));
});
