import 'dart:async';

/// Combina cuatro streams en uno que emite cada vez que cualquiera de ellos
/// cambia, siempre con el último valor de todos.
///
/// Existe porque las vistas de materia leen cuatro tablas a la vez (materia,
/// clases, sesiones y evaluaciones) y una consulta por materia sería N+1: el
/// contador de faltas dejaría de actualizarse en vivo al marcar una sesión.
/// Drift emite un stream por consulta y el proyecto no trae rxdart, así que la
/// combinación se hace aquí, en un solo sitio y documentada.
Stream<R> combineLatest4<A, B, C, D, R>(
  Stream<A> a,
  Stream<B> b,
  Stream<C> c,
  Stream<D> d,
  R Function(A, B, C, D) combine,
) {
  late StreamController<R> controller;
  final subscriptions = <StreamSubscription<void>>[];

  A? va;
  B? vb;
  C? vc;
  D? vd;
  var seen = 0;
  var done = 0;

  void emit() {
    // No se emite nada hasta que los cuatro hayan hablado una vez: un combinado
    // a medias sería una materia sin faltas o sin notas, que es peor que nada.
    if (seen < 4) return;
    controller.add(combine(va as A, vb as B, vc as C, vd as D));
  }

  void onDone() {
    done++;
    if (done == 4) controller.close();
  }

  void start() {
    final indexSeen = <int>{};
    void mark(int i) {
      if (indexSeen.add(i)) seen++;
    }

    subscriptions
      ..add(a.listen((v) {
        va = v;
        mark(0);
        emit();
      }, onError: controller.addError, onDone: onDone))
      ..add(b.listen((v) {
        vb = v;
        mark(1);
        emit();
      }, onError: controller.addError, onDone: onDone))
      ..add(c.listen((v) {
        vc = v;
        mark(2);
        emit();
      }, onError: controller.addError, onDone: onDone))
      ..add(d.listen((v) {
        vd = v;
        mark(3);
        emit();
      }, onError: controller.addError, onDone: onDone));
  }

  controller = StreamController<R>(
    onListen: start,
    onCancel: () async {
      for (final s in subscriptions) {
        await s.cancel();
      }
      subscriptions.clear();
    },
  );

  return controller.stream;
}
