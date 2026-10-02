package com.autozoom.autozoom

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.autozoom/autojoin")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "sync" -> {
                            val items = (call.argument<List<*>>("items") ?: emptyList<Any>()).map {
                                val m = it as Map<*, *>
                                JSONObject()
                                    .put("id", (m["id"] as Number).toInt())
                                    .put("timeMillis", (m["timeMillis"] as Number).toLong())
                                    .put("uri", m["uri"] as String)
                                    .put("fallbackUri", m["fallbackUri"] as String?)
                                    .put("title", (m["title"] as String?) ?: "")
                            }
                            AutoJoinScheduler.sync(this, items)
                            result.success(null)
                        }
                        "cancel" -> {
                            AutoJoinScheduler.cancel(this, call.argument<Number>("id")!!.toInt())
                            result.success(null)
                        }
                        "getPermissionStatus" -> result.success(AutoJoinScheduler.permissionStatus(this))
                        "requestOverlayPermission" -> {
                            if (Build.VERSION.SDK_INT >= 23) {
                                startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
                            }
                            result.success(null)
                        }
                        "requestFullScreenPermission" -> {
                            if (Build.VERSION.SDK_INT >= 34) {
                                startActivity(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:$packageName")))
                            }
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("autojoin_error", e.message, null)
                }
            }
    }
}
