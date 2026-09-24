# Decisiones de diseño

Cada desviación del prototipo importado, con su razón. El prototipo vive en
`https://claude.ai/design/p/f4061a58-2717-4d86-8957-20ae1223bee1`.

El contrato es `design/tokens.json`. Este archivo explica por qué el contrato
dice lo que dice donde no coincide con el prototipo.

---

## 1. La escala tipográfica se amplió de 9 a 11 pasos

**Prototipo:** `type` nombra 9 tamaños. Las pantallas usan 15.

**Desviación:** se añadieron `bodyS` (14 px) y `captionS` (11 px).

**Razón:** 14 px aparece 58 veces y 11 px 56 veces en `Screens.dc.html`. Son el
segundo y tercer tamaño más usados de toda la app: la tab bar, los metadatos de
los widgets y los subtítulos de la timeline. Redondearlos a 15 y 12 habría
cambiado visiblemente ~114 nodos de texto.

Los otros 7 tamaños fuera de escala (16, 18, 19, 21, 22, 26, 27 px; 24 usos en
total) **sí** se redondean al paso más cercano. Son títulos de una sola
aparición y el redondeo no es perceptible.

## 2. El semáforo de faltas se definió aquí, no en el diseño

**Prototipo:** solo dibuja un estado: 3 de 6 en `accent.attention` con la
insignia «Mitad del cupo usada». No hay verde ni rojo.

**Desviación:** cuatro estados con umbrales por fracción del límite.

| Estado | Fracción | Color |
|---|---|---|
| `ok` | < 0,5 | `accent.ok` |
| `attention` | 0,5 – 0,834 | `accent.attention` |
| `risk` | 0,834 – 1,0 | `accent.urgent` |
| `lost` | ≥ 1,0 | `accent.urgent` |

**Razón:** los umbrales son fracción y no conteo porque `limite_faltas` varía
por materia; un umbral de «3 faltas» sería falso con un límite de 3. El 0,5 sale
del único punto calibrado del prototipo. El 0,834 es 5/6: con el límite por
defecto, `risk` entra exactamente cuando queda una sola falta, que es cuando el
shake de 4 px tiene algo que decir.

**Aprobado el 2026-09-03.** Era la desviación con más criterio propio; queda
confirmada tal cual. Los umbrales viven en `semaphore.thresholds` de
`design/tokens.json` y se generan a `absence_state.g.dart`: cambiarlos es tocar
el contrato, no el código.

## 3. Se añadió `easeOutExpo` a las curvas

**Prototipo:** `tokens.json` define `easeOutCubic` como `(.33, 1, .68, 1)` y la
tabla de movimiento la asigna a la cascada de la timeline y al revelado del PDF.
Pero el CSS realmente dibujado usa `(.16, 1, .30, 1)`, que es easeOutExpo.

**Desviación:** se añadió `easeOutExpo` y se asignó a `timelineCascade` y
`pdfRows`. `easeOutCubic` sigue siendo la curva por defecto de todo lo demás.

**Razón:** el CSS es lo que el diseñador vio y aprobó al mirar el prototipo. La
tabla es una descripción posterior y menos precisa.

## 4. Los radios del anillo urgente son los dibujados, no los de la prosa

**Prototipo:** la sección 1f describe el paso a urgente como `r 50 → 47 → 49`.
El SVG dibujado usa `r = 45` en normal y `r = 43` en urgente, sin fotograma
intermedio.

**Desviación:** se implementa 45 → 43 con `easeOutBackSoft`.

**Razón:** esa curva sobrepasa por debajo de 43 y asienta ahí, lo que reproduce
el «contrae y asienta» descrito sin inventar una escala que el SVG no tiene. Los
números 50/47/49 no corresponden a ninguna geometría del prototipo.

## 5. El odómetro corre a 320 ms, no a 500

`motion.durations.odometer` dice 320 ms; el keyframe `sc-roll` del canvas corre a
500 ms. Manda la tabla: el keyframe del canvas es una demo, no una especificación.

## 6. La temperatura ambiental solo corre en tema oscuro

**Prototipo:** `surface.ambientWarmNight.light` = `#F7F1E4` existe como token
pero no aparece dibujado en ninguna pantalla.

**Desviación:** `color.ambient.enabledInLightTheme = false`.

**Razón:** sobre el hueso `#F5F0E6` del tema claro, un +4 % cálido vira a
amarillo sucio. El prototipo nunca lo dibujó, así que nadie lo ha visto. Se deja
como token para poder activarlo sin tocar código.

## 7. Las sombras del tema claro llevan alfa reducido

Las tres sombras del prototipo son negras con alfa fijo, calibradas sobre
`#14100E`. Sobre `#F5F0E6` quedan duras. En claro se usa el mismo desenfoque con
alfa × 0,45.

## 8. Se añadió `text.onUrgent`

El botón «Abrir la ruta» de la pantalla B2 usa `#F7EFE8` sobre `accent.urgent`,
en ambos temas, y no `text.onAccent`. No tenía nombre de token; ahora lo tiene.

## 9. Las pantallas de captura manual se escribieron aquí

**Prototipo:** el onboarding ofrece «Entrar los datos a mano» y ahí se acaba.
No hay formulario de materia, ni de clase, ni de evaluación.

**Desviación:** tres formularios nuevos, con su microcopy en el bloque `copy`
de `design/tokens.json` marcado `"$from": "gap-fill"`.

**Razón:** el criterio de cierre de la Fase 1 es que el horario se pueda meter a
mano. Sin estas pantallas la fase no cierra y no hay nada que probar contra el
prototipo, porque no habría datos.

Lo que sí sale del prototipo: el layout. Los campos usan `component.input`, los
botones `component.button`, los chips de día y de meta `component.chip`, y el
espaciado la escala `space`. No se inventó ningún componente nuevo salvo el
selector de color, que abajo tiene su propia entrada.

La voz del microcopy imita la del prototipo: segunda persona, frases cortas, sin
signos de admiración, y el porqué antes que la instrucción («El límite es 6 en el
semestre. Las canceladas por el profe no cuentan», no «Ingrese el límite»).

## 10. Cinco medidas que estaban dibujadas pero no tenían nombre

La regla del proyecto es que un literal en código de UI es un bug. Al escribir
las pantallas nuevas aparecieron cinco números sin token detrás:

| Token | Valor | De dónde sale |
|---|---|---|
| `layout.timelineRow.railHeight` | 34 | Dibujado en la timeline de B1 |
| `layout.weekColumnWidth` | 116 | Dibujado en la columna de día de C1 |
| `component.colorPicker.swatch` | 34 | `gap-fill` |
| `icon.named` (14/16/18/20/24) | — | Nombres para `icon.sizes`, que era una lista |
| `component.button.minTouchTarget` | 44 | Ya estaba en el contrato; el tema usaba 48 |

Los dos primeros ya se estaban usando como literales y solo les faltaba nombre.

`component.colorPicker.swatch` es de criterio propio: 34 px es tocable sin llegar
al mínimo de 44 del botón, que haría la fila de ocho colores más ancha que el
marco de 360.

`icon.named` no inventa medidas: pone nombre a los cinco valores que `icon.sizes`
ya tenía. Citarlos por índice desde un widget sería un número mágico disfrazado.

`minTouchTarget` es una corrección: el tema ponía 48 en los botones y el contrato
dice 44. Manda el contrato.

## 11. La mascota de la esquina urgente pasa de 40 a 62 px

La card de «Ya. Camina.» tenía la mascota a `size: 40`, un literal que no salía
de ningún sitio. `mascot.sizesUsed.urgentCorner` dice 62, que es la medida a la
que el diseño la dibujó en B2. Ahora el generador emite `MascotTokens.size*` y la
pantalla la cita.

Es un cambio visible: el erizo de la esquina se ve más grande que hasta ahora.
Se ve como en el prototipo.

---

## Los números de la calculadora del prototipo no son consistentes

