import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/providers.dart';
import '../../../l10n/strings.g.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/haptics.dart';
import '../../../theme/layout.dart';
import '../../../theme/palette.dart';
import '../../../theme/tokens.g.dart';
import '../../mascot/mascot_error.dart';
import '../../mascot/mascot_loader.dart';
import '../../subjects/application/subjects_providers.dart';
import 'widgets/color_wheel_sheet.dart';
import 'widgets/theme_tile.dart';

Future<void> openCustomize(BuildContext context) =>
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const CustomizeScreen()));

/// Personalizar (§48): el modo, el tema de color (prediseñado o propio desde
/// la rueda) y el color de cada materia. Se guarda al tocar, como Ajustes, y
/// se ve en vivo: la pantalla misma cambia de colores.
class CustomizeScreen extends ConsumerWidget {
  const CustomizeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(SCustomize.title)),
      body: ContentWidth(
        child: settings.when(
          loading: () => const MascotLoader(),
          error: (e, _) => MascotError(error: e, onRetry: () => ref.invalidate(settingsProvider)),
          data: (s) => _Body(settings: s),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.settings});
  final UserSetting settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.read(settingsDaoProvider);
    final secondary = context.themed(ColorTokens.textSecondary);
    final current = settings.temaPaleta;
    final ownPaper = settings.temaPapel == null ? Palettes.defaultPaper : Color(settings.temaPapel!);
    final ownAccent = settings.temaAcento == null ? Palettes.defaultAccent : Color(settings.temaAcento!);

    void choose(String id, {int? paper, int? accent}) {
      Haptics.fire('cambioTransporte');
      dao.setPalette(id, paper: paper, accent: accent);
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(SpaceTokens.screenMargin, SpaceTokens.m, SpaceTokens.screenMargin, SpaceTokens.xxxl),
      children: [
        _Label(SCustomize.mode),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 0, label: Text(SSettings.themeAuto), icon: Icon(Icons.brightness_auto_outlined)),
            ButtonSegment(value: 1, label: Text(SSettings.themeLight), icon: Icon(Icons.light_mode_outlined)),
            ButtonSegment(value: 2, label: Text(SSettings.themeDark), icon: Icon(Icons.dark_mode_outlined)),
          ],
          selected: {settings.tema},
          onSelectionChanged: (v) => dao.setThemeIndex(v.single),
        ),
        SizedBox(height: SpaceTokens.xl),
        _Label(SCustomize.sectionThemes),
        Text(SCustomize.themesHint, style: context.type(TypeTokens.captionS, color: secondary)),
        SizedBox(height: SpaceTokens.m),
        LayoutBuilder(builder: (context, box) {
          final columns = box.maxWidth >= 520 ? 3 : 2;
          final gap = SpaceTokens.m;
          final w = (box.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              SizedBox(
                width: w,
                child: ThemeTile(
                  name: SCustomize.papiro,
                  palette: null,
                  selected: current == Palettes.papiro,
                  onTap: () => choose(Palettes.papiro),
                ),
              ),
              for (final p in Palettes.presets)
                SizedBox(
                  width: w,
                  child: ThemeTile(
                    name: p.name,
                    palette: p,
                    selected: current == p.id,
                    onTap: () => choose(p.id),
                  ),
                ),
              SizedBox(
                width: w,
                child: ThemeTile(
                  name: SCustomize.ownTheme,
                  palette: Palettes.fromWheel(paper: ownPaper, accent: ownAccent),
                  selected: current == Palettes.custom,
                  onTap: () => choose(
                    Palettes.custom,
                    paper: ownPaper.toARGB32(),
                    accent: ownAccent.toARGB32(),
                  ),
                ),
              ),
            ],
          );
        }),
        SizedBox(height: SpaceTokens.xl),
        _Label(SCustomize.ownTheme),
        Text(SCustomize.ownThemeHint, style: context.type(TypeTokens.captionS, color: secondary)),
        SizedBox(height: SpaceTokens.s),
        _SwatchRow(
          label: SCustomize.paper,
          color: ownPaper,
          onTap: () async {
            final c = await pickColorFromWheel(context, initial: ownPaper, title: SCustomize.paper);
            if (c != null) choose(Palettes.custom, paper: c.toARGB32(), accent: ownAccent.toARGB32());
          },
        ),
        _SwatchRow(
          label: SCustomize.accent,
          color: ownAccent,
          onTap: () async {
            final c = await pickColorFromWheel(context, initial: ownAccent, title: SCustomize.accent);
            if (c != null) choose(Palettes.custom, paper: ownPaper.toARGB32(), accent: c.toARGB32());
          },
        ),
        SizedBox(height: SpaceTokens.xl),
        _Label(SCustomize.sectionSubjects),
        Text(SCustomize.subjectsHint, style: context.type(TypeTokens.captionS, color: secondary)),
        SizedBox(height: SpaceTokens.s),
        const _SubjectColors(),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: SpaceTokens.s),
        child: Text(text, style: context.type(TypeTokens.label, color: context.themed(ColorTokens.textTertiary))),
      );
}

class _SwatchRow extends StatelessWidget {
  const _SwatchRow({required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: onTap,
        leading: _Dot(color: color),
        title: Text(label, style: context.type(TypeTokens.bodyM)),
        trailing: const Icon(Icons.palette_outlined),
      );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: ComponentTokens.colorPickerSwatch,
        height: ComponentTokens.colorPickerSwatch,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: context.themed(ColorTokens.surfaceBorder)),
        ),
      );
}

class _SubjectColors extends ConsumerWidget {
  const _SubjectColors();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsOverviewProvider).valueOrNull ?? const [];
    if (subjects.isEmpty) {
      return Text(
        SCustomize.subjectsNone,
        style: context.type(TypeTokens.bodyM, color: context.themed(ColorTokens.textSecondary)),
      );
    }
    final dao = ref.read(subjectsDaoProvider);
    return Column(
      children: [
        for (final card in subjects)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: _Dot(color: SubjectPalette.at(card.subject.colorIndex)),
            title: Text(card.subject.nombre, style: context.type(TypeTokens.bodyM)),
            trailing: SubjectPalette.isCustom(card.subject.colorIndex)
                ? IconButton(
                    tooltip: SCustomize.resetColor,
                    icon: const Icon(Icons.format_color_reset_outlined),
                    // Vuelve al color de la paleta por orden, el de siempre.
                    onPressed: () => dao.setColor(card.subject.id, card.subject.id % SubjectPalette.length),
                  )
                : const Icon(Icons.palette_outlined),
            onTap: () async {
              final c = await pickColorFromWheel(
                context,
                initial: SubjectPalette.at(card.subject.colorIndex),
                title: card.subject.nombre,
              );
              if (c != null) await dao.setColor(card.subject.id, c.toARGB32() | SubjectPalette.customThreshold);
            },
          ),
      ],
    );
  }
}
