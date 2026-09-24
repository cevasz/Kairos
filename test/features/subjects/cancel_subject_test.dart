import 'package:kairos/core/db/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Materia cancelada: sale de Hoy, de la semana y de «lo próximo», pero no se
/// borra nada, y reactivarla la devuelve tal cual.
void main() {
  late KairosDatabase db;

  setUp(() => db = KairosDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('cancelar la saca del día y reactivar la devuelve', () async {
    final dao = db.subjectsDao;
    final id = await dao.createSubject(nombre: 'Física', colorIndex: 0, limiteFaltas: 6);
    final other = await dao.createSubject(nombre: 'Cálculo', colorIndex: 1, limiteFaltas: 6);
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    await dao.saveSession(subjectId: id, diaSemana: day.weekday, horaInicio: 420, horaFin: 540);
    await dao.saveSession(subjectId: other, diaSemana: day.weekday, horaInicio: 600, horaFin: 720);

    Future<List<String>> names() async =>
        (await db.scheduleDao.watchDay(day).first).map((c) => c.subject.nombre).toList();

    expect(await names(), ['Física', 'Cálculo']);

    await dao.setCancelled(id, cancelled: true);
    expect(await names(), ['Cálculo']);
    final week = await db.scheduleDao.watchWeek(day).first;
    expect(week.values.expand((l) => l).any((c) => c.subject.id == id), isFalse);

    // Sigue en la lista de materias, al final y marcada.
    final overview = await dao.watchOverview().first;
    expect(overview.map((o) => o.subject.nombre), ['Cálculo', 'Física']);
    expect(overview.last.subject.cancelada, isTrue);
    expect(overview.last.subject.fechaCancelacion, isNotNull);

    await dao.setCancelled(id, cancelled: false);
    expect(await names(), ['Física', 'Cálculo']);
    final back = await (db.select(db.subjects)..where((t) => t.id.equals(id))).getSingle();
    expect(back.fechaCancelacion, isNull);
  });
}