No es una desviación: es un hallazgo. Las cifras de las pantallas E1 y E2 son
maquetación, no cálculo.

Con las evaluaciones de «Bases de datos» (Parcial 1 25 % → 3,2; Taller SQL 15 %
→ 4,1; Proyecto 30 % → 3,3; Parcial 2 30 % pendiente):

- Acumulada: 2,405 / 0,70 = **3,44** → «3,4» en pantalla. **Coincide.**
- Proyección: la pantalla dice **3,5**; extrapolando el rendimiento actual da 3,4.
- «Cerrar en 3,5» requiere (3,5 − 2,405) / 0,30 = **3,65**; la pantalla dice **3,8**.
- «Cerrar en 3,0» requiere **1,98**; la pantalla dice **2,2**.
- «Cerrar en 4,0» requiere **5,32** (imposible); la pantalla dice **5,0** (al límite).

Cada meta implicaría un acumulado distinto (2,34 / 2,36 / 2,50), así que los
números están escogidos a mano para que la pantalla se lea bien.

**Qué se implementó:** la fórmula correcta,
`necesito = (meta − puntos_asegurados) / peso_pendiente`, verificada en
`test/domain/grades_test.dart` contra estos mismos datos. La pantalla mostrará
3,7 donde el prototipo dice 3,8.

## El plan de salida del prototipo también se contradice

La pantalla B1 dice a la vez «sal 9:52» (= 10:00 − 8 min de ruta, buffer 0) y
«llegas 4 antes» (que implica buffer 4 y salida 9:48).

**Qué se implementó:** `hora_salida = hora_clase − ruta − buffer`, y
«llegas N antes» donde N **es** el buffer. Con buffer 4 la app dirá «sal 9:48».
Es la única lectura en la que las dos frases de la pantalla son ciertas a la vez.

## 12. La mascota no se limita a los estados vacíos

**Regla previa del proyecto:** «Erizógenes solo en estados vacíos».

**Prototipo:** lo dibuja en seis pantallas, y solo dos son estados vacíos. Las
otras cuatro son `A1 splash`, `A3 procesando PDF`, `A5 error de PDF` y la
esquina de `B2 sal ya`.

**Desviación:** manda `mascot.allowedScreens` del contrato, no la regla. La
lista de seis queda como está.

**Razón:** las cuatro pantallas no vacías son justo aquellas en las que la
persona está esperando o algo salió mal —arranque, parseo, error, urgencia—, y
son el único sitio donde la mascota hace un trabajo real en vez de decorar. La
regla «solo en vacíos» describía el caso mayoritario, no el criterio. El
criterio es: la mascota aparece donde no hay contenido que mirar, sea porque
todavía no lo hay, porque falló, o porque lo único que importa es salir ya.

**Aprobado el 2026-09-07.** El `assert` de `MascotView` sigue siendo la única
compuerta: una pantalla nueva no puede poner la mascota sin entrar antes en el
contrato. La regla del proyecto se reescribe como «la mascota solo en las
pantallas que el contrato autoriza».

## 13. Cinco tokens más para vaciar de literales el código de pantalla

La auditoría del 2026-09-07 encontró siete literales sobrevividos. Cinco
necesitaban nombre en el contrato:

| Token | Valor | Qué reemplaza |
|---|---|---|
| `ring.countdown.breatheScale` | 0,018 | Amplitud de la respiración, suelta en `countdown_ring.dart` |
| `ring.countdown.progressWindowMinutes` | 60 | La ventana del anillo, que además era regla de negocio en un widget |
| `motion.durations.clockTick` | 20 000 ms | Cadencia del `clockProvider` |
| `component.odometer.maxMinutes` | 999 | Tope de dígitos del odómetro |
| `copy.today.roomLine` | `Salón {code} · {hora}` | Microcopy escrito a mano en `today_screen.dart` |

`progressWindowMinutes` vive en el contrato porque es la **escala del dibujo**,
pero el cálculo se movió a `DeparturePlanner.ringProgress`, que es Dart puro y
tiene cinco tests. El dominio no lee tokens: la ventana entra por parámetro.

`copy.today.roomLine` va marcado `gap-fill`: el prototipo dibuja esa fila pero
nunca la nombra. `component.odometer.maxMinutes` también, y su porqué está en el
propio contrato.

Los otros dos literales no necesitaban token: el título de la app pasó a
`SOnboarding.brand`, que ya existía, y `RingMotion.radiusNormal/radiusUrgent`
dejaron de repetir 45 y 43 para citar `RingTokens.countdownRadius*`.

## 14. La calculadora tiene tres respuestas, no dos

**Prototipo:** dos mensajes. «Está dentro de lo que ya has sacado» cuando la
meta es cómoda, y «No da / Con los números actuales no da» cuando es imposible.
Entre los dos hay un hueco: cuando la nota requerida cabe en la escala pero está
por encima de todo lo que esa persona ha sacado, el prototipo no dice nada.

**Desviación:** `TargetVerdict` gana el estado `demanding`, con su propio
mensaje `copy.calculator.demanding`, marcado gap-fill.

| Veredicto | Condición | Mensaje |
|---|---|---|
| `reachable` | requerida ≤ tu mejor nota | «Está dentro de lo que ya has sacado.» |
| `demanding` | requerida ≤ 5,0 pero > tu mejor nota | «Está por encima de lo que has sacado hasta ahora.» |
| `impossible` | requerida > 5,0 | «No da.» + «Habla con el profe.» |

**Razón:** el umbral no es un número inventado sino **tu propio historial**, que
es la vara que el prototipo ya usaba en el mensaje `reachable`. Un 4,35 es
cómodo para quien viene sacando 4,1 y es otra cosa para quien no ha pasado de
2,4; un corte fijo en 4,0 trataría los dos casos igual. El caso de Física II del
prototipo (E2) es justo este: necesita 4,35 con una mejor nota de 2,4.

Sin nada calificado no se declara exigente. No hay con qué comparar, y afirmarlo
sería inventar un juicio sobre alguien de quien todavía no se sabe nada.

En la lista de «si quisieras otra meta» la fila exigente **conserva el número** y
dice su estado con color (`accent.attention`); solo la imposible lo reemplaza por
«No da», porque ahí el número ya no señala nada alcanzable.

## 15. El tachado de una cancelada se dibuja

**Prototipo:** muestra la clase cancelada tachada. No especifica si el tachado
entra animado, porque un HTML estático no puede mostrarlo.

**Desviación:** el trazo se dibuja de izquierda a derecha en los 400 ms de
`motion.durations.strike`, y el texto pierde color a la vez.

**Razón:** cancelar es algo que **acaba de pasar**. Un `lineThrough` que aparece
de golpe se lee como un estilo que siempre estuvo ahí; el trazo dibujándose se
lee como el resultado de lo que acabas de tocar. La duración ya existía en el
contrato con ese nombre exacto y no se estaba usando para nada.

Vive en `lib/theme/strike_through.dart`, junto a `CascadeIn`, porque la timeline
de Hoy y la pestaña de asistencia lo usan igual. Bajo reduced-motion el trazo no
se acorta: se salta, y la línea aparece entera en su estado final.

## 16. «Ya voy» avanza la card; «Cancelar» la convierte en la B3

**Prototipo:** B2 dibuja «Abrir la ruta» y «Ya voy» en el estado urgente, y B1
lista «Cancelar» entre las acciones de Hoy. No dice qué pasa con la card
después de tocar ninguno de los dos.

**Desviación:** «Ya voy» marca la sesión como asistida y la card pasa a la
clase de después (o a «Nada más» si no hay). «Cancelar» la marca cancelada por
el profe y aparece la card B3 —«Cancelada por el profe · No cuenta como falta ·
Marcada hace N min · Deshacer»— encima de la siguiente, etiquetada «Lo
siguiente». Las dos acciones están visibles en todos los estados, no solo en
urgente.

