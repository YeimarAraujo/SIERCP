package com.example.siercp

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Práctica con gafas: abre SICAP VR y mantiene la sesión viva en segundo plano.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sicap/vr").setMethodCallHandler { call, result ->
            when (call.method) {
                "isInstalled" -> result.success(packageManager.getLaunchIntentForPackage(VR_PACKAGE) != null)
                "launch" -> {
                    val intent = packageManager.getLaunchIntentForPackage(VR_PACKAGE)
                    if (intent == null) {
                        result.success(false)
                    } else {
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    }
                }
                "keepAlive" -> {
                    val service = Intent(this, SessionKeepAliveService::class.java)
                    if (call.argument<Boolean>("on") == true) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(service) else startService(service)
                    } else {
                        stopService(service)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        const val VR_PACKAGE = "com.sicap.vr"
    }
}
