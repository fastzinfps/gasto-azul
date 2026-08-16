package com.gastoazul.gasto_azul

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity : FlutterActivity() {
    private val methodsChannel = "gasto_azul/notification_methods"
    private val eventsChannel = "gasto_azul/notification_events"
    private val prefsName = "gasto_azul_notifications"
    private val pendingKey = "pending"

    private var eventSink: EventChannel.EventSink? = null

    private val notificationReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != BankNotificationListener.ACTION_BANK_NOTIFICATION) return
            eventSink?.success(
                mapOf(
                    "title" to intent.getStringExtra(BankNotificationListener.EXTRA_TITLE).orEmpty(),
                    "text" to intent.getStringExtra(BankNotificationListener.EXTRA_TEXT).orEmpty(),
                    "packageName" to intent.getStringExtra(BankNotificationListener.EXTRA_PACKAGE).orEmpty(),
                    "postTime" to intent.getLongExtra(BankNotificationListener.EXTRA_POST_TIME, 0L),
                )
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openNotificationAccessSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("SETTINGS_ERROR", e.message, null)
                        }
                    }

                    "getPendingNotifications" -> {
                        result.success(readAndClearPending())
                    }

                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventsChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val filter = IntentFilter(BankNotificationListener.ACTION_BANK_NOTIFICATION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(notificationReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(notificationReceiver, filter)
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(notificationReceiver)
        } catch (_: Exception) {
        }
        super.onDestroy()
    }

    private fun readAndClearPending(): List<Map<String, Any>> {
        val prefs = getSharedPreferences(prefsName, MODE_PRIVATE)
        val raw = prefs.getString(pendingKey, "[]") ?: "[]"
        val result = mutableListOf<Map<String, Any>>()

        try {
            val array = JSONArray(raw)
            for (i in 0 until array.length()) {
                val item = array.getJSONObject(i)
                result.add(
                    mapOf(
                        "title" to item.optString("title"),
                        "text" to item.optString("text"),
                        "packageName" to item.optString("packageName"),
                        "postTime" to item.optLong("postTime"),
                    )
                )
            }
        } catch (_: Exception) {
        }

        prefs.edit().putString(pendingKey, "[]").apply()
        return result
    }
}