**Razón:** una clase a la que ya dijiste que vas no necesita alerta; dejar la
cuenta atrás corriendo sería seguir avisando de algo resuelto. Y la B3 no
puede quedarse para siempre: se retira sola cuando pasa la hora a la que la
clase habría terminado, que es cuando deja de ser noticia y pasa a ser
historial. «Abrir la ruta» sigue sin implementar: es de la Fase 4.

## 17. Los huecos de la timeline empiezan en 30 minutos

**Prototipo:** B1 dibuja «Hueco de 1 h 30» entre dos clases. No dice desde
cuánto tiempo un espacio entre clases merece una fila.

**Desviación:** `DayGaps.minimumMinutes = 30`, en el dominio y con tests. Por
debajo es cambio de salón y no se dibuja. Una clase cancelada no corta el
hueco: su tiempo se suma al de alrededor.

**Razón:** el umbral es regla de negocio, no medida de dibujo, así que vive en
`lib/domain/schedule/` y no en el contrato. Treinta es el punto en el que se
puede hacer algo con el tiempo —comer, ir a la biblioteca— y no solo caminar
al siguiente salón.

## 18. El rango de la semana y las flechas

**Prototipo:** C1 tiene el título «Semana» y la cadena `range` («{desde} –
{hasta} · {n} clases») pero la pantalla se dibuja solo para la semana actual.

**Desviación:** dos flechas mueven la semana de siete en siete y el rango se
vuelve tocable, en `accent.primary`, para volver a la de hoy. La columna de
hoy va sobre `surface.raised` con el día del mes al lado de la etiqueta, y las
columnas ya pasadas se atenúan. La franja arranca desplazada a la columna de
hoy.

**Razón:** «qué tengo la semana que viene» es la segunda pregunta más común
del horario y sin flechas no tenía respuesta. Todo lo demás son decisiones de
lectura: sin resaltar hoy, siete columnas iguales obligan a contar.

## 19. El sheet del bloque semanal contesta las tres cifras

**Prototipo:** C2 nombra `absences`, `ofLimit`, `accumulated` y `nextEval`,
pero la primera implementación solo puso el encabezado y los botones.

**Desviación:** fila de tres cifras —faltas con su semáforo, acumulada sobre
5,0 y la próxima evaluación con fecha o porcentaje— entre el encabezado y las
acciones. Si la sesión ya está marcada, los dos botones de marcar se
sustituyen por uno de «{estado} · Deshacer».

**Razón:** la próxima evaluación es la primera sin nota, ordenada por fecha
si la tiene y por `orden` si no. Ofrecer «Marcar falta» sobre una sesión ya
marcada como falta duplicaría la marca; el deshacer es lo único que tiene
sentido ahí.

## 20. Los rangos de Ajustes viven en el dominio

Ajustes deja mover el buffer de 0 a 30 minutos y el límite de faltas por
defecto de 1 a 20. Los cuatro números están en `DeparturePlanner` y
`AttendanceCounter`, no en el contrato ni en el widget: son límites de la
regla, no medidas del dibujo. El 6 del límite por defecto también tiene
nombre (`AttendanceCounter.defaultLimit`) y coincide con el `withDefault` de
las dos columnas que lo guardan.

## 21. Tablet: riel, dos paneles y ancho de contenido

**Prototipo:** dieciocho pantallas a 360 dp. Nada por encima.

**Desviación:** tres clases de tamaño con los cortes de Material 3, en
`layout.breakpoint*` del contrato:

| Clase | Ancho | Qué cambia |
|---|---|---|
| compact | < 600 | Nada: es el prototipo |
| medium | 600 – 839 | La barra inferior pasa a riel lateral; el contenido se acota a 720 |
| expanded | ≥ 840 | Hoy en dos columnas (cards \| el día); Materias en maestro-detalle; Notas y Asistencia lado a lado; la semana reparte sus siete columnas sin scroll |

Los sheets se acotan al mismo ancho de 720 y quedan centrados.

**Razón:** en una pantalla ancha una barra abajo queda lejos del pulgar y roba
una franja de alto que el contenido sí aprovecha. Los dos paneles no inventan
pantallas: ponen juntas las que en teléfono se visitan una detrás de otra. El
panel maestro abre la primera materia si no hay selección, porque un panel
vacío con una lista al lado es una pregunta sin responder. Los 720 del ancho
de contenido y los 380 del panel maestro son criterio propio; los cortes no.

La mascota no crece con la pantalla: se queda al tamaño del contrato y la
columna se centra. Una mascota gigante deja de ser compañía y pasa a ser
decoración.

El lienzo con los dos layouts de tablet, la hoja de poses y la tabla de
movimiento vive en
`https://claude.ai/code/artifact/4902e94d-fe07-41d3-9d0b-0bb1fb685914`.

## 22. Cuatro transiciones de pantalla y cinco micro-movimientos de mascota

**Prototipo:** la tabla de movimiento (1f) tiene catorce filas. Ninguna habla
de cambiar de pantalla, y de la mascota solo nombra parpadeo, respiración y
rodada.

**Desviación:** se añaden al bloque `motion.spec` del contrato, marcadas
`gap-fill`:

| Animación | Qué hace | Duración |
|---|---|---|
| `routeTransition` | Toda ruta entra con opacidad y 8 px de subida | `hero` (340) |
| `cardSwitch` | Las cards de Hoy se cruzan: la saliente sube y se va, la entrante sube y llega | `base` (300) |
| `paneReveal` | El panel de detalle de tablet entra igual al cambiar de materia | `base` (300) |
| `railIndicator` | El indicador del riel viaja; no parpadea | 220 |
| `mascotEnter` | Una vez: escala 0,6 → 1 con easeOutBackBounce | 480 |
| `mascotSquash` | Rodando se aplasta y estira dos veces por vuelta | 400 |
| `mascotSleep` | Dormido respira hacia abajo (1 → 0,985) y suelta tres «z» | 2 400 |
| `mascotGlance` | Examinando barre la mirada ±1,2 px y el monóculo destella | 1 800 |
| `mascotWobble` | Confundido bambolea el monóculo ±4°; la cabeza no | 3 000 |

Las amplitudes viven en `mascot.*` del contrato (`enterScale`, `sleepScale`,
`glanceOffset`, `wobbleDegrees`, `squashScale`); el painter las cita, no las
inventa.

**Razón:** una animación nueva entra solo si contesta «¿qué acaba de pasar?».
Las de pantalla dicen «cambiaste de sitio» y sustituyen al deslizamiento
lateral de Android, que arrastra 400 ms y no existe en el prototipo. Las de
mascota dicen «sigo aquí» y solo viven donde el contrato ya la permite, que
son las pantallas sin contenido que leer. Bajo reduced-motion las de pantalla
se quedan en el fade de 180 ms y las de mascota se congelan en el primer
fotograma; la entrada se queda en un fade sin escala.

## 23. El PDF se lee en el teléfono; el texto, a veces, sale

**Prototipo:** A2 promete «Todo se lee en el teléfono. Nada se sube» y A1
«El PDF no sale de tu teléfono». El brief, a la vez, pide una clave de la API
de Anthropic para el parseo.

**Desviación:** dos pasadas. La primera es un parser heurístico en Dart puro
(`lib/domain/import/schedule_parser.dart`, doce tests) que corre siempre y
cubre los tres layouts habituales: una fila por clase, nombre arriba y horario
abajo, encabezado de día. La segunda, solo si hay
`--dart-define=ANTHROPIC_API_KEY`, manda **el texto extraído** —nunca el
archivo— a `claude-opus-5` con salida estructurada por esquema JSON y se
queda con su lectura si trae algo. Si la API falla o no hay red, la app sigue
con lo heurístico: el importador no depende de la red para funcionar.

El pie de A2 dice la verdad según el caso: sin clave, el texto del prototipo;
con clave, «El archivo no sale de tu teléfono. El texto sí: lo lee Claude para
armar el horario» (`pdfPicker.footerApi`, gap-fill).

