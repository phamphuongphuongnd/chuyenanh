package com.phuong.pdfoffice

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var shortcutChannel: ShortcutChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shortcutChannel = ShortcutChannel(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        ).also { it.handleLaunchIntent(intent) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        shortcutChannel?.handleNewIntent(intent)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        shortcutChannel?.dispose()
        shortcutChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
