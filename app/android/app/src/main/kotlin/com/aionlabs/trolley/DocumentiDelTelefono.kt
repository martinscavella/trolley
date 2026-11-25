package com.aionlabs.trolley

import android.app.KeyguardManager
import android.app.admin.DevicePolicyManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.pdf.PdfRenderer
import android.media.ExifInterface
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.system.ErrnoException
import android.system.OsConstants
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * I documenti sul telefono (docs/tecnico/03-documenti-sul-dispositivo.md, ADR-008):
 * le cose che Dart da solo non sa fare. È la stessa cosa di
 * `ios/Runner/DocumentiDelTelefono.swift`, con quello che Android ha.
 *
 * - dire com'è protetto un file: Android non ha una protezione per file come
 *   iOS, ma cifra tutta la memoria dell'app con le chiavi della persona
 *   (cifratura per file, FBE). Il file è cifrato con il codice di sblocco e si
 *   apre dal primo sblocco dopo l'accensione: è `dopo_il_primo_sblocco`, la
 *   classe predefinita di iOS. Il backup su Google non li porta (25 MB per
 *   app): lo decidono `res/xml/data_extraction_rules.xml` e
 *   `res/xml/backup_rules.xml`;
 * - disegnare una pagina di un PDF **in memoria**, senza scriverla da nessuna
 *   parte: niente anteprime fuori dal documento, nemmeno in una cache;
 * - comprimere una foto in JPEG, raddrizzata e senza i metadati (il luogo dello
 *   scatto compreso);
 * - dire se il telefono ha un codice di sblocco, senza il quale la cifratura
 *   non lega niente.
 *
 * Nessun metodo apre una connessione o passa un file a un'altra app.
 */
