package com.phuong.pdfoffice

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// FragmentActivity: local_auth (khoa app) can BiometricPrompt.
class MainActivity : FlutterFragmentActivity() {
    private var shortcutChannel: ShortcutChannel? = null
    private var incomingFilesChannel: IncomingFilesChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        // Kenh "mo file tu app khac" chup URI cua intent truoc: ShortcutChannel.takeInitialPath
        // doi action intent thanh MAIN.
        incomingFilesChannel = IncomingFilesChannel(applicationContext, messenger)
            .also { it.handleLaunchIntent(intent) }
        shortcutChannel = ShortcutChannel(applicationContext, messenger)
            .also { it.handleLaunchIntent(intent) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Thu tu: loi tat truoc (chi xu ly OPEN_PDF), roi file tu app khac (VIEW/SEND...).
        shortcutChannel?.handleNewIntent(intent)
        incomingFilesChannel?.handleNewIntent(intent)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        shortcutChannel?.dispose()
        shortcutChannel = null
        incomingFilesChannel?.dispose()
        incomingFilesChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
