package com.matapps.nonetcom

import android.app.Application
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant

class NoNetComApplication : Application() {
    lateinit var flutterEngine: FlutterEngine
        private set
    private var dartStarted = false
    private var bleBridgeConfigured = false

    override fun onCreate() {
        super.onCreate()
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(this)
        loader.ensureInitializationComplete(this, null)
        flutterEngine = FlutterEngine(this)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        FlutterEngineCache.getInstance().put(engineId, flutterEngine)
    }

    fun ensureDartStarted() {
        if (dartStarted) return
        dartStarted = true
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault(),
        )
    }

    @Synchronized
    fun claimBleBridge(): Boolean {
        if (bleBridgeConfigured) return false
        bleBridgeConfigured = true
        return true
    }

    companion object {
        const val engineId = "nonetcom_background_engine"
    }
}
