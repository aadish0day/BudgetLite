package com.budgetlite.budget_lite

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var smsService: SmsService? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        smsService = SmsService(this, flutterEngine)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        smsService?.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onDestroy() {
        smsService?.destroy()
        smsService = null
        super.onDestroy()
    }
}
