# Arquitectura

## Regla que ordena todo lo demás

`design/tokens.json` es el contrato. De él se generan tres archivos y ninguno se
edita a mano:

```
design/tokens.json
        │
        └── dart run tool/gen_tokens.dart
                ├── lib/theme/tokens.g.dart                    (necesita Flutter)
                ├── lib/domain/attendance/absence_state.g.dart (Dart puro)
                ├── lib/l10n/strings.g.dart                    (microcopy del prototipo)
                └── android/app/src/main/res/values{,-night}/  (colores y textos de los widgets nativos)
```

**Ningún color, tamaño de fuente, radio, espaciado ni duración hardcodeado dentro
de un widget.** Un literal en código de UI es un bug, no una preferencia.

`analysis_options.yaml` excluye `**/*.g.dart`, así que **`flutter analyze` en
verde no significa que el proyecto compile**: el analizador no mira el código
generado y el compilador sí. La prueba es `flutter build apk`. Costó dos builds
fallidos aprenderlo.

El semáforo de faltas se parte en dos a propósito: los umbrales son Dart puro y
viven en el dominio, los colores son Flutter y viven en el tema. Así la lógica de
faltas se testea sin binding de Flutter.

## Capas

```
lib/
├── theme/        el contrato hecho código: ThemeData M3, MotionGuard, háptica,
│                 clases de tamaño (layout.dart) y transiciones (transitions.dart)
├── l10n/         microcopy generado. No se inventan textos.
├── core/         BD (Drift), tiempo, providers raíz
├── domain/       Dart PURO. Sin un solo import de Flutter.
└── features/     una carpeta por feature, no por capa técnica
```

`domain/` está fuera de `features/` porque es lógica compartida y quiero que sea
físicamente evidente cuando alguien intente importar Flutter ahí.

Cada feature lleva:

```
features/<nombre>/
├── data/          repositorios sobre los DAOs
├── application/   providers de Riverpod y modelos de vista
└── presentation/  pantallas y widgets
```

## Tamaños de pantalla

`SizeClass.forWidth` parte el ancho en compact / medium / expanded con los
cortes del contrato. Las pantallas preguntan `context.sizeClass` y cambian de
disposición, no de contenido: riel lateral desde `medium`, dos paneles desde
`expanded`. `ContentWidth` acota una columna al ancho máximo del contrato.
Ver `DESIGN_DECISIONS.md` §21.

## Movimiento

Todo pasa por `MotionGuard`. Lee `MediaQuery.disableAnimations` y degrada:

| Situación | Qué hace |
|---|---|
| Duración | Colapsa al fade de 180 ms del contrato |
| Curva | Se vuelve lineal: un fade no lleva rebote |
| Desplazamiento | Cero: se entra por opacidad |
| Escalonado | Cero: la cascada se vuelve una aparición conjunta |
| Loops | Se congelan en el primer fotograma, no se ocultan |
| Lista `disable` | Se omiten por completo, no se acortan |

La respiración del anillo es la única animación en loop de una pantalla de
trabajo. Va envuelta en `RepaintBoundary` y se detiene cuando la card no está
visible.

Las transiciones de ruta (`FadeRiseTransitionsBuilder`) y de estado
(`StateSwitcher`) viven en `theme/transitions.dart` y se instalan una vez en
el tema; ninguna pantalla trae la suya. La mascota lleva cuatro controladores:
entrada (una vez), idle, un segundo movimiento por pose y parpadeo. Ver
`DESIGN_DECISIONS.md` §22.

## Datos

Drift sobre SQLite, offline desde el primer día. Supabase entra en la Fase 6 y
no condiciona nada del esquema actual.

Cuatro decisiones que no son obvias:

1. **Las horas se guardan como minutos desde medianoche** (`int`), no como texto
   ni `DateTime`. Una clase de «martes 10:00» no tiene fecha propia; un
   `DateTime` con fecha falsa arrastra zona horaria y horario de verano a un dato
   que no los tiene. Ver `MinutesOfDay`.

2. **Las sesiones se materializan**, no se calculan al vuelo. Cada
   `SessionInstance` lleva estado propio (asististe, faltaste, cancelada) y ese
   estado tiene que sobrevivir a que cambies el horario. El índice único
   `(session_id, fecha)` hace que regenerar sea idempotente.

3. **`dia_semana` es ISO 8601**, 1 = lunes … 7 = domingo, igual que
   `DateTime.weekday`. Cualquier otra convención genera off-by-one el día que
   alguien mezcle las dos.

4. **El color de materia es un índice, no un color.** Se guarda `color_index`
   (0-7) y se resuelve contra `SubjectPalette`. Así la materia se ve igual en
   cualquier dispositivo, sobrevive a un cambio de paleta y nunca es aleatoria.

## Lógica de negocio

Tres clases puras, todas con tests y ninguna toca Flutter:

| Clase | Responde a |
|---|---|
| `GradeCalculator` / `TargetCalculator` | ¿Cómo voy? ¿Qué necesito en el final? |
| `AttendanceCounter` | ¿Cuántas faltas me quedan? ¿Ya entré en riesgo? |
| `DeparturePlanner` | ¿A qué hora salgo de casa? |
| `DayGaps` | ¿Cuánto tiempo libre hay entre dos clases? |
| `ScheduleParser` | ¿Qué clases hay en este texto de horario? |

