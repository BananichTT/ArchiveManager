package com.example.archive_manager

import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    private val TAG = "ArchiveManager_Native"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.i(TAG, "onCreate: Activity started with intent: ${intent?.action}")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.i(TAG, "onNewIntent: Received new intent: ${intent.action}")
        // FlutterActivity usually handles this, but explicit call ensures plugins like receive_sharing_intent see it
        setIntent(intent)
    }
}
