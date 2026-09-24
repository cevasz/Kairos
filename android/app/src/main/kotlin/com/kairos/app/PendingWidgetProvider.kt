package com.kairos.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.time.LocalDate

/**
 * Widget «Pendientes»: lo que falta por hacer en todas las actividades, de
 * lo más cercano a lo más lejano, con el color de su actividad.
 *
 *  - 2×2: cuatro filas, con cuándo;
 *  - 4×2: cinco filas, con actividad y cuándo;
 *  - 4×4: ocho filas y Erizógenes en el pie.
 *
 * Sin nada pendiente, solo el erizo con su frase: es la mejor noticia posible.
 */
class PendingWidgetProvider : HomeWidgetProvider() {
    private class Size(val rows: Int, val withSubject: Boolean, val withMascot: Boolean)

    private val small = Size(rows = 4, withSubject = false, withMascot = false)
    private val wide = Size(rows = 5, withSubject = true, withMascot = false)
    private val large = Size(rows = 8, withSubject = true, withMascot = true)

    private val rows = intArrayOf(
        R.id.prow_0, R.id.prow_1, R.id.prow_2, R.id.prow_3,
        R.id.prow_4, R.id.prow_5, R.id.prow_6, R.id.prow_7,
    )
    private val dots = intArrayOf(
        R.id.prow_0_dot, R.id.prow_1_dot, R.id.prow_2_dot, R.id.prow_3_dot,
        R.id.prow_4_dot, R.id.prow_5_dot, R.id.prow_6_dot, R.id.prow_7_dot,
    )
    private val titles = intArrayOf(
        R.id.prow_0_title, R.id.prow_1_title, R.id.prow_2_title, R.id.prow_3_title,
        R.id.prow_4_title, R.id.prow_5_title, R.id.prow_6_title, R.id.prow_7_title,
    )
    private val metas = intArrayOf(
        R.id.prow_0_meta, R.id.prow_1_meta, R.id.prow_2_meta, R.id.prow_3_meta,
        R.id.prow_4_meta, R.id.prow_5_meta, R.id.prow_6_meta, R.id.prow_7_meta,
    )

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
        fun views(size: Size) = RemoteViews(context.packageName, R.layout.widget_pending).also {
            it.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            bind(context, prefs, it, data, size)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return RemoteViews(
                mapOf(
                    SizeF(110f, 110f) to views(small),
                    SizeF(250f, 110f) to views(wide),
                    SizeF(250f, 250f) to views(large),
                ),
            )
        }
        val o = manager.getAppWidgetOptions(id)
        val w = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val h = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
        return views(
            when {
                w >= 250 && h >= 250 -> large
                w >= 250 -> wide
                else -> small
            },
        )
    }

    private fun bind(context: Context, prefs: SharedPreferences, v: RemoteViews, data: WidgetData?, size: Size) {
        val tertiary = ContextCompat.getColor(context, R.color.kairos_text_tertiary)
        val urgent = ContextCompat.getColor(context, R.color.kairos_accent_urgent)
        val attention = ContextCompat.getColor(context, R.color.kairos_accent_attention)
        val today = LocalDate.now().toString()
        val tomorrow = LocalDate.now().plusDays(1).toString()

        v.setTextViewText(R.id.pending_header, data?.s("pendingHeader") ?: "")
        val items = data?.pending.orEmpty()
        v.setTextViewText(
            R.id.pending_count,
            if (data == null || items.isEmpty()) "" else String.format(data.s("pendingCount"), data.pendingTotal),
        )

        val shown = items.take(size.rows)
        for (i in rows.indices) {
            val p = shown.getOrNull(i)
            if (p == null) {
                v.setViewVisibility(rows[i], View.GONE)
                continue
            }
            v.setViewVisibility(rows[i], View.VISIBLE)
            v.setInt(dots[i], "setColorFilter", WidgetData.subjectColor(context, p.color))
            v.setTextViewText(titles[i], p.title)
            val meta = listOf(
                if (size.withSubject) p.subject else "",
                p.whenLabel,
            ).filter { it.isNotEmpty() }.joinToString(" · ")
            v.setTextViewText(metas[i], meta)
            // Hoy en terracota, mañana en ámbar: lo demás en gris.
            v.setTextColor(
                metas[i],
                when (p.date) {
                    today -> urgent
                    tomorrow -> attention
                    else -> tertiary
                },
            )
        }

        // El erizo: siempre si no hay nada (es la noticia), y en el grande
        // con una frase de su repertorio.
        val empty = items.isEmpty()
        val showMascot = empty || size.withMascot
        v.setViewVisibility(R.id.widget_footer, if (showMascot) View.VISIBLE else View.GONE)
        if (showMascot && data != null) {
            val bmp = WidgetData.mascot(context, prefs, if (empty) "satisfecho" else "reposo")
            if (bmp != null) {
                v.setViewVisibility(R.id.widget_mascot, View.VISIBLE)
                v.setImageViewBitmap(R.id.widget_mascot, bmp)
            } else {
                v.setViewVisibility(R.id.widget_mascot, View.GONE)
            }
            v.setTextViewText(
                R.id.widget_quip,
                if (empty) data.quip("pendingEmpty") else data.quip("normal"),
            )
        }
    }
}
