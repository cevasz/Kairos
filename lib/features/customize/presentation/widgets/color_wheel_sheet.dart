import 'package:flutter/material.dart';

import '../../../../l10n/strings.g.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/palette.dart';
import '../../../../theme/tokens.g.dart';
import 'copic_wheel.dart';

/// Abre la rueda en una hoja y devuelve el color elegido, o null si se
/// cancela. [initial] la abre en el código más cercano.
Future<Color?> pickColorFromWheel(BuildContext context, {Color? initial, String? title}) =>
    showModalBottomSheet<Color>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _WheelSheet(initial: initial, title: title ?? SCustomize.wheelTitle),
    );

class _WheelSheet extends StatefulWidget {
  const _WheelSheet({required this.initial, required this.title});
  final Color? initial;
  final String title;

  @override
  State<_WheelSheet> createState() => _WheelSheetState();
}

class _WheelSheetState extends State<_WheelSheet> {
  late WheelSwatch _swatch = widget.initial == null ? const WheelSwatch(4, 0, 3) : CopicWheel.nearest(widget.initial!);

  /// El color final: el del código o el ajustado a mano con HSL.
  late Hsl _hsl = Hsl.of(widget.initial ?? _swatch.color);
  bool _tuned = false;
  bool _showTune = false;

  Color get _color => _hsl.toColor();

  String get _hex => '#${(_color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  void _pick(WheelSwatch w) => setState(() {
        _swatch = w;
        _hsl = Hsl.of(w.color);
        _tuned = false;
      });

  void _tune(Hsl h) => setState(() {
        _hsl = h;
        _tuned = true;
      });

  @override
  Widget build(BuildContext context) {
    final secondary = context.themed(ColorTokens.textSecondary);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: SpaceTokens.screenMargin,
          right: SpaceTokens.screenMargin,
          bottom: SpaceTokens.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: context.type(TypeTokens.titleM)),
            SizedBox(height: SpaceTokens.xs),
            Text(SCustomize.wheelHint, style: context.type(TypeTokens.captionS, color: secondary)),
            SizedBox(height: SpaceTokens.m),
            CopicWheel(selected: _tuned ? null : _swatch, onPick: _pick),
            SizedBox(height: SpaceTokens.m),
            Row(
              children: [
                AnimatedContainer(
                  duration: MotionDurations.fast,
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: BorderRadius.circular(RadiusTokens.control),
                    border: Border.all(color: context.themed(ColorTokens.surfaceBorder)),
                  ),
                ),
                SizedBox(width: SpaceTokens.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tuned ? '${_swatch.code} ~' : _swatch.code,
                        style: context.type(TypeTokens.titleS).copyWith(fontFamily: FontFamilies.mono),
                      ),
                      Text(
                        '$_hex · ${CopicWheel.families[_swatch.family].name}',
                        style: context.type(TypeTokens.captionS, color: secondary),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _showTune = !_showTune),
                  icon: Icon(_showTune ? Icons.expand_less : Icons.tune),
                  label: const Text(SCustomize.fineTune),
                ),
              ],
            ),
            AnimatedSize(
              duration: MotionDurations.fast,
              child: _showTune
                  ? Column(
                      children: [
                        _TuneSlider(
                          label: SCustomize.hue,
                          value: _hsl.hue,
                          max: 360,
                          onChanged: (v) => _tune(_hsl.copyWith(hue: v)),
                        ),
                        _TuneSlider(
                          label: SCustomize.saturation,
                          value: _hsl.saturation,
                          max: 1,
                          onChanged: (v) => _tune(_hsl.copyWith(saturation: v)),
                        ),
                        _TuneSlider(
                          label: SCustomize.lightness,
                          value: _hsl.lightness,
                          max: 1,
                          onChanged: (v) => _tune(_hsl.copyWith(lightness: v)),
                        ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
            SizedBox(height: SpaceTokens.m),
            Row(
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text(SCustomize.cancel)),
                SizedBox(width: SpaceTokens.m),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _color),
                    child: const Text(SCustomize.use),
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

class _TuneSlider extends StatelessWidget {
  const _TuneSlider({required this.label, required this.value, required this.max, required this.onChanged});
  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(width: 84, child: Text(label, style: context.type(TypeTokens.bodyM))),
          Expanded(child: Slider(value: value.clamp(0, max), max: max, onChanged: onChanged)),
        ],
      );
}
