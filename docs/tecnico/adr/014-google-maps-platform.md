# ADR-014 — Google Maps Platform al posto di Geoapify

**Stato**: accettata dall'utente il 25 novembre 2026 (CR-06); passi 1–4 costruiti il 26 novembre 2026, resta il rinnovo delle coordinate. Sostituisce [ADR-006](006-mappe-e-percorsi.md) per il fornitore: Geoapify non c'è più; restano valide le sue regole sull'interfaccia interna e sul degradare con grazia.

## Contesto

Il 21 novembre 2026, a Copenaghen, il tetto delle mappe si è esaurito a metà giornata: 2000 riquadri contati, 1253 fermati, circa 810 crediti chiesti, il 27% della quota gratuita giornaliera di **tutta** l'app ([analisi dei costi](../../BETA_COST_ANALYSIS_2027.md), §3). Quattro persone così nello stesso giorno spengono la mappa a tutti.

Allo stesso tempo le richieste dopo Copenaghen ([decisioni](../../decisioni/prodotto.md#le-richieste-dopo-copenaghen-25-novembre-2026)) chiedono quello che Geoapify non ha: i mezzi pubblici con gli orari veri (CR-07), gli orari di apertura dei locali (CR-03), le descrizioni dei luoghi (CR-01), e una guida che tenga la persona dentro l'app.

## Decisione

**Google Maps Platform, fornitore unico, dietro le stesse interfacce interne.**

| Cosa | Prodotto Google | Dove passa |
|---|---|---|
| La mappa | Maps SDK per iOS e Android, con `google_maps_flutter` | Sul telefono, chiave legata all'app |
| La guida passo passo, a piedi, in bici, in auto | Navigation SDK | Sul telefono, chiave legata all'app |
| I tragitti fra le tappe e i mezzi pubblici | Routes API (Compute Routes, modo `TRANSIT` compreso) | Dalla funzione del server |
| Cercare un posto | Places API (New): Autocomplete e Place Details | Dalla funzione del server |
| Gli orari e le descrizioni | Places API (New): Place Details, Nearby Search | Dalla funzione del server |

- **Il `place_id` si tiene per sempre**; latitudine e longitudine al massimo 30 giorni. La tappa tiene il `place_id` e le coordinate come copia con la data; un lavoro le rinnova prima dei 30 giorni con un Place Details che chiede solo il `place_id`, che non si paga. Un viaggio chiuso non ha bisogno delle coordinate: il passaporto e il mappamondo usano paese e città, che sono nostri ([ADR-005](005-dati-geografici.md)).
- **Le chiavi**: quelle degli SDK stanno nell'app, legate all'identificativo dell'app iOS e al pacchetto e all'impronta della firma Android (Google lo permette, Geoapify no). Quelle delle API web restano sul server, come oggi `GEOAPIFY_CHIAVE`, dietro la funzione `mappe`.
- **Il tetto è unico per tutta l'app, alle quote gratuite** (scelta dell'utente, per ora): le quote di Google sono mensili e per SKU, e le quote del progetto Google Cloud si fermano lì. Raggiunto, la guida passa a Google Maps o a Mappe di Apple, i tragitti mostrano l'ultimo calcolato, la ricerca dice di scrivere il posto a mano. ADR-006, regola 1, chiedeva il contrario — un tetto per persona — e il rischio resta: chi lo consuma lo consuma per tutti. Prima della demo si decide un budget e, se serve, un tetto per persona sopra quello unico.
- **Cambiare fornitore resta un file**: `dati/mappe.dart` e la funzione `mappe`. La mappa nativa però cambia anche `aspetto/` e le schermate della mappa: i segni delle tappe diventano immagini disegnate dai nostri widget.

## Quello che si sa, e quello che va verificato

Letto il 25 novembre 2026:

- **Navigation SDK**: si paga a destinazione chiesta; avviare la guida e i ricalcoli non costano; le prime 1000 destinazioni al mese sono gratis ([Navigation SDK, fatturazione](https://developers.google.com/maps/documentation/navigation/android-sdk/pricing); [nuovi prezzi](https://mapsplatform.google.com/resources/blog/making-navigation-sdks-more-accessible-with-new-pricing/)). Una destinazione è un «portami lì» intero; un percorso con una tappa in mezzo sono due.
- **Quote gratuite per SKU**: Essentials 10 000 al mese, Pro 5000, Enterprise 1000 ([listino](https://developers.google.com/maps/billing-and-pricing/pricing), [categorie](https://developers.google.com/maps/billing-and-pricing/pricing-categories)). Il `place_id` si rinnova gratis ([Place ID](https://developers.google.com/maps/documentation/places/web-service/place-id)).
- **Le condizioni europee** valgono per chi è fatturato nello Spazio economico europeo dall'8 luglio 2025, quindi per noi ([condizioni EEA](https://cloud.google.com/terms/maps-platform/eea/maps-service-terms)).

Da verificare sul testo prima di costruire ([punti aperti](../../punti-aperti.md)):

1. **Le condizioni EEA** non si sono lasciate leggere dagli strumenti automatici. Fonti indirette dicono che il contenuto di Places diverso da coordinate e `place_id` non si mostra con **nessuna** mappa, e che le istruzioni delle Routes API non si usano con nessuna mappa. Per questo «Qui vicino» è un elenco e non dei segni sulla mappa. Va capito se il percorso a passi dei mezzi pubblici e il tragitto disegnato sulla mappa ci rientrano.
2. **Il prezzo del Navigation SDK** oltre le 1000 destinazioni: le fonti non concordano.
3. **Se il Navigation SDK guida anche con i mezzi pubblici**: per quanto se ne sa, no; per questo i mezzi sono un percorso a passi dalle Routes API.
4. ~~**Il plugin Flutter del Navigation SDK** (`google_navigation_flutter`): com'è mantenuto, e se regge la tela.~~ Visto il 26 novembre 2026 (passo 4, sotto): lo mantiene Google, è alla 0.13 (beta, uscita il 13 novembre 2026), e regge la tela.
5. **Le condizioni sui contenuti di Places dati a un modello** (CR-01): la scheda della guida si scrive da Wikipedia e dal nome del luogo, non dal contenuto di Google, finché non è chiaro.

## Le condizioni europee, lette il 26 novembre 2026

Il testo delle condizioni non si legge dagli strumenti automatici, ma le pagine per sviluppatori che le spiegano sì ([Places](https://developers.google.com/maps/comms/eea/places), [Routes](https://developers.google.com/maps/comms/eea/routes), [domande frequenti](https://developers.google.com/maps/comms/eea/faq)). Valgono per un conto di fatturazione con indirizzo nello Spazio economico europeo, quindi per noi.

- **Places**: tranne latitudine, longitudine e `place_id`, il contenuto di Places **non si usa con nessuna mappa**, nemmeno di Google: né sopra, né accanto, né in modo che si legga insieme. Senza mappa si può, negli usi permessi. L'eccezione è il Places UI Kit di Google, nativo, con l'aspetto di Google.
- **Routes**: la descrizione e i passi di un percorso **non si usano con nessuna mappa**; senza mappa sì. Durata e distanza non sono nominate; la linea del percorso sulla mappa nemmeno.
- **Navigation SDK**: la guida in tempo reale si può fare, con i requisiti di sicurezza di Google. Guida a piedi, in bici, in auto e in taxi; **non con i mezzi pubblici**. Il plugin Flutter (`google_navigation_flutter`) è alla 0.13, ancora beta, per Android dalla API 24 e iOS dalla 17.
- **Mescolare fornitori** è permesso in Europa: il divieto di usare Google con mappe non Google è stato tolto. L'utente ha comunque scelto Google solo (sotto).

## Scelte dell'utente, 26 novembre 2026

- **Solo Google**, anche per i posti: proposto il misto (Google per mappa e guida, OpenStreetMap per i posti, che si conservano e si mostrano sulla mappa), l'utente ha scelto Google.
- **Quindi sulla mappa solo il nostro**: il titolo della tappa, il suo numero, il suo colore, alle coordinate. Indirizzi, orari e descrizioni di Google stanno in schermate senza mappa.
- **Il posto di una tappa cercato con Google** tiene il `place_id` e le coordinate (da rinnovare entro 30 giorni), non il nome né l'indirizzo: si chiedono a Google quando servono, con la rete. Le tappe di prima, con il posto di OpenStreetMap, tengono quello che hanno.
- **Il dettaglio della tappa ha due schede**, «Info» (indirizzo, aperto o chiuso, orari, descrizione) e «Mappa» (la mini mappa), mai visibili insieme. Da confermare che due schede bastino a non essere «accanto» alla mappa: domanda per l'avvocato.
- **I passi dei mezzi pubblici** stanno in una schermata loro, senza mappa; sulla mappa, se si può, solo la linea del percorso.
- **«Qui vicino»** resta un elenco senza mappa (già deciso il 25 novembre).

## La costruzione

**Passo 1, la ricerca dei posti (26 novembre 2026).** «Dove?» cerca con Google: `places:autocomplete` mentre si scrive, poi `places/{id}` con le sole coordinate e l'indirizzo (Place Details Essentials) per il posto scelto, nella stessa sessione, così i suggerimenti non si pagano. Passa dalla funzione `mappe` (`/cerca`, `/posto`), che conta tutti e due come `ricerche` sul tetto; l'app li conta a parte (`consumo_mappe.dettagli`). I riquadri e il percorso a piedi restano di Geoapify fino ai passi 2 e 4: le coordinate di Google su una mappa non di Google si possono mostrare (sono l'eccezione, e in Europa mescolare è permesso).

- **Cosa tiene la tappa**: `place_id`, coordinate e `coordinate_il`. `luogo_nome` resta vuoto: il nome e l'indirizzo di Google si vedono nell'elenco e nel foglio della tappa finché è aperto, poi no. Il titolo non si prende più dal nome del posto: sarebbe il nome di Google tenuto per sempre, e sulla mappa.
- **Senza rete** una tappa di Google dice «Sulla mappa»; con la rete il dettaglio chiede l'indirizzo a Google (un dettaglio in più a ogni apertura) e lo mostra con «Google Maps» sotto, perché lì non c'è una mappa.
- **L'attribuzione** è il testo «Google Maps», com'è, grigio #5E5E5E, 12 punti, peso normale: le pagine di Google lo chiedono per i nuovi lavori al posto di «powered by Google» ([regole](https://developers.google.com/maps/documentation/places/web-service/policies)).
- **Da fare**: rinnovare le coordinate prima dei 30 giorni (per ora il lavoro di notte le toglie e la tappa resta senza posto finché non la si cerca di nuovo); una tappa di Google senza coordinate oggi conta come «senza posto».
- **Le chiavi degli SDK** (iOS e Android, legate all'app) sono in `app/chiavi.json`, che git ignora: il repository è pubblico. Servono dal passo 2.

**Passo 2, la mappa (26 novembre 2026).** La mappa del viaggio (tela, 159–160) è la mappa di Google, con `google_maps_flutter` e, su iOS, `google_maps_flutter_ios_sdk10` (Google Maps SDK 10, con Swift Package Manager): **l'app chiede iOS 16**. Le schermate non parlano con Google: `Mappe.mappa` riceve segni, linee e margini e dà un `ControlloMappa` per inquadrare; nelle prove la mappa è finta e i segni si toccano come prima.

- **Sulla mappa solo il nostro**: i segni delle tappe sono i nostri widget (`SegnoSullaMappa`), fatti immagine (`immagineDelWidget`), il puntino della persona, la linea della giornata. Il marchio di Google lo mette la mappa: i margini lo tengono sopra le schede.
- **Le chiavi degli SDK**: `tool/scrivi_chiavi.dart` le scrive da `app/chiavi.json` in `ios/Flutter/Chiavi.xcconfig` (che Info.plist passa come `GMSApiKey`, letto da `AppDelegate`) e in `android/local.properties` (che il manifesto passa come `com.google.android.geo.API_KEY`). Tutti e tre ignorati da git.
- **Resta su Geoapify** la navigazione a piedi (riquadri e percorso), fino al passo 4.

**Passo 3, il dettaglio con due schede (26 novembre 2026).** Con un posto sulla mappa, il dettaglio della tappa ha «Info» e «Mappa», mai visibili insieme (tela, 161–162). «Info» chiede a Google, con la rete e solo quando si vede, la scheda del posto: indirizzo, aperto adesso e fino a quando, gli orari della settimana, la descrizione (`/mappe/scheda`; Enterprise e Atmosphere, le chiamate più care, contate in `consumo_mappe.schede`). Gli orari di un giorno si calcolano in `dominio/apertura.dart`, che servirà anche agli avvisi della CR-03. «Mappa» è la mappa di Google ferma, con il solo segno della tappa. Senza rete «Info» dice «Sulla mappa». La domanda 31 per l'avvocato (se due schede bastano a non essere «accanto» alla mappa) resta aperta.

**Passo 4, la guida (26 novembre 2026).** «Portami» apre la guida a piedi dentro Trolley con il Navigation SDK (tela, 163): la mappa di Google che segue la persona, la nostra intestazione in alto con la svolta che viene (dalle indicazioni passo passo dell'SDK), la nostra scheda in basso con quanto manca, a che ora si arriva, «Fine» e «Apri in Google Maps», e il nostro pulsante tondo «Torna dove sei» quando si sposta la mappa. Intestazione, «Ricentra» e scheda di Google sono spenti (scelta dell'utente del 26 novembre 2026: di Google resta solo il logo); il dialogo delle condizioni di Google prende i nostri colori. All'arrivo, l'evento dell'SDK apre «Sei qui» (tela, 52), come prima. La tappa con il posto di Google va al suo `place_id`, che sa dov'è l'ingresso; le altre alle coordinate. Bici e auto arrivano con i mezzi della CR-07.

- **Un plugin solo per la mappa e la guida**: `google_navigation_flutter` 0.13.0 (beta, versione fissata) porta il suo Maps SDK (11.3 su iOS), e due Maps SDK nella stessa app non convivono, come dice il plugin stesso. Per questo `google_maps_flutter` se ne va e la mappa del viaggio e la mini mappa passano alla sua `GoogleMapsMapView` (`dati/mappa_google.dart`). Lì i segni si aggiungono e si tolgono a comando: `SegniSullaMappa` tiene la differenza, per la mappa e per la guida. Le immagini dei segni si registrano con la sola densità (con anche la misura il plugin su iOS scala due volte), in un quadrato di 72 punti perché l'alone del segno scelto non si tagli.
- **L'app chiede iOS 17** (era 16), come il plugin; su Android API 24, con il desugaring `nio`. Nel Info.plist: la posizione in sottofondo (`UIBackgroundModes` `location`, per guidare a schermo spento) e il permesso del movimento (`NSMotionUsageDescription`), che il Navigation SDK chiede.
- **Dietro un'interfaccia**: `dati/guida.dart` (`Guida`: prepara, vista, parti, quanto manca, arrivo, ferma), `dati/guida_google.dart` per Google; nelle prove una guida finta. Le schermate non parlano con l'SDK.
- **Le condizioni della guida di Google** si accettano una volta, nel dialogo di Google, alla prima guida. Rifiutate, la guida non parte e restano le Mappe. I segnali di quando l'app si chiude male non vanno a Google.
- **Il tetto**: ogni destinazione si paga (1000 al mese gratis). Prima di partire l'app chiede `/mappe/guida`, che la conta sul tetto per persona, viaggio e giorno (il contatore `percorsi` della migrazione `tetto_mappe`, 60 al giorno) senza chiamare nessuno, e senza il posto. La quota del Navigation SDK nella console di Google, a 1000 al mese, è il tetto unico; raggiunta, Google risponde `quotaExceeded` e l'app dice «le guide sono finite».
- **La mappa della guida è tutta nostra**: la grafica di navigazione di Google è spenta (`setNavigationUIEnabled(false)`); la guida, la voce, le indicazioni e l'arrivo vanno avanti lo stesso, perché sono della sessione. La strada è la nostra linea cobalto (dai segmenti della guida, tagliata da dove si è), la persona il nostro puntino, la camera la muove l'app a ogni posizione: con la follow di Google il puntatore finiva sotto la nostra scheda. In 3D la mappa è inclinata di 45° e girata dove si cammina (la direzione cambia ogni 5 m), in 2D dall'alto col nord in alto; il pulsante «2D»/«3D» passa dall'una all'altra con un movimento di camera, e quello della voce la toglie e la rimette. Il telefono ricorda le due scelte (`impostazione`, `guida_voce` e `guida_3d`). Tela, 163 (v84). Con la grafica spenta le posizioni sulla strada della guida possono non arrivare: puntino e camera usano allora quella del telefono (`Posizione.segui`, mai in sottofondo). Il logo sta in basso al centro su ogni mappa a tutto schermo (scelta dell'utente, 27 novembre 2026): la zona che gli si lascia è una striscia larga quanto il logo, in mezzo (`latoPerIlLogo`). Su iPhone la mappa aggiunge da sola la zona sicura a quella zona: il logo sta circa 9 punti sopra la zona sicura, più quello che si lascia. Nella guida sta nella striscia sotto la scheda; sulla mappa del viaggio fra la scheda e la barra delle sezioni, con una tappa aperta sopra il suo foglio. Le inquadrature della mappa del viaggio le calcola l'app (`inquadratura` in `dominio/mappa.dart`), perché la zona stretta del logo non le stringa. Il puntino della guida ha un cono verso dove punta il telefono (tela, 163): la bussola la legge un canale nostro (`ios/Runner/BussolaDelTelefono.swift`, `BussolaDelTelefono.kt`, mai provato su Android) dietro `Posizione.direzione`; il segno è appoggiato sulla mappa e girato, così gira con lei. La direzione non lascia mai il telefono. La voce: Google la riaccende quando una guida nuova parte o la strada cambia, e la guida la rimette come la vuole la persona.
- **Il logo di Google** sta in fondo a destra su ogni mappa (`semanticContentAttribute` da destra a sinistra, in AppDelegate). Con la grafica di navigazione accesa la guida gli teneva un posto più in su e più a sinistra; spenta, sta come nelle altre mappe, nella striscia sotto la scheda. Sulla mappa del viaggio sta sopra le schede: sotto c'è la barra delle sezioni.
- **La posizione in sottofondo è solo della guida**: il permesso `location` in sottofondo serve all'SDK, ma la libreria della posizione lo userebbe da sola anche per la mappa del viaggio; lì è spento (`allowBackgroundLocationUpdates: false` in `dati/posizione.dart`).
- **Cosa vede Google**: mentre guida, la posizione precisa del telefono, di continuo; prima, il posto della tappa. È l'eccezione all'arrotondamento di 08, regola 7: domanda 32 per l'avvocato.
- **Geoapify se ne va**: niente più riquadri né percorsi, né nell'app (`flutter_map`, `latlong2`, `dominio/navigazione.dart`) né nella funzione `mappe`. `consumo_mappe` perde `riquadri` e `percorsi` e prende `destinazioni`. Il segreto `GEOAPIFY_CHIAVE` sul server non serve più.

## Conseguenze

- **La mappa non si paga più a visualizzazione**: il problema di Copenaghen sparisce sul telefono. Restano a consumo i tragitti, le ricerche, gli orari e la guida.
- **La tela cambia**: le schermate della mappa (tela, 47–56) si ridisegnano sulla mappa di Google prima di costruire.
- **Le prove non vedono più la mappa**: è una vista nativa. Le regole restano in `dominio/` e si provano lì; la mappa si prova sul telefono.
- **Un responsabile del trattamento nuovo**, Google, al posto di Geoapify, con un trasferimento fuori dall'UE ([per la revisione](../../legale/per-la-revisione.md), 27–29).
- **`consumo_mappe` cambia i suoi campi**: niente più riquadri; tragitti, ricerche, dettagli, destinazioni guidate, fermati.