**Razón:** las dos frases del prototipo eran ciertas a la vez solo si nada
salía del teléfono, y con eso los PDF raros no se leen. Se prefirió decir
exactamente qué sale y cuándo antes que dejar una promesa falsa en pantalla.
La extracción de texto sí es local (Syncfusion, Dart puro, en un isolate) y
es lo que distingue el caso «escaneado como imagen» de A5.

La clave embebida por `dart-define` es la del brief y sirve para un uso
personal; una distribución pública tendría que pasar por un servidor propio.
Queda anotado en `ESTADO.md` como deuda.

## 24. A3 revela las filas en cascada aunque el parser sea instantáneo

**Prototipo:** A3 es una lista que va apareciendo fila a fila con «Detectando
filas · 3 de 12» y Erizógenes examinando.

**Desviación:** la heurística resuelve en milisegundos; se ejecuta por tramos
—veinte pasos, `MotionStagger.pdfRows` entre uno y otro— y cada tramo emite
lo encontrado hasta ahí. Las filas entran con la cascada del PDF (80 ms, 8 px).
Con clave de API, después llega «Ordenando lo que encontré» mientras responde
Claude, con la barra en indeterminado.

**Razón:** enseñar qué se va encontrando es lo que hace revisable el
resultado antes de A4, y la persona necesita ver que la app está leyendo *su*
horario y no cargando algo genérico. Es la única espera artificial de la app
y dura como mucho un segundo y medio.

## 25. A4 corrige en sitio y dice por qué duda

**Prototipo:** A4 tiene una insignia «Revisa esto» y el subtítulo «Dos me
dejaron dudando».

**Desviación:** cada duda tiene su motivo en texto (`doubtName`, `doubtDays`,
`doubtRange`, `doubtNamePrev`, gap-fill) y corregir el campo la retira. El
subtítulo cambia con el conteo real: ninguna, una, dos (el del prototipo) o
«{n} me dejaron dudando». El horario se edita por chip con el mismo selector
de día y hora del formulario de clase (`session_fields.dart`, compartido).
«Confirmar {n} clases» cuenta sesiones, no materias, y se deshabilita hasta
que toda materia tenga nombre y toda sesión tenga día.

**Razón:** una insignia sin motivo obliga a releer toda la fila. Y el número
del prototipo era el de su maqueta.

## 26. La bienvenida es la portada mientras no haya datos

**Prototipo:** A1 con marca, lema, dos CTA y pie de privacidad.

**Desviación:** no hay bandera «ya vi el onboarding». La app arranca en A1
cuando no existe ninguna materia y en el shell cuando existe al menos una;
borrar la última devuelve a A1. Tampoco hay «saltar».

**Razón:** las dos salidas de A1 son las dos únicas formas de meter datos, y
sin datos el shell entero son estados vacíos. Una columna nueva en la BD para
recordar algo que los datos ya dicen sería una migración por una bandera.

---

## 27. El guardado del importador es todo o nada

**Síntoma reportado:** «se demora bastante importando el horario y cuando se
importó solo fueron 3 materias».

**Causa:** `Rooms.codigo` aceptaba 20 letras. El horario real de la Santo
Tomás trae «Lab. de Física Mecánica y Eléctrica» (35) en la tercera materia.
Drift lanzaba `InvalidDataException`, `confirm()` no la atrapaba y el estado
se quedaba en `ImportSaving`: la pantalla giraba para siempre con dos materias
y media ya guardadas. La «demora» era un cuelgue.

**Decisión:** el código de salón sube a 80 (validación de Dart, no cambia el
DDL); nombre, profesor y salón se recortan a su máximo antes de guardar; el
guardado entero va en una transacción; y si algo falla se ve A5 con
`saveFailed` («No quedó nada a medias: prueba otra vez»). Un test guarda el
horario real completo (7 materias, 18 clases) y otro comprueba que un fallo en
la tercera materia no deja ninguna.

De paso, la pasada con Claude (solo cuando lo determinista no encuentra nada)
baja a `effort: low`, recibe el texto con la disposición de la página —en una
retícula, la columna dice el día— y, mientras corre, A3 ofrece «Seguir con lo
que encontré».

## 28. Materia cancelada no es materia archivada

**Desviación:** columna `cancelada` + `fecha_cancelacion` (esquema v2) en vez
de reutilizar `archivada`.

**Razón:** cancelar es un hecho académico con fecha límite propia; archivar es
limpieza de fin de semestre. Una cancelada:

- sale de Hoy, la semana, «lo próximo», el mapa y los widgets (el filtro vive
  en `ScheduleDao._live`, una sola vez);
- sigue en Materias, al final, bajo «Canceladas», tachada y sin color;
- conserva notas, faltas e historial, y se reactiva con un toque.

Cancelar pregunta antes (una hoja con el porqué); reactivar no, porque no
destruye nada. Las dos dejan «Deshacer». Se llega desde el menú de la materia,
manteniendo pulsada su tarjeta y desde el aviso de su pantalla. La pantalla de
la materia añade la cuenta regresiva a la fecha límite: «Quedan 4 días para
cancelarla».

## 29. Erizógenes se deja tocar y dice algo útil

**Desviación:** nuevo host `B1 compañero` en `mascot.allowedScreens`, a 52 px
en la cabecera de Hoy.

**Razón:** la mascota solo aparecía cuando no había nada que mirar. El pedido
fue hacerla «más interactiva y útil sin quitarle personalidad». Útil quiere
decir que hable de tus datos, no de sí misma; con personalidad quiere decir
que lo haga con su voz seca de siempre:

- «Sigue Cálculo a las 11:00 en 610F. Sal a las 10:40.»
- «Física: te queda una falta. Una.»
- «Parcial 2 de Álgebra es el jue 24. Te lo digo porque nadie más lo hará.»

Tocarlo pasa al siguiente consejo; mantenerlo pulsado suelta una frase de
caricia y se sonroja («El monóculo no se toca.»). Con cinco toques seguidos se
marea. El dedo encima hace que te siga con la mirada. Todo degrada bajo
«reducir movimiento» y la háptica es `tocarMascota`, ligera.

Lo que no cambia: no aparece en pantallas de trabajo ni nombra nunca una
materia perdida; en «sal ya» no se deja tocar (ahí lo único que importa es
salir) y el compañero se esconde para no duplicar al erizo de la esquina. En
el día vacío el erizo grande dormido también responde, sin moverse del sitio.

## 30. El mapa se ubica a mano, una vez

**Desviación:** la pestaña Mapa usa OpenStreetMap y no geocodifica.

**Razón:** el PDF dice «Sala de Sistemas 2E», no una dirección; ningún
geocodificador sabe dónde queda. Cada salón se ubica una sola vez —se arrastra
el mapa bajo el pin y se confirma «Aquí queda»— y desde ahí «Iniciar ruta»
abre la app de mapas del teléfono con el modo de transporte de Ajustes. Cátedra
no dibuja rutas: la app de mapas ya lo hace, con tráfico.

Los mosaicos se tiñen con una matriz que sale del contrato
(`theme/map_style.dart`): en oscuro, el blanco del mapa se vuelve
`surface.base`; en claro, `surface.card`. Sin eso el mapa parece otra app.

La ubicación se pide al tocar «Mi ubicación», no al abrir la pestaña: el
permiso se entiende cuando se pide para algo. Denegado, el mapa funciona igual.
Solo primer plano. Sin mascota: «mapa» sigue en la lista prohibida.

## 31. Widgets de inicio: RemoteViews, no Glance

**Desviación:** los dos widgets son `AppWidgetProvider` clásicos, no Glance.

**Razón:** Glance arrastra Compose al APK por dos vistas de texto. Los
colores sí salen del contrato: `gen_tokens.dart` escribe
`res/values{,-night}/catedra_tokens.xml` y los textos del selector.

- **Próxima clase (2×2):** el número grande es la hora de salir, no los
  minutos que faltan. Un widget no se redibuja cada minuto y una cuenta atrás
  congelada miente; debajo, un `Chronometer` del sistema sí lleva «en 12:04»
  en vivo. Urgente pinta terracota el número y el borde, nunca el fondo.
