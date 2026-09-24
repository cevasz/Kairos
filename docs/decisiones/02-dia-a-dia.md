# 02 · Del estudio al día a día

Kairós nace de Cátedra (ver `docs/BRIEF.md`). Aquí se deja constancia de lo que
se quitó, lo que se renombró y cómo funciona la racha.

## Qué se quitó

- **Notas y evaluaciones**: pestaña Notas, formulario de evaluación,
  `domain/grades` y la calculadora inversa con su pantalla. La tabla
  `evaluations` y sus columnas siguen en el esquema (sin migración ni cambio de
  `schemaVersion`); nada nuevo las escribe. `SubjectCard.evaluations` se
  conserva solo porque la mascota todavía la lee.
- **Créditos y fecha límite de cancelación**: fuera del formulario, del detalle
  y del DAO (`createSubject`/`updateSubject` ya no las escriben). Las columnas
  quedan.
- **Semestre en la interfaz**: la tabla sigue y se crea sola con su periodo por
  defecto (16 semanas desde el primer uso).
- **Importación de PDF**: `pdf_text`, `column_schedule_parser`,
  `time_grid_parser`, el heurístico `ScheduleParser`, `claude_schedule_parser`
  y la dependencia `syncfusion_flutter_pdf`. También `go_router` y
  `flutter_animate`, que nada importaba. Queda solo el calendario `.ics`
  (`ics_schedule_parser.dart`) y la carga a mano. Los tipos `ParsedClass` /
  `ParsedSession` viven ahora en `domain/import/parsed_schedule.dart`.
- **Avisos de evaluación**: pasan a ser avisos de la víspera de pendientes con
  fecha (`AlarmPlanner.pendingReminders`, canal Android `kairos_pending`). Los
  ajustes siguen en las columnas `alarmaEvaluaciones` / `avisoEvaluacionMin`.

## Qué se renombró (solo en pantalla)

Todo el bloque `copy` de `design/tokens.json` salvo `copy.mascotVoice`:
Materia → **Actividad**, Clase → **Bloque**, Salón/Mapa → **Lugar/Lugares**,
Profesor → **Con quién** (opcional), Asistió/Faltó → **Hecho/Saltado/
Cancelado/Justificado**, Límite de faltas → **Saltos permitidos**, «Sal para…»
→ **«Salir hacia…»**. Cancelar una actividad ahora es **pausarla** («Cancelado»
queda para un bloque suelto). Los grupos `pdf*` pasan a `import*`
(`SImportPicker`, `SImportConfirm`…). El semáforo dice «Te quedan N saltos».
Detección de casa: «Saltado si sigues en casa». Widgets: «Próxima actividad»,
«Tu día», «Pendientes».

El detalle de actividad tiene dos pestañas, **Pendientes** e **Historial**. El
menú radial: Hoy, Semana, Actividades, Lugares; acciones Importar calendario,
Nueva actividad, Personalizar, Ajustes.

## La racha

`lib/domain/streaks/streaks.dart`, Dart puro, con tests en
`test/domain/streaks_test.dart`. La racha se cuenta en **semanas** (lunes a
domingo):

- Una semana está **cumplida** si todas sus sesiones ya pasadas quedaron
  Hecho, Justificado o Cancelado.
- Un **Saltado** la rompe. Una sesión pasada **sin marcar** también la rompe en
  una semana cerrada: la racha es de lo que hiciste.
- La **semana en curso** se puede arreglar todavía: si ya tiene un Saltado la
  racha actual es 0; si solo tiene sesiones sin marcar, no suma ni corta; si va
  cumplida hasta hoy, suma.
- De hoy cuenta lo ya marcado; lo pendiente de hoy aún no pasó.
- Una semana sin sesiones pasadas (vacaciones, un bloque que todavía no
  empieza) se salta: ni suma ni corta.

Se muestra la actual y la mejor en el Historial, «Racha de N semanas» en la
tarjeta de la lista y el número en la hoja del bloque de la semana.

## Pendiente de decidir

- El periodo por defecto de 16 semanas: pasado ese plazo los bloques dejan de
  materializarse. Para una app del día a día hace falta un periodo que ruede o
  que se renueve solo.
- La voz de la mascota (`copy.mascotVoice`) y `mascot_tips` todavía hablan de
  clases y evaluaciones; los ajusta el trabajo de la mascota.
