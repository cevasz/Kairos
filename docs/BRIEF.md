# Kairós · brief

**Kairós** (καιρός, «el momento oportuno») es la hermana de Cátedra para el
día a día. Mismo diseño, mismo sistema (Flutter + Riverpod + Drift, offline
primero, contrato `design/tokens.json` → código generado, guardia de
contrato, temas, menú radial, rueda de color, widgets), pero no está
enfocada en el estudio: organiza la rutina, avisa **cuándo salir** hacia
cada cosa y aprende cuánto tardas.

Nace como copia de Cátedra en el commit `9b85c5f` (23 sep 2026). La historia
de decisiones heredadas está en `docs/heredado-catedra/`.

## Traducción de conceptos

Los nombres **internos** (tablas, clases Dart, providers) se quedan como en
Cátedra para no romper el esquema ni los tests: `Subject` sigue siendo la
tabla, pero en pantalla es una **Actividad**. Lo que cambia es lo que ve la
persona (copy en `design/tokens.json`) y qué módulos existen.

| Cátedra (interno) | Kairós (en pantalla) | Notas |
|---|---|---|
| Materia (`Subject`) | **Actividad** | Gimnasio, Trabajo, Inglés, Terapia… con color |
| Profesor | **Con quién** (opcional) | Entrenador, jefe, médico |
| Créditos | — | Se quita de la interfaz |
| Clase / sesión semanal (`ClassSession`) | **Bloque** | Horario que se repite |
| Salón (`Room`) | **Lugar** | Se ubica en el mapa igual que antes |
| Mapa | **Lugares** | Misma pantalla |
| Asistió / faltó / cancelada / justificada | **Hecho / Saltado / Cancelado / Justificado** | |
| Límite de faltas | **Saltos permitidos** | Mismo semáforo |
| Evaluaciones, notas, calculadora | — | Se quitan (Kairós no califica) |
| Tareas de la materia | **Pendientes** | Se quedan |
| Semestre, fecha límite de cancelación | — | Se ocultan (la tabla sigue, con un periodo por defecto) |
| Importar horario PDF (+ Claude) | **Importar calendario .ics** | Se quita el PDF, syncfusion y Claude; queda `.ics` y la carga a mano |
| Hoy, salida, trayecto que aprende, «Ya voy / Llegué» | Igual | Es el corazón de Kairós |
| Alarmas del Reloj, detección de casa | Igual | «Salir hacia…» en vez de «clase» |
| Temas, rueda de color, menú radial, widgets | Igual | |

## Mascota

**Erizógenes morado**: el mismo personaje en su versión violeta ciruela, el
erizo de mar con **monóculo** del rediseño B (Cátedra `b416a89`, §37 de las
decisiones heredadas), antes de la lámpara y el terracota. Conserva el rig
actual (poses interpoladas, gestos, carrera, tacto) pero con la paleta
violeta y el monóculo en lugar de la lámpara. Su voz sigue siendo la de
Diógenes, cínica y breve, pero sobre la vida diaria: salir a tiempo, rutinas,
pendientes, rachas. Nunca humilla.

## Reglas que no cambian

- Ningún literal de color, espacio, radio, fuente o duración en pantallas: el
  guardia de contrato (`test/contract_guard_test.dart`) lo exige.
- Todo texto visible sale de `design/tokens.json` → `dart run tool/gen_tokens.dart`.
- `export PATH=$HOME/flutter/bin:$PATH` antes de `flutter`/`dart`.
- `flutter analyze` sin errores ni avisos y `flutter test` en verde al cerrar.
- Commits en español, con `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
