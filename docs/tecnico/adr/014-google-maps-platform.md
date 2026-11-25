# ADR-014 — Google Maps Platform al posto di Geoapify

**Stato**: accettata dall'utente il 25 novembre 2026 (CR-06), da costruire. Alla costruzione sostituisce [ADR-006](006-mappe-e-percorsi.md) per il fornitore; restano valide le sue regole sull'interfaccia interna e sul degradare con grazia.

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
4. **Il plugin Flutter del Navigation SDK** (`google_navigation_flutter`): com'è mantenuto, e se regge la tela.
5. **Le condizioni sui contenuti di Places dati a un modello** (CR-01): la scheda della guida si scrive da Wikipedia e dal nome del luogo, non dal contenuto di Google, finché non è chiaro.

## Conseguenze

- **La mappa non si paga più a visualizzazione**: il problema di Copenaghen sparisce sul telefono. Restano a consumo i tragitti, le ricerche, gli orari e la guida.
- **La tela cambia**: le schermate della mappa (tela, 47–56) si ridisegnano sulla mappa di Google prima di costruire.
- **Le prove non vedono più la mappa**: è una vista nativa. Le regole restano in `dominio/` e si provano lì; la mappa si prova sul telefono.
- **Un responsabile del trattamento nuovo**, Google, al posto di Geoapify, con un trasferimento fuori dall'UE ([per la revisione](../../legale/per-la-revisione.md), 27–29).
- **`consumo_mappe` cambia i suoi campi**: niente più riquadri; tragitti, ricerche, dettagli, destinazioni guidate, fermati.
