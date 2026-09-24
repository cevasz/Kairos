package com.kairos.app

import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.LocalTime

/**
 * Lo que Flutter deja para los widgets (ver lib/features/widgets/home_widget_sync.dart),
 * ya interpretado. Los widgets no calculan nada del dominio: solo eligen, según
 * la hora, cuál de las clases que les pasaron toca enseñar.
 */
data class WidgetClass(
    val date: String,
    val day: String,
    val start: Int,
    val end: Int,
    val leave: Int,
    val startLabel: String,
    val endLabel: String,
    val leaveLabel: String,
    val name: String,
    val room: String?,
    val color: Int,
    val status: String,
    /** Trayecto de esta clase: 0 si ya estás en la U por una anterior. */
    val travel: Int = -1,
) {
    val isLive get() = status == "pending"
}

/** Un pendiente: una tarea o una evaluación sin nota, con su materia. */
data class WidgetPending(
    val subject: String,
    val color: Int,
    val title: String,
    val whenLabel: String,
    val date: String?,
    val isEval: Boolean,
)

/** A qué hora llegas y con cuánto margen. `late` en minutos si llegas tarde. */
data class Arrival(val label: String, val marginMinutes: Int, val ifLeaveNow: Boolean)

class WidgetData(
    val today: String,
    val todayHeader: String,
    val strings: Map<String, String>,
    val classes: List<WidgetClass>,
    val travel: Int,
    val buffer: Int,
    /** Minutos que te dejan entrar tarde sin falta (DeparturePlanner.lateToleranceMinutes). */
    val tolerance: Int,
    val quips: Map<String, List<String>>,
    val pending: List<WidgetPending>,
    val pendingTotal: Int,
) {
    fun s(key: String) = strings[key] ?: ""

    /** Minutos desde medianoche, igual que MinutesOfDay en Dart. */
    private fun nowMinutes(): Int = LocalTime.now().let { it.hour * 60 + it.minute }

    /** La fecha real de hoy: si el teléfono cruzó la medianoche, manda el reloj. */
    private fun realToday(): String = LocalDate.now().toString()

    fun todayClasses(): List<WidgetClass> = classes.filter { it.date == realToday() }

    /**
     * La próxima clase a la que hay que ir: la de hoy que no ha terminado (ni
     * cancelada ni ya marcada) o, si no queda, la primera de un día siguiente.
     */
    fun next(): WidgetClass? {
        val today = realToday()
        val now = nowMinutes()
        // Igual que Hoy: una clase es «a la que hay que ir» hasta su inicio más
        // la tolerancia. A una de 11:00 no se le dice «Camina ya» a mediodía.
        return classes.firstOrNull { it.isLive && (it.date > today || (it.date == today && it.start + tolerance > now)) }
    }

    /** La clase que viene después de [c], el mismo día. */
    fun after(c: WidgetClass): WidgetClass? =
        classes.firstOrNull { it.isLive && it.date == c.date && it.start > c.start }

    fun isToday(c: WidgetClass) = c.date == realToday()

    fun isTomorrow(c: WidgetClass) = c.date == LocalDate.now().plusDays(1).toString()

    fun isUrgent(c: WidgetClass) = isToday(c) && nowMinutes() >= c.leave

    /** Milisegundos desde ahora hasta la hora de salir. */
    fun millisUntilLeave(c: WidgetClass): Long {
        val t = LocalTime.now()
        val nowMs = ((t.hour * 60 + t.minute) * 60 + t.second) * 1000L
        return c.leave * 60_000L - nowMs
    }

    /**
     * Llegada estimada. Si todavía no es hora de salir, llegas cuando lo
     * planeó la app (la hora de salir más el trayecto: el buffer de margen).
     * Si ya pasó, cuenta desde ahora: «si sales ya, llegas 8:07».
     */
    fun arrival(c: WidgetClass): Arrival {
        val now = nowMinutes()
        val late = isToday(c) && now > c.leave
        val trip = if (c.travel >= 0) c.travel else travel
        val at = if (late) now + trip else c.leave + trip
        return Arrival(hhmm(at), c.start - at, late)
    }

    /** «llegas 7:55 · 5 min antes», o «si sales ya, llegas 8:07 · 7 min tarde». */
    fun arrivalLine(c: WidgetClass): String {
        val a = arrival(c)
        val margin = when {
            a.marginMinutes > 0 -> String.format(s("arriveEarly"), a.marginMinutes)
            a.marginMinutes == 0 -> s("arriveOnTime")
            else -> String.format(s("arriveLate"), -a.marginMinutes)
        }
        val base = "${String.format(s("arriveAt"), a.label)} · $margin"
        return if (a.ifLeaveNow) "${s("ifLeaveNow")}, $base" else base
    }

    /** Una frase de Erizógenes; cambia con la hora para no repetir siempre la misma. */
    fun quip(kind: String): String {
        val list = quips[kind].orEmpty()
        if (list.isEmpty()) return ""
        val t = LocalTime.now()
        return list[Math.floorMod(LocalDate.now().dayOfYear + t.hour, list.size)]
    }

    companion object {
        const val KEY = "kairos_upcoming"

        /** 7:05 o 14:30, como MinutesOfDay.hhmm en Dart. */
        fun hhmm(minutes: Int): String {
            val m = Math.floorMod(minutes, 24 * 60)
            return "%d:%02d".format(m / 60, m % 60)
        }

        private fun JSONObject.strings(key: String): Map<String, String> {
            val o = optJSONObject(key) ?: return emptyMap()
            return o.keys().asSequence().associateWith { o.getString(it) }
        }

        private fun JSONArray.strings(): List<String> = (0 until length()).map { getString(it) }

        fun read(prefs: SharedPreferences): WidgetData? {
            val raw = prefs.getString(KEY, null) ?: return null
            return try {
                val o = JSONObject(raw)
                val arr = o.getJSONArray("classes")
                val classes = (0 until arr.length()).map { i ->
                    val c = arr.getJSONObject(i)
                    WidgetClass(
                        date = c.getString("date"),
                        day = c.getString("day"),
                        start = c.getInt("start"),
                        end = c.getInt("end"),
                        leave = c.getInt("leave"),
                        startLabel = c.getString("startLabel"),
                        endLabel = c.getString("endLabel"),
                        leaveLabel = c.getString("leaveLabel"),
                        name = c.getString("name"),
                        room = if (c.isNull("room")) null else c.getString("room"),
                        color = c.getInt("color"),
                        status = c.getString("status"),
                        travel = c.optInt("travel", -1),
                    )
                }
                val q = o.optJSONObject("quips")
                val quips = q?.keys()?.asSequence()?.associateWith { q.getJSONArray(it).strings() }.orEmpty()
                val p = o.optJSONArray("pending") ?: JSONArray()
                val pending = (0 until p.length()).map { i ->
                    val e = p.getJSONObject(i)
                    WidgetPending(
                        subject = e.getString("subject"),
                        color = e.getInt("color"),
                        title = e.getString("title"),
                        whenLabel = e.optString("when"),
                        date = if (e.isNull("date")) null else e.getString("date"),
                        isEval = e.getString("kind") == "eval",
                    )
                }
                WidgetData(
                    today = o.getString("today"),
                    todayHeader = o.getString("todayHeader"),
                    // Los textos nuevos llegan en `strings2` para no romper un
                    // JSON viejo que quede en disco hasta la próxima escritura.
                    strings = o.strings("strings") + o.strings("strings2"),
                    classes = classes,
                    travel = o.optInt("travel", 15),
                    buffer = o.optInt("buffer", 5),
                    tolerance = o.optInt("tolerance", 15),
                    quips = quips,
                    pending = pending,
                    pendingTotal = o.optInt("pendingTotal", pending.size),
                )
            } catch (e: Exception) {
                null
            }
        }

        private val subjectColors = intArrayOf(
            R.color.kairos_subject_0, R.color.kairos_subject_1, R.color.kairos_subject_2,
            R.color.kairos_subject_3, R.color.kairos_subject_4, R.color.kairos_subject_5,
            R.color.kairos_subject_6, R.color.kairos_subject_7,
        )

        /**
         * Igual que SubjectPalette.at: el índice se normaliza, nunca revienta.
         * Un color de la rueda llega como ARGB opaco (≥ 0xFF000000 en Dart);
         * `getInt` se queda con los 32 bits bajos, que en Kotlin es negativo.
         */
        fun subjectColor(context: Context, index: Int): Int =
            if (index < 0) index
            else ContextCompat.getColor(context, subjectColors[Math.floorMod(index, subjectColors.size)])

        /**
         * Erizógenes en la pose pedida, pintado por Flutter al arrancar la app
         * (ver `_renderMascots`), en la variante del tema actual del sistema.
         * Null si la app todavía no lo pintó: el widget se ve igual, sin erizo.
         */
        fun mascot(context: Context, prefs: SharedPreferences, pose: String): Bitmap? {
            val night = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
            val path = prefs.getString("mascot_${pose}_${if (night) "dark" else "light"}", null) ?: return null
            return try {
                BitmapFactory.decodeFile(path)
            } catch (e: Exception) {
                null
            }
        }
    }
}
