import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../theme/motion.dart';
import '../../../../theme/palette.dart';
import '../../../../theme/tokens.g.dart';

/// Una familia de color de la rueda, al modo de los marcadores COPIC: una
/// letra, un tono y cuánta saturación aguanta. Cada familia tiene cuatro
/// rayos (de viva a agrisada) y cada rayo seis pasos (de clara a oscura).
class WheelFamily {
  const WheelFamily(this.code, this.name, this.hue, this.saturation);
  final String code;
  final String name;
  final double hue;
  final double saturation;
}

/// Un color con su código: «B03» es la familia B, rayo 0 (el más vivo),
/// paso 3.
class WheelSwatch {
  const WheelSwatch(this.family, this.ray, this.step);
  final int family;
  final int ray;
  final int step;

  static const rays = 4;
  static const steps = <int>[0, 1, 3, 5, 7, 9];
  static const _lightness = <double>[0.9, 0.8, 0.66, 0.52, 0.4, 0.28];
  static const _saturation = <double>[1, 0.72, 0.48, 0.26];

  WheelFamily get _f => CopicWheel.families[family];

  String get code => '${_f.code}$ray${steps[step]}';

  Color get color => Hsl(_f.hue, _f.saturation * _saturation[ray], _lightness[step]).toColor();

  @override
  bool operator ==(Object other) =>
      other is WheelSwatch && other.family == family && other.ray == ray && other.step == step;

  @override
  int get hashCode => Object.hash(family, ray, step);
}

/// La rueda de color de Personalizar (§48). Se ve media rueda, con el centro
/// abajo: queda en la zona del pulgar. Arrastrar el anillo la gira; tocar
/// una familia la trae arriba y abre sus rayos; tocar o arrastrar sobre los
/// rayos elige el color.
class CopicWheel extends StatefulWidget {
  const CopicWheel({required this.selected, required this.onPick, super.key});

  final WheelSwatch? selected;
  final ValueChanged<WheelSwatch> onPick;

  static const families = <WheelFamily>[
    WheelFamily('R', 'Rojo', 356, 0.72),
    WheelFamily('RV', 'Rosa', 330, 0.6),
    WheelFamily('V', 'Violeta', 282, 0.45),
    WheelFamily('BV', 'Añil', 248, 0.45),
    WheelFamily('B', 'Azul', 208, 0.62),
    WheelFamily('BG', 'Turquesa', 178, 0.5),
    WheelFamily('G', 'Verde', 142, 0.48),
    WheelFamily('YG', 'Lima', 84, 0.52),
    WheelFamily('Y', 'Amarillo', 50, 0.85),
    WheelFamily('YR', 'Naranja', 28, 0.8),
    WheelFamily('E', 'Tierra', 22, 0.36),
    WheelFamily('W', 'Gris cálido', 32, 0.1),
    WheelFamily('C', 'Gris frío', 208, 0.1),
    WheelFamily('N', 'Neutro', 0, 0),
  ];

  /// El código más cercano a [c], para que un color guardado abra la rueda
  /// en su sitio.
  static WheelSwatch nearest(Color c) {
    WheelSwatch? best;
    var bestD = double.infinity;
    for (var f = 0; f < families.length; f++) {
      for (var r = 0; r < WheelSwatch.rays; r++) {
        for (var s = 0; s < WheelSwatch.steps.length; s++) {
          final w = WheelSwatch(f, r, s);
          final o = w.color;
          final d = math.pow(o.r - c.r, 2) + math.pow(o.g - c.g, 2) + math.pow(o.b - c.b, 2);
          if (d < bestD) {
            bestD = d.toDouble();
            best = w;
          }
        }
      }
    }
    return best!;
  }

  @override
  State<CopicWheel> createState() => _CopicWheelState();
}

