package com.kairos.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StrikethroughSpan
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget «Tu día» (4×2, se estira a 4×4): las clases de hoy en filas, la que
 * sigue resaltada con su color, las canceladas tachadas y las ya pasadas
 * atenuadas. Cuatro filas fijas: RemoteViews no necesita una lista para eso.
 */
class TodayWidgetProvider : HomeWidgetProvider() {
    private val rows = intArrayOf(R.id.row_0, R.id.row_1, R.id.row_2, R.id.row_3)
    private val times = intArrayOf(R.id.row_0_time, R.id.row_1_time, R.id.row_2_time, R.id.row_3_time)
    private val names = intArrayOf(R.id.row_0_name, R.id.row_1_name, R.id.row_2_name, R.id.row_3_name)
    private val metas = intArrayOf(R.id.row_0_meta, R.id.row_1_meta, R.id.row_2_meta, R.id.row_3_meta)
    private val dots = intArrayOf(R.id.row_0_dot, R.id.row_1_dot, R.id.row_2_dot, R.id.row_3_dot)

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val data = WidgetData.read(widgetData)
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_today)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            bind(context, views, data)
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun bind(context: Context, v: RemoteViews, data: WidgetData?) {
        val primary = ContextCompat.getColor(context, R.color.kairos_text_primary)
        val secondary = ContextCompat.getColor(context, R.color.kairos_text_secondary)
        val tertiary = ContextCompat.getColor(context, R.color.kairos_text_tertiary)
        val border = ContextCompat.getColor(context, R.color.kairos_surface_border)

        v.setTextViewText(R.id.widget_header, data?.todayHeader ?: "")
        val list = data?.todayClasses().orEmpty()
        val next = data?.next()

        if (data == null || list.isEmpty()) {
            rows.forEach { v.setViewVisibility(it, View.GONE) }
            v.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            val upcoming = next?.let {
                String.format(data.s("nextUpDay"), it.day, it.startLabel, it.name)
            }
            v.setTextViewText(R.id.widget_empty, listOfNotNull(data?.s("noClassesToday"), upcoming).joinToString("\n"))
            v.setViewVisibility(R.id.widget_more, View.GONE)
            return
        }
        v.setViewVisibility(R.id.widget_empty, View.GONE)

        // Se enseñan las cuatro que más importan: desde la siguiente, si caben.
        // Sin siguiente hoy, las últimas del día, ya atenuadas.
        val nextIdx = list.indexOf(next)
        val start = if (nextIdx < 0) maxOf(0, list.size - rows.size) else minOf(nextIdx, maxOf(0, list.size - rows.size))
        val shown = list.drop(start).take(rows.size)

        for (i in rows.indices) {
            val c = shown.getOrNull(i)
            if (c == null) {
                v.setViewVisibility(rows[i], View.GONE)
                continue
            }
            v.setViewVisibility(rows[i], View.VISIBLE)
            val index = list.indexOf(c)
            val isNext = index == nextIdx
            val cancelled = c.status == "cancelled"
            val past = nextIdx < 0 || index < nextIdx
            v.setTextViewText(times[i], c.startLabel)
            // Tachado como en la app: RemoteViews no deja tocar el Paint, pero
            // sí pasar el texto con su span.
            v.setTextViewText(
                names[i],
                if (cancelled) SpannableString(c.name).apply {
                    setSpan(StrikethroughSpan(), 0, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                } else c.name,
            )
            v.setTextViewText(
                metas[i],
                when {
                    cancelled -> data.s("cancelled")
                    c.status == "attended" -> data.s("attended")
                    else -> c.room ?: c.endLabel
                },
            )
            v.setTextColor(names[i], if (cancelled || past) secondary else primary)
            v.setTextColor(times[i], if (isNext) primary else tertiary)
            v.setInt(dots[i], "setColorFilter", if (cancelled || past) border else WidgetData.subjectColor(context, c.color))
        }

        val hidden = list.size - shown.size
        if (hidden > 0) {
            v.setViewVisibility(R.id.widget_more, View.VISIBLE)
            v.setTextViewText(R.id.widget_more, String.format(data.s("more"), hidden))
        } else if (next == null) {
            v.setViewVisibility(R.id.widget_more, View.VISIBLE)
            v.setTextViewText(R.id.widget_more, data.s("noMore"))
        } else {
            v.setViewVisibility(R.id.widget_more, View.GONE)
        }
    }
}
