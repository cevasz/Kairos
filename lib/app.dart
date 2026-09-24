import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'features/alarms/application/alarms_controller.dart';
import 'features/home_check/application/home_check_providers.dart';
import 'features/import/presentation/onboarding_screen.dart';
import 'features/mascot/mascot_corner.dart';
import 'features/shell/presentation/app_shell.dart';
import 'features/subjects/application/subjects_providers.dart';
import 'features/widgets/home_widget_sync.dart';
import 'l10n/strings.g.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.g.dart';
import 'theme/transitions.dart';

class KairosApp extends ConsumerWidget {
  const KairosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Los widgets de la pantalla de inicio se alimentan solos desde aquí.
    ref.watch(homeWidgetSyncProvider);
    // Y los avisos de la víspera de cada evaluación.
    ref.watch(pendingRemindersSyncProvider);
    // Y «¿sigues en casa?»: programar las comprobaciones y aplicar lo que
    // Android decidió con la app cerrada.
    ref.watch(homeCheckSyncProvider);
    ref.watch(homeCheckVerdictsProvider);
    // El tema de color se instala antes de construir el ThemeData: los
    // ColorTokens lo consultan por rol (§48).
    final palette = ref.watch(paletteProvider);
    ThemedColor.palette = palette;
    return MaterialApp(
      title: SOnboarding.brand,
      debugShowCheckedModeBanner: false,
      // Los dos temas existen desde el día uno; no hay un tema «principal».
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),

      themeMode: ref.watch(themeModeProvider),
      // La app es de un país y un idioma. Sin esto, los selectores de fecha y
      // hora de Material salen en inglés aunque el resto esté en español.
      locale: const Locale('es', 'CO'),
      supportedLocales: const [Locale('es', 'CO'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Erizógenes acompaña en todas las rutas, no solo en las pestañas.
      builder: (context, child) => MascotCorner(child: child ?? const SizedBox.shrink()),
      home: const _Home(),
    );
  }
}

/// Sin materias, la app arranca en la bienvenida; con una, en el shell. Es
/// una vista de los datos, no una bandera: borrar la última materia vuelve
/// a la bienvenida, que es donde se vuelve a empezar.
class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsOverviewProvider);
    final child = switch (subjects) {
      AsyncData(:final value) when value.isEmpty => const OnboardingScreen(key: ValueKey('onboarding')),
      AsyncData() => const AppShell(key: ValueKey('shell')),
      // Mientras la base abre no se enseña nada: un parpadeo de bienvenida
      // ante alguien con datos se lee como que se perdieron.
      _ => const Scaffold(key: ValueKey('loading'), body: SizedBox.shrink()),
    };
    return StateSwitcher(rise: 0, child: child);
  }
}
