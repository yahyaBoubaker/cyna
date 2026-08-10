package com.example.cyna_mobile

import com.it_nomads.fluttersecurestorage.FlutterSecureStoragePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (!flutterEngine.plugins.has(FlutterSecureStoragePlugin::class.java)) {
            flutterEngine.plugins.add(FlutterSecureStoragePlugin())
        }
    }
}
