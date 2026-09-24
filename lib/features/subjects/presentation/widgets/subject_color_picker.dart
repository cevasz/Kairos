import 'package:flutter/material.dart';

import '../../../../l10n/strings.g.dart';
import '../../../../theme/motion.dart';
import '../../../../theme/tokens.g.dart';
import '../../../customize/presentation/widgets/color_wheel_sheet.dart';

/// Los ocho colores de materia del contrato, en fila y seleccionables.
///
/// Se elige un índice, no un color: lo que se guarda en la BD es `color_index`
/// para que la materia se vea igual en cualquier dispositivo y sobreviva a un
/// cambio de paleta. Por eso el widget devuelve `int` y no `Color`.
class SubjectColorPicker extends StatelessWidget {
  const SubjectColorPicker({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final guard = MotionGuard.of(context);

    return Wrap(
      spacing: SpaceTokens.m,
      runSpacing: SpaceTokens.m,
      children: [
        for (var i = 0; i < SubjectPalette.length; i++)
          Semantics(
            label: SubjectPalette.names[i],
            selected: i == selected,
            button: true,
            child: InkWell(
              onTap: () => onChanged(i),
              borderRadius: BorderRadius.circular(RadiusTokens.full),
              child: AnimatedContainer(
                duration: guard.duration(MotionDurations.fast),
                curve: guard.curve(MotionCurves.easeOutCubic),
                width: ComponentTokens.colorPickerSwatch,
                height: ComponentTokens.colorPickerSwatch,
                decoration: BoxDecoration(
                  color: SubjectPalette.at(i),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i == selected
                        ? ColorTokens.textPrimary.of(b)
                        : ColorTokens.surfaceBorder.of(b),
                    // El seleccionado se marca con el mismo grosor que el borde
                    // de acento de una materia: es el mismo lenguaje.
                    width: i == selected
                        ? BorderTokens.subjectAccent
                        : BorderTokens.hairline,
                  ),
                ),
              ),
            ),
          ),
        // Cualquier otro color, desde la rueda (§48). Se guarda como ARGB en
        // el mismo entero; si ya hay uno elegido, se ve aquí.
        Semantics(
          label: SCustomize.wheelTitle,
          selected: SubjectPalette.isCustom(selected),
          button: true,
          child: InkWell(
            onTap: () async {
              final picked = await pickColorFromWheel(
                context,
                initial: SubjectPalette.isCustom(selected) ? SubjectPalette.at(selected) : null,
              );
              if (picked != null) onChanged(picked.toARGB32() | SubjectPalette.customThreshold);
            },
            borderRadius: BorderRadius.circular(RadiusTokens.full),
            child: Container(
              width: ComponentTokens.colorPickerSwatch,
              height: ComponentTokens.colorPickerSwatch,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SubjectPalette.isCustom(selected) ? SubjectPalette.at(selected) : null,
                gradient: SubjectPalette.isCustom(selected)
                    ? null
                    : SweepGradient(colors: [
                        for (final h in const [0, 60, 120, 180, 240, 300, 360])
                          HSLColor.fromAHSL(1, h.toDouble(), 0.55, 0.55).toColor(),
                      ]),
                border: Border.all(
                  color: SubjectPalette.isCustom(selected)
                      ? ColorTokens.textPrimary.of(b)
                      : ColorTokens.surfaceBorder.of(b),
                  width: SubjectPalette.isCustom(selected) ? BorderTokens.subjectAccent : BorderTokens.hairline,
                ),
              ),
              child: SubjectPalette.isCustom(selected)
                  ? null
                  : Icon(Icons.palette_outlined, size: 18, color: ColorTokens.textOnSubject.of(b)),
            ),
          ),
        ),
      ],
    );
  }
}
