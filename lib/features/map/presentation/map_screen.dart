import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/providers.dart';
import '../../../l10n/strings.g.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/haptics.dart';
import '../../../theme/map_style.dart';
import '../../../theme/motion.dart';
import '../../../theme/tokens.g.dart';
import '../application/map_providers.dart';
import 'widgets/next_room_card.dart';
import 'widgets/room_pin.dart';
import 'widgets/room_sheet.dart';
import 'widgets/room_tile.dart';

/// Sin salones ubicados ni ubicación, el mapa arranca sobre Colombia entera.
/// Es la única coordenada fija de la app: en cuanto ubicas un salón o das
/// permiso de ubicación, el mapa se va para allá.
const LatLng kFallbackCenter = LatLng(4.6, -74.08);
const double kFallbackZoom = 5.5;

/// Zoom de campus: se leen los edificios y los caminos entre ellos.
const double kCampusZoom = 17.5;

/// La pestaña Mapa.
///
/// Los PDF traen el código del salón, nunca su ubicación, y ningún servicio de
/// geocodificación sabe dónde queda «Sala de Sistemas 2E». Así que cada salón
/// se ubica a mano una sola vez —se arrastra el mapa bajo la cruz y se
/// confirma— y desde ahí la ruta sale sola cada semana.
///
/// Sin mascota: «mapa» está en la lista de pantallas prohibidas del contrato.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with TickerProviderStateMixin {
  final _map = MapController();
  final _search = TextEditingController();
  final _sheet = DraggableScrollableController();

  /// El salón que se está ubicando. Mientras no sea null, el mapa muestra la
  /// cruz y los botones de confirmar.
  MapRoom? _placing;

  /// Salón resaltado en el mapa tras tocarlo en la lista.
  int? _focused;

  String _query = '';
  bool _ready = false;
  bool _framed = false;
  AnimationController? _flight;

  @override
  void dispose() {
    _flight?.dispose();
    _search.dispose();
    _sheet.dispose();
    _map.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────── cámara

  /// Vuela a un punto. Bajo «reducir movimiento» salta.
  void _flyTo(LatLng dest, {double? zoom}) {
    if (!_ready) return;
    final targetZoom = zoom ?? _map.camera.zoom;
    final guard = MotionGuard.of(context);
    if (guard.reduced) {
      _map.move(dest, targetZoom);
      return;
    }
    final from = _map.camera.center;
    final fromZoom = _map.camera.zoom;
    _flight?.dispose();
    final c = AnimationController(vsync: this, duration: MotionDurations.hero * 2);
    _flight = c;
    final t = CurvedAnimation(parent: c, curve: MotionCurves.easeOutCubic);
    c.addListener(() {
      final lat = from.latitude + (dest.latitude - from.latitude) * t.value;
      final lng = from.longitude + (dest.longitude - from.longitude) * t.value;
      _map.move(LatLng(lat, lng), fromZoom + (targetZoom - fromZoom) * t.value);
    });
    c.forward();
  }

  /// La primera vez que hay datos, se encuadran los salones ubicados. Si no
  /// hay ninguno, se espera a la ubicación.
  void _frameOnce(List<MapRoom> rooms, LocationState location) {
    if (_framed || !_ready) return;
    final placed = rooms.where((r) => r.isPlaced).map((r) => r.point!).toList();
    if (placed.length == 1) {
      _framed = true;
      _map.move(placed.single, kCampusZoom);
    } else if (placed.length > 1) {
      _framed = true;
      _map.fitCamera(CameraFit.coordinates(
        coordinates: placed,
        padding: EdgeInsets.all(
          SpaceTokens.xxxl * 2,
        ),
        maxZoom: kCampusZoom,
      ));
    } else if (location.position != null) {
      _framed = true;
      _map.move(location.position!, kCampusZoom);
    }
  }

  Future<void> _locate() async {
    final here = await ref.read(locationProvider.notifier).request();
    if (!mounted) return;
    if (here != null) {
      _flyTo(here, zoom: kCampusZoom);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(SMap.locationDenied)));
  }

  // ─────────────────────────────────────────────────────────── ubicar

  void _startPlacing(MapRoom room) {
    setState(() {
      _placing = room;
      _focused = room.room.id;
    });
    // Arranca donde tenga más sentido: donde ya estaba, donde estás tú, o
    // donde el mapa esté mirando.
    final start = room.point ?? ref.read(locationProvider).position;
    if (start != null) _flyTo(start, zoom: kCampusZoom);
  }

  Future<void> _confirmPlacing() async {
    final room = _placing;
    if (room == null) return;
    final c = _map.camera.center;
    unawaited(Haptics.fire('ubicarSalon'));
    await ref.read(scheduleDaoProvider).setRoomLocation(room.room.id, lat: c.latitude, lng: c.longitude);
    if (mounted) setState(() => _placing = null);
  }

  void _focus(MapRoom room) {
    setState(() => _focused = room.room.id);
    if (room.isPlaced) {
      _flyTo(room.point!, zoom: kCampusZoom);
      unawaited(showRoomSheet(context, room: room, onMove: () => _startPlacing(room)));
    } else {
      _startPlacing(room);
    }
  }

  // ─────────────────────────────────────────────────────────── build

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final rooms = ref.watch(mapRoomsProvider).valueOrNull ?? const <MapRoom>[];
    final location = ref.watch(locationProvider);
    final next = ref.watch(nextRoomProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _frameOnce(rooms, location);
    });

    final nextRoomId = next?.item.room?.id;
    final placing = _placing;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: kFallbackCenter,
              initialZoom: kFallbackZoom,
              backgroundColor: ColorTokens.surfaceBase.of(b),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onMapReady: () {
                _ready = true;
                _frameOnce(rooms, location);
              },
              // Ubicando, tocar el mapa lleva la cruz hasta ahí.
              onTap: (_, point) {
                if (_placing != null) _flyTo(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.kairos.app',
                tileBuilder: MapTileStyle.tileBuilder,
              ),
              MarkerLayer(
                markers: [
                  for (final r in rooms)
                    if (r.isPlaced && r.room.id != placing?.room.id)
                      Marker(
                        point: r.point!,
                        width: RoomPin.width,
                        height: RoomPin.height,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () => _focus(r),
                          child: RoomPin(
                            label: r.room.codigo,
                            color: SubjectPalette.at(r.colorIndex),
                            isNext: r.room.id == nextRoomId,
                            focused: r.room.id == _focused,
                          ),
                        ),
                      ),
                  if (location.position != null)
                    Marker(
                      point: location.position!,
                      width: UserDot.size,
                      height: UserDot.size,
                      child: const UserDot(),
                    ),
                ],
              ),
              const SimpleAttributionWidget(source: Text(SMap.attribution)),
            ],
          ),
          if (placing != null) ...[
            // La cruz: el salón queda donde apunta la base del pin.
            IgnorePointer(
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -RoomPin.height / 2),
                  child: RoomPin(
                    label: placing.room.codigo,
                    color: SubjectPalette.at(placing.colorIndex),
                    isNext: false,
                    focused: true,
                  ),
                ),
              ),
            ),
            _PlacingBar(
              room: placing,
              onCancel: () => setState(() => _placing = null),
              onConfirm: _confirmPlacing,
            ),
          ] else ...[
            _TopBar(
              controller: _search,
              onChanged: (v) {
                setState(() => _query = v.trim().toLowerCase());
                // Al buscar, la lista sube para que se vean los resultados.
                if (v.isNotEmpty && _sheet.isAttached && _sheet.size < _RoomsSheet.max) {
                  _sheet.animateTo(
                    _RoomsSheet.max,
                    duration: MotionGuard.of(context).duration(MotionDurations.base),
                    curve: MotionCurves.easeOutCubic,
                  );
                }
              },
              onLocate: _locate,
              locating: location.status == LocationStatus.granted,
            ),
            _RoomsSheet(
              controller: _sheet,
              rooms: rooms,
              query: _query,
              focused: _focused,
              onRoom: _focus,
              onPlace: _startPlacing,
              onFocusNext: (r) => _focus(r),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── piezas

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.onChanged,
    required this.onLocate,
    required this.locating,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onLocate;
  final bool locating;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final surface = ColorTokens.surfaceCard.of(b);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          SpaceTokens.l,
          SpaceTokens.s,
          SpaceTokens.l,
          0,
        ),
        child: Row(
          children: [
            Expanded(
              child: Material(
                color: surface,
                elevation: 0,
                borderRadius: BorderRadius.circular(RadiusTokens.full),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(RadiusTokens.full),
                    boxShadow: ElevationTokens.raised(b),
                  ),
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    style: context.type(TypeTokens.bodyL),
                    decoration: InputDecoration(
                      hintText: SMap.search,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: ValueListenableBuilder(
                        valueListenable: controller,
                        builder: (_, v, __) => v.text.isEmpty
                            ? const SizedBox.shrink()
                            : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  controller.clear();
                                  onChanged('');
                                },
                              ),
                      ),
                      filled: true,
                      fillColor: surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RadiusTokens.full),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RadiusTokens.full),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RadiusTokens.full),
                        borderSide: BorderSide(color: ColorTokens.accentPrimary.of(b)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: SpaceTokens.s),
            Container(
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: ElevationTokens.raised(b)),
              child: IconButton.filledTonal(
                onPressed: onLocate,
                tooltip: SMap.locate,
                style: IconButton.styleFrom(
                  backgroundColor: surface,
                  minimumSize: const Size.square(ComponentTokens.buttonMinTouchTarget + SpaceTokens.xs),
                ),
                icon: Icon(
                  locating ? Icons.my_location : Icons.location_searching,
                  color: ColorTokens.accentPrimary.of(b),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Instrucción arriba y los dos botones abajo, en la zona del pulgar.
class _PlacingBar extends StatelessWidget {
  const _PlacingBar({required this.room, required this.onCancel, required this.onConfirm});

  final MapRoom room;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(SpaceTokens.l),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(SpaceTokens.m + SpaceTokens.xs),
              decoration: BoxDecoration(
                color: ColorTokens.surfaceCard.of(b),
                borderRadius: BorderRadius.circular(RadiusTokens.card),
                boxShadow: ElevationTokens.raised(b),
              ),
              child: Row(
                children: [
                  Icon(Icons.touch_app_outlined, color: ColorTokens.accentPrimary.of(b)),
                  SizedBox(width: SpaceTokens.m),
                  Expanded(
                    child: Text(
                      SMap.placing(salon: room.room.codigo),
                      style: context.type(TypeTokens.bodyS),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(backgroundColor: ColorTokens.surfaceCard.of(b)),
                    onPressed: onCancel,
                    child: const Text(SMap.cancel),
                  ),
                ),
                SizedBox(width: SpaceTokens.m),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.check),
                    label: const Text(SMap.placeHere),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// La hoja de abajo: tu próximo salón y la lista de salones.
class _RoomsSheet extends ConsumerWidget {
  const _RoomsSheet({
    required this.controller,
    required this.rooms,
    required this.query,
    required this.focused,
    required this.onRoom,
    required this.onPlace,
    required this.onFocusNext,
  });

  final DraggableScrollableController controller;
  final List<MapRoom> rooms;
  final String query;
  final int? focused;
  final ValueChanged<MapRoom> onRoom;
  final ValueChanged<MapRoom> onPlace;
  final ValueChanged<MapRoom> onFocusNext;

  static const double _min = 0.16;
  static const double _initial = 0.36;
  static const double max = 0.88;

  bool _matches(MapRoom r) {
    if (query.isEmpty) return true;
    if (r.room.codigo.toLowerCase().contains(query)) return true;
    return r.classes.any((c) => c.$2.nombre.toLowerCase().contains(query));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = Theme.of(context).brightness;
    final visible = rooms.where(_matches).toList();
    final placed = rooms.where((r) => r.isPlaced).length;
    final searching = query.isNotEmpty;

    return DraggableScrollableSheet(
      controller: controller,
      minChildSize: _min,
      initialChildSize: _initial,
      maxChildSize: max,
      snap: true,
      snapSizes: const [_initial],
      builder: (context, scroll) => DecoratedBox(
        decoration: BoxDecoration(
          color: ColorTokens.surfaceBase.of(b),
          borderRadius: BorderRadius.vertical(top: Radius.circular(RadiusTokens.sheet)),
          boxShadow: ElevationTokens.sheet(b),
        ),
        child: ListView(
          controller: scroll,
          padding: EdgeInsets.fromLTRB(
            SpaceTokens.l,
            0,
            SpaceTokens.l,
            SpaceTokens.xxl,
          ),
          children: [
            const _Handle(),
            if (!searching) ...[
              NextRoomCard(rooms: rooms, onFocus: onFocusNext, onPlace: onPlace),
              SizedBox(height: SpaceTokens.xl),
            ],
            if (rooms.isEmpty)
              _Empty()
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(SMap.roomsLabel, style: context.type(TypeTokens.titleS)),
                  const Spacer(),
                  Text(
                    SMap.placedCount(n: placed, total: rooms.length),
                    style: context.type(
                      TypeTokens.captionS,
                      color: placed == rooms.length
                          ? ColorTokens.accentOk.of(b)
                          : ColorTokens.textTertiary.of(b),
                    ),
                  ),
                ],
              ),
              if (placed < rooms.length && !searching) ...[
                SizedBox(height: SpaceTokens.xs),
                Text(
                  SMap.notPlacedHint,
                  style: context.type(TypeTokens.captionS, color: ColorTokens.textTertiary.of(b)),
                ),
              ],
              SizedBox(height: SpaceTokens.m),
              if (visible.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: SpaceTokens.xl),
                  child: Text(
                    SMap.searchEmpty,
                    textAlign: TextAlign.center,
                    style: context.type(TypeTokens.bodyM, color: ColorTokens.textSecondary.of(b)),
                  ),
                ),
              for (final r in visible) ...[
                RoomTile(
                  room: r,
                  focused: r.room.id == focused,
                  onTap: () => onRoom(r),
                  onPlace: () => onPlace(r),
                ),
                SizedBox(height: SpaceTokens.s),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: EdgeInsets.symmetric(vertical: SpaceTokens.m),
          width: SpaceTokens.xxxl,
          height: SpaceTokens.xs,
          decoration: BoxDecoration(
            color: context.themed(ColorTokens.surfaceBorder),
            borderRadius: BorderRadius.circular(RadiusTokens.full),
          ),
        ),
      );
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: SpaceTokens.l),
      child: Column(
        children: [
          Icon(Icons.meeting_room_outlined, size: IconTokens.sizeXl * 2, color: ColorTokens.textTertiary.of(b)),
          SizedBox(height: SpaceTokens.m),
          Text(SMap.noRooms, textAlign: TextAlign.center, style: context.type(TypeTokens.titleS)),
          SizedBox(height: SpaceTokens.xs),
          Text(
            SMap.noRoomsBody,
            textAlign: TextAlign.center,
            style: context.type(TypeTokens.bodyM, color: ColorTokens.textSecondary.of(b)),
          ),
        ],
      ),
    );
  }
}
