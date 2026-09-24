import 'package:flutter/material.dart';

import '../../../../core/time/minutes_of_day.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/tokens.g.dart';

/// Los dos controles de una clase (día y hora), compartidos por el formulario
/// de clase y por la revisión del PDF importado. Una sola versión para que
/// las dos pantallas se vean y se toquen igual.

/// Chip de día. Usa las medidas de `component.chip` del contrato.
class DayChip extends StatelessWidget {
  const DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final color = selected
        ? ColorTokens.accentPrimary.of(b)
        : ColorTokens.textTertiary.of(b);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RadiusTokens.control),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: ComponentTokens.chipPaddingV,
          horizontal: ComponentTokens.chipPaddingH,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(RadiusTokens.control),
          border: Border.all(
            color: selected ? color : ColorTokens.surfaceBorder.of(b),
            width: BorderTokens.hairline,
          ),
        ),
        child: Text(label, style: context.type(TypeTokens.captionS, color: color)),
      ),
    );
  }
}

class TimeField extends StatelessWidget {
  const TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final MinutesOfDay value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.type(
            TypeTokens.label,
            color: ColorTokens.textTertiary.of(b),
          ),
        ),
        SizedBox(height: SpaceTokens.s),
        OutlinedButton(
          onPressed: onTap,
          child: Text(value.hhmm, style: context.type(TypeTokens.bodyL)),
        ),
      ],
    );
  }
}
