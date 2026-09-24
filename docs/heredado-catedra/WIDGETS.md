# Widgets de Cátedra: los que hay y los posibles

Todos son RemoteViews (§31): Kotlin lee el JSON que escribe
`home_widget_sync.dart`, así que un widget nuevo casi siempre es un layout
XML, un `AppWidgetProvider` y unos campos más en el JSON.

## Ya existen

| Widget | Tamaños | Qué muestra |
|---|---|---|
| Próxima clase | 2×1, 2×2, 4×2+ | Hora de salir, cuenta atrás, materia y salón, llegada estimada, Erizógenes |
| Pendientes | 2×2, 4×2, 4×4 | Evaluaciones y tareas por fecha, con el color de cada materia |
| Tu día | 4×2 | Hasta cuatro clases; canceladas tachadas, pasadas atenuadas |

## Posibles, por prioridad

**Valor**: cuánto ayuda en el día a día. **Esfuerzo**: S (una tarde),
M (un par de días), L (más).

| # | Widget | Tamaño | Qué hace | Valor | Esfuerzo |
|---|---|---|---|---|---|
| 1 | **Ya voy / Llegué** | 1×1, 2×1 | Un botón que empieza y cierra el viaje sin abrir la app. Alimenta el aprendizaje del trayecto (§47): cuantos más viajes, mejor la hora de salir | Alta | S |
| 2 | **Salida en vivo** (notificación, no widget) | — | Notificación en curso con la cuenta atrás y «si sales ya, llegas 8:07». En el Galaxy A56 (One UI 7+) aparece en la Now Bar de la pantalla de bloqueo, que es donde más se mira | Alta | M |
| 3 | **Faltas en riesgo** | 2×2 | Las materias más cerca del límite, con su semáforo y «te quedan N» | Alta | S |
| 4 | **Próxima evaluación** | 2×1 | «Parcial de Física · en 3 días», con la nota que necesitas (de la calculadora inversa) | Alta | S |
| 5 | **Semana compacta** | 4×2, 4×3 | La semana en bloques de color, hoy resaltado, como la pantalla Semana en miniatura | Media | M |
| 6 | **Hueco libre** | 2×1 | «1 h 30 libre hasta Cálculo · Salón 301». Útil para estudiar o comer entre clases | Media | S |
| 7 | **Notas del semestre** | 2×2, 4×2 | Acumulada y proyección por materia, con barra | Media | M |
| 8 | **Tile de Ajustes rápidos** | — | «Ya voy» / «Llegué» en la cortina de notificaciones, al lado del wifi | Media | S |
| 9 | **Erizógenes** | 1×1, 2×2 | Solo la mascota con la sentencia del día; tocarlo cambia de frase | Baja (cariño) | S |
| 10 | **Semestre en curso** | 4×1 | «Semana 7 de 16» con barra y los días al límite de cancelación | Baja | S |
| 11 | **Próximo salón** | 2×2 | Mapa estático del campus con el pin del próximo salón y la distancia | Media | L |

## Transversal

- **Los widgets con el tema de la app** (§48): hoy usan los colores del
  contrato (XML generado). Para que sigan Pizarra, Tinta, etc., el JSON
  tendría que llevar la paleta y Kotlin pintarla con `setInt(...,
  "setBackgroundColor")`. Esfuerzo M, y aplica a todos los widgets a la vez.
- **Acciones sin abrir la app**: marcar asistencia, cancelada o tarea hecha
  desde el widget con `PendingIntent` a un `BroadcastReceiver`, que deja el
  cambio en cola como hoy hace la detección de casa (§45).

## Recomendación

Primero el 1 y el 2 juntos: son la misma idea (salir y llegar) y cierran el
círculo del trayecto que aprende. Después el 3 y el 4, que son los que más
evitan malas sorpresas.
