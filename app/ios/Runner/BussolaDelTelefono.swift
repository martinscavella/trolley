import CoreLocation
import Flutter
import UIKit

/// La bussola del telefono (CR-06, passo 4): dove punta l'iPhone, in gradi
/// dal nord, per il cono del puntino nella guida (tela, 163). Si accende
/// solo mentre qualcuno ascolta, e la direzione non lascia mai il telefono.
/// Il nord è quello vero quando il telefono sa dove si trova (il permesso
/// di posizione c'è già, per la guida), altrimenti quello magnetico.
final class BussolaDelTelefono: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {
  private let gestore = CLLocationManager()
  private var invia: FlutterEventSink?

  static func register(with registrar: FlutterPluginRegistrar) {
    let bussola = BussolaDelTelefono()
    let canale = FlutterEventChannel(
      name: "trolley/bussola",
      binaryMessenger: registrar.messenger()
    )
    canale.setStreamHandler(bussola)
    // Resta viva finché c'è l'app.
    tenuta = bussola
  }

  private static var tenuta: BussolaDelTelefono?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    guard CLLocationManager.headingAvailable() else { return nil }
    invia = events
    gestore.delegate = self
    // Meno di tre gradi non si vedono: non si manda niente.
    gestore.headingFilter = 3
    gestore.headingOrientation = .portrait
    gestore.startUpdatingHeading()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    gestore.stopUpdatingHeading()
    invia = nil
    return nil
  }

  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    let gradi = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    guard gradi >= 0 else { return }
    invia?(gradi)
  }

  // La taratura di iOS (l'otto col telefono) non si chiede: il cono è un
  // aiuto, non uno strumento.
  func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
    false
  }
}
