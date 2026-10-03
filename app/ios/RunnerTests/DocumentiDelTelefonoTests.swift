import CoreGraphics
import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest

@testable import Runner

/// Il canale dei documenti (Runner/DocumentiDelTelefono.swift) provato dove
/// gira davvero. Su un iPhone sono la verifica che 03 chiede: che un documento
/// sia cifrato con il codice di sblocco e stia nel backup lo si controlla, non
/// lo si dà per scontato (docs/tecnico/03-documenti-sul-dispositivo.md).
final class DocumentiDelTelefonoTests: XCTestCase {
  private var cartella: URL!

  override func setUpWithError() throws {
    // Dove l'app tiene i documenti: Application Support.
    let supporto = try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    cartella = supporto.appendingPathComponent(
      "prove-\(UUID().uuidString)",
      isDirectory: true
    )
    try FileManager.default.createDirectory(at: cartella, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: cartella)
  }

  func testUnDocumentoProtettoECifratoConIlCodiceEStaNelBackup() throws {
    let file = cartella.appendingPathComponent("documento.pdf")
    try pdf(pagine: 1).write(to: file)

    let stato = try DocumentiDelTelefono.proteggi(file.path)

    #if targetEnvironment(simulator)
      // Il simulatore non ha la protezione dei dati: lo dice, e basta.
      print("Protezione sul simulatore: \(stato["protezione"] ?? "?")")
    #else
      XCTAssertEqual(stato["protezione"] as? String, "completa")
    #endif
    XCTAssertEqual(stato["nelBackup"] as? Bool, true)
    // Riletto da capo, è rimasto così.
    let riletto = try DocumentiDelTelefono.stato(file.path)
    XCTAssertEqual(riletto["protezione"] as? String, stato["protezione"] as? String)
    XCTAssertEqual(riletto["nelBackup"] as? Bool, true)
  }

