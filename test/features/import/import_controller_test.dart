import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:kairos/domain/import/schedule_parser.dart';
import 'package:kairos/features/import/application/import_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Un PDF de verdad, generado en el test, con las líneas que se le pidan.
Uint8List _pdf(List<String> lines) {
  final doc = PdfDocument();
  final page = doc.pages.add();
  final font = PdfStandardFont(PdfFontFamily.helvetica, 12);
  var y = 20.0;
  for (final l in lines) {
    page.graphics.drawString(l, font, bounds: Rect.fromLTWH(20, y, 500, 20));
    y += 24;
  }
  final bytes = Uint8List.fromList(doc.saveSync());
  doc.dispose();
  return bytes;
}

Future<ImportState> _run(Uint8List bytes) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final sub = container.listen(importControllerProvider, (_, __) {});
  addTearDown(sub.close);
  await container.read(importControllerProvider.notifier).importBytes(bytes, fileName: 'horario.pdf');
  return container.read(importControllerProvider);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImportController', () {
    test('un PDF con horario llega a la revisión con sus materias', () async {
      final state = await _run(_pdf([
        'HORARIO 2026-2',
        'Bases de datos   Martes 10:00 - 12:00   Salon 604',
        'Calculo III      Lunes 8:00-10:00       Aula 301',
      ]));
      expect(state, isA<ImportReview>());
      final review = state as ImportReview;
      expect(review.classes.map((c) => c.nombre), containsAll(['Bases de datos', 'Calculo III']));
      expect(review.sessionCount, 2);
      expect(review.canConfirm, isTrue);
      expect(review.usedClaude, isFalse, reason: 'sin clave no hay segunda pasada');
    });

    test('un PDF con texto pero sin horas cae en «nada encontrado»', () async {
      final state = await _run(_pdf(['Universidad', 'Certificado de notas', 'Firma']));
      expect(state, isA<ImportFailed>());
      expect((state as ImportFailed).reason, ImportFailure.nothingFound);
    });

    test('un PDF sin texto es el caso escaneado', () async {
      final state = await _run(_pdf([]));
      expect(state, isA<ImportFailed>());
      expect((state as ImportFailed).reason, ImportFailure.noText);
    });

    test('bytes que no son un PDF se reportan como ilegibles', () async {
      final state = await _run(Uint8List.fromList('no soy un pdf'.codeUnits));
      expect(state, isA<ImportFailed>());
      expect((state as ImportFailed).reason, ImportFailure.unreadable);
    });

    test('quitar y corregir en la revisión mantiene la identidad de las filas', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sub = container.listen(importControllerProvider, (_, __) {});
      addTearDown(sub.close);
      final ctrl = container.read(importControllerProvider.notifier);
      await ctrl.importBytes(
        _pdf(['Algebra  Lunes 8:00-10:00', 'Biologia  Martes 8:00-10:00', '10:00-12:00']),
        fileName: 'x.pdf',
      );
      var review = container.read(importControllerProvider) as ImportReview;
      expect(review.classes, hasLength(3));
      expect(review.canConfirm, isFalse, reason: 'la tercera no tiene nombre ni día');

      ctrl.removeClass(0);
      review = container.read(importControllerProvider) as ImportReview;
      expect(review.ids, [1, 2]);
      expect(review.classes.first.nombre, 'Biologia');

      ctrl.setName(1, 'Quimica');
      final s = review.classes[1].sessions.first;
      ctrl.setSession(1, 0, ParsedSession(diaSemana: 3, inicio: s.inicio, fin: s.fin));
      review = container.read(importControllerProvider) as ImportReview;
      expect(review.classes[1].nombre, 'Quimica');
      expect(review.classes[1].isLowConfidence, isFalse);
      expect(review.canConfirm, isTrue);
    });
  });
}