- **Tu día (4×2):** hasta cuatro clases desde la siguiente; canceladas
  tachadas, pasadas atenuadas, «+2 más».

La app les deja una semana de clases ya resueltas y programa actualizaciones
para la hora de salir, el inicio y el fin de cada clase de hoy y mañana: el
widget elige solo cuál enseñar aunque no abras la app.

## 32. Erizógenes en toda la app, con voz de Diógenes

**Pedido del usuario (2026-09-22):** la mascota «mucho más presente: en las
cargas, en las esquinas mientras uno hace cosas», con diálogos variados y la
actitud de Diógenes. Esto revierte la regla del §12 («solo en las pantallas que
`allowedScreens` autoriza»), así que el contrato cambia en vez de esquivarse:

- `allowedScreens` suma `carga`, `esquina global` y `widgets`.
- `forbiddenScreens` se queda con **materia perdida** y **calculadora
  imposible**. Ahí la razón del §12 sigue en pie y con un cínico pesa más: una
  cara burlona junto a una mala noticia se lee como burla.

Dónde está ahora:

- **Esquina global** (`MascotCorner`, en `MaterialApp.builder`, así que
  acompaña también en detalle, formularios y hojas). En reposo solo asoma la
  cabeza por el borde izquierdo, a la altura de la barra de navegación, para no
  tapar contenido. Cuando pasa algo (asistir, faltar, cancelada, nota guardada,
  tarea creada o hecha, materia guardada, alarmas creadas) sale entero con un
  globo y a los `mascotLine` (4,2 s) se esconde. Tocarlo suelta una sentencia.
  Con el teclado abierto se esconde del todo. Se apaga en Ajustes.
- **Cargas** (`MascotLoader`): rueda en lugar de un spinner en Semana,
  Materias, Ajustes, detalle, el guardado del PDF y la cabecera de carga de
  Hoy. La frase cambia cada `mascotLoaderLine` (2,4 s): una espera larga con la
  misma frase parece colgada.
- **Widgets:** ver §33.

La voz: `copy.mascotVoice.$attitude` la fija. Franco, austero, burlón con las
excusas y la pompa, cariñoso a su manera; referencias a la tinaja, la lámpara,
Alejandro y Platón. Cada consejo tiene variantes (`*Variants`) con **los mismos
datos**: la regla del §29 («nunca inventa») se mantiene, lo que varía es la
frase. En Hoy la variante queda fija todo el día (el provider se recalcula con
cada tic y el texto no puede saltar solo). En la esquina y las cargas no se
repite la última (`VariantPicker`). Al final del ciclo de consejos va una
sentencia (`aphorisms`), que es actitud y no dato, y nunca ocupa el lugar de un
consejo útil.

El generador de textos aprendió listas con huecos: una lista con `{clase}` se
vuelve una función que devuelve las variantes llenas.

## 33. Widgets: tres tamaños, llegada estimada y pendientes

- **«Sin clases hoy» mentía.** Pasadas las clases del día, el widget decía «Sin
  clases hoy» sobre la de mañana. Ahora dice «Mañana» o «El jue».
- **Llegada estimada.** Debajo de la clase: «llegas 6:55 · 5 min antes». Si ya
  pasó la hora de salir: «si sales ya, llegas 8:07 · 7 min tarde», recalculado
  con el reloj real. En esa ventana «Próxima clase» se refresca cada minuto
  (home_widget encadena una alarma a la vez, así que no cuesta alarmas). El
  trayecto sale del ajuste «Tiempo de trayecto» (§38) o, sin él, del
  estimado por modo.
- **Tamaños** (`RemoteViews` con mapa de tamaños en Android 12+; en versiones
  anteriores se escoge a mano al redimensionar): 2×1 una fila; 2×2 con
  llegada y Erizógenes pequeño en el pie, donde antes quedaba media tarjeta
  vacía; 4×2 o más con Erizógenes grande, su frase y «Después: …».
- **Pendientes (nuevo):** evaluaciones sin nota y tareas abiertas de todas las
  materias, por fecha. 2×2 cuatro filas, 4×2 cinco con materia, 4×4 ocho y el
  erizo. Hoy en terracota, mañana en ámbar. Sin nada: solo el erizo.
- **El erizo en nativo:** Flutter lo pinta una vez por arranque con
  `MascotStill` (el pintor en su fotograma de reposo, sin la entrada animada,
  que capturada saldría encogida) en claro y oscuro, y Kotlin escoge según el
  tema del sistema.

## 34. Pendientes por materia

Tercera pestaña del detalle (tercera columna en tablet). Arriba, las
evaluaciones sin nota que vienen (solo lectura: se editan en Notas). Abajo, las
tareas propias: título y fecha opcional, casilla con el tachado del §20,
mantener pulsado para borrar con «Deshacer». Tabla `Tasks` en la v3 del
esquema. Una evaluación pasada sin nota no es un pendiente: es una nota que
falta poner, y eso lo dice Notas.

## 35. Alarmas en el Reloj, no en Alarmy

El pedido era conectar con Alarmy. Comprobado en el teléfono: Alarmy **no**
atiende `AlarmClock.ACTION_SET_ALARM` (solo el Reloj de Samsung lo hace) y su
deep link `alarmy://editor` abre el editor pero ignora la hora. No hay forma
documentada de programarlo desde otra app. Decisión del usuario: el Reloj del
teléfono, automático.

- **Despertar:** por día con clase, N minutos (15–180) antes de salir hacia la
  primera. **Salir:** una por clase y hora. Las que coinciden se juntan en una
  alarma con varios días.
- Se crean al tocar «Crear alarmas en el Reloj», no solas: ninguna app puede
  borrar ni editar alarmas de otra, así que crearlas sin preguntar cada vez que
  cambia el horario llenaría el Reloj de copias. La pantalla lo dice.
- **Evaluaciones:** el Reloj solo sabe de días de la semana, no de fechas.
  Son notificaciones de Cátedra la víspera, a la hora elegida (20:00 por
  defecto), reprogramadas solas cada vez que cambian las evaluaciones.
  `setAndAllowWhileIdle`: inexacta a propósito, no necesita el permiso de
  alarmas exactas. Tras reiniciar el teléfono se reprograman al abrir la app.

## 36. Dos fallos que se veían como «sigue cargando»

- **El PDF «cargaba» para siempre con todo ya guardado.** El aviso de
  `ImportDone` llega antes de redibujar, cuando el `PopScope` todavía tiene el
  `canPop: false` de «guardando»; `maybePop` le hacía caso y no cerraba.
  Ahora es `pop`. Test: `import_done_pops_test.dart`, que pinta el fotograma
  intermedio como pasa en el teléfono.
- **Tarjetas con franja de color y esquinas redondeadas** (Hoy, revisión del
  PDF, Mapa): Flutter no pinta `borderRadius` con lados de colores distintos;
  en debug revienta al pintar y en release sale con esquinas cuadradas.
  `AccentCard` pone el filete uniforme con el radio y recorta la franja por
  dentro.

## 37. Erizógenes rediseñado: erizo de mar, no bola de púas

> **Actualizado por el §39:** el cuerpo, la cara y las poses siguen; el
> monóculo y el violeta no. Ahora es terracota y lleva la lámpara.

**Pedido del usuario (2026-09-23):** rediseñarlo por completo «para que tenga
mucha más personalidad». Se exploraron tres láminas en el lienzo
«Erizógenes rediseño» (actual, A fiel en pardo, B erizo de mar) y el usuario
eligió **B**. Esto sustituye las proporciones portadas de
`Erizogenes.dc.html`, que ya no está en el repositorio.

- **Cuerpo:** cúpula de erizo de mar (más alta que honda) en violeta ciruela,
  con hileras de tubérculos arriba. Las agujas van en dos capas con la punta
  clara y un largo que varía con una suma de senos fija: irregulares a la
  vista, idénticas en cada fotograma. Pies tubulares y sombra en el suelo.
