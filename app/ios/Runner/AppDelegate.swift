import Flutter
import GoogleMaps
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // I promemoria toccati, e quelli che arrivano con l'app aperta, passano
    // dal plugin delle notifiche (14-notifiche.md).
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    // La mappa di Google (ADR-014): la chiave legata all'app, scritta in
    // Info.plist da Flutter/Chiavi.xcconfig (tool/scrivi_chiavi.dart).
    if let chiave = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
      !chiave.isEmpty, !chiave.hasPrefix("$(")
    {
      GMSServices.provideAPIKey(chiave)
    }
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
