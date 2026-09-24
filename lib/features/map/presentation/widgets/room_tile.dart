import 'package:flutter/material.dart';

import '../../../../l10n/strings.g.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/tokens.g.dart';
import '../../application/map_providers.dart';

/// Una fila de «Tus salones». Sin ubicar, la acción está a la vista; ubicado,
/// la fila entera lleva al salón en el mapa.
class RoomTile extends StatelessWidget {
  const RoomTile({
    required this.room,
    required this.focused,
    required this.onTap,
    required this.onPlace,
    super.key,
  });

  final MapRoom room;
  final bool focused;
  final VoidCallback onTap;
  final VoidCallback onPlace;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final color = SubjectPalette.at(room.colorIndex);
    final subjects = {for (final c in room.classes) c.$2.nombre}.join(' · ');
    final weekly = room.classes.length;
    final notes = room.room.indicaciones;

    return Material(
      color: focused ? ColorTokens.surfaceRaised.of(b) : ColorTokens.surfaceCard.of(b),
      borderRadius: BorderRadius.circular(RadiusTokens.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(RadiusTokens.card),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(SpaceTokens.m),
          child: Row(
            children: [
              Container(
                width: ComponentTokens.buttonMinTouchTarget,
                height: ComponentTokens.buttonMinTouchTarget,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: room.isPlaced ? 0.9 : 0.16),
                  borderRadius: BorderRadius.circular(RadiusTokens.control),
                ),
                child: Icon(
                  room.isPlaced ? Icons.place : Icons.not_listed_location_outlined,
                  color: room.isPlaced ? ColorTokens.textOnSubject.of(b) : color,
                ),
              ),
              SizedBox(width: SpaceTokens.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.room.codigo, style: context.type(TypeTokens.titleS)),
                    SizedBox(height: SpaceTokens.xs / 2),
                    Text(
                      subjects,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type(TypeTokens.captionS, color: ColorTokens.textSecondary.of(b)),
                    ),
                    Text(
                      notes ?? (weekly == 1 ? SMap.classesInOne : SMap.classesIn(n: weekly)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type(TypeTokens.captionS, color: ColorTokens.textTertiary.of(b)),
                    ),
                  ],
                ),
              ),
              if (room.isPlaced)
                Icon(Icons.chevron_right, color: ColorTokens.textTertiary.of(b))
              else
                TextButton(onPressed: onPlace, child: const Text(SMap.placeRoom)),
            ],
          ),
        ),
      ),
    );
  }
}