class _CopicWheelState extends State<CopicWheel> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: MotionDurations.base);
  late int _family = widget.selected?.family ?? 4;

  /// Giro de la rueda, en radianes. La familia elegida queda arriba (−π/2).
  late double _rotation = _restFor(_family);
  double _spinFrom = 0;
  double _spinTo = 0;

  /// Qué hace el arrastre en curso: girar (anillo) o elegir (rayos).
  bool _scrubbing = false;
  double? _lastAngle;

  static double get _slice => 2 * math.pi / CopicWheel.families.length;
  static double _restFor(int family) => -math.pi / 2 - family * _slice;

  @override
  void initState() {
    super.initState();
    _spin.addListener(() {
      final t = MotionCurves.easeOutCubic.transform(_spin.value);
      setState(() => _rotation = _spinFrom + (_spinTo - _spinFrom) * t);
    });
  }

  @override
  void didUpdateWidget(CopicWheel old) {
    super.didUpdateWidget(old);
    final f = widget.selected?.family;
    if (f != null && f != _family) _focus(f);
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _focus(int family) {
    _family = family;
    _spinFrom = _rotation;
    // Por el camino corto.
    var target = _restFor(family);
    while (target - _spinFrom > math.pi) {
      target -= 2 * math.pi;
    }
    while (_spinFrom - target > math.pi) {
      target += 2 * math.pi;
    }
    _spinTo = target;
    if (MotionGuard.of(context).reduced) {
      setState(() => _rotation = target);
    } else {
      _spin.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final width = box.maxWidth;
      final geo = _WheelGeometry(width: width);
      return Semantics(
        label: 'Rueda de color. Familia ${CopicWheel.families[_family].name}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _tap(geo, d.localPosition),
          onPanStart: (d) {
            final hit = geo.hit(d.localPosition, _rotation, _family);
            _scrubbing = hit is _HitSwatch;
            _lastAngle = geo.angleOf(d.localPosition);
            if (hit is _HitSwatch) widget.onPick(hit.swatch);
          },
          onPanUpdate: (d) {
            if (_scrubbing) {
              final hit = geo.hit(d.localPosition, _rotation, _family);
              if (hit is _HitSwatch && hit.swatch != widget.selected) widget.onPick(hit.swatch);
              return;
            }
            final a = geo.angleOf(d.localPosition);
            final last = _lastAngle;
            _lastAngle = a;
            if (last == null) return;
            var delta = a - last;
            if (delta > math.pi) delta -= 2 * math.pi;
            if (delta < -math.pi) delta += 2 * math.pi;
            _spin.stop();
            setState(() => _rotation += delta);
          },
          onPanEnd: (_) {
            if (_scrubbing) return;
            // Al soltar, la familia que quedó más arriba es la elegida.
            final top = (((-math.pi / 2 - _rotation) / _slice).round()) % CopicWheel.families.length;
            _focus(top);
          },
          child: CustomPaint(
            size: Size(width, geo.height),
            painter: _WheelPainter(
              geo: geo,
              rotation: _rotation,
              family: _family,
              selected: widget.selected,
              ring: context.themed(ColorTokens.surfaceRaised),
              border: context.themed(ColorTokens.surfaceBorder),
              ink: context.themed(ColorTokens.textPrimary),
            ),
          ),
        ),
      );
    });
  }

  void _tap(_WheelGeometry geo, Offset p) {
    final hit = geo.hit(p, _rotation, _family);
    switch (hit) {
      case _HitFamily(:final family):
        _focus(family);
      case _HitSwatch(:final swatch):
        widget.onPick(swatch);
      case null:
        break;
    }
  }
}

sealed class _Hit {
  const _Hit();
}

class _HitFamily extends _Hit {
  const _HitFamily(this.family);
  final int family;
}

class _HitSwatch extends _Hit {
  const _HitSwatch(this.swatch);
  final WheelSwatch swatch;
}

/// Radios y ángulos de la rueda para un ancho dado. La usan el pintor y el
/// toque, así que lo que se ve es lo que se toca.
class _WheelGeometry {
  _WheelGeometry({required this.width})
      : outer = math.min(width / 2 - 8, 190),
        hub = 30;

  final double width;
  final double outer;
  final double hub;

  double get height => outer + 12;
  Offset get center => Offset(width / 2, height - 4);
  double get ringIn => hub + 6;
  double get ringOut => hub + 34;
  double get fanIn => ringOut + 6;
  double get stepDepth => (outer - fanIn) / WheelSwatch.steps.length;

  /// Los rayos de la familia abierta ocupan este ángulo, centrado arriba.
  static const double fanSpan = math.pi * 0.62;

  double angleOf(Offset p) => math.atan2(p.dy - center.dy, p.dx - center.dx);

