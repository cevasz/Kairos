import 'package:kairos/domain/grades/grades.dart';
// `Evaluation` también existe en flutter_test (accessibility.dart). El del
// dominio es el que importa aquí.
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

/// Los datos de «Bases de datos» tal como aparecen en Screens.dc.html · D2.
List<Evaluation> get _basesDeDatos => const [
      Evaluation(id: '1', name: 'Parcial 1', weight: 0.25, score: 3.2),
      Evaluation(id: '2', name: 'Taller SQL', weight: 0.15, score: 4.1),
      Evaluation(id: '3', name: 'Proyecto, entrega 1', weight: 0.30, score: 3.3),
      Evaluation(id: '4', name: 'Parcial 2', weight: 0.30),
    ];

/// «Física II» del caso imposible, Screens.dc.html · E2.
List<Evaluation> get _fisicaII => const [
      Evaluation(id: '1', name: 'Parcial 1', weight: 0.30, score: 1.8),
      Evaluation(id: '2', name: 'Laboratorios', weight: 0.30, score: 2.4),
      Evaluation(id: '3', name: 'Final', weight: 0.40),
    ];

void main() {
  group('GradeCalculator', () {
    test('la acumulada del prototipo da 3,4', () {
      final s = GradeCalculator.summarize(_basesDeDatos);
      expect(s.gradedWeight, closeTo(0.70, 0.0001));
      expect(s.earned, closeTo(2.405, 0.0001));
      // 2.405 / 0.70 = 3.4357 -> «3,4» en pantalla.
      expect(double.parse(s.accumulated.toStringAsFixed(1)), 3.4);
    });

    test('sin nada calificado la acumulada es 0 y no se muestra como perdida', () {
      final s = GradeCalculator.summarize(const [
        Evaluation(id: '1', name: 'Parcial 1', weight: 0.5),
      ]);
      expect(s.gradedWeight, 0);
      expect(s.accumulated, 0);
      expect(s.isComplete, isFalse);
    });

    test('detecta porcentajes que no suman 100 %', () {
      expect(GradeCalculator.weightsAreComplete(_basesDeDatos), isTrue);
      expect(
        GradeCalculator.weightsAreComplete(const [
          Evaluation(id: '1', name: 'Parcial', weight: 0.4),
        ]),
        isFalse,
      );
    });

    test('con todo calificado la proyección es la acumulada', () {
      final s = GradeCalculator.summarize(const [
        Evaluation(id: '1', name: 'A', weight: 0.5, score: 4.0),
        Evaluation(id: '2', name: 'B', weight: 0.5, score: 3.0),
      ]);
      expect(s.isComplete, isTrue);
      expect(s.projection, closeTo(3.5, 0.0001));
      expect(s.accumulated, closeTo(3.5, 0.0001));
    });
  });

  group('TargetCalculator', () {
    test('cerrar en 3,5 con un 30 % pendiente necesita 3,7', () {
      final r = TargetCalculator.required(evaluations: _basesDeDatos, target: 3.5);
      expect(r.verdict, TargetVerdict.reachable);
      // (3.5 - 2.405) / 0.30 = 3.6500
      expect(r.needed, closeTo(3.65, 0.0001));
      expect(r.pendingNames, ['Parcial 2']);
    });

    test('una meta baja ya está asegurada', () {
      final r = TargetCalculator.required(evaluations: _basesDeDatos, target: 2.0);
      expect(r.verdict, TargetVerdict.alreadySecured);
    });

    test('Física II no da para 3,0 y se dice con el número real', () {
      final r = TargetCalculator.required(evaluations: _fisicaII, target: 3.0);
      // (3.0 - 1.26) / 0.40 = 4.35: cabe en la escala, pero la mejor nota de
      // esta materia es 2,4. Es posible y no es cómodo, y son estados
      // distintos: pedir un 4,35 a quien nunca ha pasado de 2,4 no es lo
      // mismo que pedírselo a quien ya sacó 4,1.
      expect(r.verdict, TargetVerdict.demanding);
      expect(r.isPossible, isTrue);

      final r4 = TargetCalculator.required(evaluations: _fisicaII, target: 3.5);
      // (3.5 - 1.26) / 0.40 = 5.6 -> se pasa de la escala
      expect(r4.verdict, TargetVerdict.impossible);
      expect(r4.needed, greaterThan(kMaxGrade));
    });

    test('sin evaluaciones pendientes el veredicto es nothingLeft', () {
      final r = TargetCalculator.required(
        evaluations: const [
          Evaluation(id: '1', name: 'A', weight: 1.0, score: 3.0),
        ],
        target: 4.0,
      );
      expect(r.verdict, TargetVerdict.nothingLeft);
    });

    test('«está dentro de lo que ya has sacado» compara con la mejor nota', () {
      expect(
        TargetCalculator.isWithinPastPerformance(
          evaluations: _basesDeDatos,
          needed: 3.65,
        ),
        isTrue, // la mejor histórica es 4,1
      );
      expect(
        TargetCalculator.isWithinPastPerformance(
          evaluations: _basesDeDatos,
          needed: 4.5,
        ),
        isFalse,
      );
    });
  });

  group('TargetCalculator: exigente no es lo mismo que imposible', () {
    // Mejor nota histórica de «Bases de datos»: 4,1 (Taller SQL).
    test('por encima de la mejor nota pero dentro de la escala: exigente', () {
      final r = TargetCalculator.required(evaluations: _basesDeDatos, target: 4.0);
      // (4,0 − 2,405) / 0,30 = 5,32 → eso sí se sale. Se busca una meta que
      // caiga entre 4,1 y 5,0.
      final r2 = TargetCalculator.required(evaluations: _basesDeDatos, target: 3.75);
      expect(r.verdict, TargetVerdict.impossible, reason: 'necesita 5,32');
      expect(r2.needed, closeTo(4.48, 0.01));
      expect(r2.verdict, TargetVerdict.demanding);
    });

    test('dentro de la mejor nota histórica: alcanzable', () {
      final r = TargetCalculator.required(evaluations: _basesDeDatos, target: 3.5);
      expect(r.needed, closeTo(3.65, 0.01)); // < 4,1
      expect(r.verdict, TargetVerdict.reachable);
    });

    test('justo en la mejor nota histórica todavía es alcanzable', () {
      final r = TargetCalculator.required(
        evaluations: const [
          Evaluation(id: '1', name: 'Uno', weight: 0.5, score: 4.0),
          Evaluation(id: '2', name: 'Dos', weight: 0.5),
        ],
        target: 4.0,
      );
      // (4,0 − 2,0) / 0,5 = 4,0, exactamente la mejor histórica.
      expect(r.needed, closeTo(4.0, 0.0001));
      expect(r.verdict, TargetVerdict.reachable);
    });

    test('un pelo por encima de la mejor histórica ya es exigente', () {
      final r = TargetCalculator.required(
        evaluations: const [
          Evaluation(id: '1', name: 'Uno', weight: 0.5, score: 4.0),
          Evaluation(id: '2', name: 'Dos', weight: 0.5),
        ],
        target: 4.1,
      );
      expect(r.needed, closeTo(4.2, 0.0001));
      expect(r.verdict, TargetVerdict.demanding);
    });

    test('exactamente 5,0 es exigente, no imposible', () {
      final r = TargetCalculator.required(
        evaluations: const [
          Evaluation(id: '1', name: 'Uno', weight: 0.5, score: 3.0),
          Evaluation(id: '2', name: 'Dos', weight: 0.5),
        ],
        target: 4.0,
      );
      // (4,0 − 1,5) / 0,5 = 5,0: cabe en la escala, por los pelos.
      expect(r.needed, closeTo(5.0, 0.0001));
      expect(r.verdict, TargetVerdict.demanding);
      expect(r.isPossible, isTrue);
    });

    test('pasarse de 5,0 es imposible, y se dice con el número real', () {
      // (3,5 − 1,26) / 0,40 = 5,6: ninguna nota de la escala lo alcanza.
      final r = TargetCalculator.required(evaluations: _fisicaII, target: 3.5);
      expect(r.verdict, TargetVerdict.impossible);
      expect(r.isPossible, isFalse);
      expect(r.needed, closeTo(5.6, 0.01));
    });

    test('sin historial no se declara exigente: no hay con qué comparar', () {
      final r = TargetCalculator.required(
        evaluations: const [
          Evaluation(id: '1', name: 'Único', weight: 1.0),
        ],
        target: 4.8,
      );
      expect(TargetCalculator.bestScore(const <Evaluation>[]), isNull);
      expect(r.needed, closeTo(4.8, 0.0001));
      expect(r.verdict, TargetVerdict.reachable);
    });

    test('bestScore devuelve la mejor, no la última', () {
      expect(TargetCalculator.bestScore(_basesDeDatos), 4.1);
    });
  });

  group('GradeCalculator sin evaluaciones', () {
    test('una materia vacía no está completa: está vacía', () {
      final s = GradeCalculator.summarize(const <Evaluation>[]);
      expect(s.gradedWeight, 0);
      expect(s.earned, 0);
      expect(s.accumulated, 0);
      expect(s.projection, 0);
      // El caso que importa: sin este guardia `remaining` vale 0 y la materia
      // recién creada se reportaría terminada.
      expect(s.isComplete, isFalse);
    });

    test('sin evaluaciones los pesos no suman 100 %', () {
      expect(GradeCalculator.weightsAreComplete(const <Evaluation>[]), isFalse);
    });

    test('sin evaluaciones no hay meta que calcular', () {
      final r = TargetCalculator.required(
        evaluations: const <Evaluation>[],
        target: 3.5,
      );
      expect(r.verdict, TargetVerdict.nothingLeft);
      expect(r.remainingWeight, 0);
      expect(r.pendingNames, isEmpty);
    });
  });
}
