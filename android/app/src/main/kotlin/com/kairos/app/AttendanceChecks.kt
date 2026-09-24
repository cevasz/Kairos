package com.kairos.app

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject

/**
 * «¿Sigues en casa a la hora de clase?», con la app cerrada.
 *
 * La app manda, para cada clase pendiente, el momento en que acaba la
 * tolerancia (inicio + 15 min). A esa hora este código pide una ubicación; si
 * estás a menos del radio de casa y la ubicación es fiable, deja un veredicto
 * «falto» en cola y avisa con una notificación que tiene «Sí fui». Los
 * veredictos los aplica la app al abrirse: la base de datos es de Dart.
 *
 * Sin permiso de ubicación en segundo plano, sin casa o sin una ubicación
 * fiable no se anota nada: mejor no anotar una falta que anotarla mal.
 */
object AttendanceChecks {
    private const val PREFS = "kairos_attendance"
    private const val PLAN = "plan"
    private const val VERDICTS = "verdicts"
    private const val REQUEST_BASE = 700_000

    /** Reemplaza todas las comprobaciones por las de [plan] y las guarda para el reinicio. */
    fun schedule(context: Context, plan: JSONObject) {
        prefs(context).edit().putString(PLAN, plan.toString()).apply()
        arm(context, plan)
    }

    /** Vuelve a programar lo guardado: tras reiniciar el teléfono o actualizar la app. */
    fun rearm(context: Context) {
        val raw = prefs(context).getString(PLAN, null) ?: return
        arm(context, JSONObject(raw))
    }

    private fun arm(context: Context, plan: JSONObject) {
        val am = context.getSystemService(AlarmManager::class.java)
        val p = prefs(context)
        p.getStringSet("ids", emptySet())!!.forEach { id ->
            pending(context, id.toInt(), null)?.let { am.cancel(it) }
        }
        val ids = mutableSetOf<String>()
        val items = plan.optJSONArray("items") ?: JSONArray()
        val now = System.currentTimeMillis()
        for (i in 0 until items.length()) {
            val item = items.getJSONObject(i)
            val at = item.getLong("at")
            if (at <= now) continue
            val id = item.getInt("id")
            val intent = Intent(context, AttendanceCheckReceiver::class.java)
                .putExtra("id", id)
                .putExtra("clase", item.getString("clase"))
            // Inexacta: unos minutos de más no cambian si sigues en casa, y
            // así no hace falta el permiso de alarmas exactas.
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending(context, id, intent)!!)
            ids += id.toString()
        }
        p.edit().putStringSet("ids", ids).apply()
    }

    private fun pending(context: Context, id: Int, intent: Intent?): PendingIntent? {
        val i = intent ?: Intent(context, AttendanceCheckReceiver::class.java)
        val flags = PendingIntent.FLAG_IMMUTABLE or
            if (intent == null) PendingIntent.FLAG_NO_CREATE else PendingIntent.FLAG_UPDATE_CURRENT
        return PendingIntent.getBroadcast(context, REQUEST_BASE + id, i, flags)
    }

    fun plan(context: Context): JSONObject? = prefs(context).getString(PLAN, null)?.let { JSONObject(it) }

    /** Deja un veredicto en cola; el último sobre una misma sesión manda. */
    fun addVerdict(context: Context, id: Int, status: String) {
        val p = prefs(context)
        val list = JSONArray(p.getString(VERDICTS, "[]"))
        list.put(JSONObject().put("id", id).put("status", status).put("at", System.currentTimeMillis()))
        p.edit().putString(VERDICTS, list.toString()).apply()
    }

    /** Entrega la cola a la app y la vacía. */
    fun takeVerdicts(context: Context): List<Map<String, Any>> {
        val p = prefs(context)
        val list = JSONArray(p.getString(VERDICTS, "[]"))
        p.edit().remove(VERDICTS).apply()
        return (0 until list.length()).map { i ->
            val o = list.getJSONObject(i)
            mapOf("id" to o.getInt("id"), "status" to o.getString("status"))
        }
    }

    fun hasBackgroundLocation(context: Context): Boolean {
        fun granted(p: String) = ContextCompat.checkSelfPermission(context, p) == PackageManager.PERMISSION_GRANTED
        val foreground = granted(Manifest.permission.ACCESS_FINE_LOCATION) ||
            granted(Manifest.permission.ACCESS_COARSE_LOCATION)
        val background = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            granted(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        return foreground && background
    }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}

class AttendanceCheckReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", -1)
        val plan = AttendanceChecks.plan(context) ?: return
        if (id < 0 || !AttendanceChecks.hasBackgroundLocation(context)) return
        val home = Location("home").apply {
            latitude = plan.getDouble("lat")
            longitude = plan.getDouble("lng")
        }
        val radius = plan.getInt("radius")
        val maxAccuracy = plan.getInt("maxAccuracy")
        val clase = intent.getStringExtra("clase").orEmpty()

        val result = goAsync()
        locate(context) { here ->
            try {
                if (here != null && here.accuracy <= maxAccuracy && here.distanceTo(home) <= radius) {
                    AttendanceChecks.addVerdict(context, id, "falto")
                    notify(context, plan, id, clase)
                }
            } finally {
                result.finish()
            }
        }
    }

    /**
     * Una ubicación actual, con un tope de espera. Si el sistema no da una a
     * tiempo, vale la última conocida si es reciente; si no, ninguna.
     */
    @Suppress("MissingPermission")
    private fun locate(context: Context, done: (Location?) -> Unit) {
        val lm = context.getSystemService(LocationManager::class.java)
        val main = Handler(Looper.getMainLooper())
        var delivered = false
        fun deliver(l: Location?) {
            if (delivered) return
            delivered = true
            done(l)
        }
        fun lastKnown(): Location? = lm.getProviders(true)
            .mapNotNull { runCatching { lm.getLastKnownLocation(it) }.getOrNull() }
            .filter { System.currentTimeMillis() - it.time <= FRESH_MS }
            .minByOrNull { it.accuracy }

        main.postDelayed({ deliver(lastKnown()) }, TIMEOUT_MS)
        val provider = when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && lm.isProviderEnabled(LocationManager.FUSED_PROVIDER) ->
                LocationManager.FUSED_PROVIDER
            lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
            lm.isProviderEnabled(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
            else -> null
        }
        if (provider == null) {
            deliver(lastKnown())
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            lm.getCurrentLocation(provider, null, context.mainExecutor) { deliver(it ?: lastKnown()) }
        } else {
            @Suppress("DEPRECATION")
            lm.requestSingleUpdate(provider, { deliver(it) }, Looper.getMainLooper())
        }
    }

    private fun notify(context: Context, plan: JSONObject, id: Int, clase: String) {
        val strings = plan.getJSONObject("strings")
        val nm = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, strings.getString("channel"), NotificationManager.IMPORTANCE_DEFAULT),
            )
        }
        val undo = PendingIntent.getBroadcast(
            context,
            800_000 + id,
            Intent(context, AttendanceUndoReceiver::class.java).putExtra("id", id),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val open = PendingIntent.getActivity(
            context,
            900_000 + id,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val n = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_kairos)
            .setContentTitle(strings.getString("title").replace("%s", clase))
            .setContentText(strings.getString("body"))
            .setStyle(NotificationCompat.BigTextStyle().bigText(strings.getString("body")))
            .setContentIntent(open)
            .setAutoCancel(true)
            .addAction(0, strings.getString("undo"), undo)
            .build()
        runCatching { NotificationManagerCompat.from(context).notify(NOTIFICATION_BASE + id, n) }
    }

    companion object {
        const val CHANNEL = "kairos_attendance"
        const val NOTIFICATION_BASE = 600_000
        private const val TIMEOUT_MS = 20_000L
        private const val FRESH_MS = 15 * 60_000L
    }
}

/** «Sí fui»: deshace la falta automática y quita la notificación. */
class AttendanceUndoReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", -1)
        if (id < 0) return
        AttendanceChecks.addVerdict(context, id, "asistio")
        NotificationManagerCompat.from(context).cancel(AttendanceCheckReceiver.NOTIFICATION_BASE + id)
    }
}

/** Tras reiniciar o actualizar la app, las comprobaciones de hoy vuelven a quedar armadas. */
class AttendanceBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AttendanceChecks.rearm(context)
    }
}
