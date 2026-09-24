# Estado del programa · 23 de septiembre de 2026 (noche)

Cátedra es una app Flutter (Riverpod + Drift, offline primero) para
estudiantes universitarios en Colombia. Este archivo dice qué funciona hoy,
qué falta y en qué orden conviene seguir. Las razones de cada decisión están
en `DESIGN_DECISIONS.md`; la estructura, en `ARCHITECTURE.md`.

**Cifras:** 270 tests en verde, `flutter analyze` sin errores ni avisos,
esquema de base v6.

## Hitos del 23 de septiembre

| Hito | Estado | Dónde |
|---|---|---|
| H1 · Actualizaciones en línea: publicar por GitHub Releases | Código listo desde el §43; falta publicar la primera versión (`tool/publicar.sh`) | §43 |
| H2 · Llegada real y trayecto que aprende (OSRM + viajes medidos) | Hecho | §47 |
| H3 · Menú radial al modo de Concepts | Hecho | §49 |
| H4 · Personalizar: 7 temas en claro/oscuro, tema propio y rueda COPIC, color por materia | Hecho | §48 |
| H5 · Retícula por horas y calendarios .ics | Hecho | §50 |
| H6 · Catálogo de widgets posibles | Hecho, sin construir | `WIDGETS.md` |

## Funciona

### Bienvenida e importar PDF (Fase 3)
- [x] A1: portada con Erizógenes, lema y dos salidas; aparece mientras no haya materias
- [x] A2: selector de PDF del sistema; el pie dice si el texto sale del teléfono o no
- [x] Extracción de texto local (Syncfusion, en isolate); un PDF escaneado se detecta como tal
- [x] Parser de retícula en Dart puro (`ColumnScheduleParser`): usa la X de cada celda para saber el día. Lee nombre, días, horas, salón por día, código, docente y créditos; cruza la tabla con la sección «Detalle de las Materias» por código de asignatura
- [x] Probado contra un horario real de la Santo Tomás (PACR42): 7 materias y 18 sesiones, todo correcto, sin marcar dudas. El fixture está en `test/fixtures/`
- [x] Parser heurístico en Dart puro, para los PDF que no son retícula: una fila por clase, nombre arriba y horario abajo, encabezado de día; horas «1-3 pm» y «11-1»; profesor con etiqueta; misma materia en dos filas se une
- [x] A3: las filas aparecen en cascada con «Detectando filas · N de M»; cancelable
- [x] Tercera pasada con `claude-opus-5` (salida estructurada) solo como red de seguridad: se llama únicamente si lo determinista no encontró nada o lo encontró todo con dudas, y solo si hay `ANTHROPIC_API_KEY`. Con la retícula resuelta no se toca la red
- [x] A4: revisión en sitio con motivo de cada duda, horario por chips, quitar materia, agregar a mano; «Confirmar N clases» se habilita cuando todo tiene nombre y día
- [x] A5: error con la mascota confundida y tres cuerpos según el motivo
- [x] Guardado: materias con color por orden, salones reutilizados, sesiones materializadas
- [x] Guardado todo o nada, en una transacción; si falla, A5 lo dice. Antes un salón de más de 20 letras colgaba la pantalla con 2–3 materias guardadas (§27)
- [x] Durante la pasada con Claude, «Seguir con lo que encontré»
- [x] Entradas: bienvenida, icono en Materias y botón en su estado vacío

### Hoy
- [x] Erizógenes compañero en la cabecera: consejos de tus datos (próxima clase y hora de salir, faltas en riesgo, evaluaciones de la semana, huecos, fecha límite de cancelación); tocarlo cambia de consejo (§29)
- [x] Cuenta atrás hasta la hora de salir, con anillo que se vacía y odómetro
- [x] Estado «sal ya»: anillo terracota, háptica pesada, mascota rodando en la esquina
- [x] Botones «Ya voy» (marca asistencia y avanza a la siguiente) y «Cancelar»
- [x] Card de cancelada (B3): «Cancelada por el profe · Marcada hace N min · Deshacer», se retira sola al pasar la hora
- [x] Card «Nada más» al terminar el día, con «Lo próximo: jue 8:00 · Física II»
- [x] Timeline con huecos («Hueco de 1 h 30»), rango horario, salón, estado y etiqueta «Siguiente» / «Sal ahora»
- [x] Día vacío con mascota dormida, «Lo próximo» y botón «Ver la semana»
- [x] El buffer y el transporte salen de Ajustes y mueven la hora en vivo

