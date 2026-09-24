import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/daos/tasks_dao.dart';
import '../../../core/db/database.dart';
import '../../../core/providers.dart';

/// Las tareas de una materia, abiertas primero.
final subjectTasksProvider = StreamProvider.family<List<Task>, int>(
  (ref, subjectId) => ref.watch(tasksDaoProvider).watchForSubject(subjectId),
);

/// Todo lo pendiente de materias vivas: tareas abiertas y evaluaciones sin
/// nota desde hoy. Lo leen el widget de pendientes y las alarmas.
final pendingProvider = StreamProvider<List<PendingItem>>(
  (ref) => ref.watch(tasksDaoProvider).watchPending(ref.watch(todayProvider)),
);
