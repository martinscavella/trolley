import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // I documenti sul telefono: protezione, pagine dei PDF, foto (ADR-008).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DocumentiDelTelefono") {
      DocumentiDelTelefono.register(with: registrar)
    }
  }
}