- **La cara es el personaje:** un párpado a media asta (escepticismo), el ojo
  derecho agrandado por el cristal del monóculo, cejas, media sonrisa y una
  barba de tres púas: la de Diógenes. Las seis poses siguen siendo las mismas;
  cada una es una combinación de párpados, cejas, boca, púas y monóculo, no un
  dibujo aparte. Satisfecho es párpados pesados y media sonrisa, no un «¡yay!».
  Confundido deja caer el monóculo, que cuelga de la cadena.
- **Contrato:** `color.mascot` cambia de paleta y suma `spikeTip`,
  `tubercle`, `brow` y `shadow`. `mascot.motion` guarda las amplitudes de las
  reacciones (salto, erizado, sombra, mirada); `mascotHop` y `mascotDizzy`
  dejan de tomar prestados `mascotEnter` y `blinkMin`, y `dizzyTaps` /
  `pokeWindowMs` sustituyen al `5` suelto. La geometría del dibujo sigue
  exenta del guardia: es la ilustración.
- **Correcciones del mismo paso:** los vaivenes usan por fin la
  `easeInOutSine` del contrato (antes eran ondas triangulares que frenaban en
  seco); un parpadeo en vuelo ya no deja una segunda cadena de parpadeos si
  cambia la pose; la esquina tenía dos `Semantics(button)` anidados y una
  pista que hablaba de «consejos».
- **Red:** `mascot_still_golden_test.dart` congela las seis poses en claro y
  oscuro más los tamaños pequeños. Es lo que se rasteriza para los widgets.

## 38. El trayecto lo mide la persona

**Pedido del usuario (2026-09-23):** «desde mi ubicación me demoro media
hora»; la app calculaba con 15 min a pie. El trayecto era una tabla fija por
modo (15 a pie, 35 bus, 20 carro) y no usaba la ubicación para nada.

- **Ajustes → Tiempo de trayecto**, de 5 a 120 min. Sin tocarlo enseña el
  estimado del modo; «Usar el estimado» lo devuelve a la tabla.
- Columna `trayectoMinutos` (nullable) en la v4 del esquema. Nulo = estimado
  del modo, así que nadie que ya tenía la app cambia de hora de salida sin
  pedirlo.
- `DeparturePlanner.travelMinutesFor` es la única regla: la usan Hoy, los
  widgets y las alarmas del Reloj. Las alarmas ya creadas en el Reloj no se
  mueven solas (ninguna app puede editar alarmas de otra): hay que volver a
  crearlas desde Ajustes.
- La ruta real con ubicación sigue pendiente (Fase 4); cuando llegue, este
  ajuste queda como respaldo.

## 39. Más Diógenes: la lámpara, la cerámica griega y el ánfora

**Pedido del usuario (2026-09-23):** «dejemos a un lado la idea del
monóculo… más griego, más Diógenes». Se exploraron la lámpara, el tribón con
bastón, las figuras rojas y un busto con melena (lámina «Sin monóculo»). El
usuario pidió **la lámpara mezclada con las figuras rojas** y, además, que
Erizógenes aparezca **de fondo pintado en un jarrón griego, como las musas de
Hércules**.

- **La lucerna sustituye al monóculo.** Es la lámpara con la que Diógenes
  buscaba «un hombre» a plena luz del día. La llama cuenta cómo está: viva en
  reposo, alta cuando examina, humo cuando duerme, casi apagada y la lámpara
  en el suelo cuando algo no cuadra. Se mece con la respiración y aletea
  hacia atrás al correr.
- **Paleta de figuras rojas:** cuerpo terracota, agujas oscuras con punta
  clara. En tema oscuro las agujas y los pies se aclaran
  (`spikesOnDark`, `spikeTipOnDark`, `pawOnDark`): negras sobre casi negro
  desaparecían y solo quedaban las puntas.
- **`MascotVase`:** un ánfora de figuras negras (cuello negro con hojas,
  meandro, rayos) con Erizógenes pintado en el panel, con la paleta
  `figure` del mismo pintor: todo silueta, las líneas «incisas» dejan ver el
  barro. Respira y su llama se mece; bajo reduced-motion, quieta. Va tenue
  (`vaseOpacityDark` 0,16, `vaseOpacityLight` 0,2), sin tacto y fuera del
  lector de pantalla. Aparece solo en la bienvenida y detrás del día sin
  clases (dormido, como el de delante). Nuevo host `jarrón de fondo`.
- **Fase 2, la carrera:** `rodando` ya no gira 360°: corre (bob, zancada
  alterna, agujas que aletean, sombra que respira, aplastado al tocar el
  suelo). La carga y el «sal ya» corren igual (decisión del usuario).
  `MascotLoader`, pasado `mascotLoaderLong` (6 s), lo cansa: zancada más
  corta, párpados bajos, cada `mascotLookBack` mira hacia atrás, y la frase
  pasa a `loadingLongLines`. `mascotRoll` pasa a llamarse `mascotRun`.
- **Pendiente:** el saltito de aterrizaje al terminar una carga. Hoy la
  pantalla cambia el loader por el contenido en el mismo fotograma; para
  verlo haría falta que el loader sobreviva un instante al dato, y eso toca
  las seis pantallas que lo usan.

## 40. Las poses se interpolan y las reacciones tienen gesto

Fases 3 y 4 de la auditoría de Erizógenes.

- **Interpolación:** cambiar de pose ya no salta de un fotograma a otro.
  Cuerpo, párpados, cejas, mirada, púas y lámpara se interpolan en
  `mascotMorph` (360 ms, easeOutCubic); la boca, si corre o si respira
  cambian a mitad de camino. Bajo reduced-motion, de golpe. El tumbado de las
  púas al dormir pasó a ser proporcional (antes era un salto al pasar de 0)
  para poder interpolarse; el fotograma final de cada pose no cambia (los
  goldens siguen iguales).
- **Gestos (`MascotBeat`):** `notice` (se da cuenta), `celebrate` (se da
  cuenta y un saltito seco), `hop`, `sigh` (suspira y se hunde) y `stumble`
  (tropieza de lado). Viven en el pintor como mandos que se suman a la pose,
  no como poses nuevas. Las amplitudes están en `mascot.motion`.
- **Quién decide:** las pantallas siguen diciendo solo qué pasó
  (`MascotReaction`); cada reacción declara su gesto y la esquina lo
  reproduce con la frase. Celebrar es escaso a propósito: solo terminar una
  tarea. Una falta es un suspiro; una cancelación no mueve el cuerpo; nota y
  tarea nueva, «se da cuenta»; asistir, guardar y alarmas, un salto. El error
  del PDF entra tropezando.
- **Reduced motion:** sin gesto. La pose y la frase ya comunican lo que pasó.

## 41. Erizógenes, el viejo: más oficio y las ocurrencias de Diógenes

**Pedido del usuario (2026-09-23):** «al diseño le falta cariño»; más
Diógenes en las animaciones: que a veces guarde la lámpara y saque algo de su
vida, con interacciones al estilo del clip de Office. Diseñado en el lienzo
(lámina «v3 · el viejo», con animaciones) y portado 1:1.

- **El personaje:** lo memorable es la cara de viejo filósofo. Cejas pobladas
  de hueso con la punta disparada, bigote de dos alas que hace de boca
  (sube con la sonrisa, cae al dormir), barba de tres puntas, nariz, ojeras de
  pensar de más, ojos con dos brillos y contorno. El cuerpo tiene volumen
  (luz arriba a la izquierda, sombra abajo a la derecha), contorno de tinta
  como la cerámica pintada, agujas en tres tonos y pies con dedos. A tamaño
  pequeño pierde luces, ojeras, dedos y asa.