### Semana
- [x] Siete columnas, hoy resaltada, auto-scroll a hoy, días pasados atenuados
- [x] Flechas para cambiar de semana; rango «1 sep – 7 sep · 12 clases» tocable para volver
- [x] Bloques con hora, salón, tachado si está cancelada; hero hacia el sheet
- [x] Sheet de materia con faltas (semáforo), acumulada y próxima evaluación; marcar falta / cancelada / deshacer

### Materias
- [x] Lista con semáforo de faltas y acumulada, en cascada
- [x] Alta y edición: nombre, profesor, créditos, límite, color, fecha límite de cancelación, horario
- [x] Borrado en cascada con confirmación
- [x] Cancelar materia: sale de Hoy, semana, mapa y widgets; queda al final de la lista, tachada, con su historial; se reactiva (§28)
- [x] Mantener pulsada una tarjeta: editar, cancelar o reactivar
- [x] Cuenta regresiva a la fecha límite de cancelación en la pantalla de la materia
- [x] Detalle en dos pestañas (Notas / Asistencia) con fecha límite de cancelación visible
- [x] Notas: acumulada, proyección, aviso si los porcentajes no suman 100, alta/edición de evaluaciones
- [x] Asistencia: anillo segmentado, «Te quedan N faltas», historial con deshacer, tachado animado
- [x] Calculadora inversa con tres veredictos (alcanzable / exigente / no da) y otras metas

### Mapa
- [x] OpenStreetMap teñido con la paleta; pines con el código del salón y el color de la materia; el del próximo salón resaltado
- [x] «Tu próximo salón» con hora de salir, distancia e «Iniciar ruta» (abre la app de mapas con el modo de Ajustes)
- [x] Ubicar un salón a mano una vez: se arrastra el mapa bajo el pin y «Aquí queda»; mover, quitar e indicaciones por salón
- [x] Buscar salón o materia; «Mi ubicación» pide permiso solo al tocarlo

### Widgets de inicio (Android)
- [x] Próxima clase en tres tamaños (2×1, 2×2, 4×2+): hora de salir, cuenta atrás en vivo, materia y salón, llegada estimada («llegas 6:55 · 5 min antes»), Erizógenes con su frase; urgente en terracota; «Mañana» en vez de «Sin clases hoy» cuando el día ya acabó (§33)
- [x] Pendientes (2×2, 4×2, 4×4): evaluaciones y tareas de todas las materias por fecha, con el color de cada una
- [x] Tu día (4×2): hasta cuatro clases, canceladas tachadas, pasadas atenuadas
- [x] Se actualizan solos a la hora de salir y al empezar/terminar cada clase

### Erizógenes
- [x] Tacto: toque = salto con púas erizadas; cinco toques = mareado; mantener = se sonroja; arrastrar = te sigue con la mirada
- [x] En toda la app: asoma en la esquina y comenta lo que haces (asistir, faltar, notas, tareas, alarmas); tocarlo suelta una sentencia; se apaga en Ajustes (§32)
- [x] Rueda en las cargas en lugar de un spinner, con frases que cambian
- [x] Voz de Diógenes: varias frases por consejo con los mismos datos y sentencias sueltas; nunca junto a una materia perdida

### Pendientes y alarmas
- [x] Pestaña Pendientes en cada materia: evaluaciones sin nota que vienen y tareas propias con fecha opcional, tachado y deshacer (§34)
- [x] Alarmas en el Reloj del teléfono (despertar y hora de salir, agrupadas por días) con un botón en Ajustes; Alarmy no acepta alarmas de otras apps (§35)
- [x] Aviso la víspera de cada evaluación, como notificación de Cátedra, a la hora elegida

### Ajustes
- [x] Buffer (0–30 min), transporte por defecto, límite de faltas por defecto, tema
- [x] Se guarda al tocar; el tema persiste entre sesiones

### Tablet y movimiento
- [x] Riel lateral desde 600 dp; barra inferior en teléfono
- [x] Desde 840 dp: Hoy en dos columnas, Materias en maestro-detalle, Notas y Asistencia lado a lado, semana sin scroll horizontal
- [x] Formularios, calculadora, ajustes y sheets acotados a 720 dp y centrados
- [x] Transición de ruta propia (fade + subida), cross-fade entre estados de la card de Hoy y del panel de detalle
- [x] Mascota: entrada con rebote, respiración, parpadeo, carrera con zancada y cansancio en cargas largas, sueño con «z», mirada que barre y lámpara cuya llama cuenta el estado; ánfora de figuras negras de fondo
- [x] Todo degrada bajo «reducir movimiento»

