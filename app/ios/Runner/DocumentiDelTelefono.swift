import CoreGraphics
import Flutter
import ImageIO
import LocalAuthentication
import UIKit
import UniformTypeIdentifiers

/// I documenti sul telefono (docs/tecnico/03-documenti-sul-dispositivo.md, ADR-008):
/// le cose che Dart da solo non sa fare.
///
/// - proteggere un file con la classe di protezione più forte, e dire com'è
///   rimasto: cifrato finché il telefono è bloccato, e dentro il backup;
/// - disegnare una pagina di un PDF **in memoria**, senza scriverla da nessuna
///   parte: niente anteprime fuori dal documento, nemmeno in una cache;
/// - comprimere una foto in JPEG, raddrizzata e senza i metadati (il luogo dello
///   scatto compreso);
/// - dire se il telefono ha un codice di sblocco, senza il quale la cifratura
///   non lega niente.
///
/// Nessun metodo apre una connessione o passa un file a un'altra app.
final class DocumentiDelTelefono: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let canale = FlutterMethodChannel(
      name: "trolley/documenti",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(DocumentiDelTelefono(), channel: canale)
  }

  /// Il lavoro sui file si fa fuori dal thread principale, una cosa alla volta.
  private let coda = DispatchQueue(label: "trolley.documenti", qos: .userInitiated)

  /// Il lato massimo in pixel di una pagina disegnata, e quanti pixel in tutto:
  /// una ricevuta lunghissima non deve finire la memoria.
  private static let latoMassimo = 4000
  private static let pixelMassimi = 16_000_000

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let argomenti = call.arguments as? [String: Any] ?? [:]
    coda.async {
      let risposta: Any?
      do {
        switch call.method {
        case "proteggi":
          risposta = try Self.proteggi(try Self.testo(argomenti, "percorso"))
        case "stato":
          risposta = try Self.stato(try Self.testo(argomenti, "percorso"))
        case "pagine":
          risposta = try Self.documentoPdf(try Self.testo(argomenti, "percorso")).numberOfPages
        case "pagina":
          risposta = try Self.pagina(
            try Self.testo(argomenti, "percorso"),
            indice: try Self.numero(argomenti, "indice"),
            larghezza: try Self.numero(argomenti, "larghezza")
          )
        case "comprimi":
          risposta = try Self.comprimi(
            da: try Self.testo(argomenti, "da"),
            a: try Self.testo(argomenti, "a"),
            lato: try Self.numero(argomenti, "lato"),
            qualita: argomenti["qualita"] as? Double ?? 0.85
          )
        case "codiceDiSblocco":
          risposta = LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        default:
          risposta = FlutterMethodNotImplemented
        }
      } catch let errore as ErroreDocumenti {
        risposta = FlutterError(code: errore.codice, message: errore.messaggio, details: nil)
      } catch {
        let ns = error as NSError
        // Lo spazio finito ha un codice suo: Dart lo traduce in una frase.
        let pieno = ns.domain == NSCocoaErrorDomain && ns.code == NSFileWriteOutOfSpaceError
        risposta = FlutterError(
          code: pieno ? "spazio_finito" : "errore",
          message: ns.localizedDescription,
          details: nil
        )
      }
      DispatchQueue.main.async { result(risposta) }
    }
  }

  // ─── Protezione ────────────────────────────────────────────────────────────

  /// Cifrato con il codice di sblocco e illeggibile a telefono bloccato
  /// (`complete`); nel backup di sistema, così il telefono nuovo lo ritrova.
  static func proteggi(_ percorso: String) throws -> [String: Any] {
    try FileManager.default.setAttributes(
      [.protectionKey: FileProtectionType.complete],
      ofItemAtPath: percorso
    )
    var url = URL(fileURLWithPath: percorso)
    var valori = URLResourceValues()
    valori.isExcludedFromBackup = false
    try url.setResourceValues(valori)
    return try stato(percorso)
  }

  /// Com'è un file adesso: la sua classe di protezione e se va nel backup.
  static func stato(_ percorso: String) throws -> [String: Any] {
    let attributi = try FileManager.default.attributesOfItem(atPath: percorso)
    let protezione = (attributi[.protectionKey] as? FileProtectionType)?.rawValue
    let url = URL(fileURLWithPath: percorso)
    let escluso = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
      .isExcludedFromBackup ?? false
    return [
      "protezione": protezione.map(nomeProtezione) ?? "nessuna",
      "nelBackup": !escluso,
    ]
  }

  private static func nomeProtezione(_ grezzo: String) -> String {
    switch FileProtectionType(rawValue: grezzo) {
    case .complete: return "completa"
    case .completeUnlessOpen: return "salvo_se_aperto"
    case .completeUntilFirstUserAuthentication: return "dopo_il_primo_sblocco"
    case .none: return "nessuna"
    default: return grezzo
    }
  }

  // ─── PDF ───────────────────────────────────────────────────────────────────

  static func documentoPdf(_ percorso: String) throws -> CGPDFDocument {
    guard let documento = CGPDFDocument(URL(fileURLWithPath: percorso) as CFURL) else {
      throw ErroreDocumenti("pdf_illeggibile", "Il file non è un PDF leggibile.")
    }
    // Un PDF con la password vuota si apre da solo; con una password vera no.
    if documento.isEncrypted && !documento.isUnlocked && !documento.unlockWithPassword("") {
      throw ErroreDocumenti("pdf_protetto", "Il PDF è protetto da una password.")
    }
    return documento
  }

  /// La pagina [indice] (da 0) larga [larghezza] pixel, in PNG. Resta in
  /// memoria: la riceve Dart, e nessuno la scrive su disco.
  static func pagina(_ percorso: String, indice: Int, larghezza: Int) throws
    -> FlutterStandardTypedData
  {
    let documento = try documentoPdf(percorso)
    guard indice >= 0, let pagina = documento.page(at: indice + 1) else {
      throw ErroreDocumenti("pagina_assente", "Il PDF non ha questa pagina.")
    }
    let riquadro = pagina.getBoxRect(.cropBox)
    let girata = pagina.rotationAngle % 180 != 0
    let (w, h) = girata
      ? (riquadro.height, riquadro.width)
      : (riquadro.width, riquadro.height)
    guard w > 0, h > 0 else {
      throw ErroreDocumenti("pagina_vuota", "La pagina non ha dimensioni.")
    }
    var scala = CGFloat(min(max(larghezza, 1), latoMassimo)) / w
    if w * scala * h * scala > CGFloat(pixelMassimi) {
      scala = (CGFloat(pixelMassimi) / (w * h)).squareRoot()
    }
    let dimensione = CGSize(width: (w * scala).rounded(), height: (h * scala).rounded())

    let formato = UIGraphicsImageRendererFormat()
    formato.scale = 1
    formato.opaque = true
    let immagine = UIGraphicsImageRenderer(size: dimensione, format: formato).image { tela in
      let c = tela.cgContext
      c.setFillColor(UIColor.white.cgColor)
      c.fill(CGRect(origin: .zero, size: dimensione))
      c.interpolationQuality = .high
      // Il PDF ha l'origine in basso: si capovolge e si ingrandisce a mano,
      // perché getDrawingTransform non ingrandisce mai oltre la misura naturale.
      c.translateBy(x: 0, y: dimensione.height)
      c.scaleBy(x: scala, y: -scala)
      c.concatenate(
        pagina.getDrawingTransform(
          .cropBox,
          rect: CGRect(x: 0, y: 0, width: w, height: h),
          rotate: 0,
          preserveAspectRatio: true
        )
      )
      c.drawPDFPage(pagina)
    }
    guard let png = immagine.pngData() else {
      throw ErroreDocumenti("pagina_vuota", "La pagina non si è potuta disegnare.")
    }
    return FlutterStandardTypedData(bytes: png)
  }

  // ─── Foto ──────────────────────────────────────────────────────────────────

  /// Da qualunque immagine (HEIC, PNG, JPEG) a un JPEG con il lato lungo al più
  /// [lato] pixel, raddrizzato secondo l'EXIF e senza metadati. Scrive in [a].
  static func comprimi(da: String, a: String, lato: Int, qualita: Double) throws
    -> [String: Any]
  {
    guard
      let sorgente = CGImageSourceCreateWithURL(URL(fileURLWithPath: da) as CFURL, nil)
    else {
      throw ErroreDocumenti("immagine_illeggibile", "Il file non è un'immagine leggibile.")
    }
    let opzioni: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: lato,
    ]
    guard
      let ridotta = CGImageSourceCreateThumbnailAtIndex(sorgente, 0, opzioni as CFDictionary)
    else {
      throw ErroreDocumenti("immagine_illeggibile", "Il file non è un'immagine leggibile.")
    }
    let immagine = suFondoBianco(ridotta)
    guard
      let destinazione = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: a) as CFURL,
        UTType.jpeg.identifier as CFString,
        1,
        nil
      )
    else {
      throw ErroreDocumenti("errore", "Non si è potuto scrivere il documento.")
    }
    CGImageDestinationAddImage(
      destinazione,
      immagine,
      [kCGImageDestinationLossyCompressionQuality: qualita] as CFDictionary
    )
    guard CGImageDestinationFinalize(destinazione) else {
      throw ErroreDocumenti("errore", "Non si è potuto scrivere il documento.")
    }
    return ["larghezza": immagine.width, "altezza": immagine.height]
  }

  /// Il JPEG non ha la trasparenza: quello che è trasparente diventa bianco,
  /// come la carta, invece che nero.
  private static func suFondoBianco(_ immagine: CGImage) -> CGImage {
    switch immagine.alphaInfo {
    case .none, .noneSkipFirst, .noneSkipLast:
      return immagine
    default:
      break
    }
    let riquadro = CGRect(x: 0, y: 0, width: immagine.width, height: immagine.height)
    guard
      let c = CGContext(
        data: nil,
        width: immagine.width,
        height: immagine.height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
      )
    else { return immagine }
    c.setFillColor(UIColor.white.cgColor)
    c.fill(riquadro)
    c.draw(immagine, in: riquadro)
    return c.makeImage() ?? immagine
  }

  // ─── Argomenti ─────────────────────────────────────────────────────────────

  private static func testo(_ argomenti: [String: Any], _ chiave: String) throws -> String {
    guard let valore = argomenti[chiave] as? String, !valore.isEmpty else {
      throw ErroreDocumenti("argomenti", "Manca \(chiave).")
    }
    return valore
  }

  private static func numero(_ argomenti: [String: Any], _ chiave: String) throws -> Int {
    guard let valore = argomenti[chiave] as? Int else {
      throw ErroreDocumenti("argomenti", "Manca \(chiave).")
    }
    return valore
  }
}

/// Un errore con un codice che Dart riconosce (dati/file_del_telefono.dart).
struct ErroreDocumenti: Error {
  let codice: String
  let messaggio: String

  init(_ codice: String, _ messaggio: String) {
    self.codice = codice
    self.messaggio = messaggio
  }
}
