import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../l10n/strings.g.dart';
import '../../../theme/layout.dart';
import '../../../theme/motion.dart';
import '../../../theme/tokens.g.dart';
import '../../map/presentation/map_screen.dart';
import '../../schedule/presentation/week_screen.dart';
import '../../subjects/presentation/subjects_screen.dart';
import '../../today/presentation/today_screen.dart';
import '../../updates/application/update_providers.dart';
import '../../updates/presentation/update_sheet.dart';
import '../../customize/presentation/customize_screen.dart';
import '../../import/presentation/import_pdf_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import 'widgets/radial_menu.dart';

/// Posición de cada pestaña. Quien quiera saltar a una desde otra pantalla
/// escribe uno de estos en `shellTabProvider`, no un número suelto.
abstract final class ShellTab {
  static const int today = 0;
  static const int week = 1;
  static const int subjects = 2;
  static const int map = 3;
}

/// Las cuatro pantallas y las acciones de siempre. La navegación entre ellas
/// NUNCA vibra: está en la lista `never` del contrato háptico.
///
/// En teléfono es un menú radial al modo de Concepts (§49): un botón en la
/// zona del pulgar abre dos anillos en semicírculo, las pantallas adentro y
/// las acciones afuera. Se toca, o se mantiene y se arrastra hasta la sección
/// y se suelta. Desde `medium` sigue el riel lateral, con las acciones abajo.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  static const _screens = <Widget>[
    TodayScreen(),
    WeekScreen(),
    SubjectsScreen(),
    MapScreen(),
  ];

  static const _icons = <IconData>[
    Icons.schedule_outlined,
    Icons.calendar_today_outlined,
    Icons.menu_book_outlined,
    Icons.place_outlined,
  ];

  /// Relleno cuando la pestaña está activa: la forma dice dónde estás aunque
  /// el color no se distinga.
  static const _selectedIcons = <IconData>[
    Icons.schedule,
    Icons.calendar_today,
    Icons.menu_book,
    Icons.place,
  ];

  static const _labels = <String>[STabs.today, STabs.week, STabs.subjects, STabs.map];

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with SingleTickerProviderStateMixin {
  late final AnimationController _menu = AnimationController(vsync: this, duration: MotionDurations.base);
  final _stackKey = GlobalKey();
  int? _hover;

  bool get _open => _menu.value > 0 || _menu.isAnimating;

  @override
  void dispose() {
    _menu.dispose();
    super.dispose();
  }

  void _select(int i) => ref.read(shellTabProvider.notifier).state = i;

  List<RadialItem> _screenItems() => [
        for (var i = 0; i < AppShell._screens.length; i++)
          RadialItem(
            icon: AppShell._icons[i],
            activeIcon: AppShell._selectedIcons[i],
            label: AppShell._labels[i],
            onSelect: () => _select(i),
          ),
      ];

  List<RadialItem> _actionItems() => [
        RadialItem(icon: Icons.upload_file_outlined, label: SNav.import, onSelect: () => openImportPdf(context)),
        RadialItem(icon: Icons.add_circle_outline, label: SNav.addSubject, onSelect: () => openSubjectForm(context)),
        RadialItem(icon: Icons.palette_outlined, label: SNav.customize, onSelect: () => openCustomize(context)),
        RadialItem(icon: Icons.settings_outlined, label: SNav.settings, onSelect: () => openSettings(context)),
      ];

  void _openMenu() {
    if (MotionGuard.of(context).reduced) {
      _menu.value = 1;
    } else {
      _menu.forward();
    }
  }

  void _closeMenu() {
    setState(() => _hover = null);
    if (MotionGuard.of(context).reduced) {
      _menu.value = 0;
    } else {
      _menu.reverse();
    }
  }

  void _choose(int index) {
    final items = [..._screenItems(), ..._actionItems()];
    _closeMenu();
    items[index].onSelect();
  }

  RadialGeometry? _geometry() {
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final size = box.size;
    final hubSize = ComponentTokens.buttonMinTouchTarget * 1.25;
    final inset = MediaQuery.paddingOf(context).bottom;
    return RadialGeometry(
      center: Offset(size.width / 2, size.height - inset - SpaceTokens.s - hubSize / 2),
      width: size.width,
    );
  }

  int? _hitGlobal(Offset global) {
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final geo = _geometry();
    if (box == null || geo == null) return null;
    return geo.hit(box.globalToLocal(global), inner: AppShell._screens.length, outerCount: _actionItems().length);
  }

  @override
  Widget build(BuildContext context) {
    // Al abrir, mira si hay una versión nueva publicada. Sin red no pasa nada.
    ref.listen<AsyncValue<UpdateCheck>>(updateCheckProvider, (_, next) {
      final update = next.valueOrNull?.available;
      if (update != null) showUpdateBanner(context, ref, update);
    });
    final index = ref.watch(shellTabProvider);
    final size = context.sizeClass;

    // Las pestañas ocultas siguen vivas (conservan scroll y estado), pero sin
    // animar: sus loops no deben gastar batería detrás de la que se ve.
    final body = IndexedStack(
      index: index,
      children: [
        for (var i = 0; i < AppShell._screens.length; i++) TickerMode(enabled: i == index, child: AppShell._screens[i]),
      ],
    );

    if (size.hasRail) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: _select,
              groupAlignment: -1,
              destinations: [
                for (var i = 0; i < AppShell._screens.length; i++)
                  NavigationRailDestination(
                    icon: Icon(AppShell._icons[i]),
                    selectedIcon: Icon(AppShell._selectedIcons[i]),
                    label: Text(AppShell._labels[i]),
                    padding: EdgeInsets.symmetric(vertical: SpaceTokens.xs),
                  ),
              ],
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: SpaceTokens.l),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final a in _actionItems())
                          IconButton(tooltip: a.label, icon: Icon(a.icon), onPressed: a.onSelect),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(),
            Expanded(child: body),
          ],
        ),
      );
    }

    final hubSize = ComponentTokens.buttonMinTouchTarget * 1.25;
    return PopScope(
      // Atrás cierra el menú antes de salir de la app.
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _open) _closeMenu();
      },
      child: Scaffold(
        body: Stack(
          key: _stackKey,
          children: [
            // El contenido deja libre la franja del botón (y la del sistema,
            // que ya queda debajo: las pantallas no la vuelven a sumar).
            Positioned.fill(
              bottom: hubSize + SpaceTokens.s * 2 + MediaQuery.paddingOf(context).bottom,
              child: MediaQuery.removePadding(context: context, removeBottom: true, child: body),
            ),
            // El Positioned va afuera: tiene que ser hijo directo del Stack.
            // Dentro del AnimatedBuilder, en release, se cae todo el shell.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _menu,
                builder: (context, _) {
                  final geo = _geometry();
                  if (_menu.value == 0 || geo == null) return const SizedBox.shrink();
                  return RadialMenuLayer(
                    geometry: geo,
                    screens: _screenItems(),
                    actions: _actionItems(),
                    current: index,
                    hover: _hover,
                    progress: _menu.value,
                    onTapAt: (p) {
                      final hit = geo.hit(p, inner: AppShell._screens.length, outerCount: _actionItems().length);
                      if (hit == null) {
                        _closeMenu();
                      } else {
                        _choose(hit);
                      }
                    },
                  );
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: SpaceTokens.s,
              child: SafeArea(
                top: false,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _menu,
                    builder: (context, _) => RadialHub(
                      icon: AppShell._selectedIcons[index],
                      open: _menu.value > 0.5,
                      onTap: () => _menu.value > 0.5 ? _closeMenu() : _openMenu(),
                      onDragStart: (g) {
                        _openMenu();
                        setState(() => _hover = _hitGlobal(g));
                      },
                      onDragUpdate: (g) {
                        final hit = _hitGlobal(g);
                        if (hit != _hover) setState(() => _hover = hit);
                      },
                      onDragEnd: () {
                        final hit = _hover;
                        if (hit != null) {
                          _choose(hit);
                        } else {
                          setState(() => _hover = null);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
