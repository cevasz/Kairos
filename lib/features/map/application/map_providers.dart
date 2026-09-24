import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/db/daos/schedule_dao.dart';
import '../../../core/db/database.dart';
import '../../../core/providers.dart';
import '../../../domain/departure/departure.dart';
import '../../today/application/today_providers.dart';

/// Un salón con las clases que se dictan en él. El mapa solo enseña salones
/// que importan: los de materias vivas (ni archivadas ni canceladas).
class MapRoom {
  const MapRoom({required this.room, required this.classes});

  final Room room;

  /// Clase recurrente y su materia, ordenadas por día y hora.
  final List<(ClassSession, Subject)> classes;

  bool get isPlaced => room.lat != null && room.lng != null;
  LatLng? get point => isPlaced ? LatLng(room.lat!, room.lng!) : null;

  /// El color del salón es el de su primera materia: casi siempre hay una sola.
  int get colorIndex => classes.first.$2.colorIndex;

  Set<int> get subjectIds => {for (final c in classes) c.$2.id};
}

final mapRoomsProvider = StreamProvider<List<MapRoom>>((ref) {
  return ref.watch(scheduleDaoProvider).watchLiveSessions().map((rows) {
    final byRoom = <int, (Room, List<(ClassSession, Subject)>)>{};
    for (final (session, subject, room) in rows) {
      if (room == null) continue;
      byRoom.putIfAbsent(room.id, () => (room, [])).$2.add((session, subject));
    }
    final list = [
      for (final e in byRoom.values) MapRoom(room: e.$1, classes: e.$2),
    ]..sort((a, b) => a.room.codigo.toLowerCase().compareTo(b.room.codigo.toLowerCase()));
    return list;
  });
});

/// La próxima clase a la que hay que ir, hoy o el siguiente día con clase. Si
/// es de hoy trae el plan de salida; si no, solo la clase.
class NextRoom {
  const NextRoom({required this.item, this.plan});
  final DayClass item;
  final DeparturePlan? plan;
}

final nextRoomProvider = Provider<NextRoom?>((ref) {
  final today = ref.watch(todayStateProvider).valueOrNull;
  if (today?.next != null) return NextRoom(item: today!.next!, plan: today.plan);
  final later = ref.watch(nextAfterTodayProvider).valueOrNull;
  return later == null ? null : NextRoom(item: later);
});

// ─────────────────────────────────────────────────────────────── ubicación

enum LocationStatus {
  /// No se ha preguntado todavía. El mapa no pide permiso al entrar: lo pide
  /// cuando tocas «Mi ubicación», que es cuando se entiende por qué.
  unknown,
  granted,
  denied,

  /// El GPS del teléfono está apagado.
  serviceOff,
}

class LocationState {
  const LocationState({this.status = LocationStatus.unknown, this.position});
  final LocationStatus status;
  final LatLng? position;
}

class LocationController extends StateNotifier<LocationState> {
  LocationController() : super(const LocationState()) {
    unawaited(_resumeIfGranted());
  }

  StreamSubscription<Position>? _sub;

  /// Si el permiso ya estaba dado de antes, se sigue la posición sin
  /// preguntar nada.
  Future<void> _resumeIfGranted() async {
    try {
      final p = await Geolocator.checkPermission();
      if (p == LocationPermission.always || p == LocationPermission.whileInUse) {
        await _start();
      }
    } on Object {
      // Sin plugin (tests) o sin servicio: el mapa funciona sin ubicación.
    }
  }

  /// Pide permiso si hace falta y empieza a seguir la posición. Devuelve la
  /// posición actual, o null si no se pudo.
  Future<LatLng?> request() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) state = const LocationState(status: LocationStatus.serviceOff);
        return null;
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        if (mounted) state = const LocationState(status: LocationStatus.denied);
        return null;
      }
      return await _start();
    } on Object {
      if (mounted) state = const LocationState(status: LocationStatus.denied);
      return null;
    }
  }

  Future<LatLng?> _start() async {
    final pos = await Geolocator.getCurrentPosition();
    final here = LatLng(pos.latitude, pos.longitude);
    if (!mounted) return here;
    state = LocationState(status: LocationStatus.granted, position: here);
    await _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(distanceFilter: 5),
    ).listen((p) {
      if (mounted) state = LocationState(status: LocationStatus.granted, position: LatLng(p.latitude, p.longitude));
    });
    return here;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final locationProvider = StateNotifierProvider<LocationController, LocationState>(
  (ref) => LocationController(),
);

/// Distancia en metros entre dos puntos, para «a 350 m».
double metersBetween(LatLng a, LatLng b) => const Distance().as(LengthUnit.Meter, a, b);
