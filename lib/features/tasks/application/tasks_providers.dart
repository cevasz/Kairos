import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/daos/tasks_dao.dart';
import '../../../core/db/database.dart';
import '../../../core/providers.dart';

/// Los pendientes de una actividad, abiertos primero.
final subjectTasksProvider = StreamProvider.family<List<Task>, int>(
  (ref, subjectId) => ref.watch(tasksDaoProvider).watchForSubject(subjectId),
);

/// Todo lo pendiente de actividades vivas. Lo leen el widget de pendientes
/// y los avisos de la víspera.
final pendingProvider = StreamProvider<List<PendingItem>>(
  (ref) => ref.watch(tasksDaoProvider).watchPending(),
);
