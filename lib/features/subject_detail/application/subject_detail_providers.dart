import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/daos/subjects_dao.dart';
import '../../../core/providers.dart';
import '../../../domain/attendance/attendance.dart';
import '../../../domain/grades/grades.dart' as domain;
import '../../subjects/application/subjects_providers.dart';

/// La materia abierta, con notas y faltas ya calculadas por el dominio.
class SubjectDetailState {
  const SubjectDetailState({
    required this.detail,
    required this.tally,
    required this.grades,
    required this.evaluations,
  });

  final SubjectDetail detail;
  final AbsenceTally tally;
  final domain.GradeSummary grades;

  /// Las mismas evaluaciones que alimentan el resumen, en versión de dominio,
  /// para que la calculadora inversa reciba exactamente lo que se pintó.
  final List<domain.Evaluation> evaluations;

  bool get hasGrades => evaluations.any((e) => e.isGraded);

  /// Los porcentajes que el profe dio. Cuando no suman 100 % hay que decirlo:
  /// la acumulada y la proyección se leen distinto si falta peso por repartir.
  double get totalWeight => domain.GradeCalculator.totalWeight(evaluations);
  bool get weightsAreComplete => domain.GradeCalculator.weightsAreComplete(evaluations);
}

/// Familia por id de materia. `null` significa que la materia se borró mientras
/// la pantalla estaba abierta; quien escucha cierra la ruta.
final subjectDetailProvider =
    StreamProvider.family<SubjectDetailState?, int>((ref, subjectId) {
  return ref.watch(subjectsDaoProvider).watchDetail(subjectId).map((detail) {
    if (detail == null) return null;
    final evaluations = toDomainEvaluations(detail.evaluations);
    return SubjectDetailState(
      detail: detail,
      tally: AttendanceCounter.tally(
        sessions: detail.statuses,
        limit: detail.subject.limiteFaltas,
      ),
      grades: domain.GradeCalculator.summarize(evaluations),
      evaluations: evaluations,
    );
  });
});
