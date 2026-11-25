# ADR-008 — Documenti sul telefono: dove, come si proteggono, come si leggono

**Stato**: accettata (fase 1.3, 3 ottobre 2026). Android scritto e compilato il 25 novembre 2026, non ancora provato su un telefono (vedi «Android» sotto).

## Contesto

Il capitolo [03](../03-documenti-sul-dispositivo.md) chiede che i documenti non lascino mai il telefono, che stiano nel backup di sistema, che siano cifrati con il codice di sblocco, che non ne restino copie o anteprime fuori dal documento, e che queste proprietà siano **verificate** invece che date per scontate. Servono tre cose che Flutter da solo non fa: acquisire (scansione, foto, file), mostrare un PDF, impostare e leggere la protezione di un file.

## Decisione

**Dove.** In `Application Support/documenti/<viaggio>/<documento>.pdf|jpg`, non in `Documents/`: entra nel backup allo stesso modo, ma non è mai esposta nell'app File. Il database locale tiene solo l'indice (tabella `documento`, vedi [01](../01-modello-dati.md)) con il **percorso relativo**.

**Come si scrive.** Il file si copia (o si comprime) in un `.parziale`, si rinomina, si protegge, si controlla la protezione, e solo allora entra la riga. Qualunque errore lascia né file né riga; i `.parziale` rimasti si buttano all'avvio.

**Come si protegge.** Ogni file prende `FileProtectionType.complete`: cifrato con il codice di sblocco e illeggibile a telefono bloccato, più forte del predefinito. Il canale lo rilegge e Dart **rifiuta di salvare** se non è `completa` e dentro il backup. Se il telefono non ha un codice, l'elenco lo dice.

**Il canale nativo** `trolley/documenti` (`ios/Runner/DocumentiDelTelefono.swift`) fa quattro cose: protegge e rilegge lo stato di un file; conta e disegna le pagine di un PDF con CoreGraphics, **in memoria** (PNG restituito a Dart, mai scritto); comprime un'immagine in JPEG col lato lungo al più 2800 px, raddrizzata e senza metadati (il luogo dello scatto compreso); dice se c'è un codice di sblocco.

**L'acquisizione** sta dietro un'interfaccia (`lib/dati/acquisizione.dart`):
- scansione: `cunning_document_scanner`, con la fotocamera documenti di iOS; le pagine diventano un PDF. Scrive in `Library/Caches` dell'app, mai nel rullino;
- foto e file: `file_picker` (selettore foto di sistema, senza permesso; selettore dei file). Copie in `tmp/` dell'app.
Le copie temporanee si buttano a ogni foglio chiuso.

**Scartato `pdfx`**: su iOS scrive ogni pagina disegnata in `Documents/pdf_renderer_cache/` prima di passarla a Dart. Per un passaporto è proprio la copia che 03 vieta, e per di più dentro il backup.

## Come si verifica

- `test/documenti_restano_qui_test.dart`: su Android il backup su Google tiene fuori proprio `documenti`, e il canale controlla quella cartella; i gesti senza rete sono i quattro; i file dei documenti importano solo da un elenco ammesso (niente rete); nessun file che parla col server importa i documenti; nessuno usa l'archivio di file di Supabase; nessuna migrazione crea un posto dove metterli.
- `test/dati/documenti_test.dart`: scrittura tutto o niente, disco pieno, PDF con password, protezione rifiutata, percorsi che reggono un contenitore spostato, eliminazione del file.
- `ios/RunnerTests/DocumentiDelTelefonoTests.swift`, **sull'iPhone vero** (`xcodebuild test … -destination 'platform=iOS,id=<UDID>' DEVELOPMENT_TEAM=KW7AX44FUN -allowProvisioningUpdates`): protezione `completa` e nel backup, pagine disegnate senza scrivere niente, foto ridotta e senza luogo. Passate il 3 ottobre 2026 su iPhone 18 Pro, iOS 27.0.1. Sul simulatore la protezione non esiste: lì non si verifica.

## Android (25 novembre 2026)

Lo stesso canale in `android/app/src/main/kotlin/com/aionlabs/trolley/DocumentiDelTelefono.kt`, registrato in `MainActivity`, con gli stessi metodi e gli stessi codici d'errore. Cambia quello che Android ha:

**Dove.** `getApplicationSupportDirectory` su Android è `files/`: i documenti stanno in `files/documenti/<viaggio>/`, memoria privata dell'app.

**Come si protegge.** Android non ha una classe di protezione per file. Cifra tutta la memoria dell'app con le chiavi di chi usa il telefono (FBE, obbligatoria da Android 10): un file è cifrato con il codice di sblocco e si legge dal primo sblocco dopo l'accensione fino allo spegnimento. È `dopo_il_primo_sblocco`, la classe predefinita di iOS: meno di `complete`, ma quello che il capitolo 03 chiede (cifrato a riposo e legato al codice di sblocco). Il canale non imposta niente: controlla che la cifratura ci sia (`DevicePolicyManager`, per utente o di tutto il disco, mai con la chiave predefinita) e che il file stia nella memoria legata alle credenziali, dentro `files/documenti`. Dart rifiuta il documento se non è così.

**Il backup.** Il backup su Google si ferma a 25 MB per app, e oltre non salva più niente, nemmeno il resto: bastano pochi passaporti. Quindi i documenti ne restano **fuori** (`res/xml/data_extraction_rules.xml` da Android 12, `res/xml/backup_rules.xml` prima), e il backup si fa solo se è cifrato sul telefono. Le regole sostituiscono quelle dello scanner (`tools:replace` nel manifesto), e ne tengono l'esclusione delle scansioni a metà (`external/Pictures`). Il passaggio da telefono a telefono non ha quel limite e non ha regole: da Android 12 porta i documenti. Il canale risponde `nelBackup: false`, e su Android è quello che Dart vuole; una prova controlla che le regole tengano fuori proprio la cartella dei documenti. Il foglio di un documento nuovo lo dice: «Il backup su Google non lo porta: sul telefono nuovo arriva solo se ci copi i dati da questo.»

**PDF e foto.** Le pagine con `PdfRenderer`, su una bitmap con il fondo bianco, in PNG in memoria. Un PDF con la password non si apre (prima di Android 15 il lettore non ne accetta nessuna): `pdf_protetto`. Le foto con `ImageDecoder` (Android 9 e successivi: legge HEIC e raddrizza da solo), con `BitmapFactory` ed EXIF a mano su Android 7 e 8; il JPEG che Android scrive non ha metadati. Il JPEG si prepara in memoria e si scrive in un colpo, così il disco pieno arriva come `ENOSPC` e diventa `spazio_finito`.

**Scartato**: cifrare ogni file con una chiave del Keystore che vuole il telefono sbloccato (`setUnlockedDeviceRequired`). Darebbe la protezione di `complete`, ma la chiave non lascia il telefono: sul telefono nuovo i documenti arriverebbero illeggibili. E Dart non potrebbe più leggere il file da solo.

## Conseguenze

- Su Android un documento si legge anche a telefono bloccato, dopo il primo sblocco: è meno che su iOS, ed è scritto nei [punti aperti](../../punti-aperti.md).
- Su Android i documenti passano al telefono nuovo solo con il passaggio da telefono a telefono, e solo da Android 12. Se si perde il telefono, si perdono: lo stesso di un iPhone senza backup.
- Le prove sul telefono Android, l'equivalente di `ios/RunnerTests`, non ci sono ancora.
- Due plugin in più da tenere aggiornati; il resto è codice nostro, piccolo e provato.
