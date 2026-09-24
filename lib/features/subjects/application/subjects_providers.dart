import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/daos/subjects_dao.dart';
import '../../../core/db/database.dart';
import '../../../core/providers.dart';
import '../../../domain/attendance/attendance.dart';
import '../../../domain/grades/grades.dart' as domain;

/// Una materia lista para pintar: los cálculos ya hechos por el dominio.
///
/// La pantalla no llama a `AttendanceCounter` ni a `GradeCalculator`: los pide
/// resueltos. Así la UI no puede equivocarse al contar faltas de dos maneras
/// distintas en dos sitios.
class SubjectCard {
  const SubjectCard({
    required this.subject,
    required this.weeklyClasses,
    required this.tally,
    required this.grades,
    required this.hasGrades,
    required this.evaluations,
  });

  final Subject subject;
  final int weeklyClasses;
  final AbsenceTally tally;
  final domain.GradeSummary grades;

  /// Las filas tal cual, para quien necesite la próxima evaluación con su
  /// fecha. El resumen ya está calculado en `grades`.
  final List<Evaluation> evaluations;

  /// Sin ninguna nota puesta, «acumulada 0,0» sería mentira: diría que vas
  /// perdiendo cuando no has presentado nada.
  final bool hasGrades;
}

/// Convierte las filas de Drift en las evaluaciones puras del dominio.
///
/// El dominio no conoce Drift y no va a conocerlo: el puente vive aquí, en la
/// capa de aplicación, y es el único sitio donde se cruzan los dos mundos.
List<domain.Evaluation> toDomainEvaluations(Iterable<Evaluation> rows) => [
      for (final e in rows)
        domain.Evaluation(
          id: e.id.toString(),
          name: e.nombre,
          weight: e.porcentaje,
          score: e.nota,
          date: e.fecha,
        ),
    ];

SubjectCard buildCard(SubjectOverview o) {
  final evaluations = toDomainEvaluations(o.evaluations);
  return SubjectCard(
    subject: o.subject,
    weeklyClasses: o.weeklyClasses,
    tally: AttendanceCounter.tally(
      sessions: o.statuses,
      limit: o.subject.limiteFaltas,
    ),
    grades: domain.GradeCalculator.summarize(evaluations),
    hasGrades: evaluations.any((e) => e.isGraded),
    evaluations: o.evaluations,
  );
}

final subjectsOverviewProvider = StreamProvider<List<SubjectCard>>((ref) {
  return ref.watch(subjectsDaoProvider).watchOverview().map(
        (rows) => rows.map(buildCard).toList(),
      );
});

/// Materia abierta en el panel de detalle de tablet. Null cuando nada está
/// seleccionado; la pantalla entonces abre la primera de la lista, porque un
/// panel vacío con una lista al lado es una pregunta sin responder.
final selectedSubjectProvider = StateProvider<int?>((ref) => null);
