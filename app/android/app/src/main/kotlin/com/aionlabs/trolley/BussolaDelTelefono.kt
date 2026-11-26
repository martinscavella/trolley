package com.aionlabs.trolley

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel

/**
 * La bussola del telefono (CR-06, passo 4): dove punta, in gradi dal nord
 * magnetico, per il cono del puntino nella guida (tela, 163). Si accende
 * solo mentre qualcuno ascolta, e la direzione non lascia mai il telefono.
 * Mai provata su un telefono Android.
 */
class BussolaDelTelefono : FlutterPlugin, EventChannel.StreamHandler, SensorEventListener {
    private lateinit var canale: EventChannel
    private var sensori: SensorManager? = null
    private var invia: EventChannel.EventSink? = null
    private var ultima = -1000.0

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        sensori = binding.applicationContext.getSystemService(Context.SENSOR_SERVICE) as SensorManager?
        canale = EventChannel(binding.binaryMessenger, "trolley/bussola")
        canale.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        canale.setStreamHandler(null)
        onCancel(null)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        val sensore = sensori?.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR) ?: return
        invia = events
        sensori?.registerListener(this, sensore, SensorManager.SENSOR_DELAY_UI)
    }

    override fun onCancel(arguments: Any?) {
        sensori?.unregisterListener(this)
        invia = null
    }

    override fun onSensorChanged(event: SensorEvent) {
        val rotazione = FloatArray(9)
        SensorManager.getRotationMatrixFromVector(rotazione, event.values)
        val orientamento = FloatArray(3)
        SensorManager.getOrientation(rotazione, orientamento)
        val gradi = (Math.toDegrees(orientamento[0].toDouble()) + 360) % 360
        // Meno di tre gradi non si vedono: non si manda niente.
        val scarto = Math.abs(((gradi - ultima + 540) % 360) - 180)
        if (scarto < 3) return
        ultima = gradi
        invia?.success(gradi)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}
