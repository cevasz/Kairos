import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos/core/time/minutes_of_day.dart';
import 'package:kairos/domain/import/parsed_schedule.dart';
import 'package:kairos/features/import/application/import_controller.dart';

/// Un calendario .ics con los eventos que se le pidan.
Uint8List _ics(String events) => Uint8List.fromList(
      utf8.encode('BEGIN:VCALENDAR\r\nVERSION:2.0\r\n$events\r\nEND:VCALENDAR\r\n'),
    );

String _weekly(String summary, String start, String end, String byDay) => '''
BEGIN:VEVENT
SUMMARY:$summary
DTSTART:$start
DTEND:$end
RRULE:FREQ=WEEKLY;BYDAY=$byDay
END:VEVENT''';

Future<ImportState> _run(Uint8List bytes) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final sub = container.listen(importControllerProvider, (_, __) {});
  addTearDown(sub.close);
  await container.read(importControllerProvider.notifier).importBytes(bytes, fileName: 'agenda.ics');
  return container.read(importControllerProvider);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImportController', () {
    test('un calendario con eventos semanales llega a la revisión', () async {
      final state = await _run(_ics([
        _weekly('Gimnasio', '20260907T060000', '20260907T073000', 'MO,WE,FR'),
        _weekly('Inglés', '20260908T180000', '20260908T200000', 'TU'),
      ].join('\r\n')));
      expect(state, isA<ImportReview>());
      final review = state as ImportReview;
      expect(review.classes.map((c) => c.nombre), containsAll(['Gimnasio', 'Inglés']));
      expect(review.sessionCount, 4);
      expect(review.canConfirm, isTrue);
    });

    test('un calendario vacío cae en «nada encontrado»', () async {
      final state = await _run(_ics(''));
      expect(state, isA<ImportFailed>());
      expect((state as ImportFailed).reason, ImportFailure.nothingFound);
    });

    test('un archivo que no es calendario se dice como tal', () async {
      final state = await _run(Uint8List.fromList('%PDF-1.7 no soy un calendario'.codeUnits));
      expect(state, isA<ImportFailed>());
      expect((state as ImportFailed).reason, ImportFailure.notCalendar);
    });

    test('quitar y corregir en la revisión mantiene la identidad de las filas', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sub = container.listen(importControllerProvider, (_, __) {});
      addTearDown(sub.close);
      final ctrl = container.read(importControllerProvider.notifier);
      ctrl.startReview([
        ParsedClass(
          nombre: 'Gimnasio',
          sessions: [ParsedSession(diaSemana: 1, inicio: _t(6), fin: _t(7))],
        ),
        ParsedClass(
          nombre: 'Inglés',
          sessions: [ParsedSession(diaSemana: 2, inicio: _t(18), fin: _t(20))],
        ),
        ParsedClass(
          nombre: '',
          sessions: [ParsedSession(diaSemana: 0, inicio: _t(10), fin: _t(12))],
          doubts: const {ParseDoubt.missingName, ParseDoubt.missingDays},
        ),
      ]);
      var review = container.read(importControllerProvider) as ImportReview;
      expect(review.canConfirm, isFalse, reason: 'la tercera no tiene nombre ni día');

      ctrl.removeClass(0);
      review = container.read(importControllerProvider) as ImportReview;
      expect(review.ids, [1, 2]);
      expect(review.classes.first.nombre, 'Inglés');

      ctrl.setName(1, 'Terapia');
      final s = review.classes[1].sessions.first;
      ctrl.setSession(1, 0, ParsedSession(diaSemana: 3, inicio: s.inicio, fin: s.fin));
      review = container.read(importControllerProvider) as ImportReview;
      expect(review.classes[1].nombre, 'Terapia');
      expect(review.classes[1].isLowConfidence, isFalse);
      expect(review.canConfirm, isTrue);
    });
  });
}

MinutesOfDay _t(int h) => MinutesOfDay.of(h, 0);