## Ajustes

`UserSettings` es una fila única (`id = 1`) y se lee como stream
(`settingsProvider`). No hay botón de guardar: cada control escribe su columna
al tocarse y las pantallas que dependen del dato se mueven solas. Hoy lee de ahí
el buffer y el modo de transporte; el formulario de materia, el límite de faltas
por defecto; `MaterialApp`, el tema. `themeModeProvider` ya no es estado suelto:
es una vista de la fila.

## Pestañas

`shellTabProvider` guarda la pestaña activa. Es un provider y no estado local
del shell para que una pantalla pueda mandar a otra pestaña («Ver la semana»
desde el día vacío) sin conocer al shell. `ShellTab` da nombre a los índices.

## Importar PDF

`features/import` es una máquina de estados (`ImportController`): A2 selector
→ extracción de texto en un isolate → A3 parseo heurístico por tramos →
segunda pasada con Claude si hay clave → A4 revisión → guardado; o A5 con el
motivo (`noText`, `unreadable`, `nothingFound`). Una sola ruta, cuatro vistas,
un `StateSwitcher`.

La llamada a la API va por `dart:io` sin SDK (no hay SDK oficial de Dart),
contra `POST /v1/messages` con `output_config.format` de tipo `json_schema`.
Se envía el texto, no el archivo. Ver `DESIGN_DECISIONS.md` §23.

## Cuatro consultas, no N+1

La lista de materias y la pantalla de una materia leen cuatro tablas a la vez.
Pedirlas por materia sería N+1 y, peor, el stream dependería solo de `subjects`:
marcar una falta no movería el contador hasta recargar. `combineLatest4`
(`lib/core/async`) combina los cuatro streams de Drift en uno. Está ahí y no en
una feature porque las dos pantallas lo usan y porque el proyecto no trae rxdart.

## Mapa

`features/map`: `mapRoomsProvider` agrupa las clases vivas por salón,
`nextRoomProvider` resuelve la próxima clase (hoy con plan de salida, o la
del siguiente día) y `locationProvider` envuelve a geolocator sin pedir
permiso hasta que se toca «Mi ubicación». La ruta la abre la app de mapas del
teléfono (`url_launcher`). Los mosaicos se tiñen en `theme/map_style.dart`.

## Widgets de inicio

`features/widgets/home_widget_sync.dart` escucha las clases de los próximos 8
días y los ajustes, y deja un JSON en SharedPreferences (`home_widget`). Los
providers Kotlin (`NextClassWidgetProvider`, `TodayWidgetProvider`) solo eligen
qué enseñar según la hora; no calculan nada del dominio. Las actualizaciones se
programan para la hora de salir y el inicio y fin de cada clase.

## Materias vivas

Una materia cancelada o archivada no genera clases a la vista. El filtro vive
una sola vez en `ScheduleDao._live` y lo usan Hoy, la semana, «lo próximo»,
el mapa y los widgets.

## Erizógenes

Vive en `lib/features/mascot` y se consume solo vía
`MascotView(pose:, size:, host:)`. `host` es obligatorio y sin valor por defecto:
si no sabes en qué pantalla estás, no deberías estar poniendo la mascota. En
debug, un `host` fuera de la lista permitida revienta con un assert.

Las poses son un enum generado, nunca strings. El parpadeo lo maneja el propio
módulo con un `Timer` interno. El tacto también (salto, mareo, caricia,
mirada); quien lo pone solo recibe `onTap`/`onLongPress`. Lo que dice sale de
`mascotTipsProvider`, que lee datos y nunca inventa, y lo enseña
`MascotCompanion`.

La regla no es «solo en estados vacíos»: es **solo en las pantallas que
`mascot.allowedScreens` autoriza**, que desde el §32 incluyen la esquina global
(`MascotCorner`), las cargas (`MascotLoader`) y los widgets (`MascotStill`
pintado a imagen). Lo único prohibido es junto a una materia perdida o una
calculadora imposible. Las reacciones a lo que haces pasan por
`mascotCornerProvider.react(...)`.

Antes eran ocho pantallas (incluido el compañero de Hoy, §29). Cuatro de ellas no están
vacías —splash, parseo de PDF, error de PDF y la esquina de «sal ya»— y están
ahí porque son los momentos en los que no hay contenido que mirar: se espera,
falla, o lo único que importa es salir. Ver `DESIGN_DECISIONS.md` §12.

## Fases

| Fase | Qué entra | Estado |
|---|---|---|
| 0 | Capa de tema, generador de tokens, microcopy | Hecho |
| 1 | Modelo de datos, CRUD, vista Hoy, horario semanal | Hecho |
| 2 | Notas, asistencia, calculadora, mascota en vacíos | Hecho |
| 2b | Ajustes, cancelada con Deshacer, huecos, navegación por semanas, stats en el sheet | Hecho |
| 2c | Tablet (riel, dos paneles, maestro-detalle), transiciones, micro-movimientos de la mascota | Hecho |
| 3 | Bienvenida e importar PDF (heurística + Claude), revisión y guardado | Hecho |
| 4 | Mapa, ubicar salones, ruta, ubicación | Hecho; alertas y geofence sin diseño |
| 5 | Widgets de inicio (RemoteViews) | 2×2 y 4×2 hechos; 4×4 pendiente |
| 6 | Sync con Supabase y pulido | Sin diseño |