  _Hit? hit(Offset p, double rotation, int family) {
    final d = p - center;
    final r = d.distance;
    final a = math.atan2(d.dy, d.dx);
    final n = CopicWheel.families.length;
    final slice = 2 * math.pi / n;
    if (r >= ringIn && r <= ringOut) {
      final rel = _norm(a - rotation + slice / 2);
      return _HitFamily((rel / slice).floor() % n);
    }
    if (r >= fanIn && r <= outer + 4) {
      final fanStart = -math.pi / 2 - fanSpan / 2;
      final rel = _norm(a - fanStart);
      if (rel > fanSpan) return null;
      final ray = (rel / (fanSpan / WheelSwatch.rays)).floor().clamp(0, WheelSwatch.rays - 1);
      // El paso claro va afuera, el oscuro adentro, como en los marcadores.
      final fromOut = ((outer - r) / stepDepth).floor().clamp(0, WheelSwatch.steps.length - 1);
      return _HitSwatch(WheelSwatch(family, ray, fromOut));
    }
    return null;
  }

  static double _norm(double a) {
    final t = a % (2 * math.pi);
    return t < 0 ? t + 2 * math.pi : t;
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.geo,
    required this.rotation,
    required this.family,
    required this.selected,
    required this.ring,
    required this.border,
    required this.ink,
  });

  final _WheelGeometry geo;
  final double rotation;
  final int family;
  final WheelSwatch? selected;
  final Color ring;
  final Color border;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final c = geo.center;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final n = CopicWheel.families.length;
    final slice = 2 * math.pi / n;
    final gap = 0.012;

    // Anillo de familias: el tono medio de cada una, con su letra.
    for (var i = 0; i < n; i++) {
      final start = rotation + i * slice - slice / 2 + gap;
      final sweep = slice - 2 * gap;
      final color = WheelSwatch(i, 0, 3).color;
      _sector(canvas, c, geo.ringIn, geo.ringOut, start, sweep, color, stroke: i == family ? ink : null);
      _label(canvas, c, (geo.ringIn + geo.ringOut) / 2, start + sweep / 2, CopicWheel.families[i].code,
          _onColor(color), 10, bold: i == family, tangent: true);
    }

    // Rayos de la familia abierta.
    final fanStart = -math.pi / 2 - _WheelGeometry.fanSpan / 2;
    final raySweep = _WheelGeometry.fanSpan / WheelSwatch.rays;
    for (var r = 0; r < WheelSwatch.rays; r++) {
      for (var s = 0; s < WheelSwatch.steps.length; s++) {
        final w = WheelSwatch(family, r, s);
        final rOut = geo.outer - s * geo.stepDepth;
        final rIn = rOut - geo.stepDepth + 1.5;
        final isSel = w == selected;
        _sector(canvas, c, rIn, rOut, fanStart + r * raySweep + gap, raySweep - 2 * gap, w.color,
            stroke: isSel ? ink : null, strokeWidth: isSel ? 2.5 : 1);
        _label(canvas, c, (rIn + rOut) / 2, fanStart + (r + 0.5) * raySweep, w.code, _onColor(w.color), 9,
            bold: isSel, tangent: true);
      }
    }

    // Centro: el color elegido.
    final hubColor = selected?.color ?? ring;
    canvas.drawCircle(c, geo.hub, Paint()..color = hubColor);
    canvas.drawCircle(
      c,
      geo.hub,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = border,
    );
    canvas.restore();
  }

  static Color _onColor(Color bg) =>
      PaletteMath.luminance(bg) > 0.4 ? const Color(0xDD000000) : const Color(0xEEFFFFFF);

  void _sector(Canvas canvas, Offset c, double rIn, double rOut, double start, double sweep, Color fill,
      {Color? stroke, double strokeWidth = 2}) {
    final path = Path()
      ..arcTo(Rect.fromCircle(center: c, radius: rOut), start, sweep, true)
      ..arcTo(Rect.fromCircle(center: c, radius: rIn), start + sweep, -sweep, false)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke == null ? 0.6 : strokeWidth
        ..color = stroke ?? border,
    );
  }

  void _label(Canvas canvas, Offset c, double radius, double angle, String text, Color color, double size,
      {bool bold = false, bool tangent = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontFamily: FontFamilies.mono,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final p = c + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.save();
    canvas.translate(p.dx, p.dy);
    // En los rayos el texto va de través (cabe en el ancho de la muestra);
    // en el anillo sigue el radio. Nunca queda al revés.
    var rot = tangent ? angle + math.pi / 2 : angle;
    if (math.cos(rot) < 0) rot += math.pi;
    canvas.rotate(rot);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.rotation != rotation ||
      old.family != family ||
      old.selected != selected ||
      old.ring != ring ||
      old.ink != ink ||
      old.geo.width != geo.width;
}
