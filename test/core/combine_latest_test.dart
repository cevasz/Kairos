import 'dart:async';

import 'package:kairos/core/async/combine_latest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('combineLatest4', () {
    test('no emite hasta que los cuatro han hablado', () async {
      final a = StreamController<int>();
      final b = StreamController<int>();
      final c = StreamController<int>();
      final d = StreamController<int>();

      final seen = <int>[];
      final sub = combineLatest4(a.stream, b.stream, c.stream, d.stream,
              (int w, int x, int y, int z) => w + x + y + z)
          .listen(seen.add);

      a.add(1);
      b.add(2);
      c.add(3);
      await Future<void>.delayed(Duration.zero);
      expect(seen, isEmpty, reason: 'faltaba el cuarto stream');

      d.add(4);
      await Future<void>.delayed(Duration.zero);
      expect(seen, [10]);

      await sub.cancel();
      await a.close();
      await b.close();
      await c.close();
      await d.close();
    });

    test('reemite con el último valor de cada uno', () async {
      final a = StreamController<int>();
      final b = StreamController<int>();
      final c = StreamController<int>();
      final d = StreamController<int>();

      final seen = <int>[];
      final sub = combineLatest4(a.stream, b.stream, c.stream, d.stream,
              (int w, int x, int y, int z) => w + x + y + z)
          .listen(seen.add);

      a.add(1);
      b.add(0);
      c.add(0);
      d.add(0);
      await Future<void>.delayed(Duration.zero);

      // Solo cambia uno: los otros tres conservan su valor.
      a.add(10);
      await Future<void>.delayed(Duration.zero);
      expect(seen, [1, 10]);

      await sub.cancel();
      await a.close();
      await b.close();
      await c.close();
      await d.close();
    });

    test('un valor repetido en el mismo stream vuelve a emitir', () async {
      final a = StreamController<int>();
      final b = StreamController<int>();
      final c = StreamController<int>();
      final d = StreamController<int>();

      final seen = <int>[];
      final sub = combineLatest4(a.stream, b.stream, c.stream, d.stream,
              (int w, int x, int y, int z) => w + x + y + z)
          .listen(seen.add);

      a.add(1);
      b.add(0);
      c.add(0);
      d.add(0);
      a.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(seen, [1, 1]);

      await sub.cancel();
      await a.close();
      await b.close();
      await c.close();
      await d.close();
    });

    test('propaga el error sin cerrar el combinado', () async {
      final a = StreamController<int>();
      final b = StreamController<int>();
      final c = StreamController<int>();
      final d = StreamController<int>();

      final errors = <Object>[];
      final seen = <int>[];
      final sub = combineLatest4(a.stream, b.stream, c.stream, d.stream,
              (int w, int x, int y, int z) => w + x + y + z)
          .listen(seen.add, onError: errors.add);

      a.addError(StateError('bd caída'));
      await Future<void>.delayed(Duration.zero);
      expect(errors, hasLength(1));

      a.add(1);
      b.add(2);
      c.add(3);
      d.add(4);
      await Future<void>.delayed(Duration.zero);
      expect(seen, [10], reason: 'el error no debe matar el stream');

      await sub.cancel();
      await a.close();
      await b.close();
      await c.close();
      await d.close();
    });

    test('se cierra solo cuando los cuatro se cierran', () async {
      final a = StreamController<int>();
      final b = StreamController<int>();
      final c = StreamController<int>();
      final d = StreamController<int>();

      var done = false;
      final sub = combineLatest4(a.stream, b.stream, c.stream, d.stream,
              (int w, int x, int y, int z) => w + x + y + z)
          .listen((_) {}, onDone: () => done = true);

      await a.close();
      await b.close();
      await c.close();
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);

      await d.close();
      await Future<void>.delayed(Duration.zero);
      expect(done, isTrue);

      await sub.cancel();
    });
  });
}
