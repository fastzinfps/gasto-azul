package com.gastoazul.gasto_azul

import android.app.Notification
import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

class BankNotificationListener : NotificationListenerService() {
    companion object {
        const val ACTION_BANK_NOTIFICATION = "com.gastoazul.gasto_azul.BANK_NOTIFICATION"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_PACKAGE = "packageName"
        const val EXTRA_POST_TIME = "postTime"

        private const val PREFS = "gasto_azul_notifications"
        private const val KEY_PENDING = "pending"
        private const val MAX_PENDING = 20
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
        val packageName = sbn.packageName.orEmpty()

        if (!looksLikeSupportedBank(packageName, title, text)) return

        val payload = JSONObject().apply {
            put("title", title)
            put("text", text)
            put("packageName", packageName)
            put("postTime", sbn.postTime)
        }

        cache(payload)

        val intent = Intent(ACTION_BANK_NOTIFICATION).apply {
            setPackage(applicationContext.packageName)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_TEXT, text)
            putExtra(EXTRA_PACKAGE, packageName)
            putExtra(EXTRA_POST_TIME, sbn.postTime)
        }
        sendBroadcast(intent)
    }

    private fun looksLikeSupportedBank(packageName: String, title: String, text: String): Boolean {
        val combined = "$packageName $title $text".lowercase()
        val supportedBank = combined.contains("picpay") ||
            combined.contains("banco do brasil") ||
            packageName.lowercase().contains("br.com.bb")

        val looksFinancial = combined.contains("pix") ||
            combined.contains("r$") ||
            combined.contains("compra") ||
            combined.contains("pagamento")

        return supportedBank && looksFinancial
    }

    private fun cache(payload: JSONObject) {
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        val existing = try {
            JSONArray(prefs.getString(KEY_PENDING, "[]") ?: "[]")
        } catch (_: Exception) {
            JSONArray()
        }

        val updated = JSONArray()
        val start = maxOf(0, existing.length() - (MAX_PENDING - 1))
        for (i in start until existing.length()) {
            updated.put(existing.get(i))
        }
        updated.put(payload)

        prefs.edit().putString(KEY_PENDING, updated.toString()).apply()
    }
}