  func testLePagineDiUnPdfSiDisegnanoSoloInMemoria() throws {
    let file = cartella.appendingPathComponent("tre.pdf")
    try pdf(pagine: 3).write(to: file)

    XCTAssertEqual(try DocumentiDelTelefono.documentoPdf(file.path).numberOfPages, 3)
    let png = try DocumentiDelTelefono.pagina(file.path, indice: 1, larghezza: 600)
    let immagine = try XCTUnwrap(UIImage(data: png.data)?.cgImage)
    XCTAssertEqual(immagine.width, 600)
    // Un A4 in verticale: più alto che largo.
    XCTAssertEqual(immagine.height, 849)
    // Accanto al documento non è stato scritto niente.
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: cartella.path), ["tre.pdf"])
    XCTAssertThrowsError(try DocumentiDelTelefono.pagina(file.path, indice: 3, larghezza: 600))
  }

  func testUnPdfConLaPasswordSiRiconosce() throws {
    let file = cartella.appendingPathComponent("protetto.pdf")
    let formato = UIGraphicsPDFRendererFormat()
    formato.documentInfo = [
      kCGPDFContextUserPassword as String: "segreta",
      kCGPDFContextOwnerPassword as String: "segreta",
    ]
    let dati = UIGraphicsPDFRenderer(
      bounds: CGRect(x: 0, y: 0, width: 595, height: 842),
      format: formato
    ).pdfData { $0.beginPage() }
    try dati.write(to: file)

    XCTAssertThrowsError(try DocumentiDelTelefono.documentoPdf(file.path)) { errore in
      XCTAssertEqual((errore as? ErroreDocumenti)?.codice, "pdf_protetto")
    }
  }

  func testUnaFotoGrandeSiRiduceInJpegSenzaIlLuogoDelloScatto() throws {
    let da = cartella.appendingPathComponent("foto.jpg")
    let a = cartella.appendingPathComponent("documento.jpg")
    try jpegConLuogo(larghezza: 4000, altezza: 3000).write(to: da)

    let risposta = try DocumentiDelTelefono.comprimi(
      da: da.path,
      a: a.path,
      lato: 2800,
      qualita: 0.85
    )

    XCTAssertEqual(risposta["larghezza"] as? Int, 2800)
    XCTAssertEqual(risposta["altezza"] as? Int, 2100)
    let sorgente = try XCTUnwrap(CGImageSourceCreateWithURL(a as CFURL, nil))
    XCTAssertEqual(CGImageSourceGetType(sorgente) as String?, UTType.jpeg.identifier)
    let proprieta = CGImageSourceCopyPropertiesAtIndex(sorgente, 0, nil) as? [CFString: Any]
    XCTAssertNil(proprieta?[kCGImagePropertyGPSDictionary])
  }

  func testUnaFotoPiccolaNonSiIngrandisce() throws {
    let da = cartella.appendingPathComponent("piccola.jpg")
    let a = cartella.appendingPathComponent("documento.jpg")
    try jpegConLuogo(larghezza: 800, altezza: 600).write(to: da)

    let risposta = try DocumentiDelTelefono.comprimi(
      da: da.path,
      a: a.path,
      lato: 2800,
      qualita: 0.85
    )

    XCTAssertEqual(risposta["larghezza"] as? Int, 800)
    XCTAssertEqual(risposta["altezza"] as? Int, 600)
  }

  func testUnFileCheNonEUnImmagineSiRiconosce() throws {
    let da = cartella.appendingPathComponent("non-una-foto.jpg")
    try Data("non sono una foto".utf8).write(to: da)

    XCTAssertThrowsError(
      try DocumentiDelTelefono.comprimi(
        da: da.path,
        a: cartella.appendingPathComponent("x.jpg").path,
        lato: 2800,
        qualita: 0.85
      )
    ) { errore in
      XCTAssertEqual((errore as? ErroreDocumenti)?.codice, "immagine_illeggibile")
    }
  }

  // ─── Aiuti ───────────────────────────────────────────────────────────────

  /// Un PDF A4 di [pagine] pagine, con il numero scritto su ognuna.
  private func pdf(pagine: Int) -> Data {
    UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842)).pdfData {
      contesto in
      for i in 0..<pagine {
        contesto.beginPage()
        ("Pagina \(i + 1)" as NSString).draw(
          at: CGPoint(x: 72, y: 72),
          withAttributes: [.font: UIFont.systemFont(ofSize: 24)]
        )
      }
    }
  }

  /// Una foto blu con il luogo dello scatto nei metadati, come quelle del
  /// telefono.
  private func jpegConLuogo(larghezza: Int, altezza: Int) throws -> Data {
    let formato = UIGraphicsImageRendererFormat()
    formato.scale = 1
    let immagine = UIGraphicsImageRenderer(
      size: CGSize(width: larghezza, height: altezza),
      format: formato
    ).image { contesto in
      UIColor.systemBlue.setFill()
      contesto.fill(CGRect(x: 0, y: 0, width: larghezza, height: altezza))
    }
    let dati = NSMutableData()
    let destinazione = try XCTUnwrap(
      CGImageDestinationCreateWithData(dati, UTType.jpeg.identifier as CFString, 1, nil)
    )
    let luogo: [CFString: Any] = [
      kCGImagePropertyGPSLatitude: 41.1496,
      kCGImagePropertyGPSLatitudeRef: "N",
      kCGImagePropertyGPSLongitude: 8.6109,
      kCGImagePropertyGPSLongitudeRef: "W",
    ]
    CGImageDestinationAddImage(
      destinazione,
      try XCTUnwrap(immagine.cgImage),
      [kCGImagePropertyGPSDictionary: luogo] as CFDictionary
    )
    XCTAssertTrue(CGImageDestinationFinalize(destinazione))
    // Prima della compressione il luogo c'è davvero.
    let sorgente = try XCTUnwrap(CGImageSourceCreateWithData(dati, nil))
    let proprieta = CGImageSourceCopyPropertiesAtIndex(sorgente, 0, nil) as? [CFString: Any]
    XCTAssertNotNil(proprieta?[kCGImagePropertyGPSDictionary])
    return dati as Data
  }
}
