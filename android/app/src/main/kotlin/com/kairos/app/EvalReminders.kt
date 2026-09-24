package com.kairos.app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Avisos de la víspera de una evaluación. El Reloj no sirve para esto: sus
 * alarmas solo saben de días de la semana, no de fechas. Así que son
 * notificaciones de Kairós, programadas con AlarmManager.
 *
 * Cada `schedule` reemplaza todos los anteriores: la app vuelve a mandar la
 * lista completa cada vez que cambian las evaluaciones o el ajuste.
 */
object EvalReminders {
    private const val PREFS = "kairos_reminders"
    private const val IDS = "ids"
    const val CHANNEL = "kairos_evaluations"

    fun schedule(context: Context, channelName: String, items: List<Map<String, Any>>) {
        val am = context.getSystemService(AlarmManager::class.java)
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.getStringSet(IDS, emptySet())!!.forEach { id ->
            pending(context, id.toInt(), null)?.let { am.cancel(it) }
        }
        val ids = mutableSetOf<String>()
        for (item in items) {
            val id = (item["id"] as Number).toInt()
            val at = (item["at"] as Number).toLong()
            val intent = Intent(context, EvalReminderReceiver::class.java)
                .putExtra("id", id)
                .putExtra("title", item["title"] as String)
                .putExtra("body", item["body"] as String)
                .putExtra("channel", channelName)
            // Inexacta a propósito: un aviso de víspera no necesita el
            // permiso de alarmas exactas, y unos minutos de más no importan.
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending(context, id, intent)!!)
            ids += id.toString()
        }
        prefs.edit().putStringSet(IDS, ids).apply()
    }

    private fun pending(context: Context, id: Int, intent: Intent?): PendingIntent? {
        val i = intent ?: Intent(context, EvalReminderReceiver::class.java)
        val flags = PendingIntent.FLAG_IMMUTABLE or
            if (intent == null) PendingIntent.FLAG_NO_CREATE else PendingIntent.FLAG_UPDATE_CURRENT
        return PendingIntent.getBroadcast(context, id, i, flags)
    }
}

class EvalReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val nm = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = intent.getStringExtra("channel").orEmpty().ifEmpty { EvalReminders.CHANNEL }
            nm.createNotificationChannel(
                NotificationChannel(EvalReminders.CHANNEL, name, NotificationManager.IMPORTANCE_HIGH),
            )
        }
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, EvalReminders.CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_kairos)
            .setContentTitle(intent.getStringExtra("title"))
            .setContentText(intent.getStringExtra("body"))
            .setContentIntent(open)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(intent.getIntExtra("id", 0), notification)
        } catch (e: SecurityException) {
            // Sin permiso de notificaciones no hay nada que hacer aquí.
        }
    }
}
