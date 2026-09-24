import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/daos/schedule_dao.dart';
import '../../../core/providers.dart';
import '../../../core/time/calendar_day.dart';

/// Un día cualquiera de la semana que se está mirando. Arranca en hoy y las
/// flechas lo mueven de siete en siete; volver a hoy es escribir `today`.
final weekAnchorProvider = StateProvider<DateTime>((ref) => ref.watch(todayProvider));

/// Lunes de la semana del ancla, a medianoche.
final weekMondayProvider = Provider<DateTime>((ref) {
  final anchor = startOfDay(ref.watch(weekAnchorProvider));
  return anchor.subtract(Duration(days: anchor.weekday - 1));
});

final weekProvider = StreamProvider<Map<int, List<DayClass>>>((ref) {
  final anchor = ref.watch(weekAnchorProvider);
  return ref.watch(scheduleDaoProvider).watchWeek(anchor);
});
