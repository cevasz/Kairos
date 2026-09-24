package com.kairos.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget «Próxima clase», en tres tamaños:
 *
 *  - pequeño (2×1): hora de salir, materia y llegada en una fila;
 *  - mediano (2×2): lo de siempre, la llegada estimada y Erizógenes en el pie;
 *  - ancho (4×2 o más): además, Erizógenes grande con su frase y la clase que
 *    sigue.
 *
 * El número grande es la hora de salir, no los minutos que faltan: un widget
 * no se redibuja cada minuto y una cuenta atrás congelada miente. Debajo, un
 * Chronometer del sistema sí lleva la cuenta en vivo sin despertar a la app.
 * Urgente = terracota solo en el número y en el borde, nunca en el fondo.
 */
class NextClassWidgetProvider : HomeWidgetProvider() {
    private enum class Size { SMALL, MEDIUM, WIDE }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, build(context, appWidgetManager, id, widgetData))
        }
    }

    /** Al redimensionar en Android < 12 hay que escoger el layout a mano. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        appWidgetManager.updateAppWidget(appWidgetId, build(context, appWidgetManager, appWidgetId, prefs))
    }

    private fun build(context: Context, manager: AppWidgetManager, id: Int, prefs: SharedPreferences): RemoteViews {
        val data = WidgetData.read(prefs)
        fun views(size: Size) = RemoteViews(
            context.packageName,
            when (size) {
                Size.SMALL -> R.layout.widget_next_class_small
                Size.MEDIUM -> R.layout.widget_next_class
                Size.WIDE -> R.layout.widget_next_class_wide
            },
        ).also {
            it.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            bind(context, prefs, it, data, size)
        }

        // Android 12+: el lanzador escoge solo el que mejor cabe, también
        // mientras la persona lo estira, sin despertar a la app.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return RemoteViews(
                mapOf(
                    SizeF(100f, 40f) to views(Size.SMALL),
                    SizeF(130f, 150f) to views(Size.MEDIUM),
                    SizeF(250f, 110f) to views(Size.WIDE),
                ),
            )
        }
        val o = manager.getAppWidgetOptions(id)
        val w = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val h = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
        return views(
            when {
                h in 1 until 150 -> Size.SMALL
                w >= 250 -> Size.WIDE
                else -> Size.MEDIUM
            },
        )
    }

    private fun bind(context: Context, prefs: SharedPreferences, v: RemoteViews, data: WidgetData?, size: Size) {
        val next = data?.next()
        val border = ContextCompat.getColor(context, R.color.kairos_surface_border)
        val primary = ContextCompat.getColor(context, R.color.kairos_text_primary)
        val tertiary = ContextCompat.getColor(context, R.color.kairos_text_tertiary)
        val urgentColor = ContextCompat.getColor(context, R.color.kairos_accent_urgent)
        val hasEyebrow = size != Size.SMALL
        val hasMascot = size != Size.SMALL

        if (data == null || next == null) {
            v.setInt(R.id.widget_accent, "setBackgroundColor", border)
            if (hasEyebrow) v.setTextViewText(R.id.widget_eyebrow, "")
            v.setTextViewText(R.id.widget_big, data?.s("noClassesToday") ?: "")
            v.setTextColor(R.id.widget_big, primary)
            if (hasEyebrow) {
                v.setViewVisibility(R.id.widget_countdown, View.GONE)
                v.setTextViewText(R.id.widget_meta, "")
            }
            v.setTextViewText(R.id.widget_title, "")
            v.setTextViewText(R.id.widget_arrive, "")
            if (hasMascot) mascot(context, prefs, v, "dormido", data?.quip("later"))
            if (size == Size.WIDE) v.setTextViewText(R.id.widget_after, "")
            return
        }

        val today = data.isToday(next)
        val urgent = data.isUrgent(next)
        val accent = if (urgent) urgentColor else WidgetData.subjectColor(context, next.color)
        v.setInt(R.id.widget_accent, "setBackgroundColor", accent)
        v.setTextViewText(R.id.widget_title, next.name)
        v.setTextViewText(R.id.widget_arrive, data.arrivalLine(next))

        if (today) {
            v.setTextViewText(R.id.widget_big, next.leaveLabel)
            v.setTextColor(R.id.widget_big, if (urgent) urgentColor else primary)
            if (hasEyebrow) {
                v.setTextViewText(R.id.widget_eyebrow, if (urgent) data.s("urgent") else data.s("leaveLabel"))
                v.setTextColor(R.id.widget_eyebrow, if (urgent) urgentColor else tertiary)
                val until = data.millisUntilLeave(next)
                if (!urgent && until > 0) {
                    v.setViewVisibility(R.id.widget_countdown, View.VISIBLE)
                    v.setChronometer(R.id.widget_countdown, SystemClock.elapsedRealtime() + until, data.s("countdown"), true)
                    v.setChronometerCountDown(R.id.widget_countdown, true)
                } else {
                    v.setViewVisibility(R.id.widget_countdown, View.GONE)
                }
                v.setTextViewText(
                    R.id.widget_meta,
                    listOfNotNull(next.room, "${next.startLabel}–${next.endLabel}").joinToString(" · "),
                )
            }
            if (hasMascot) {
                if (urgent) mascot(context, prefs, v, "rodando", data.quip("urgent"))
                else mascot(context, prefs, v, "reposo", data.quip("normal"))
            }
        } else {
            // Otro día. Antes decía «Sin clases hoy» aunque hoy hubiera habido
            // clases que ya terminaron: ahora dice cuándo es la próxima.
            val whenLabel = if (data.isTomorrow(next)) data.s("tomorrow") else String.format(data.s("onDay"), next.day)
            v.setTextViewText(R.id.widget_big, if (size == Size.SMALL) next.leaveLabel else next.startLabel)
            v.setTextColor(R.id.widget_big, primary)
            if (hasEyebrow) {
                v.setTextViewText(R.id.widget_eyebrow, whenLabel)
                v.setTextColor(R.id.widget_eyebrow, tertiary)
                v.setViewVisibility(R.id.widget_countdown, View.GONE)
                v.setTextViewText(
                    R.id.widget_meta,
                    listOfNotNull(next.room, "${data.s("leaveLabel")} ${next.leaveLabel}").joinToString(" · "),
                )
            }
            if (hasMascot) mascot(context, prefs, v, "dormido", data.quip("later"))
        }

        if (size == Size.WIDE) {
            val after = data.after(next)
            v.setTextViewText(
                R.id.widget_after,
                after?.let { String.format(data.s("afterThis"), it.name, it.startLabel) } ?: "",
            )
        }
    }

    private fun mascot(context: Context, prefs: SharedPreferences, v: RemoteViews, pose: String, quip: String?) {
        val bmp = WidgetData.mascot(context, prefs, pose)
        if (bmp != null) {
            v.setViewVisibility(R.id.widget_mascot, View.VISIBLE)
            v.setImageViewBitmap(R.id.widget_mascot, bmp)
        } else {
            v.setViewVisibility(R.id.widget_mascot, View.GONE)
        }
        v.setTextViewText(R.id.widget_quip, quip ?: "")
    }
}
