import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/time/minutes_of_day.dart';
import '../../../domain/attendance/absence_state.g.dart';
import '../../../l10n/strings.g.dart';
import '../../subjects/application/subjects_providers.dart';
import '../../today/application/today_providers.dart';
import '../../today/presentation/widgets/day_timeline.dart';
import '../mascot_view.dart';

/// Un consejo de Erizógenes: qué dice y con qué cara lo dice.
class MascotTip {
  const MascotTip(this.text, this.pose);

  final String text;
  final MascotPose pose;
}

/// Cuántos días antes empieza a avisar de una evaluación o de la fecha límite
/// de cancelación. Más lejos que eso es ruido.
const int kTipLookaheadDays = 7;

/// Los consejos del día, del más urgente al más tranquilo.
///
/// No inventa nada: cada frase sale de un dato que ya está en la app. Si no
/// hay nada que decir, dice que no hay nada en riesgo, que también es útil.
///
/// Nunca menciona una materia perdida: el contrato prohíbe la mascota ahí,
/// porque una cara tierna junto a esa noticia se siente burlona.
final mascotTipsProvider = Provider<List<MascotTip>>((ref) {
  final today = ref.watch(todayProvider);
  final state = ref.watch(todayStateProvider).valueOrNull;
  final cards = ref.watch(subjectsOverviewProvider).valueOrNull ?? const <SubjectCard>[];

  final tips = <MascotTip>[];

  // Cada consejo tiene varias frases con los mismos datos. La elegida se
  // mantiene todo el día —el provider se recalcula con cada tic del reloj y el
  // texto no puede saltar solo— y cambia al siguiente.
  final day = today.difference(DateTime(today.year)).inDays;
  String v(List<String> options, [int salt = 0]) => options[(day + salt) % options.length];

  // 1. Lo que viene hoy.
  final next = state?.next;
  final plan = state?.plan;
  if (next != null && plan != null && !plan.isUrgent) {
    final clase = next.subject.nombre;
    final hora = MinutesOfDay(next.session.horaInicio).hhmm;
    if (plan.minutesUntilLeave <= 15) {
      tips.add(MascotTip(
        v(SMascotVoice.leaveSoonVariants(n: plan.minutesUntilLeave, clase: clase)),
        MascotPose.examinando,
      ));
    } else {
      final salon = next.room?.codigo;
      tips.add(MascotTip(
        salon == null
            ? v(SMascotVoice.nextClassNoRoomVariants(clase: clase, hora: hora, salida: plan.leaveAt.hhmm))
            : v(SMascotVoice.nextClassVariants(clase: clase, hora: hora, salon: salon, salida: plan.leaveAt.hhmm)),
        MascotPose.reposo,
      ));
    }
  } else if (state != null && state.isDone) {
    tips.add(MascotTip(v(SMascotVoice.allDoneVariants), MascotPose.satisfecho));
  }

  final live = cards.where((c) => !c.subject.cancelada && !c.subject.archivada).toList();

  // 2. Faltas: solo riesgo, nunca perdida.
  for (final c in live) {
    if (c.tally.state != AbsenceState.risk) continue;
    tips.add(MascotTip(
      c.tally.remaining == 1
          ? v(SMascotVoice.riskOneVariants(clase: c.subject.nombre), c.subject.id)
          : v(SMascotVoice.riskVariants(clase: c.subject.nombre, n: c.tally.remaining), c.subject.id),
      MascotPose.examinando,
    ));
  }

  // 3. Evaluaciones sin nota en los próximos días.
  final horizon = today.add(const Duration(days: kTipLookaheadDays));
  for (final c in live) {
    for (final e in c.evaluations) {
      final f = e.fecha;
      if (f == null || e.nota != null) continue;
      final evalDay = DateTime(f.year, f.month, f.day);
      if (evalDay.isBefore(today) || evalDay.isAfter(horizon)) continue;
      tips.add(MascotTip(
        evalDay == today
            ? v(SMascotVoice.evalTodayVariants(eval: e.nombre, clase: c.subject.nombre), e.id)
            : v(
                SMascotVoice.evalSoonVariants(
                  eval: e.nombre,
                  clase: c.subject.nombre,
                  dia: '${SWeek.days[evalDay.weekday - 1]} ${evalDay.day}',
                ),
                e.id,
              ),
        MascotPose.examinando,
      ));
    }
  }

  // 4. El hueco más largo que todavía no pasó.
  if (state != null) {
    final now = MinutesOfDay.of(state.now.hour, state.now.minute);
    final byId = {for (final c in state.classes) c.instance.id: c};
    final upcoming = state.gapsAfter.entries
        .where((e) => MinutesOfDay(byId[e.key]!.session.horaFin) > now)
        .map((e) => e.value)
        .toList()
      ..sort((a, b) => b.minutes.compareTo(a.minutes));
    if (upcoming.isNotEmpty) {
      tips.add(MascotTip(v(SMascotVoice.gapVariants(dur: formatGapDuration(upcoming.first))), MascotPose.reposo));
    }
  }

  // 5. Fechas límite de cancelación cercanas.
  for (final c in live) {
    final f = c.subject.fechaLimiteCancelacion;
    if (f == null) continue;
    final days = DateTime(f.year, f.month, f.day).difference(today).inDays;
    if (days < 0 || days > kTipLookaheadDays) continue;
    tips.add(MascotTip(
      v(SMascotVoice.deadlineSoonVariants(n: days, clase: c.subject.nombre), c.subject.id),
      MascotPose.examinando,
    ));
  }

  // 6. Sin nada en riesgo, se dice: es la mejor noticia de la pantalla.
  if (live.isNotEmpty && live.every((c) => c.tally.state == AbsenceState.ok)) {
    tips.add(MascotTip(v(SMascotVoice.noRiskVariants), MascotPose.satisfecho));
  }

  if (tips.isEmpty && (today.weekday == DateTime.saturday || today.weekday == DateTime.sunday)) {
    tips.add(MascotTip(v(SMascotVoice.weekendVariants), MascotPose.dormido));
  }

  // Al final del ciclo, una sentencia: no es un dato, es la actitud. Solo si
  // hay algo más que decir, para que nunca ocupe el lugar de un consejo útil.
  if (tips.isNotEmpty) tips.add(MascotTip(v(SMascotVoice.aphorisms), MascotPose.reposo));
  return tips;
});

