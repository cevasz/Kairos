import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/durations.dart';
import '../../../../core/providers.dart';
import '../../../../core/time/minutes_of_day.dart';
import '../../../../l10n/strings.g.dart';
import '../../../../theme/accent_card.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/haptics.dart';
import '../../../../theme/tokens.g.dart';
import '../../../../theme/transitions.dart';
import '../../../travel/application/travel_providers.dart';

/// «En camino desde las 7:32 · Llegué». Aparece tras «Ya voy» saliendo de
/// casa y se va al cerrar el viaje. Cada viaje cerrado corrige el trayecto
/// del día y la franja en que se hizo (§47).
class TripStrip extends ConsumerWidget {
  const TripStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final since = ref.watch(tripInProgressProvider);
    return StateSwitcher(
      child: since == null
          ? const SizedBox.shrink(key: ValueKey('no-trip'))
          : Padding(
              key: const ValueKey('trip'),
              padding: EdgeInsets.only(bottom: SpaceTokens.l),
              child: _Strip(since: since),
            ),
    );
  }
}

class _Strip extends ConsumerWidget {
  const _Strip({required this.since});
  final DateTime since;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secondary = context.themed(ColorTokens.textSecondary);
    return AccentCard(
      accent: context.themed(ColorTokens.accentOk),
      color: context.themed(ColorTokens.surfaceCard),
      shadow: ElevationTokens.card(Theme.of(context).brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_walk, color: context.themed(ColorTokens.accentOk)),
              SizedBox(width: SpaceTokens.s),
              Expanded(
                child: Text(
                  STrip.onTheWay(hora: MinutesOfDay.of(since.hour, since.minute).hhmm),
                  style: context.type(TypeTokens.titleS),
                ),
              ),
            ],
          ),
          SizedBox(height: SpaceTokens.xs),
          Text(STrip.onTheWayHint, style: context.type(TypeTokens.bodyM, color: secondary)),
          SizedBox(height: SpaceTokens.s),
          Row(
            children: [
              TextButton(
                onPressed: () => ref.read(tripsDaoProvider).discard(),
                child: const Text(STrip.discard),
              ),
              const Spacer(),
              FilledButton.icon(
                // Sin esto hereda el ancho entero del tema y, junto al Spacer,
                // no se dibuja.
                style: FilledButton.styleFrom(minimumSize: Size.square(ComponentTokens.buttonMinTouchTarget)),
                onPressed: () => _arrive(context, ref),
                icon: const Icon(Icons.flag_outlined),
                label: const Text(STrip.arrived),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _arrive(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    unawaited(Haptics.fire('marcarAsistencia'));
    final minutes = await ref.read(tripsDaoProvider).arrive(DateTime.now());
    messenger?.showSnackBar(SnackBar(
      content: Text(minutes == null ? STrip.notSaved : STrip.saved(dur: TimeSpans.minutes(minutes))),
    ));
  }
}
