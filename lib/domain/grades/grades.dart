/// Cálculo de notas en la escala colombiana de 0,0 a 5,0.
///
/// Dart puro y sin estado. Todas las entradas se pasan por parámetro para que
/// los tests no necesiten ni base de datos ni binding de Flutter.
library;

/// Escala del sistema universitario colombiano.
const double kMinGrade = 0.0;
const double kMaxGrade = 5.0;

/// Una evaluación con su peso. `score` en null significa «todavía sin calificar»,
/// que es el estado normal de media materia, no un error.
class Evaluation {
  const Evaluation({
    required this.id,
    required this.name,
    required this.weight,
    this.score,
    this.date,
  }) : assert(weight >= 0, 'El peso no puede ser negativo');

  final String id;
  final String name;

  /// Fracción del total, no porcentaje: 0.30 para un 30 %.
  final double weight;

  final double? score;
  final DateTime? date;

  bool get isGraded => score != null;
}

/// Lo que se sabe hoy de una materia.
class GradeSummary {
  const GradeSummary({
    required this.gradedWeight,
    required this.earned,
    required this.accumulated,
    required this.projection,
    required this.isComplete,
  });

  /// Suma de pesos ya calificados. 0.70 con el 70 % calificado.
  final double gradedWeight;

  /// Puntos ya asegurados sobre el total del curso: sum(nota x peso).
  final double earned;

  /// Nota promedio de lo calificado: earned / gradedWeight. Es el número grande
  /// de la pantalla de notas.
  final double accumulated;

  /// Con qué cierras si en lo que falta rindes igual que hasta ahora.
  final double projection;

  final bool isComplete;
}

abstract final class GradeCalculator {
  /// Suma de pesos. Se expone porque la UI tiene que avisar cuando el profe
  /// dio porcentajes que no suman 100 %.
  static double totalWeight(Iterable<Evaluation> evaluations) =>
      evaluations.fold(0.0, (sum, e) => sum + e.weight);

  static bool weightsAreComplete(Iterable<Evaluation> evaluations) =>
      (totalWeight(evaluations) - 1.0).abs() < 0.0001;

  static GradeSummary summarize(Iterable<Evaluation> evaluations) {
    var gradedWeight = 0.0;
    var earned = 0.0;
    for (final e in evaluations) {
      if (!e.isGraded) continue;
      gradedWeight += e.weight;
      earned += e.score! * e.weight;
    }

    // Sin nada calificado no hay acumulada. Devolver 0,0 mentiría: diría que
    // vas perdiendo cuando en realidad no has presentado nada.
    final accumulated = gradedWeight <= 0 ? 0.0 : earned / gradedWeight;
    final total = totalWeight(evaluations);
    final remaining = (total - gradedWeight).clamp(0.0, 1.0);

    return GradeSummary(
      gradedWeight: gradedWeight,
      earned: earned,
      accumulated: accumulated,
      projection: earned + remaining * accumulated,
      // Una materia sin evaluaciones no está cerrada, está vacía. Sin este
      // caso `remaining` vale 0 y la materia recién creada se reportaría
      // terminada, que es justo lo contrario de lo que pasa.
      isComplete: total > 0 && remaining <= 0.0001,
    );
  }
}

/// Por qué una meta es o no alcanzable. La UI cambia de tono con esto, así que
/// el motivo es parte del resultado y no un booleano suelto.
enum TargetVerdict {
  /// Ya está asegurada pase lo que pase en lo que falta.
  alreadySecured,

  /// Se necesita una nota dentro de la escala y dentro de lo que ya has sacado.
  reachable,

  /// Cabe en la escala, pero por encima de tu mejor nota hasta ahora. Es
  /// posible y no es cómodo, y son dos cosas distintas: decir «se puede» a
  /// secas cuando hace falta más de lo que nunca has sacado es engañar.
  demanding,

  /// La nota requerida se sale de 5,0. Matemáticamente imposible.
  impossible,

  /// No queda ninguna evaluación pendiente con peso.
  nothingLeft,
}

class RequiredGrade {
  const RequiredGrade({
    required this.verdict,
    required this.needed,
    required this.remainingWeight,
    required this.target,
    required this.pendingNames,
  });

  final TargetVerdict verdict;

  /// Nota necesaria, uniforme, en todo lo que falta. Puede pasarse de 5,0
  /// a propósito: ese número es justo el que hay que enseñar cuando no da.
  final double needed;

  final double remainingWeight;
  final double target;
  final List<String> pendingNames;

  bool get isPossible => verdict != TargetVerdict.impossible;
}

/// Calculadora inversa: «¿qué necesito en el parcial 2 para cerrar en 3,5?».
abstract final class TargetCalculator {
  static RequiredGrade required({
    required Iterable<Evaluation> evaluations,
    required double target,
  }) {
    final list = evaluations.toList();
    final summary = GradeCalculator.summarize(list);
    final pending = list.where((e) => !e.isGraded && e.weight > 0).toList();
    final remainingWeight = pending.fold(0.0, (s, e) => s + e.weight);
    final names = pending.map((e) => e.name).toList();

    if (remainingWeight <= 0) {
      return RequiredGrade(
        verdict: TargetVerdict.nothingLeft,
        needed: 0,
        remainingWeight: 0,
        target: target,
        pendingNames: names,
      );
    }

    final needed = (target - summary.earned) / remainingWeight;

    // Sacar 0,0 en todo lo que falta y aun así llegar: ya está.
    if (needed <= kMinGrade) {
      return RequiredGrade(
        verdict: TargetVerdict.alreadySecured,
        needed: needed.clamp(kMinGrade, kMaxGrade),
        remainingWeight: remainingWeight,
        target: target,
        pendingNames: names,
      );
    }

    return RequiredGrade(
      verdict: _verdictFor(list, needed),
      needed: needed,
      remainingWeight: remainingWeight,
      target: target,
      pendingNames: names,
    );
  }

  /// «Está dentro de lo que ya has sacado.» El prototipo lo dice como consuelo
  /// honesto: la meta está por debajo de tu mejor nota histórica.
  static bool isWithinPastPerformance({
    required Iterable<Evaluation> evaluations,
    required double needed,
  }) {
    final best = bestScore(evaluations);
    if (best == null) return false;
    return needed <= best;
  }

  /// La mejor nota obtenida hasta ahora, o `null` si no hay nada calificado.
  /// Es la vara con la que se mide si una meta es exigente.
  static double? bestScore(Iterable<Evaluation> evaluations) {
    final scores = evaluations.where((e) => e.isGraded).map((e) => e.score!);
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a > b ? a : b);
  }

  /// Separa «no da» de «sí da, pero nunca has sacado tanto».
  ///
  /// Sin nada calificado no hay con qué comparar, así que no se declara
  /// exigente: afirmarlo sería inventar un juicio sobre alguien de quien
  /// todavía no se sabe nada.
  static TargetVerdict _verdictFor(List<Evaluation> evaluations, double needed) {
    if (needed > kMaxGrade) return TargetVerdict.impossible;
    final best = bestScore(evaluations);
    if (best != null && needed > best) return TargetVerdict.demanding;
    return TargetVerdict.reachable;
  }

  /// Las tres metas fijas del prototipo, más la que el usuario escriba.
  static const List<double> presetTargets = <double>[3.0, 3.5, 4.0];
}
