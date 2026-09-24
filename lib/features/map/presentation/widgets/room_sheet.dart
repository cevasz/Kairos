import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers.dart';
import '../../../../core/time/minutes_of_day.dart';
import '../../../../domain/departure/departure.dart';
import '../../../../l10n/strings.g.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/tokens.g.dart';
import '../../application/map_providers.dart';

/// Abre la ruta en la app de mapas del teléfono, con el modo de transporte de
/// Ajustes. Kairós no dibuja rutas: la app de mapas ya lo hace mejor y sabe
/// del tráfico.
Future<bool> openRoute(LatLng to, TransportMode mode) {
  final travel = switch (mode) {
    TransportMode.walk => 'walking',
    TransportMode.bus => 'transit',
    TransportMode.car => 'driving',
  };
  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '${to.latitude},${to.longitude}',
    'travelmode': travel,
  });
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// «a 350 m», «a 1,2 km».
String formatDistance(double meters) {
  if (meters < 1000) return SMap.distanceM(n: (meters / 10).round() * 10);
  return SMap.distanceKm(n: (meters / 1000).toStringAsFixed(1).replaceAll('.', ','));
}

/// Detalle de un salón: sus clases, las indicaciones y la ruta.
Future<void> showRoomSheet(BuildContext context, {required MapRoom room, required VoidCallback onMove}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RoomSheet(room: room, onMove: onMove),
  );
}

class _RoomSheet extends ConsumerStatefulWidget {
  const _RoomSheet({required this.room, required this.onMove});
  final MapRoom room;
  final VoidCallback onMove;

  @override
  ConsumerState<_RoomSheet> createState() => _RoomSheetState();
}

class _RoomSheetState extends ConsumerState<_RoomSheet> {
  late final _notes = TextEditingController(text: widget.room.room.indicaciones ?? '');
  bool _dirty = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    final v = _notes.text.trim();
    await ref.read(scheduleDaoProvider).setRoomNotes(widget.room.room.id, v.isEmpty ? null : v);
    if (mounted) setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final room = widget.room;
    final here = ref.watch(locationProvider).position;
    final mode = ref.watch(settingsProvider).valueOrNull?.modoTransporte ?? TransportMode.walk;
    final distance = here != null && room.point != null ? metersBetween(here, room.point!) : null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          SpaceTokens.screenMargin,
          0,
          SpaceTokens.screenMargin,
          SpaceTokens.l + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(child: Text(room.room.codigo, style: context.type(TypeTokens.titleL))),
                  if (distance != null)
                    Text(
                      formatDistance(distance),
                      style: context.type(TypeTokens.bodyM, color: ColorTokens.textSecondary.of(b)),
                    ),
                ],
              ),
              SizedBox(height: SpaceTokens.m),
              for (final (session, subject) in room.classes)
                Padding(
                  padding: EdgeInsets.only(bottom: SpaceTokens.s),
                  child: Row(
                    children: [
                      Container(
                        width: SpaceTokens.s,
                        height: SpaceTokens.s,
                        decoration: BoxDecoration(
                          color: SubjectPalette.at(subject.colorIndex),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: SpaceTokens.s),
                      SizedBox(
                        width: SpaceTokens.xxxl * 2 + SpaceTokens.l,
                        child: Text(
                          SSessionForm.summary(
                            dia: SWeek.days[session.diaSemana - 1],
                            inicio: MinutesOfDay(session.horaInicio).hhmm,
                            fin: MinutesOfDay(session.horaFin).hhmm,
                          ),
                          style: context.type(TypeTokens.caption, color: ColorTokens.textSecondary.of(b)),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          subject.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.type(TypeTokens.bodyS),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: SpaceTokens.m),
              TextField(
                controller: _notes,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) {
                  if (!_dirty) setState(() => _dirty = true);
                },
                decoration: InputDecoration(
                  labelText: SMap.notesLabel,
                  hintText: SMap.notesHint,
                  suffixIcon: _dirty
                      ? IconButton(
                          tooltip: SMap.save,
                          icon: Icon(Icons.check, color: ColorTokens.accentPrimary.of(b)),
                          onPressed: _saveNotes,
                        )
                      : null,
                ),
                onSubmitted: (_) => _saveNotes(),
              ),
              SizedBox(height: SpaceTokens.xl),
              if (room.isPlaced)
                FilledButton.icon(
                  onPressed: () => openRoute(room.point!, mode),
                  icon: Icon(transportIcon(mode)),
                  label: const Text(SMap.openRoute),
                ),
              SizedBox(height: SpaceTokens.s),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onMove();
                      },
                      icon: const Icon(Icons.open_with),
                      label: Text(room.isPlaced ? SMap.moveRoom : SMap.placeRoom),
                    ),
                  ),
                  if (room.isPlaced) ...[
                    SizedBox(width: SpaceTokens.s),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          await ref.read(scheduleDaoProvider).setRoomLocation(room.room.id);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        child: Text(
                          SMap.clearRoom,
                          style: context.type(TypeTokens.bodyM, color: ColorTokens.textSecondary.of(b)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El ícono del modo de transporte de Ajustes, en el botón de la ruta.
IconData transportIcon(TransportMode mode) => switch (mode) {
      TransportMode.walk => Icons.directions_walk,
      TransportMode.bus => Icons.directions_bus_outlined,
      TransportMode.car => Icons.directions_car_outlined,
    };
