import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/daos/subjects_dao.dart';
import '../../../core/providers.dart';
import '../../../domain/attendance/attendance.dart';
import '../../../domain/streaks/streaks.dart';

/// La actividad abierta, con saltos y racha ya calculados por el dominio.
class SubjectDetailState {
  const SubjectDetailState({
    required this.detail,
    required this.tally,
    required this.streak,
  });

  final SubjectDetail detail;
  final AbsenceTally tally;
  final Streak streak;
}

/// Familia por id de actividad. `null` significa que se borró mientras la
/// pantalla estaba abierta; quien escucha cierra la ruta.
final subjectDetailProvider =
    StreamProvider.family<SubjectDetailState?, int>((ref, subjectId) {
  final today = ref.watch(todayProvider);
  return ref.watch(subjectsDaoProvider).watchDetail(subjectId).map((detail) {
    if (detail == null) return null;
    return SubjectDetailState(
      detail: detail,
      tally: AttendanceCounter.tally(
        sessions: detail.statuses,
        limit: detail.subject.limiteFaltas,
      ),
      streak: StreakCounter.compute(detail.history, today: today),
    );
  });
});
