import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/time/minutes_of_day.dart';
import '../../../../domain/departure/departure.dart';
import '../../../../l10n/strings.g.dart';
import '../../../../theme/accent_card.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/tokens.g.dart';
import '../../application/map_providers.dart';
import 'room_sheet.dart';

/// «Tu próximo salón»: lo primero que se mira al abrir el mapa. Dice a dónde,
/// cuándo salir y, con un toque, abre la ruta.
class NextRoomCard extends ConsumerWidget {
  const NextRoomCard({required this.rooms, required this.onFocus, required this.onPlace, super.key});

  final List<MapRoom> rooms;
  final ValueChanged<MapRoom> onFocus;
  final ValueChanged<MapRoom> onPlace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = Theme.of(context).brightness;
    final next = ref.watch(nextRoomProvider);
    final today = ref.watch(todayProvider);
    final here = ref.watch(locationProvider).position;
    final mode = ref.watch(settingsProvider).valueOrNull?.modoTransporte ?? TransportMode.walk;

    if (next == null) {
      return _Frame(
        accent: ColorTokens.surfaceBorder.of(b),
        child: Text(SMap.noNext, style: context.type(TypeTokens.bodyL, color: ColorTokens.textSecondary.of(b))),
      );
    }

    final item = next.item;
    final roomId = item.room?.id;
    final room = roomId == null ? null : rooms.where((r) => r.room.id == roomId).firstOrNull;
    final hora = MinutesOfDay(item.session.horaInicio).hhmm;
    final fecha = item.instance.fecha;
    final days = DateTime(fecha.year, fecha.month, fecha.day).difference(today).inDays;
    final when = switch (days) {
      0 => SMap.dayLabel(dia: SMap.today, hora: hora),
      1 => SMap.dayLabel(dia: SMap.tomorrow, hora: hora),
      _ => SMap.dayLabel(dia: SWeek.days[fecha.weekday - 1], hora: hora),
    };
    final plan = next.plan;
    final urgent = plan?.isUrgent ?? false;
    final accent = urgent ? ColorTokens.accentUrgent.of(b) : SubjectPalette.at(item.subject.colorIndex);
    final distance = here != null && room?.point != null ? metersBetween(here, room!.point!) : null;

    return _Frame(
      accent: accent,
      onTap: room == null ? null : () => onFocus(room),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(SMap.nextRoomLabel, style: context.type(TypeTokens.label, color: ColorTokens.textTertiary.of(b))),
          SizedBox(height: SpaceTokens.s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  item.room?.codigo ?? item.subject.nombre,
                  style: context.type(TypeTokens.titleL),
                ),
              ),
              if (distance != null)
                Text(
                  formatDistance(distance),
                  style: context.type(TypeTokens.bodyM, color: ColorTokens.textSecondary.of(b)),
                ),
            ],
          ),
          SizedBox(height: SpaceTokens.xs),
          Text(
            '${item.room == null ? '' : '${item.subject.nombre} · '}$when',
            style: context.type(TypeTokens.bodyM, color: ColorTokens.textSecondary.of(b)),
          ),
          if (plan != null) ...[
            SizedBox(height: SpaceTokens.xs),
            Text(
              urgent ? SToday.urgentHeadline : SMap.nextLeave(hora: plan.leaveAt.hhmm),
              style: context.type(TypeTokens.bodyS, color: urgent ? accent : ColorTokens.accentPrimary.of(b)),
            ),
          ],
          if (room != null) ...[
            SizedBox(height: SpaceTokens.m),
            if (room.isPlaced)
              FilledButton.icon(
                onPressed: () => openRoute(room.point!, mode),
                style: urgent
                    ? FilledButton.styleFrom(
                        backgroundColor: ColorTokens.accentUrgent.of(b),
                        foregroundColor: ColorTokens.textOnUrgent.of(b),
                      )
                    : null,
                icon: Icon(transportIcon(mode)),
                label: const Text(SMap.startRoute),
              )
            else ...[
              Text(
                SMap.nextUnplaced,
                style: context.type(TypeTokens.captionS, color: ColorTokens.textTertiary.of(b)),
              ),
              SizedBox(height: SpaceTokens.s),
              OutlinedButton.icon(
                onPressed: () => onPlace(room),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text(SMap.placeRoom),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.accent, required this.child, this.onTap});
  final Color accent;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Material(
      color: ColorTokens.surfaceCard.of(b),
      borderRadius: BorderRadius.circular(RadiusTokens.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RadiusTokens.card),
        child: AccentCard(accent: accent, child: child),
      ),
    );
  }
}