- **Ocurrencias (`MascotAntic`):** guarda la lámpara, saca algo, lo usa y la
  recupera, en `mascotAntic` (3,2 s), con su frase:
  - el **cuenco** que tiró al ver a un niño beber con las manos;
  - el **rollo**, si hay una evaluación en los próximos 7 días;
  - el **reloj de arena**, si la salida a clase está a menos de 30 min;
  - el **gallo desplumado**: «¡He aquí el hombre de Platón!»;
  - la **tinaja** donde vivía, o **tomar el sol** («Apártate, que me tapas el
    sol»), si hoy no hay clases.
  El contexto elige cuál (`mascotAnticProvider`); si nada aprieta, cuenco o
  gallo, alternando por día.
- **Cuándo, sin molestar:** en la esquina, una de cada `anticEveryTaps` (4)
  sentencias y, tras `mascotAnticIdle` (2,5 min) sin decir nada, una por su
  cuenta; cualquier frase reinicia esa cuenta. En el compañero de Hoy, uno de
  cada 4 toques. Nunca corriendo. Bajo reduced-motion no se mueve: queda la
  frase.
- La luz de borde desaparece: el contorno de tinta y el volumen hacen su
  trabajo en los dos temas.

## 42. Errores de carga con Erizógenes, no con la excepción en crudo

Fase 5 de la auditoría. Hoy, Semana, Materias, Ajustes y el detalle de una
materia enseñaban `Text('$e')`: el texto de la excepción de Dart, sin salida.

- **`MascotError`:** Erizógenes confundido entra tropezando, dice una frase
  seca (`loadError.titleVariants`, sorteada una vez para que no parpadee),
  explica qué pasó («tus datos siguen guardados en el teléfono») y ofrece
  **Reintentar**, que invalida el provider de esa pantalla. El detalle técnico
  queda detrás de «Ver detalle», seleccionable para quien necesite copiarlo.
  El error no se disculpa y no es vago.
- **Contrato:** nuevo host `error de carga` en `allowedScreens` y tamaño
  `sizesUsed.loadError`. Materias y Ajustes siguen sin mascota en su uso
  normal; solo aparece si la carga falla. Materia perdida y calculadora
  imposible siguen sin mascota: eso no es un error de carga, es una mala
  noticia.

## 43. Actualizaciones sin cable: GitHub Releases y un aviso en la app

**Pedido del usuario (2026-09-23):** recibir versiones nuevas sin conectar el
teléfono al ordenador. Elegido: Releases de GitHub más un aviso dentro de la
app, sin dependencias nuevas.

- **Publicar:** un tag `vX.Y.Z` dispara `.github/workflows/release.yml`:
  genera el código, pasa los tests, compila, firma y publica `catedra.apk` y
  `version.json` (`versionCode`, `versionName`, enlace, notas del tag).
- **Recibir:** al abrir, la app lee
  `releases/latest/download/version.json`. Si su `versionCode` es mayor que el
  instalado, sale un aviso arriba («Hasta yo me actualizo»), una vez por
  sesión. «Actualizar» descarga el APK a `cache/updates/` y abre el instalador
  de Android (canal `catedra/updates` + `FileProvider` limitado a esa
  carpeta). La primera vez Android pide permiso para instalar desde Cátedra.
  En Ajustes → Actualizaciones: versión instalada y «Buscar actualización».
  Sin red no pasa nada.
- **La firma es la de siempre:** una actualización solo se instala encima si
  va firmada con la misma clave; si no, Android obliga a desinstalar y se
  pierden los datos. El workflow firma con la clave de la app ya instalada
  (secretos `ANDROID_KEYSTORE_*`); en local, sin `android/key.properties`, se
  firma como siempre.
- **Sin la clave de Claude:** el repositorio es público y el APK también.
  Cualquier clave compilada dentro se podría extraer, así que las versiones
  de GitHub no la llevan y el importador usa el lector propio de horarios.
- **Solo https** y un `version.json` mal formado se ignora: no hay descarga a
  medias por un manifiesto roto.

## 44. Horarios más realistas: tolerancia, salir desde casa y tiempos legibles

**Pedido del usuario (2026-09-23):** cálculos más realistas y «no mostrar 300
minutos». Probado en el teléfono: a las 12:30 Hoy decía «Ya. Camina.» para
una clase de 11:00 a 13:00.

- **Tolerancia de 15 min** (`DeparturePlanner.lateToleranceMinutes`): casi
  todas las clases dejan entrar tarde sin falta. Una clase es «a la que hay
  que ir» hasta su inicio más la tolerancia; después Hoy pasa a la siguiente.
  Entre el inicio y el fin de la tolerancia la card dice hasta qué hora aún
  entras. Una falta (marcada o detectada) tampoco se persigue.
- **Salir desde casa, solo cuando toca:** el trayecto cuenta para la primera
  clase del día o cuando el hueco desde la anterior da para ir a casa, estar
  una hora y volver (`leavesFromHome`). Si no, ya estás en la U: sin
  trayecto, solo el margen («Ya estás en la U · llegas 5 min antes»). La
  misma regla alimenta Hoy, los widgets (trayecto por clase) y las alarmas
  (no hay «Salir» a mitad de día entre dos clases seguidas).
- **Tiempos legibles** (`TimeSpans`): «45 min», «2 h», «1 h 20 min»; en el
  anillo, «4:05» con «h». Nunca «300 min».
- **El modo real:** la línea de llegada dice «a pie», «en bus» o «en carro»
  según Ajustes; antes decía «a pie» siempre.

## 45. Anotar falta si sigues en casa

**Pedido del usuario (2026-09-23):** «si detecta que no he salido de la casa
después de cierta hora (casi todas las clases permiten llegar 15 minutos
después sin falla), que ponga falla y pase a la otra». Revierte la regla de
«ubicación nunca en segundo plano», así que es opcional y viene apagado.

- **Cuándo:** al acabar la tolerancia de cada sesión pendiente
  (`HomeCheck.checkAt` = inicio + 15 min), con la app cerrada:
  `AttendanceChecks.kt` programa una alarma inexacta por sesión (hoy y
  mañana, reprogramadas al abrir la app y rearmadas tras reiniciar).
- **Qué:** pide una ubicación (actual con tope de 20 s, o la última si es de
  hace menos de 15 min). Si estás a menos de `HomeCheck.radiusMeters` (200 m)
  de casa y el error es menor que `maxAccuracyMeters` (250 m), deja el
  veredicto «falto» en cola y notifica «Falta anotada: {clase}» con **Sí
  fui**, que lo deshace. Sin permiso, sin casa o sin una ubicación fiable no
  anota nada: mejor no anotar una falta que anotarla mal.
- **Quién escribe en la BD:** la app, al abrirse o volver al frente
  (`HomeCheck.apply`): una falta automática solo pisa una sesión sin
  resolver; «Sí fui» la convierte en asistencia. Si anotó alguna, Erizógenes
  lo comenta en la esquina. Con la falta, Hoy pasa a la siguiente clase y el
  trayecto vuelve a contar desde casa (§44).
- **Ajustes → Mi casa y asistencia:** «Mi casa es aquí» guarda el punto (solo
  en el teléfono) y el interruptor. Android 11+ no pregunta «Permitir todo el
  tiempo» en un diálogo: la sección lo avisa y abre los permisos.
- Columna `detectarCasa` en la v5 del esquema, apagada para todos.

## 46. Widgets al día con la tolerancia, y «en la U» solo si lo sabes

Probado en el teléfono (2026-09-23):

- **Un widget seguía diciendo «10:20 Camina ya · Cálculo Vectorial» a
  mediodía.** `CatedraWidgetData.next()` tomaba como siguiente cualquier clase
  que no hubiera terminado. Ahora usa la misma regla que Hoy: inicio más la
  tolerancia (`tolerance` llega en el JSON). Las faltas llegan como `absent`
  y no se persiguen. El widget se refresca también al acabar la tolerancia.
- **«Ya estás en la U» estando en casa.** «Sin marcar» no es «fui»: solo
  cuenta como en la U si la clase anterior está marcada como asistida (o la
  detección de casa dice que saliste). Sin marca, sales de casa.
