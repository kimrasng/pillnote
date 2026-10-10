package kr.kimrasng.pillnote.pillnote

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kr.kimrasng.pillnote/device_metadata")
            .setMethodCallHandler { call, result ->
                if (call.method != "getMetadata") {
                    result.notImplemented()
                } else {
                    @Suppress("DEPRECATION")
                    val info = packageManager.getPackageInfo(packageName, 0)
                    @Suppress("DEPRECATION")
                    val build = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
                    result.success(mapOf(
                        "model" to Build.MODEL,
                        "osVersion" to Build.VERSION.RELEASE,
                        "appVersion" to (info.versionName ?: ""),
                        "appBuild" to build.toString()
                    ))
                }
            }
    }
}
