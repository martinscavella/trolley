package com.aionlabs.trolley

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Il canale `trolley/documenti` (ADR-008), come AppDelegate su iOS.
        flutterEngine.plugins.add(DocumentiDelTelefono())
        // La bussola, per il cono del puntino nella guida.
        flutterEngine.plugins.add(BussolaDelTelefono())
    }
}