- **Alarmas «Salir» para todas las clases**: una alarma semanal no sabe si
  ese día fuiste a la anterior; perder un aviso es peor que uno de más.

## 47. La llegada se calcula de verdad y el trayecto aprende

**Pedido del usuario (2026-09-23):** «no se está calculando correctamente en
base al tiempo estimado de llegada que puedo seleccionar libremente», «¿usas
la API de Maps?» y «quiero que el cálculo de llegada vaya mejorando con el
tiempo». Elegido: OSRM como estimado inicial y aprender de los viajes.

- **El fallo:** Hoy nunca calculaba la hora de llegada. Decía «llegas {buffer}
  antes» aunque ya fuera tarde, y «justo» en cuanto pasaba la hora de salir;
  el widget sí hacía la cuenta. Ahora `DeparturePlan.estimatedArrival` es la
  única cuenta: saliendo a tiempo, inicio − margen; pasada la hora de salir,
  ahora + trayecto. Hoy dice «35 min en bus · llegas 7:55, 5 min antes» o «Si
  sales ya, llegas 8:07 · 7 min tarde».
- **No hay API de Google Maps.** El número de partida es, en orden: el que la
  persona fija en Ajustes, la ruta por calles de casa al campus (OSRM en
  routing.openstreetmap.de, sin clave; el campus es el promedio de los
  salones ubicados) o la tabla del modo. OSRM no sabe de tráfico ni de buses:
  el carro se infla ×1,35 + 4 min y el bus es carro ×1,5 + 10 min.
- **Aprende (`TravelEstimator`):** «Ya voy» saliendo de casa empieza a medir,
  «Llegué» cierra el viaje (tabla `Trips`, v6). El estimado mezcla el número
  de partida (vale como 3 viajes) con los viajes del modo, con más peso a lo
  reciente (vida media de 45 días), al mismo día de la semana y a la misma
  franja (×1,5 cada uno). Con 4 viajes o más descarta los que se alejan de la
  mediana, y si varían mucho suma medio desvío (máximo 10 min): llegar antes
  cuesta menos que llegar tarde. Viajes de menos de 3 o más de 180 min no
  cuentan, y uno sin cerrar en 3 h se descarta.
- Hoy y los widgets usan el trayecto del día y la franja de cada clase. Las
  alarmas semanales usan el general. Ajustes muestra el número y de dónde
  sale («Aprendido de 7 viajes · partía de 30 min»), deja apagar el
  aprendizaje y olvidar los viajes.

## 48. Personalizar: temas en claro y oscuro y la rueda de color

**Pedido del usuario (2026-09-23):** «usando una rueda de colores parecida a
la que usa Concepts, agregar secciones para cambiar el diseño de la app»,
con colores de materias, fondos y superficies, y diseños prehechos «pensados
como el que ya está en la app», que funcionen en modo oscuro y normal.

- **Mecánica:** cada `ColorTokens.*` sabe su rol (`surfaceBase`,
  `accentPrimary`…) y consulta `ThemedColor.palette` antes de devolver el par
  del contrato. La app instala el tema antes de construir el `ThemeData`, así
  que las 300 llamadas que ya existían cambian de color sin tocarlas. Papiro
  es el contrato tal cual (resolver nulo).
- **Temas:** Papiro, Pizarra (la pizarra verde de Concepts: tiza crema y
  amarilla de noche), Tinta, Terracota, Lavanda, Musgo y Alto contraste. Cada
  uno se define con papel, tinta y acento **por modo**; tarjetas, bordes,
  textos secundarios y texto sobre acento se derivan con reglas que buscan el
  contraste (WCAG: 7 el texto, 4,5 el secundario y los botones, 3 el
  terciario y los acentos). `palette_test.dart` lo comprueba en todos los
  temas y en temas propios extremos (amarillo puro, gris sobre gris).
- **Tema propio:** dos colores de la rueda. Del papel se toma el tono y de
  ahí salen el fondo claro y el oscuro; el acento se aclara en oscuro y se
  oscurece en claro. Funciona en los dos modos sin pedir más.
- **La rueda (`CopicWheel`):** media rueda con el centro abajo, en la zona del
  pulgar. Catorce familias al modo COPIC (R, RV, V, BV, B, BG, G, YG, Y, YR,
  E, W, C, N) en el anillo; la elegida sube y abre cuatro rayos (de viva a
  agrisada) de seis pasos (claro afuera, oscuro adentro), con su código
  («E13»). Arrastrar el anillo gira la rueda; arrastrar sobre los rayos
  elige. «Ajuste fino» da tono, saturación y luz.
- **Color de materia:** desde Personalizar o el formulario de la materia. Se
  guarda como ARGB opaco en el mismo `colorIndex` (≥ 0xFF000000), sin cambio
  de esquema; los widgets de Kotlin lo reciben como entero negativo y lo usan
  tal cual. «Color por defecto» lo devuelve a la paleta.
- Columnas `temaPaleta`, `temaPapel` y `temaAcento` en la v6.
- **Límite conocido:** los widgets de la pantalla de inicio siguen con los
  colores del contrato (son XML generados): no siguen el tema de la app,
  solo el color de cada materia.

## 49. Menú radial al modo de Concepts

**Pedido del usuario (2026-09-23):** «replantea el menú de navegación para
que no sea tan simple», con la rueda radial de Concepts.

- En teléfono la barra inferior se cambia por un botón central (el ícono de
  la pantalla actual). Tocarlo abre un semicírculo con dos anillos: adentro
  Hoy, Semana, Materias y Mapa; afuera Importar horario, Nueva materia,
  Personalizar y Ajustes. Mantener y arrastrar resalta el sector bajo el dedo
  y soltar lo elige, sin segundo toque. Atrás o tocar fuera lo cierra.
- Los sectores entran escalonados; bajo «reducir movimiento» aparecen de una.
  La navegación sigue sin háptica (lista `never` del contrato).
- Desde `medium` sigue el riel lateral, con las cuatro acciones abajo.
- `RadialGeometry` es la misma para el dibujo y el toque, y tiene test.

## 50. Otros formatos de horario: retícula por horas y calendarios .ics

**Pedido del usuario (2026-09-23):** «en el parser del horario prepárate para
otro tipo de horarios».

- **Retícula por horas (`TimeGridParser`):** días arriba, horas en la
  primera columna y en la casilla solo la materia (con salón o profesor si
  vienen etiquetados). La hora sale de la fila por coordenada Y. La misma
  materia en filas seguidas se une en una sesión, y una hora que retrocede
  sin a.m./p.m. («12:00, 1:00») es de la tarde. Si las casillas traen su
  propia hora es el formato de «Servicios académicos» y se retira: sobre el
  PDF real de la Santo Tomás habría leído 9 «materias» basura.
- **Calendarios (.ics):** Google Calendar, Outlook/Teams, Moodle. Un evento
  semanal (`RRULE` con `BYDAY`) es una clase con sus días. Un evento suelto
  cuenta solo si se repite el mismo día y a la misma hora en dos semanas o
  más. Si nada se repite, se toma todo con duda. Las horas en UTC pasan a la
  hora local; los eventos de todo el día se descartan.
- **Elección:** con un PDF corren las dos retículas y `bestParse` se queda
  con la de más sesiones y menos dudas; el heurístico sigue de respaldo y
  Claude de red de seguridad (solo con clave). El selector acepta `.pdf` y
  `.ics`.
- Falta lo de siempre: horarios reales de otras universidades como fixture.
  Si uno falla, guardar sus líneas en `test/fixtures/`.

## Lo que sigue sin especificación visual

Único hueco abierto de los nueve detectados; el de las pantallas de captura
manual se resolvió en el §9. Las Fases 4 y 6 siguen necesitando diseño antes de
implementarse:

- Pre-marcado por geofence y la pregunta de fin de día.
- Permiso de ubicación denegado: hoy es un aviso en la barra de abajo (§30).
- Notificación programada y su escalado a alerta urgente.
- Estadísticas de fin de semestre.