/// Qué ocurrencia viene a cuento ahora. Cada una remite a la vida de
/// Diógenes, y el contexto decide cuál: el rollo si hay una evaluación cerca,
/// el reloj de arena si la próxima clase está a menos de media hora, la
/// tinaja o el sol si hoy no hay clases. Si nada aprieta, el cuenco o el gallo
/// de Platón, alternando por día.
final mascotAnticProvider = Provider<MascotAntic>((ref) {
  final today = ref.watch(todayProvider);
  final state = ref.watch(todayStateProvider).valueOrNull;
  final cards = ref.watch(subjectsOverviewProvider).valueOrNull ?? const <SubjectCard>[];

  final horizon = today.add(const Duration(days: kTipLookaheadDays));
  final examSoon = cards.any(
    (c) => c.evaluations.any((e) {
      final f = e.fecha;
      if (f == null || e.nota != null) return false;
      final d = DateTime(f.year, f.month, f.day);
      return !d.isBefore(today) && !d.isAfter(horizon);
    }),
  );
  if (examSoon) return MascotAntic.scroll;

  final plan = state?.plan;
  if (plan != null && !plan.isUrgent && plan.minutesUntilLeave <= kAnticClassSoonMinutes) {
    return MascotAntic.hourglass;
  }

  final day = today.difference(DateTime(today.year)).inDays;
  if (state != null && state.classes.isEmpty) return day.isEven ? MascotAntic.jar : MascotAntic.sun;
  return day.isEven ? MascotAntic.bowl : MascotAntic.chicken;
});

/// Minutos hasta la salida por debajo de los cuales el reloj de arena viene
/// a cuento.
const int kAnticClassSoonMinutes = 30;