### Cimientos
- [x] Contrato `design/tokens.json` → tema, microcopy y umbrales generados; el guardia de contrato falla si aparece un literal en una pantalla
- [x] Dominio en Dart puro con tests: notas, faltas, salida, huecos
- [x] Drift v1 con volcado de esquema y test de migraciones
- [x] Reloj y «hoy» como providers: nada llama a `DateTime.now()` en un build

## No funciona todavía

| Qué | Fase | Qué hace falta |
|---|---|---|
| «Abrir la ruta» y hora de salida real | 4 | Ubicación, geocodificar salones, ruta a pie/bus/carro; el diseño de permisos denegados no existe |
| Pre-marcado de faltas por geofence | 4 | Polígono del campus (tabla `Campuses` ya existe), pregunta de fin de día; sin diseño |
| Notificación programada y escalado a urgente | 4 | Sin diseño |
| Geocodificar salones automáticamente | 4 | No hay servicio que sepa dónde queda un salón; hoy se ubican a mano (§30) |
| Sync con Supabase | 6 | Sin diseño; el esquema no lo condiciona |
| Estadísticas de fin de semestre | 6 | Sin diseño |
| Cambio de semestre | — | La tabla existe y se crea uno por defecto; no hay pantalla para cerrarlo ni abrir otro |
| Archivar materia | — | La columna `archivada` existe; no hay acción en la interfaz |
| Materia perdida (faltas ≥ límite) | — | El estado `lost` se calcula y colorea; falta una pantalla que lo diga con claridad |

## Deuda conocida

- La clave de Anthropic va embebida por `dart-define`: sirve para uso personal; una distribución pública necesita un servidor propio que haga la llamada.
- El parser de retícula está probado contra un PDF real (Santo Tomás). Faltan dos o tres de otras universidades para saber qué tan general es el formato `Cod./Prog./Grupo.`; el heurístico sigue con sus doce casos sintéticos.
- No hay test del importador de punta a punta con una retícula: el escritor de PDF de Syncfusion fusiona las columnas de una misma fila, así que no se puede generar una retícula sintética. Se prueba el parser con el fixture real.
- La pasada con Claude no está probada contra la API real desde la app (sí el decodificador de su respuesta). Hoy casi nunca se llama: solo si lo determinista falla.
- La estimación de tiempo de ruta es fija por modo (15 / 35 / 20 min): el mapa ya sabe la distancia, pero todavía no la usa para la hora de salir. La llegada estimada de los widgets hereda esa limitación.
- Las alarmas del Reloj no se pueden borrar ni actualizar desde Cátedra (Android no lo permite): si cambia el horario, hay que borrarlas a mano y crearlas otra vez.
- Los avisos de evaluación no sobreviven a un reinicio hasta que se abre la app.
- El widget «Tu día» a última hora de la noche sigue enseñando las clases de hoy, atenuadas; podría pasar a las de mañana.
- `gradle.properties` pide 8 GB para el daemon y el equipo tiene 7: un build de cada tanto muere con «daemon disappeared». Bajar `-Xmx` lo evitaría.
- Los widgets no tienen test automático (son Kotlin); se probaron compilando. Revisarlos a mano en un teléfono.
- Los mosaicos de OpenStreetMap necesitan red y su política de uso pide no abusar; para una distribución pública conviene un proveedor de mosaicos propio.
- «Lo próximo» solo mira sesiones ya materializadas (16 semanas desde el alta de la clase).
- Los formularios abren a pantalla completa también en tablet; podrían ser diálogos.
- Sin tests de widget para las pantallas completas: se prueba el dominio, los providers de Hoy, la mascota y el tachado.
- `pacr42 (1) (3)-1.pdf` está versionado y lleva nombre y cédula del estudiante. El fixture de test sí está anonimizado.
- Si un PDF de otro formato vuelve a importar solo unas materias, conviene guardar sus líneas como fixture: con el PDF de la Santo Tomás el parser saca las 7.

## Siguiente paso recomendado

1. Conseguir dos o tres horarios reales de otras universidades y ver si la
   retícula aguanta. Lo que hoy se da por supuesto del formato: encabezado con
   los días en una línea o una por día, `Cod.` abriendo la celda, `Grupo.`
   cerrando el nombre y la hora cerrando la celda.
2. Fase 4 necesita diseño antes de código: permiso de ubicación denegado,
   pre-marcado por geofence y la notificación con escalado. Lo que sí se puede
   hacer ya sin diseño es geocodificar salones y la ruta a pie con «Abrir la
   ruta», porque B2 ya lo dibuja.