class DocumentiDelTelefono : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var canale: MethodChannel
    private lateinit var contesto: Context

    /** Il lavoro sui file si fa fuori dal thread principale, una cosa alla volta. */
    private val coda: ExecutorService = Executors.newSingleThreadExecutor()
    private val principale = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        contesto = binding.applicationContext
        canale = MethodChannel(binding.binaryMessenger, "trolley/documenti")
        canale.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        canale.setMethodCallHandler(null)
        coda.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        coda.execute {
            val risposta: Any? = try {
                when (call.method) {
                    "proteggi" -> proteggi(testo(call, "percorso"))
                    "stato" -> stato(testo(call, "percorso"))
                    "pagine" -> conPdf(testo(call, "percorso")) { it.pageCount }
                    "pagina" -> pagina(
                        testo(call, "percorso"),
                        indice = numero(call, "indice"),
                        larghezza = numero(call, "larghezza"),
                    )
                    "comprimi" -> comprimi(
                        da = testo(call, "da"),
                        a = testo(call, "a"),
                        lato = numero(call, "lato"),
                        qualita = (call.argument<Any>("qualita") as? Number)?.toDouble() ?: 0.85,
                    )
                    "codiceDiSblocco" -> codiceDiSblocco()
                    else -> {
                        principale.post { result.notImplemented() }
                        return@execute
                    }
                }
            } catch (errore: ErroreDocumenti) {
                principale.post { result.error(errore.codice, errore.messaggio, null) }
                return@execute
            } catch (errore: Throwable) {
                // Lo spazio finito ha un codice suo: Dart lo traduce in una frase.
                val codice = if (spazioFinito(errore)) "spazio_finito" else "errore"
                principale.post { result.error(codice, errore.message, null) }
                return@execute
            }
            principale.post { result.success(risposta) }
        }
    }

    // ─── Protezione ──────────────────────────────────────────────────────────

    /**
     * Su Android non c'è niente da impostare file per file: la memoria dell'app
     * è già cifrata con le chiavi della persona. Si controlla che il file stia
     * proprio lì, e che la cifratura ci sia, e lo si dice.
     */
    private fun proteggi(percorso: String): Map<String, Any> = stato(percorso)

    /** Com'è un file adesso: la sua protezione e se va nel backup su Google. */
    private fun stato(percorso: String): Map<String, Any> {
        val file = File(percorso)
        if (!file.isFile) throw ErroreDocumenti("errore", "Il documento non c'è.")
        // La memoria dell'app legata alle credenziali (CE), non quella che si
        // apre prima dello sblocco (DE).
        val cartella = File(contesto.filesDir, CARTELLA).canonicalPath + File.separator
        val alSuoPosto = file.canonicalPath.startsWith(cartella) &&
            !contesto.isDeviceProtectedStorage
        return mapOf(
            "protezione" to if (alSuoPosto && cifraturaAttiva()) "dopo_il_primo_sblocco" else "nessuna",
            // Le regole di backup tengono fuori la cartella dei documenti: il
            // backup su Google li perderebbe tutti oltre i 25 MB per app.
            "nelBackup" to false,
        )
    }

    /**
     * La memoria cifrata con le chiavi di chi usa il telefono (FBE, obbligatoria
     * da Android 10), o tutto il disco cifrato sui telefoni più vecchi. Cifrata
     * con una chiave predefinita, senza credenziali, non conta.
     */
    private fun cifraturaAttiva(): Boolean {
        val gestore = contesto.getSystemService(DevicePolicyManager::class.java) ?: return false
        return when (gestore.storageEncryptionStatus) {
            DevicePolicyManager.ENCRYPTION_STATUS_ACTIVE_PER_USER,
            DevicePolicyManager.ENCRYPTION_STATUS_ACTIVE -> true
            else -> false
        }
    }

    private fun codiceDiSblocco(): Boolean =
        contesto.getSystemService(KeyguardManager::class.java)?.isDeviceSecure ?: true

    // ─── PDF ─────────────────────────────────────────────────────────────────

    /** Apre il PDF, ci fa [azione] e lo chiude, qualunque cosa succeda. */
    private fun <T> conPdf(percorso: String, azione: (PdfRenderer) -> T): T {
        val descrittore = try {
            ParcelFileDescriptor.open(File(percorso), ParcelFileDescriptor.MODE_READ_ONLY)
        } catch (e: IOException) {
            throw ErroreDocumenti("pdf_illeggibile", "Il file non è un PDF leggibile.")
        }
        val lettore = try {
            PdfRenderer(descrittore)
        } catch (e: SecurityException) {
            // Prima di Android 15 il lettore non accetta nessuna password.
            runCatching { descrittore.close() }
            throw ErroreDocumenti("pdf_protetto", "Il PDF è protetto da una password.")
        } catch (e: IOException) {
            runCatching { descrittore.close() }
            throw ErroreDocumenti("pdf_illeggibile", "Il file non è un PDF leggibile.")
        }
        // Chiudere il lettore chiude anche il descrittore.
        return try {
            azione(lettore)
        } finally {
            lettore.close()
        }
    }

    /**
     * La pagina [indice] (da 0) larga [larghezza] pixel, in PNG. Resta in
     * memoria: la riceve Dart, e nessuno la scrive su disco.
     */
    private fun pagina(percorso: String, indice: Int, larghezza: Int): ByteArray =
        conPdf(percorso) { lettore ->
            if (indice < 0 || indice >= lettore.pageCount) {
                throw ErroreDocumenti("pagina_assente", "Il PDF non ha questa pagina.")
            }
            lettore.openPage(indice).use { pagina ->
                // In punti, già girati secondo la rotazione della pagina.
                val w = pagina.width.toDouble()
                val h = pagina.height.toDouble()
                if (w <= 0 || h <= 0) {
                    throw ErroreDocumenti("pagina_vuota", "La pagina non ha dimensioni.")
                }
                var scala = min(max(larghezza, 1), LATO_MASSIMO) / w
                if (w * scala * h * scala > PIXEL_MASSIMI) scala = sqrt(PIXEL_MASSIMI / (w * h))
                val larga = max(1, (w * scala).roundToInt())
                val alta = max(1, (h * scala).roundToInt())

                val immagine = Bitmap.createBitmap(larga, alta, Bitmap.Config.ARGB_8888)
                try {
                    // Il lettore disegna sopra quello che trova: prima la carta.
                    immagine.eraseColor(Color.WHITE)
                    val trasformazione = Matrix().apply {
                        setScale((larga / w).toFloat(), (alta / h).toFloat())
                    }
                    pagina.render(
                        immagine,
                        null,
                        trasformazione,
                        PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY,
                    )
                    val png = ByteArrayOutputStream()
                    if (!immagine.compress(Bitmap.CompressFormat.PNG, 100, png)) {
                        throw ErroreDocumenti("pagina_vuota", "La pagina non si è potuta disegnare.")
                    }
                    png.toByteArray()
                } finally {
                    immagine.recycle()
                }
            }
        }

    // ─── Foto ────────────────────────────────────────────────────────────────

    /**
     * Da qualunque immagine (HEIC, PNG, JPEG) a un JPEG con il lato lungo al più
     * [lato] pixel, raddrizzato secondo l'EXIF e senza metadati: il JPEG che
     * scrive Android non ne ha. Scrive in [a].
     */
    private fun comprimi(da: String, a: String, lato: Int, qualita: Double): Map<String, Int> {
        val letta = leggiRidotta(File(da), max(lato, 1))
        val ridotta = riduci(letta, max(lato, 1))
        val bianca = suFondoBianco(ridotta)
        try {
            // Prima in memoria, poi sul disco in un colpo: così lo spazio che
            // finisce arriva come errore del disco, e Dart lo riconosce.
            val jpeg = ByteArrayOutputStream()
            val q = (qualita * 100).roundToInt().coerceIn(1, 100)
            if (!bianca.compress(Bitmap.CompressFormat.JPEG, q, jpeg)) {
                throw ErroreDocumenti("errore", "Non si è potuto scrivere il documento.")
            }
            FileOutputStream(a).use { uscita ->
                jpeg.writeTo(uscita)
                uscita.fd.sync()
            }
            return mapOf("larghezza" to bianca.width, "altezza" to bianca.height)
        } finally {
            for (b in setOf(letta, ridotta, bianca)) b.recycle()
        }
    }

    /**
     * L'immagine già raddrizzata e quasi della misura giusta, senza mai tenere
     * in memoria tutti i pixel di una foto da 48 megapixel.
     */
    private fun leggiRidotta(file: File, lato: Int): Bitmap {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                // Legge anche HEIC, e raddrizza da solo secondo l'EXIF.
                return ImageDecoder.decodeBitmap(ImageDecoder.createSource(file)) { lettore, info, _ ->
                    lettore.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                    val (w, h) = info.size.width to info.size.height
                    val lungo = max(w, h)
                    // Larghezza e altezza scalano insieme: l'orientamento non
                    // cambia le proporzioni.
                    if (lungo > lato) {
                        val s = lato.toDouble() / lungo
                        lettore.setTargetSize(max(1, (w * s).roundToInt()), max(1, (h * s).roundToInt()))
                    }
                }
            }
            return leggiRidottaSenzaImageDecoder(file, lato)
        } catch (e: IOException) {
            throw ErroreDocumenti("immagine_illeggibile", "Il file non è un'immagine leggibile.")
        }
    }

    /** Android 7 e 8: si campiona, poi si raddrizza a mano secondo l'EXIF. */
    private fun leggiRidottaSenzaImageDecoder(file: File, lato: Int): Bitmap {
        val misure = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, misure)
        if (misure.outWidth <= 0 || misure.outHeight <= 0) {
            throw ErroreDocumenti("immagine_illeggibile", "Il file non è un'immagine leggibile.")
        }
        var campione = 1
        while (max(misure.outWidth, misure.outHeight) / (campione * 2) >= lato) campione *= 2
        val letta = BitmapFactory.decodeFile(
            file.path,
            BitmapFactory.Options().apply { inSampleSize = campione },
        ) ?: throw ErroreDocumenti("immagine_illeggibile", "Il file non è un'immagine leggibile.")

        val orientamento = runCatching {
            ExifInterface(file.path).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)
        val giro = Matrix()
        when (orientamento) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> giro.setScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> giro.setRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> {
                giro.setRotate(180f)
                giro.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                giro.setRotate(90f)
                giro.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_90 -> giro.setRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                giro.setRotate(-90f)
                giro.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_270 -> giro.setRotate(-90f)
            else -> return letta
        }
        val dritta = Bitmap.createBitmap(letta, 0, 0, letta.width, letta.height, giro, true)
        if (dritta !== letta) letta.recycle()
        return dritta
    }

    /** Il lato lungo al più [lato], con le proporzioni di prima. */
    private fun riduci(immagine: Bitmap, lato: Int): Bitmap {
        val lungo = max(immagine.width, immagine.height)
        if (lungo <= lato) return immagine
        val s = lato.toDouble() / lungo
        return Bitmap.createScaledBitmap(
            immagine,
            max(1, (immagine.width * s).roundToInt()),
            max(1, (immagine.height * s).roundToInt()),
            true,
        )
    }

    /**
     * Il JPEG non ha la trasparenza: quello che è trasparente diventa bianco,
     * come la carta, invece che nero.
     */
    private fun suFondoBianco(immagine: Bitmap): Bitmap {
        if (!immagine.hasAlpha()) return immagine
        val bianca = Bitmap.createBitmap(immagine.width, immagine.height, Bitmap.Config.ARGB_8888)
        Canvas(bianca).apply {
            drawColor(Color.WHITE)
            drawBitmap(immagine, 0f, 0f, Paint(Paint.FILTER_BITMAP_FLAG))
        }
        return bianca
    }

    // ─── Errori e argomenti ──────────────────────────────────────────────────

    /** Il disco pieno, comunque arrivi: ENOSPC dentro un errore di Java. */
    private fun spazioFinito(errore: Throwable): Boolean {
        var causa: Throwable? = errore
        while (causa != null) {
            if (causa is ErrnoException && causa.errno == OsConstants.ENOSPC) return true
            if (causa.message?.contains("ENOSPC") == true) return true
            causa = causa.cause
        }
        return false
    }

    private fun testo(call: MethodCall, chiave: String): String {
        val valore = call.argument<Any>(chiave) as? String
        if (valore.isNullOrEmpty()) throw ErroreDocumenti("argomenti", "Manca $chiave.")
        return valore
    }

    private fun numero(call: MethodCall, chiave: String): Int =
        (call.argument<Any>(chiave) as? Number)?.toInt()
            ?: throw ErroreDocumenti("argomenti", "Manca $chiave.")

    companion object {
        /** La cartella dei documenti dentro quella dell'app (CartellaDocumenti.cartella). */
        const val CARTELLA = "documenti"

        /**
         * Il lato massimo in pixel di una pagina disegnata, e quanti pixel in
         * tutto: una ricevuta lunghissima non deve finire la memoria.
         */
        private const val LATO_MASSIMO = 4000
        private const val PIXEL_MASSIMI = 16_000_000.0
    }
}

/** Un errore con un codice che Dart riconosce (dati/file_del_telefono.dart). */
class ErroreDocumenti(val codice: String, val messaggio: String) : Exception(messaggio)
