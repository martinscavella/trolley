# Trolley — Analisi tecnica ed economica della beta 2027

**Periodo:** 1° gennaio – 31 dicembre 2027 · **Redatto il:** 25 novembre 2026 · **Listini verificati il:** 25 novembre 2026

**Come leggere questo documento.** Ogni affermazione porta uno di tre segni:

- **[codice]**: verificato nel repository (file e righe indicati).
- **[misurato]**: letto in sola lettura sul database `trolley-db` il 25 novembre 2026.
- **[ipotesi]**: una stima mia, con i numeri dichiarati. Si corregge con i dati della beta.

I prezzi sono **netti, in dollari USA dove il fornitore fattura in dollari**, convertiti a **1 USD = 0,90 EUR** (BCE, 11 novembre 2026: 1,1127 USD per euro). **IVA esclusa**: vedi §8.4. Le formule sono nel §16. I numeri si possono ricalcolare con lo script descritto lì.

---

## 1. Executive summary

1. **Oggi Trolley costa quasi zero e chiama pochi servizi.** Ne usa quattro a pagamento o a quota. Supabase è sul piano Free. Geoapify è sul Free, con 3000 crediti al giorno. Twilio Verify serve solo per la parte pubblica. I tassi di cambio vengono da una fonte gratuita, scaricati dal server. **Nessun modello AI viene chiamato**: l'itinerario passa dall'assistente della persona, che copia la richiesta e incolla la risposta (ADR-010). Non ci sono Realtime, Storage, notifiche push o servizi di analisi esterni.

2. **Il costo che conta sono i riquadri della mappa, non l'AI.** Un dato reale lo mostra. Il 21 novembre 2026 una persona in viaggio ha raggiunto il tetto di 2000 riquadri al giorno, e il tetto ne ha fermati altri 1253 **[misurato]**. Sono circa 3250 riquadri chiesti in una giornata, cioè circa 810 crediti Geoapify: il 27% della quota gratuita giornaliera di **tutta l'app**. **Quattro persone che viaggiano così nello stesso giorno esauriscono il piano gratuito.**

3. **L'AI nativa costerebbe pochissimo.** Con un mix di modelli leggeri e intermedi si spendono **0,03–0,45 $ al mese per tester**, a seconda dell'uso. Anche 50 tester intensi costano circa **23 $ al mese**. La voce più cara dell'AI è la **ricerca web**, non i token: vale circa il 40% del costo AI. Per le informazioni sui luoghi conviene usare i dati del fornitore di mappe.

4. **Con 10–30 tester e uso leggero o regolare, la beta 2027 costa circa 130–190 € netti l'anno.** Sono quasi solo l'Apple Developer Program e il dominio. Con uso intenso il costo sale a **1.200–2.100 € l'anno**. A farlo salire sono il piano a pagamento di Geoapify (59–109 $ al mese) e Supabase Pro (25 $ al mese).

5. **La pubblicità non copre i costi di una beta.** Con 30 tester, nell'ipotesi media, AdMob renderebbe circa **65 € l'anno**. È sotto la soglia di pagamento di AdMob, che è di 70 €. Il pareggio con la sola pubblicità chiede **centinaia di utenti attivi mensili** nell'ipotesi favorevole. Nell'ipotesi media non arriva finché le mappe costano quanto oggi.

6. **Ci sono tre bloccanti che non sono costi ma vanno risolti prima della beta:**
   - le email di accesso dal server SMTP predefinito di Supabase, che manda 2 messaggi l'ora e solo agli indirizzi del team;
   - il sito su Vercel Hobby, che è riservato all'uso non commerciale;
   - il piano Free di Supabase, che non ha backup.

**Conclusione in breve (dettagli nel §15).** Consiglio di tenere Geoapify e Supabase, di passare a **Supabase Pro** all'apertura della beta, e di ridurre i riquadri prima di comprare un piano Geoapify. Con **30 tester** il costo più probabile del 2027 è di **circa 740 € netti** (circa 62 € al mese), cioè **circa 900 € con l'IVA**. Conviene **accantonare 80 € al mese**, con un tetto prudenziale di **180 € al mese** se l'uso risulta intenso.

---

## 2. Architettura e servizi rilevati nel codice

### 2.1 L'app

**[codice]** L'app è in Flutter, con un solo codice per iOS e Android ([app/pubspec.yaml](../app/pubspec.yaml)). Le librerie che toccano servizi esterni o costi sono queste:

| Libreria | A cosa serve | Costo diretto |
|---|---|---|
| `supabase_flutter` 2.18 | Accesso, lettura e scrittura sul server | Nel piano Supabase |
| `drift` / `drift_flutter` | La copia locale in SQLite e la coda dei gesti senza rete | Nessuno |
| `flutter_map` 8.3 + `latlong2` | La mappa: riquadri raster disegnati in Flutter | Riquadri Geoapify |
| `http` (con `RetryClient`) | Le chiamate alla funzione `mappe` | — |
| `geolocator` 14 | La posizione del telefono | Nessuno: è locale |
| `flutter_local_notifications` | Promemoria calcolati sul telefono (ADR-012) | Nessuno |
| `connectivity_plus`, `app_links`, `share_plus`, `url_launcher`, `file_picker`, `cunning_document_scanner` | Rete, link, condivisione, documenti sul telefono | Nessuno |

Non ci sono SDK di pubblicità, di analisi di terzi o di monitoraggio degli arresti, né Firebase. Gli eventi di misurazione vanno nella tabella `evento` di Supabase ([app/lib/misurazione/misurazione.dart](../app/lib/misurazione/misurazione.dart)).

### 2.2 Supabase

| Componente | Uso rilevato | Fonte |
|---|---|---|
| **Postgres** | 28 migrazioni. Dimensione attuale **14 MB**, con 3 utenti, 10 viaggi, 115 tappe, 23 spese e 341 eventi | [codice] `supabase/migrations/`; [misurato] |
| **Auth** | Email e password (`signUp`, `signInWithPassword`). L'accesso con Google e la conferma dell'email sono ancora da fare | [codice] [accesso.dart:58-74](../app/lib/schermate/accesso.dart#L58-L74); [punti-aperti.md](punti-aperti.md) |
| **Storage** | **Non usato.** I documenti restano sul telefono (ADR-008, CLAUDE.md regola 3) | [codice] nessuna chiamata `storage.` |
| **Realtime** | **Non usato.** Al suo posto c'è un polling: conversazione ogni 5 s, community ogni 15 s, presenza in città ogni 30 s, solo con la schermata aperta | [codice] [collegamenti.dart:21](../app/lib/dominio/collegamenti.dart#L21), [presenza.dart:16](../app/lib/dominio/presenza.dart#L16), [community.dart:76](../app/lib/schermate/community.dart#L76) |
| **Edge Functions** | `mappe` (Geoapify) e `telefono` (Twilio Verify) | [codice] `supabase/functions/` |
| **pg_cron** | Tassi di cambio due volte al giorno (alle 4 e alle 16 UTC) da `fawazahmed0/currency-api`, gratuito. Pulizie notturne di presenze, ricerche e tentativi del telefono | [codice] [spese_e_tassi.sql:113](../supabase/migrations/20261003090000_spese_e_tassi.sql#L113) e altre |
| **Piano** | Organizzazione `aionlabs` sul piano **Free**; progetto in eu-west-1, Postgres 17 | [misurato] |

### 2.3 Geoapify, attraverso la funzione `mappe`

**[codice]** La chiave sta solo sul server. Ogni chiamata passa dalla funzione `mappe` ([supabase/functions/mappe/index.ts](../supabase/functions/mappe/index.ts)). La funzione chiede prima al database `consuma_mappe(viaggio, tipo)` ([tetto_mappe.sql](../supabase/migrations/20261008090000_tetto_mappe.sql)), che conta la chiamata e applica il tetto.

| Operazione | Endpoint Geoapify | Quando parte | Crediti |
|---|---|---|---|
| Riquadri | `GET maps.geoapify.com/v1/tile/klokantech-basic/{z}/{x}/{y}[@2x].png` | A ogni riquadro che entra nello schermo. Gli schermi ad alta densità chiedono `@2x` | 0,25 per riquadro |
| Ricerca di un luogo | `GET /v1/geocode/autocomplete` (`limit=8`, `lang=it`, `filter=circle` entro 40 km) | Dopo 400 ms senza scrivere ([luogo.dart:76](../app/lib/schermate/luogo.dart#L76)). **Se entro 40 km non trova niente, cerca di nuovo ovunque**: costa una seconda chiamata ([mappe.dart:313-315](../app/lib/dati/mappe.dart#L313-L315)) | 1 (2 col ripiego) |
| Percorso a piedi | `GET /v1/routing` (`mode=walk`, `details=instruction_details`) | Solo su «Portami». Si ricalcola fuori strada (oltre 50 m, due posizioni di fila), **al massimo 8 volte e non prima di 20 s** dal ricalcolo precedente ([navigazione.dart:207-235](../app/lib/dominio/navigazione.dart#L207-L235)) | 1 per coppia di punti |

**Il tetto attuale, per persona, viaggio e giorno UTC:** 2000 riquadri, 150 ricerche e 60 percorsi, cioè 710 crediti. I valori stanno in `configurazione.tetto_mappe`. **Non c'è un tetto complessivo** (AUDIT SEC-05): chi crea molti viaggi moltiplica il proprio tetto.

**Non vengono usati:** Places API (ricerca per categoria e orari di apertura), Place Details, geocodifica inversa, Route Matrix e la modalità `transit`. **Le destinazioni e i confini dei paesi sono incorporati nell'app** (`assets/destinazioni.tsv`, `assets/confini.bin`, ADR-005): scegliere una meta non costa niente.

### 2.4 Altri servizi con un costo

| Servizio | Uso | Costo oggi |
|---|---|---|
| **Twilio Verify** | SMS di verifica per la parte pubblica. Tetto di 5 invii al giorno per persona, 3 per numero e 100 al giorno per tutta l'app ([sicurezza.sql](../supabase/migrations/20261009090000_sicurezza.sql)) | A verifica riuscita, più l'SMS |
| **Vercel** | Il sito `trolleyapp.vercel.app`: inviti, informativa, misurazione, condizioni | Hobby, 0 $ |
| **fawazahmed0/currency-api** | Tassi di cambio | 0 $ (licenza CC0) |
| **Apple** | Account gratuito oggi. TestFlight richiede quello a pagamento | 0 $ oggi |
| **Assistente AI** | Quello della persona, che lo paga lei | 0 $ per Trolley |

---

## 3. Consumi attuali e criticità

### 3.1 Cosa dicono i dati reali [misurato]

Gli eventi `consumo_mappe`, dal 5 ottobre al 21 novembre 2026, sono 101 sessioni di mappa con **7.356 riquadri, 53 ricerche e 38 percorsi**. Il tetto ha fermato 1.253 riquadri. In media sono **73 riquadri per sessione**, con un massimo di 915.

| Giornata | Sessioni | Riquadri | Ricerche | Percorsi | Fermati dal tetto |
|---|---|---|---|---|---|
| 6 ottobre 2026 (prove di sviluppo) | 13 | 1.543 | 0 | 0 | 0 |
| 17 ottobre 2026 | 9 | 728 | 23 | 2 | 0 |
| **21 novembre 2026 (un viaggio vero)** | **20** | **1.219 contati dall'app; 2.000 dal server** | **23** | **18–19** | **1.253** |

Le due cifre del 21 novembre non coincidono perché le misure sono diverse. Il server ha contato 2.000 riquadri, il tetto, in `privato.consumo_mappe`. L'app ne ha contati 1.219 negli eventi `consumo_mappe`. Una parte degli eventi probabilmente non è partita, perché vengono scritti alla chiusura della mappa.

**È l'unico giorno di viaggio intenso misurato**, e serve come base dello scenario C: circa **3.250 riquadri chiesti, 23 ricerche e 19 percorsi**. Senza tetto sarebbero stati circa 860 crediti. Il tetto li ha ridotti a 710.

### 3.2 Criticità

| # | Criticità | Effetto sul costo | Verificato |
|---|---|---|---|
| C1 | **I riquadri già sul telefono si ricontrollano a ogni visualizzazione.** Geoapify li manda `no-cache`, quindi l'app chiede ogni volta se sono cambiati (`if-none-match`) e la funzione inoltra la domanda ([mappe/index.ts:123-129](../supabase/functions/mappe/index.ts#L123-L129)). Ogni ricontrollo è un'invocazione della funzione e due scritture sul database, e **conta nel tetto** perché `consuma` viene prima dell'inoltro. Se Geoapify fattura anche le risposte 304 **non è documentato**: le sue pagine non ne parlano | Il tetto si esaurisce prima del dovuto, e forse anche i crediti | [codice]; la fatturazione dei 304 va chiesta a Geoapify |
| C2 | **I riquadri passano dalla funzione Supabase**: i loro byte sono egress Supabase. Il piano Free ne comprende 5 GB al mese | Con uso intenso supera il piano Free (§7) | [codice]; la dimensione media di un riquadro è [ipotesi] |
| C3 | **Non c'è un tetto complessivo** (AUDIT SEC-05). Geoapify ha limiti «morbidi»: se si superano spesso, scrive e chiede di cambiare piano, e si riserva di bloccare l'account | Un abuso, o 4–5 persone intense, rompono la mappa a tutti | [codice] + condizioni Geoapify |
| C4 | Il ripiego della ricerca (cercare ovunque se entro 40 km non c'è niente) raddoppia le ricerche a vuoto | +20% sulle ricerche, secondo la mia stima | [codice]; percentuale [ipotesi] |
| C5 | `RetryClient` sui riquadri: i tentativi ripetuti sono chiamate vere | Piccolo | [codice] |
| C6 | **La sincronizzazione è sempre totale** (AUDIT PERF-02) e la messaggistica usa il polling | Poco egress oggi. Cresce con viaggi e messaggi | [codice] |
| C7 | **L'SMTP predefinito di Supabase** manda 2 email l'ora e solo agli indirizzi del team | **Blocca la registrazione di tester esterni** se la conferma email si accende | Documentazione Supabase |
| C8 | **Supabase Free**: nessun backup, progetto messo in pausa dopo una settimana di inattività | Perdere i dati della beta senza poterli recuperare | Listino Supabase |
| C9 | **Vercel Hobby è solo per uso personale e non commerciale** | Con pubblicità o pagamenti serve un piano Pro o un'altra soluzione | Condizioni Vercel |

**Cosa si può già misurare:** riquadri, ricerche, percorsi e chiamate fermate, per sessione e per viaggio (`consumo_mappe`); invii SMS (`tetto_telefono`); dimensione del database. **Cosa si deve stimare:** l'egress reale di Supabase (va letto dal pannello Usage), la quota di risposte 304, la dimensione media di un riquadro, i crediti realmente scalati da Geoapify (vanno letti dal pannello di Geoapify), e qualunque consumo AI.

---

## 4. Assunzioni degli scenari [ipotesi]

Tutti i valori sono **per tester attivo al mese**. Uno scenario C tenuto per dodici mesi di fila è volutamente pessimista. I budget del §12 tengono conto della stagionalità.

| Voce | A · Leggero | B · Regolare | C · Intenso | Note |
|---|---|---|---|---|
| Giorni di utilizzo al mese | 4 | 10 | 16 | |
| … di cui giorni in viaggio | 2 | 5 | 8 | |
| Viaggi creati al mese | 0,5 | 1 | 2 | |
| Tappe per viaggio | 8 | 15 | 25 | |
| Sessioni di mappa al mese | 8 | 40 | 200 | Viaggio: 3, 6 e 20 al giorno (C dal 21/11). Pianificazione: 1, 2 e 5 al giorno |
| Riquadri per sessione | 40 | 80 | 125 in viaggio, 100 in pianificazione | Media misurata: 73 per sessione |
| **Riquadri al mese** | **320** | **3.200** | **24.000** | |
| Ricerche di luoghi e locali | 8 | 33 | 235 | Tappe × 1,5 più le ricerche in viaggio. C: 20 al giorno (misurate: 23) |
| Geocodifica (verifica delle tappe proposte dall'AI) | 4 | 15 | 75 | Funzione futura: oggi l'AI dà le coordinate e si accettano entro 150 km |
| Percorsi di navigazione | 4 | 25 | 152 | C: 19 al giorno (misurati) |
| Percorsi per l'itinerario dinamico (crediti) | 12 | 60 | 240 | Ricalcoli al giorno × tratti fra le tappe |
| Richieste di trasporto pubblico | 1 | 10 | 40 | Funzione futura |
| Orari dei luoghi (Place Details, una volta per tappa) | 4 | 15 | 50 | Funzione futura, con il risultato tenuto |
| Ricerche nei dintorni | 2 | 15 | 64 | Funzione futura |
| **Aggiornamenti GPS** | ~800 | ~5.000 | ~36.000 | **Locali: 0 chiamate API** (§6) |
| Riprogrammazioni locali | 4 | 15 | 40 | **0 chiamate API** |
| **Eventi che richiedono l'AI** | **11,5** | **63** | **162** | Somma delle righe qui sotto |
| – Itinerari generati con l'AI | 0,5 | 1 | 3 | |
| – Modifiche intelligenti dell'itinerario | 1 | 4 | 12 | |
| – Liste valigia | 0,5 | 1 | 2 | |
| – Spese in linguaggio naturale | 5 | 30 | 60 | |
| – Categorizzazione delle spese (solo i casi ambigui) | 1 | 6 | 15 | Prima le regole locali, l'AI dopo |
| – Guide turistiche contestuali | 2 | 10 | 30 | Il 25% con ricerca web |
| – Suggerimenti durante il viaggio | 1 | 8 | 30 | Il 25% con ricerca web |
| – Riprogrammazione con imprevisti | 0,5 | 3 | 10 | |
| **Crediti Geoapify al mese** | **117** | **979** | **6.903** | Formula F1 |
| Crediti in un giorno di viaggio | 41 | 144 | 711 | Formula F2. C coincide col tetto attuale, 710 |
| Crediti in un giorno di pianificazione | 18 | 51 | 152 | |

### 4.1 Picchi giornalieri

Geoapify vende **crediti al giorno**, non al mese. Il costo lo decide **il giorno peggiore**. Ipotizzo che nel giorno di picco siano in viaggio il **20% dei tester (A), il 30% (B) o il 50% (C)**, e che stiano pianificando il 20%, il 25% o il 30%. È realistico per una beta fatta di amici che viaggiano insieme, o durante ponti e feste. Ai picchi aggiungo un **margine del 20%** per tentativi ripetuti, errori e 304.

| Crediti al giorno nel picco | 10 tester | 30 tester | 50 tester |
|---|---|---|---|
| A | 140 | 420 | 700 |
| B | 705 | 2.053 | **3.401** |
| C | **4.807** | **14.420** | **24.034** |

In grassetto i picchi che **superano il piano Free di Geoapify** (3.000 crediti al giorno), anche se il consumo mensile resta basso.

---

## 5. Confronto dei fornitori di mappe

### 5.1 Listini (verificati il 25 novembre 2026, salvo dove indicato)

| | **Geoapify** | **Mapbox** | **Google Maps Platform** | **HERE** |
|---|---|---|---|---|
| Modello di prezzo | **Abbonamento a crediti giornalieri**. Free: 3.000 al giorno. API 10: 59 $/mese per 10.000. API 25: 109 $ per 25.000. API 50: 179 $ per 50.000. API 100: 299 $ per 100.000 | Quote gratuite mensili per prodotto, poi a consumo, per 1.000 | Quote gratuite mensili **per SKU** (Essentials 10.000, Pro 5.000, Enterprise 1.000), poi per 1.000 | Base Plan a transazioni. **Listino ufficiale non leggibile**: il sito rifiuta i lettori automatici |
| Flutter | `flutter_map` + REST (**già integrato**) | `mapbox_maps_flutter` (SDK) oppure `flutter_map` + Static Tiles | `google_maps_flutter` (ufficiale) | HERE SDK for Flutter (licenza da verificare) |
| Visualizzazione della mappa | 0,25 crediti per riquadro | **SDK mobile: gratis fino a 25.000 MAU**, poi 4 $ ogni 1.000 MAU. Static Tiles: 200.000 gratis, poi 0,50 $ per 1.000 | **Maps SDK iOS/Android: gratis e illimitato**. Map Tiles API 2D: 100.000 gratis, poi 0,60 $ per 1.000 | Non verificato |
| Geocodifica | 1 credito | Temporanea: 100.000 gratis, poi 0,75 $. **Permanente: 5 $ per 1.000, senza quota gratuita** | 10.000 gratis, poi 5 $ per 1.000 | 30.000 gratis, poi 0,83 $ per 1.000 (pagina non datata, prima dell'aumento del 6% di aprile 2026) |
| Ricerca di luoghi | Autocomplete: 1 credito. Places: 1 credito ogni 20 risultati | Search Box: 2.500 sessioni gratis, poi 11,50 $ per 1.000 | Autocomplete: 10.000 gratis, poi 2,83 $. Text Search e Nearby Pro: 5.000 gratis, poi 32 $ | Non verificato |
| Orari di apertura | Place Details: 1 credito più eventuali extra. Dati OpenStreetMap, copertura variabile | Metadati POI, da verificare | Place Details Enterprise (*il livello degli orari è da verificare*): 1.000 gratis, poi 20 $ | Non verificato |
| A piedi, in bici, in auto | 1 credito per coppia di punti. Modi `walk`, `bicycle`, `drive` | Directions: 100.000 gratis, poi 2 $ per 1.000 | Routes Essentials: 10.000 gratis, poi 5 $ | Non verificato |
| Monopattino | `scooter` (motorino). Per il monopattino si approssima con la bici | No, si approssima con la bici | `TWO_WHEELER` (motorizzato) | Non verificato |
| Taxi | No | No | No (solo tempo in auto) | No |
| **Trasporto pubblico** | Modi `transit` e `approximated_transit`, costruiti sulle linee OpenStreetMap. **Orari reali non documentati** | **Assente** | **Sì, con orari**, compreso in Routes Essentials | Public Transit API, peso 10 transazioni (non verificato) |
| **Conservare le coordinate** | **Sì, senza limiti** (Places e Batch dichiarati) | Solo con la geocodifica permanente, che si paga | **Coordinate al massimo 30 giorni.** `place_id` per sempre | La geocodifica permanente è esclusa dal Base Plan |
| Limiti | Morbidi: se si superano, Geoapify scrive. **Vietato dividere le chiamate su più account** | Carta richiesta | Carta richiesta. Il contenuto Google ha restrizioni d'uso con mappe non Google (*da verificare nei termini*) | — |
| Attribuzione | OSM sempre. Geoapify sul piano Free | Logo Mapbox | Logo Google | — |
| Unione europea | Società europea (Germania o Cipro, da identificare con certezza: [punti-aperti.md](punti-aperti.md)) | USA | USA | Paesi Bassi |
| Migrazione | — | **Alta**: una mappa nativa al posto di `flutter_map` (i segni non sono più widget Flutter, la tela va rifatta in Mapbox Studio), più la geocodifica permanente | **Alta**: come Mapbox, e in più le tappe perderebbero le coordinate dopo 30 giorni, contro ADR-006 | Alta, e i prezzi vanno verificati |

### 5.2 Costo nei nove scenari (USD al mese, netti)

Formule F3–F6. Per Mapbox e Google ho scelto la variante più economica, cioè l'SDK nativo con riquadri gratuiti. Fra parentesi c'è la variante che tiene `flutter_map`.

| Scenario | Geoapify (piano) | Mapbox (SDK) | Google (SDK) | HERE (*indicativo, non verificato*) |
|---|---|---|---|---|
| A · 10 | 0 (Free) | 0,48 | 0 | 0 |
| A · 30 | 0 (Free) | 1,44 | 0 | 0 |
| A · 50 | 0 (Free) | 2,40 | 0 | 0 |
| B · 10 | 0 (Free) | 1,80 | 0 | ~7 |
| B · 30 | 0 (Free) | 5,40 | 0 (9 con `flutter_map`) | ~71 |
| B · 50 | **59** (API 10) | 9,00 | 0 (55) | ~134 |
| C · 10 | **59** (API 10) | 11 (55) | 0 (113) | ~214 |
| C · 30 | **109** (API 25) | 91 (423) | 51 (510) | ~692 |
| C · 50 | **109–179** (API 25 al limite, API 50 prudenziale) | 171 (791) | 176 (980) | ~1.170 |

### 5.3 Valutazione

- **Sul solo prezzo**, con questi volumi, Google e Mapbox con l'SDK nativo costano meno di Geoapify negli scenari C. È così perché la mappa mobile è gratuita.
- **Sulle funzioni richieste Geoapify resta il più adatto**:
  - è l'unico che lascia **conservare le coordinate senza limiti**, il criterio che ha deciso ADR-006;
  - è già integrato, dietro una chiave sul server e un tetto;
  - tiene `flutter_map`, cioè la tela di Claude Design (CLAUDE.md, regola 9).
  Con Google le tappe dovrebbero rinnovare le coordinate ogni 30 giorni. Con Mapbox ogni tappa salvata costerebbe una geocodifica permanente, e il trasporto pubblico non c'è.
- **Il trasporto pubblico con orari veri** ce l'ha davvero solo Google, nei fornitori verificati. HERE ce l'ha ma non è verificato. La modalità `transit` di Geoapify si appoggia sulle linee OSM e va provata prima di prometterla.
- **Architettura ibrida.** Ha senso su un punto solo: **i riquadri**. Si possono prendere da una fonte che non si paga a riquadro, e lasciare a Geoapify ricerca, percorsi e luoghi. Senza i riquadri, Geoapify consuma circa 86 crediti per tester intenso al giorno: anche 50 tester C restano vicini al piano Free (circa 3.070 crediti al giorno nel picco). Le strade possibili, **tutte da verificare prima**:
  1. **Chiedere a Geoapify** se si possono tenere i riquadri sul telefono per giorni invece che `no-cache`, e se i 304 si pagano. È il guadagno più grande, e quasi non cambia il codice: elimina C1.
  2. Riquadri vettoriali ospitati in proprio (per esempio Protomaps/PMTiles su uno storage a egress gratuito), disegnati da `flutter_map` con un plugin vettoriale. Prezzi non verificati in questo documento.
  3. Google Routes solo per il trasporto pubblico. **Sconsigliato senza un parere sui termini**: Google limita l'uso dei suoi dati insieme a una mappa non Google. Per la beta basta **aprire il percorso in Google Maps o in Apple Mappe**, che è gratis e già previsto (`MappeDelTelefono`).
  4. Taxi e monopattini in condivisione: un **link all'app del servizio**, senza contratto e senza costo.

---

## 6. Itinerario dinamico in tempo reale

### 6.1 Cosa fa oggi [codice]

- **«Adesso»** mostra cosa succede ora, cosa viene dopo e fra quanto. **Non riorganizza mai il programma da solo**: se il programma è indietro rispetto all'orologio, dice cosa resta ([adesso.dart:1-6](../app/lib/dominio/adesso.dart#L1-L6)).
- **Gli orari** ([orari.dart](../app/lib/dominio/orari.dart)) impediscono le sovrapposizioni, controllano la capienza della giornata e propongono di **spostare in avanti le tappe successive** quando manca un buco. Una tappa fatta o saltata non si sposta. Gli spostamenti a piedi fra le tappe **non entrano nel calcolo**.
- **La navigazione** usa il GPS in primo piano (`distanceFilter` di 4 m, `ActivityType.fitness`). Rileva l'arrivo entro 35 m e l'uscita di strada oltre 50 m, **sul telefono**. Chiede a Geoapify solo il percorso iniziale e i ricalcoli: al massimo 8, uno ogni 20 s.
- **La posizione non lascia mai il telefono** ([posizione.dart](../app/lib/dati/posizione.dart)). L'unica eccezione è il punto di partenza di un percorso chiesto dalla persona.

### 6.2 Le tre categorie

| | Operazione | Dove | Costo |
|---|---|---|---|
| **A · Locale** | Rilevare un ritardo (orologio contro programma) | App | 0 |
| | Tappa finita prima, tappa saltata (`tappa_marcata`) | App | 0 |
| | Spostare le tappe successive, controllare capienza e sovrapposizioni | App ([orari.dart](../app/lib/dominio/orari.dart)) | 0 |
| | Arrivo, uscita di strada, aggiornamenti GPS | App ([navigazione.dart](../app/lib/dominio/navigazione.dart)) | 0 |
| | Confrontare con gli orari di apertura **già scaricati** | App | 0 |
| | **Decidere se serve l'AI**, con regole: ritardo oltre 30 min **e** una tappa a orario fisso o in chiusura, oppure una richiesta esplicita | App | 0 |
| **B · Mappe** | Tempi di percorrenza fra le tappe del giorno: un percorso con più punti costa (tappe − 1) crediti, e si ricalcola solo quando la giornata cambia | Geoapify | 4–25 crediti al giorno |
| | Orari di apertura: un Place Details per tappa, **una volta per viaggio**, poi conservato | Geoapify | 1 credito per tappa |
| | Alternative nei dintorni: Places, 1 credito ogni 20 risultati | Geoapify | 1–8 crediti al giorno |
| | Trasporto pubblico | Geoapify `transit` da provare, oppure un link alle Mappe del telefono | 0–5 crediti al giorno |
| **C · AI** | «Riorganizza la giornata» dopo un imprevisto | LLM attraverso una funzione del server | 0,005 $ per richiesta |
| | «Cosa faccio adesso qui vicino?», con preferenze e posizione approssimata | LLM | 0,002–0,013 $ per richiesta (con ricerca web) |

### 6.3 Costo per giorno di viaggio, per tester

| | A | B | C |
|---|---|---|---|
| A · Locale | 0 | 0 | 0 |
| B · Mappe, escluse ricerche e riquadri (crediti) | 9 | 22 | 62 |
| B · Mappe con i riquadri (crediti) | 41 | 144 | 711 |
| C · AI (suggerimenti e riprogrammazione, $) | 0,004 | 0,011 | 0,024 |

**La logica dinamica in sé non costa quasi niente.** Il costo del viaggio in corso è **la mappa guardata**, cioè i riquadri. Il margine per imprevisti, tentativi ripetuti e picchi è già nel 20% dei §4.1 e §7.3. Per l'AI conviene un tetto per persona e per giorno, come quello delle mappe (per esempio 30 richieste), con un evento nuovo che registri tipo ed esito, mai il testo (CLAUDE.md, regola 1).

---

## 7. Costi dell'AI

### 7.1 Listini (USD per milione di token, letti il 25 novembre 2026)

| Modello | Input | Output | Note |
|---|---|---|---|
| OpenAI `gpt-5-nano` | 0,05 | 0,40 | Il più economico |
| OpenAI `gpt-5-mini` | 0,25 | 2,00 | Intermedio, consigliato per il ragionamento |
| OpenAI `gpt-5.4-mini` | 0,75 | 4,50 | |
| OpenAI `gpt-6-luna` / `gpt-5.6-luna` | 0,10 / 0,20 | 0,50 / 1,20 | Nuovi, elencati sulla pagina. Da provare |
| Google `gemini-2.5-flash-lite` | 0,10 | 0,40 | *Dal riassunto della pagina, da riconfermare* |
| Google `gemini-3.1-flash-lite` | 0,25 | 1,50 | *Dal riassunto della pagina, da riconfermare* |
| Google `gemini-3.5-flash-lite` | 0,30 | 2,50 | |
| Google `gemini-3.8-flash` | 0,75 → **1,50 dal 1° gennaio 2027** | 3,75 → **7,50 dal 1° gennaio 2027** | **Il prezzo raddoppia proprio nell'anno della beta** |
| Ricerca web OpenAI | 10 $ ogni 1.000 chiamate | + token dei contenuti | |
| Grounding con Google Search | 5.000 al mese gratis (Gemini 3 e successivi), poi 14 $ per 1.000 | | |
| Batch (entrambi) | −50% | −50% | Solo per lavori differiti |

**Vincoli che contano per Trolley:**

- **Le condizioni dell'API Gemini permettono solo i servizi a pagamento per app rivolte a utenti in UE, SEE, Svizzera e Regno Unito.** Il piano gratuito di Gemini **non si può usare** per i tester. Con il piano gratuito, inoltre, i contenuti servono a Google per migliorare i suoi prodotti.
- OpenAI chiede credito prepagato: il minimo di ricarica va verificato al momento.
- La chiave deve stare sul server, in una funzione come `mappe`, con tetto ed evento (CLAUDE.md, regole 2 e 5). Ogni chiamata AI conta quindi anche come un'invocazione di Supabase.

### 7.2 Token e costo per operazione [ipotesi sui token]

Il contesto comprende: scheletro del viaggio, tappe del giorno, preferenze, vincoli, posizione **approssimata alla zona** (mai la posizione esatta nel testo), e ora. L'output è **JSON strutturato** (Structured Outputs o `response_schema`). Il JSON rende la lettura sicura, ma un JSON troncato si perde tutto, come ricorda ADR-010. Per l'itinerario conviene chiedere **una riga per tappa** dentro il JSON, oppure lo streaming. L'output comprende un ragionamento minimo.

| # | Funzione | Token in | Token out | gpt-5-nano | gpt-5-mini | gpt-5.4-mini | Gemini 2.5 FL | Gemini 3.1 FL | Gemini 3.8 Flash (2027) |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Itinerario completo (5 giorni, ~20 tappe) | 2.500 | 5.000 | 0,0021 | **0,0106** | 0,0244 | 0,0023 | 0,0081 | 0,0413 |
| 2 | Modifica intelligente | 3.000 | 2.200 | 0,0010 | **0,0052** | 0,0122 | 0,0012 | 0,0041 | 0,0210 |
| 3 | Lista valigia | 1.000 | 1.000 | **0,0005** | 0,0023 | 0,0053 | 0,0005 | 0,0018 | 0,0090 |
| 4 | Spesa scritta a parole | 400 | 100 | **0,00006** | 0,0003 | 0,0008 | 0,00008 | 0,0003 | 0,0014 |
| 5 | Categoria di una spesa | 300 | 30 | **0,00003** | 0,0001 | 0,0004 | 0,00004 | 0,0001 | 0,0007 |
| 6 | Informazioni turistiche | 600 | 700 | **0,0003** | 0,0016 | 0,0036 | 0,0003 | 0,0012 | 0,0062 |
| 7 | Suggerimento durante il viaggio | 2.500 | 800 | 0,0004 | **0,0022** | 0,0055 | 0,0006 | 0,0018 | 0,0098 |
| 8 | Riprogrammazione dopo un imprevisto | 3.500 | 1.800 | 0,0009 | **0,0045** | 0,0107 | 0,0011 | 0,0036 | 0,0188 |

Costi in USD per operazione. In grassetto il modello del **mix consigliato**: `gpt-5-mini` per le operazioni 1, 2, 7 e 8, che chiedono ragionamento; `gpt-5-nano` per le 3, 4, 5 e 6. Al 25% di guide e suggerimenti si aggiunge la ricerca web: 0,010 $ più 3.000 token di contenuto a chiamata.

### 7.3 Costo mensile [mix consigliato, ricerca web, +20% per i tentativi ripetuti]

| Per tester al mese (USD) | A | B | C |
|---|---|---|---|
| Itinerari | 0,005 | 0,011 | 0,032 |
| Modifiche | 0,005 | 0,021 | 0,062 |
| Liste valigia | 0,0002 | 0,0005 | 0,001 |
| Spese (interpretazione e categoria) | 0,0003 | 0,002 | 0,004 |
| Guide (con ricerca web) | 0,006 | 0,029 | 0,085 |
| Suggerimenti (con ricerca web) | 0,005 | 0,039 | 0,147 |
| Riprogrammazione | 0,002 | 0,013 | 0,045 |
| **Totale con +20%** | **0,029** | **0,138** | **0,451** |

| Totale AI al mese (USD) | 10 tester | 30 tester | 50 tester |
|---|---|---|---|
| A | 0,29 | 0,86 | 1,43 |
| B | 1,38 | 4,13 | 6,89 |
| C | 4,51 | 13,54 | 22,57 |

**Confronto, tutto su un solo modello e senza ricerca web** (per tester al mese, B): `gpt-5-nano` 0,022 $; Gemini 2.5 Flash-Lite 0,026 $; Gemini 3.1 Flash-Lite 0,086 $; `gpt-5-mini` 0,108 $; `gpt-5.4-mini` 0,258 $; Gemini 3.8 Flash dal 2027 0,450 $.

**Cosa ne segue:**

1. L'AI **non è la voce che decide il budget**: anche un modello intermedio per tutto costa meno di un euro per tester al mese.
2. **La ricerca web vale circa il 40% del costo AI** (B: 0,047 $ su 0,115 $ prima del margine). Gli orari e le informazioni sui luoghi vanno presi da Geoapify Places e Place Details (1 credito) e passati come contesto.
3. **Le spese non hanno bisogno di un modello nella maggior parte dei casi.** «12 € pranzo» si legge con una regola locale. L'AI serve per frasi come «ho pagato io la cena per tutti e tre, 84 franchi».
4. Il costo di un'operazione è più incerto di quello di un modello: i token di ragionamento possono raddoppiare l'output. Per questo il budget mette un margine del 15–25% (§12).

---

## 8. Supabase e infrastruttura

### 8.1 Free e Pro (verificati il 25 novembre 2026)

| | Free (0 $) | Pro (25 $/mese, 10 $ di calcolo compresi) | Oltre la quota Pro |
|---|---|---|---|
| Database | 500 MB | 8 GB di disco | 0,125 $ per GB |
| Egress | 5 GB (+5 GB in cache) | 250 GB (+250 GB in cache) | 0,09 $ per GB |
| Utenti attivi al mese | 50.000 | 100.000 | 0,00325 $ per MAU |
| Invocazioni delle funzioni | 500.000 | 2 milioni | 2 $ per milione |
| Realtime | 200 connessioni, 2 milioni di messaggi | 500 connessioni, 5 milioni di messaggi | Non usato |
| Storage | 1 GB | 100 GB | Non usato |
| **Backup** | **Nessuno** | Giornalieri, tenuti 7 giorni (PITR a parte, 100 $ al mese) | |
| Registri | 1 giorno | 7 giorni | |
| Pausa per inattività | **Dopo 1 settimana** | Mai | |
| Tetto di spesa | Nessuna eccedenza fatturata | Acceso di serie | |
| Team | 599 $ al mese | | Non serve |

### 8.2 Cosa si raggiunge nei nove scenari

Formule F7 e F8. Per l'egress ipotizzo **25 KB per richiesta di riquadro** [ipotesi], una media fra le risposte 200 da 15–60 KB e le 304 vuote. Il resto dell'egress è REST: 5, 20 o 50 MB per tester al mese.

| Scenario | Invocazioni al mese | Egress al mese | Database | Free basta? |
|---|---|---|---|---|
| A · 10 / 30 / 50 | 4.400 / 13.000 / 22.000 | 0,2 / 0,5 / 0,8 GB | < 50 MB | Sì |
| B · 10 / 30 | 41.000 / 124.000 | 1,2 / 3,6 GB | < 100 MB | Sì (B30 al 72% dell'egress) |
| B · 50 | 207.000 | **6,0 GB** | < 100 MB | **No, per l'egress** |
| C · 10 / 30 / 50 | 301.000 / **902.000** / **1,5 milioni** | **7,8 / 23 / 39 GB** | < 200 MB | **No** (egress, e invocazioni da C30) |

Il database non è mai il limite: oggi pesa 14 MB, e i testi crescono di qualche kilobyte a viaggio.

**Quando passare a Pro.** Per i limiti, dagli scenari B50 e C10 in su. **Per prudenza, all'apertura della beta a persone esterne**, qualunque sia lo scenario, per tre motivi: i backup (C8); il progetto che non va in pausa nelle settimane senza viaggi; i registri di 7 giorni per capire cosa è successo. Se si tolgono i riquadri dall'egress, Pro torna a essere una scelta di sicurezza e non di capienza. Team non serve.

### 8.3 Gli altri servizi

| Servizio | Scelta per la beta | Costo | Verificato |
|---|---|---|---|
| **Email di accesso (SMTP)** | Resend Free: 3.000 email al mese, 100 al giorno, richiede un dominio | 0 $ | Sì |
| Notifiche push | APNs (con l'account Apple a pagamento) e FCM | 0 $ | FCM sì; APNs compreso nel programma Apple |
| Arresti e diagnostica | Firebase Crashlytics (gratis) oppure Sentry Developer (gratis, 5.000 errori) | 0 $ | Sì |
| Analisi | Già interne (tabella `evento`) | 0 $ | [codice] |
| **Dominio** | Proprio, per inviti ed email. Va preso prima degli inviti esterni ([punti-aperti.md](punti-aperti.md)) | **10–40 € l'anno** | **Prezzo non verificato** (stima di mercato) |
| **Pagine web** | Vercel Hobby, ammesso **solo per uso non commerciale**. Con pubblicità o acquisti: Vercel Pro (20 $ al mese) o un altro hosting statico gratuito che ammetta l'uso commerciale (da verificare) | 0–240 $ l'anno | Sì (Vercel) |
| Informativa e cookie | Le pagine sono già scritte (`sito/`). Facoltativo: iubenda Essentials, 4,99 € al mese su base annua, IVA esclusa | 0–60 € l'anno | Sì |
| Revisione legale | Necessaria prima dell'ondata 1 ([punti-aperti.md](punti-aperti.md)) | **Non stimata**: dipende dal professionista | — |
| Twilio Verify (Italia) | 0,05 $ a verifica riuscita più 0,0927 $ a SMS (anche se fallisce) | circa 0,19 $ per tester (1,3 tentativi) | Sì |
| Tassi di cambio | fawazahmed0 | 0 $ | [codice] |
| Geolocalizzazione esterna | Nessuna: il GPS è locale | 0 $ | [codice] |

### 8.4 IVA e valute

I prezzi qui sono netti. **Se le spese le sostiene una persona fisica senza partita IVA**, i fornitori applicano di norma l'**IVA italiana al 22%** sui servizi digitali: Supabase lo dice esplicitamente, in base all'indirizzo di fatturazione. **Con partita IVA** in genere si applica l'inversione contabile (*reverse charge*). L'Apple Developer Program in Italia mostra il prezzo in euro solo durante l'iscrizione: **99 $ ≈ 89 € netti**, ma il prezzo locale va letto lì. Il tasso USD/EUR può muovere i conti di qualche punto: con questi importi sono pochi euro.

---

## 9. Distribuzione

| Voce | Costo | Tipo | Note verificate |
|---|---|---|---|
| **Apple Developer Program** | **99 $ l'anno** (circa 89 € netti) | Ricorrente | Obbligatorio per TestFlight. TestFlight: fino a 10.000 tester esterni; la prima build passa dalla revisione beta; **ogni build dura 90 giorni**, quindi va ricaricata almeno ogni tre mesi. Per un'organizzazione serve il D-U-N-S, gratuito nella maggior parte dei paesi. Esenzione solo per enti non profit, scuole e enti pubblici |
| **Google Play Console** | **25 $ una volta sola** (circa 22,50 €) | Iniziale | Gli account personali nuovi devono fare un **test chiuso con almeno 12 tester per 14 giorni di fila** prima di andare in produzione. **Con 10 tester non basta per la produzione**, ma il test chiuso è proprio la beta |
| Commissioni sugli acquisti | Apple 15% (Small Business Program, sotto 1 milione $); Google: abbonamenti 10% + 5% di commissione di fatturazione nel SEE dal 30 giugno 2026 | Solo se si vende | Non è un costo della beta |
| Costi in più per TestFlight o Play | Nessuno | — | |

**Primo anno e anni successivi.** I 25 $ di Google si pagano una volta. Apple è annuale. Se l'iscrizione Apple parte a dicembre 2026, la quota del 2027 è la stessa: nessun doppio conteggio.

---

## 10. Pubblicità (AdMob)

### 10.1 Fattibilità [verificato]

- **Plugin:** `google_mobile_ads` 9.2.0, ufficiale (editore verificato google.dev), per Android e iOS. Formati: banner, nativi, interstitial e rewarded. Integrarlo vuol dire circa 1–2 giorni di lavoro più il consenso. Gli annunci nativi però vanno disegnati sulla tela (regola 9), e un banner rompe lo stile «Biglietti».
- **Annunci di prova:** ID di prova ufficiali, e i dispositivi registrati come dispositivi di prova. **Cliccare annunci veri fuori dal test può far segnalare l'account per attività non valida**, un rischio concreto con una beta di amici.
- **GDPR:** nel SEE e nel Regno Unito servono la **UMP SDK** di Google con un messaggio IAB TCF, il consenso verificato a ogni avvio (`requestConsentInfoUpdate`, `canRequestAds`) e un punto da cui rivedere la scelta. Senza consenso gli annunci sono **«limitati»**, con resa più bassa. Su iOS serve **App Tracking Transparency** per il tracciamento, e la scheda privacy dell'App Store deve dichiarare i dati raccolti dall'SDK.
- **Apple 2.5.18:** annunci adatti all'età, interstitial chiaramente marcati e con chiusura visibile, un modo per segnalare un annuncio inappropriato. **Gonfiare impression o clic è vietato** (3.2.2).
- **Pagamento AdMob:** soglia di **70 €**. Sotto la soglia il saldo si accumula e passa al mese dopo.
- **Coerenza con il prodotto:** [05-modello-di-business.md](discovery/05-modello-di-business.md) prevede freemium, pacchetto viaggio e abbonamento, e **nessun pagamento nell'MVP**. La pubblicità non è nel modello.

### 10.2 Ricavi stimati [ipotesi]

Non ho dati verificati di eCPM per l'Italia. Le fonti di terze parti (marketing, non ufficiali) collocano l'Italia nel secondo gruppo di paesi: banner circa 0,8–2 $, interstitial 6–10 $, rewarded 8–15 $. Il dato affidabile è il rapporto *eCPM Trends* dentro AdMob, che si legge solo con un account attivo.

| Livello | Impression per giorno d'uso | eCPM ipotizzato | Ricavo per giorno d'uso |
|---|---|---|---|
| Bassa | 3 nativi | 0,80 € (molti annunci limitati) | 0,0024 € |
| Media | 8 banner o nativi + 1 interstitial | 1,50 € e 6 € | 0,018 € |
| Favorevole | 12 banner o nativi + 1 interstitial + 1 rewarded | 2,50 €, 8 € e 12 € | 0,050 € |

**Ricavo annuo con l'uso B** (10 giorni al mese). Fra parentesi l'intervallo da A a C.

| | Bassa | Media | Favorevole |
|---|---|---|---|
| 10 tester | 3 € (1–5) | 22 € (9–35) | 60 € (24–96) |
| 30 tester | 9 € (3–14) | 65 € (26–104) | 180 € (72–288) |
| 50 tester | 14 € (6–23) | 108 € (43–173) | 300 € (120–480) |

**Quanta parte dei costi copre.** Con 30 tester e il budget probabile (circa 740 €): **1% nell'ipotesi bassa, 9% nella media, 24% nella favorevole**. Sotto i 70 € l'anno AdMob non paga nulla nel 2027.

**Pareggio** (formula F10). Fissi: circa 33 € al mese, cioè Supabase Pro più Apple e dominio annualizzati. Costo variabile di un utente B a regime: circa 0,31 € al mese, di cui mappe 0,18, AI 0,12 e Supabase 0,01.
- **Ipotesi media** (0,18 € di ricavo per utente al mese): **nessun pareggio**, perché il ricavo per utente è sotto il costo variabile. Con le mappe ottimizzate e l'AI leggera (circa 0,13 € per utente) servono **circa 700 MAU**.
- **Ipotesi favorevole** (0,50 € per utente al mese): **circa 170 MAU** così come sono le mappe oggi, circa 90 ottimizzandole.
- **Ipotesi bassa:** mai.

### 10.3 Alternative

- **Pacchetto viaggio a 9,99 €**, già nel modello di business: tolti IVA e il 15% Apple ne restano circa **6,96 €**. Ne bastano **circa 27 l'anno** per coprire il budget minimo, **circa 107** per quello probabile. **Non sono ricavi garantiti.**
- **AI come funzione a pagamento:** l'AI nativa costa da 0,03 a 0,45 $ al mese per persona, ma ha valore percepito alto. È il candidato naturale per il premium, accanto al copia-e-incolla gratuito che già funziona (11 itinerari incollati e 10 richieste esportate finora **[misurato]**).
- **Raccomandazione:** **niente pubblicità nella beta**. Se la si vuole provare, solo con annunci di prova, per misurare l'impatto sull'esperienza e non il ricavo.

---

## 11. I nove scenari

Valori in euro netti, **per 12 mesi allo stesso livello d'uso**. La configurazione è la **minima che funziona** per ogni scenario: Supabase Free dove i limiti lo permettono. Il costo dei backup è nel §12.

**Costi fissi annualizzati, primo anno** (formula F9): Apple 89,10 € + Google Play 22,50 € (una tantum) + dominio 15 € = **126,60 €**. **Anni successivi: 104,10 €.**
**Altri servizi:** verifiche Twilio, circa 0,26 € per tester all'anno. Email, notifiche, diagnostica e hosting restano a 0 €.
**Margine prudenziale:** 15% dei costi operativi.

| Tester | Uso | Mappe | Supabase | AI | Altri servizi | Fissi annualizzati | Totale annuo | Media mensile |
|---|---|---|---|---|---|---|---|---|
| 10 | A | 0 € (Free) | 0 € (Free) | 3 € | 3 € | 127 € | **133 €** | 11,1 € |
| 30 | A | 0 € | 0 € | 9 € | 8 € | 127 € | **146 €** | 12,2 € |
| 50 | A | 0 € | 0 € | 15 € | 13 € | 127 € | **159 €** | 13,3 € |
| 10 | B | 0 € | 0 € | 15 € | 3 € | 127 € | **147 €** | 12,2 € |
| 30 | B | 0 € | 0 € | 45 € | 8 € | 127 € | **187 €** | 15,6 € |
| 50 | B | 637 € (API 10) | 270 € (Pro) | 74 € | 13 € | 127 € | **1.270 €** | 105,9 € |
| 10 | C | 637 € (API 10) | 270 € (Pro) | 49 € | 3 € | 127 € | **1.229 €** | 102,4 € |
| 30 | C | 1.177 € (API 25) | 270 € (Pro) | 146 € | 8 € | 127 € | **1.968 €** | 164,0 € |
| 50 | C | 1.177 € (API 25 al limite) | 270 € (Pro) | 244 € | 13 € | 127 € | **2.086 €** | 173,8 € |

Il totale annuo comprende il margine del 15%. Con API 50 per C50, mappe a 1.933 € e totale circa 2.960 €.

| Tester | Uso | Operativo al mese | Operativo all'anno | Iniziali | Primo anno | Media mensile equivalente | Per tester al mese | Margine 15% | AdMob, ipotesi media | Netto dopo AdMob | Anni successivi |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 10 | A | 0,3 € | 6 € | 25 € | 133 € | 11,1 € | 1,11 € | 1 € | 9 € | 124 € | 111 € |
| 30 | A | 0,8 € | 17 € | 30 € | 146 € | 12,2 € | 0,41 € | 3 € | 26 € | 120 € | 124 € |
| 50 | A | 1,3 € | 28 € | 36 € | 159 € | 13,3 € | 0,27 € | 4 € | 43 € | 116 € | 137 € |
| 10 | B | 1,2 € | 17 € | 25 € | 147 € | 12,2 € | 1,22 € | 3 € | 22 € | 125 € | 124 € |
| 30 | B | 3,7 € | 53 € | 30 € | 187 € | 15,6 € | 0,52 € | 8 € | 65 € | 122 € | 164 € |
| 50 | B | 81,8 € | 994 € | 36 € | 1.270 € | 105,9 € | 2,12 € | 149 € | 108 € | 1.162 € | 1.248 € |
| 10 | C | 79,7 € | 959 € | 25 € | 1.229 € | 102,4 € | 10,24 € | 144 € | 35 € | 1.194 € | 1.206 € |
| 30 | C | 132,8 € | 1.602 € | 30 € | 1.968 € | 164,0 € | 5,47 € | 240 € | 104 € | 1.864 € | 1.945 € |
| 50 | C | 140,9 € | 1.703 € | 36 € | 2.086 € | 173,8 € | 3,48 € | 256 € | 173 € | 1.913 € | 2.063 € |

«Iniziali» comprende Google Play (22,50 €) e le prime verifiche Twilio. Sono **già dentro** il primo anno: non vanno sommati di nuovo. «Anni successivi» toglie Google Play.

**Due avvertenze:**
- Gli scenari A e B fino a 30 tester stanno nei piani gratuiti. Costano quasi solo Apple e dominio, ma **senza backup** (C8).
- Il salto fra B30 (187 €) e B50 o C10 (circa 1.250 €) è tutto nei due abbonamenti a gradino, Geoapify API 10 e Supabase Pro, e quasi tutto nei riquadri. **Ottimizzare i riquadri sposta il gradino più in là.**

---

## 12. I tre budget per il 2027

Riferimento: **30 tester**. Fra parentesi 10 e 50 tester.

| | **Minimo realistico** | **Probabile** | **Prudenziale** |
|---|---|---|---|
| Uso | B, con i riquadri ottimizzati | B tutto l'anno, con 4 mesi di picco (ponti ed estate) al 50% di tester in viaggio | C tutto l'anno |
| Supabase | Free (**senza backup**, rischio accettato) | **Pro tutto l'anno**: 270 € | Pro: 270 € |
| Geoapify | Free | Free, più **API 10 nei 4 mesi di picco**: 212 € | API 25 tutto l'anno: 1.177 € |
| AI | Mix leggero: 45 € | Mix consigliato: 45 € | Mix consigliato: 146 € |
| Altri servizi | 8 € | 8 € | 8 € |
| Fissi (Apple, Google Play, dominio) | 127 € | 127 € | 127 € |
| Margine | — | 15% dei costi operativi: 80 € | 25% dei costi operativi: 400 € |
| **Totale netto 2027** | **circa 190 €** (10: ~150 € · 50: ~225 €) | **circa 740 €** (10: ~455 € · 50: ~780 €) | **circa 2.130 €** (10: ~1.330 € · 50: ~3.200 € con API 50) |
| Media mensile | ~16 € | **~62 €** | ~178 € |
| Con IVA al 22% (persona fisica) | ~230 € | **~905 €** | ~2.600 € |
| Anni successivi (senza Google Play) | ~165 € | ~720 € | ~2.100 € |

Calcolo del probabile con 30 tester. Il picco dei mesi forti è (15 tester in viaggio × 144 crediti + 8 in pianificazione × 51) × 1,2 = 3.082 crediti al giorno: appena sopra il piano Free, quindi API 10 per 4 mesi (4 × 59 $ × 0,9 = 212 €). Supabase Pro costa 12 × 22,50 € = 270 €; AI 45 €; altri 8 €; fissi 127 €. Il subtotale è 662 €; il margine del 15% su 535 € di costi operativi aggiunge 80 €. Totale **742 €, cioè circa 740 €**.

---

## 13. Proiezione 2027 e anni successivi

- **Gennaio–marzo 2027** (pochi viaggi): Supabase Pro e piano Free di Geoapify. Circa 25 € al mese più i fissi.
- **Aprile–ottobre** (ponti ed estate): qui cadono i mesi di picco. Il piano Geoapify si cambia **mese per mese**, quindi si compra solo quando il picco misurato lo chiede.
- **Novembre–dicembre:** come gennaio.
- **2028 e dopo:** gli stessi costi meno Google Play (−22,50 €). Crescono con i tester. Per 100–200 utenti B regolari senza ottimizzare i riquadri, la stima è di 1.500–2.500 € l'anno, perché Geoapify sale ad API 25 o API 50. Con i riquadri ottimizzati, molto meno.
- **I prezzi cambiano:** Gemini 3.8 Flash raddoppia il 1° gennaio 2027, il Base Plan di HERE è salito del 6% ad aprile 2026, e Sentry cambia prezzi a dicembre 2026. **Conviene rileggere questo documento a marzo e a settembre 2027.**

---

## 14. Rischi

| Rischio | Probabilità | Impatto | Mitigazione |
|---|---|---|---|
| Pochi tester intensi esauriscono i 3.000 crediti giornalieri e **la mappa si ferma per tutti** | **Alta**: è già successo a una persona sola | Alto, durante un viaggio | Tetto complessivo (SEC-05), riquadri ottimizzati, API 10 pronto da attivare |
| I 304 si pagano su Geoapify | Media | Medio | Chiederlo a Geoapify; non contarli nel tetto |
| Geoapify blocca l'account per limiti superati spesso | Bassa | Alto | Cambiare piano appena il picco misurato si avvicina a 2.500 crediti |
| Egress oltre il piano Free per via dei riquadri | Alta dagli scenari B50 e C | Medio: con Free il servizio si limita | Supabase Pro, riquadri ottimizzati |
| **Nessun backup sul piano Free** | Certa | Alto | Pro all'apertura |
| Email di accesso bloccate dall'SMTP predefinito | Certa con tester esterni | **Bloccante** | Resend o un altro SMTP, più il dominio |
| Vercel Hobby e uso commerciale | Certa se arrivano pubblicità o pagamenti | Medio | Vercel Pro o un altro hosting |
| Costo dell'AI senza tetto (abusi, cicli) | Media | Basso o medio | Funzione sul server con tetto per persona e giorno, ed evento |
| I prezzi dell'AI cambiano (Gemini 3.8 ×2 nel 2027) | Certa per alcuni modelli | Basso | Un'interfaccia interna, modelli sostituibili |
| Il piano gratuito di Gemini non si può usare nel SEE | Certa | Basso | Usare il piano a pagamento fin dall'inizio |
| Dati OSM incompleti (piccoli locali, orari) | Media | Medio sulla qualità | Nome scritto a mano, Mappe del telefono |
| Annunci e beta di amici: clic non validi | Media | Account AdMob sospeso | Niente pubblicità reale nella beta |
| Google Play chiede 12 tester per 14 giorni | Certa con 10 tester | Rinvia la produzione, non la beta | Test chiuso |

---

## 15. Raccomandazioni e conclusione

### 15.1 La configurazione per la beta

1. **Mappe:** tenere **Geoapify** dietro la funzione `mappe`. Prima di comprare un piano:
   - chiedere a Geoapify se si possono tenere i riquadri per giorni e se i 304 si pagano;
   - smettere di contare i 304 nel tetto;
   - aggiungere un **tetto complessivo** (SEC-05).
   Trasporto pubblico, taxi e monopattini nella beta: **link alle app esterne**. Provare `transit` di Geoapify prima di costruirci sopra.
2. **Backend:** **Supabase Pro** dal giorno in cui entrano i tester esterni, con il tetto di spesa acceso.
3. **AI, quando arriva:** una funzione sul server con tetto ed evento. **`gpt-5-mini` per itinerari, modifiche e riprogrammazione; `gpt-5-nano` per spese, valigia e guide.** Gemini Flash-Lite a pagamento come alternativa equivalente. Output JSON strutturato, e ricerca web solo su richiesta esplicita. Il copia-e-incolla resta come strada gratuita.
4. **Servizi di contorno:** dominio proprio, Resend Free per le email, Crashlytics o Sentry gratuiti, APNs e FCM quando servono le notifiche dal server.
5. **Distribuzione:** Apple Developer Program (99 $ l'anno) e Google Play (25 $ una volta).
6. **Pubblicità:** non nella beta.

### 15.2 Quanto costa davvero mantenere 30 tester nel 2027

- **Uso regolare, configurazione consigliata:** **circa 740 € netti** (circa 62 € al mese), **circa 905 € con l'IVA**.
- Se i tester usano l'app poco: si scende verso **190 €**, ma senza backup.
- Se la usano tutti intensamente tutto l'anno, senza ottimizzare i riquadri: si sale fino a **circa 2.130 €** (circa 178 € al mese).

### 15.3 Quanto accantonare

**80 € al mese** (circa 960 € l'anno) coprono il budget probabile con l'IVA e un margine. Va aggiunta una **riserva da attivare a 180 € al mese** se nei mesi di picco il consumo `consumo_mappe` misurato supera i 2.500 crediti al giorno. Il segnale da guardare ogni settimana è uno solo: **i crediti Geoapify del giorno peggiore**.

---

## 16. Fonti e formule

### 16.1 Fonti (consultate il 25 novembre 2026)

| Fornitore | Servizio o SKU | Prezzo | Quota gratuita | URL |
|---|---|---|---|---|
| Geoapify | Piani Free, API 10, 25, 50, 100, 250 | 0 / 59 / 109 / 179 / 299 / 609 $ al mese | 3.000 crediti al giorno | https://www.geoapify.com/pricing/ |
| Geoapify | Crediti per API (riquadro 0,25; autocomplete 1; routing 1 per coppia di punti; Places 1 ogni 20 risultati) | — | — | https://www.geoapify.com/pricing-details/ · https://apidocs.geoapify.com/docs/maps/ |
| Geoapify | Modi di routing (`transit`, `scooter`, `bicycle`) | — | — | https://apidocs.geoapify.com/docs/routing/ |
| Geoapify | Condizioni (attribuzione, divieto di più account, eccedenze) | — | — | https://www.geoapify.com/term-and-conditions/ |
| Supabase | Free, Pro, Team; eccedenze | 0 / 25 / 599 $ al mese | Vedi §8.1 | https://supabase.com/pricing |
| Supabase | Edge Functions | 2 $ per milione oltre la quota | 500.000 / 2 milioni | https://supabase.com/docs/guides/functions/pricing |
| Supabase | SMTP predefinito | — | 2 email l'ora | https://supabase.com/docs/guides/auth/auth-smtp |
| Supabase | Calcolo e disco | Micro 10 $ al mese | — | https://supabase.com/docs/guides/platform/compute-and-disk |
| OpenAI | gpt-5-nano, gpt-5-mini, gpt-5.4-mini, ricerca web | Vedi §7.1 | — | https://developers.openai.com/api/docs/pricing |
| Google | Modelli Gemini, Grounding | Vedi §7.1 | Piano gratuito non usabile nel SEE | https://aistudio.google.com/docs/pricing |
| Google | Condizioni dell'API Gemini (SEE: solo a pagamento) | — | — | https://aistudio.google.com/docs/terms |
| Google Maps | SKU e quote per SKU | Vedi §5.1 | 10.000 / 5.000 / 1.000 | https://developers.google.com/maps/billing-and-pricing/pricing |
| Google Maps | Conservare i dati (coordinate 30 giorni, `place_id`) | — | — | https://developers.google.com/maps/documentation/places/web-service/policies |
| Mapbox | SDK mobile, Static e Vector Tiles, geocodifica, Search Box, Directions | Vedi §5.1 | Vedi §5.1 | https://www.mapbox.com/pricing |
| Mapbox | Profili di Directions (nessun trasporto pubblico) | — | — | https://docs.mapbox.com/api/navigation/directions/ |
| HERE | Base Plan | **Non verificato**: il sito rifiuta i lettori automatici. Geocodifica 0,83 $ per 1.000 da una pagina non datata | 30.000 al mese | https://www.here.com/get-started/pricing |
| Apple | Developer Program | 99 $ l'anno | — | https://developer.apple.com/programs/ |
| Apple | TestFlight | — | 10.000 tester, build di 90 giorni | https://developer.apple.com/testflight/ |
| Apple | Small Business Program | 15% | — | https://developer.apple.com/app-store/small-business-program/ |
| Google | Play Console | 25 $ una volta | — | https://support.google.com/googleplay/android-developer/answer/6112435 |
| Google | Test chiuso obbligatorio | 12 tester per 14 giorni | — | https://support.google.com/googleplay/android-developer/answer/14151465 |
| Google | Commissioni Play | Vedi §9 | — | https://support.google.com/googleplay/android-developer/answer/112622 |
| Twilio | Verify; SMS verso l'Italia | 0,05 $ a verifica + 0,0927 $ a SMS | — | https://www.twilio.com/en-us/verify/pricing · https://www.twilio.com/en-us/sms/pricing/it |
| Vercel | Hobby e Pro; uso commerciale | 0 / 20 $ al mese | — | https://vercel.com/pricing · https://vercel.com/terms |
| Resend | Free e Pro | 0 / 20 $ al mese | 3.000 email al mese | https://resend.com/pricing |
| Firebase | Crashlytics, FCM | 0 $ | — | https://firebase.google.com/pricing |
| Sentry | Developer | 0 $ | 5.000 errori | https://sentry.io/pricing/ |
| iubenda | Essentials | 4,99 € al mese su base annua, IVA esclusa | — | https://www.iubenda.com/en/pricing |
| AdMob | Plugin Flutter, annunci di prova, consenso | — | — | https://pub.dev/packages/google_mobile_ads · https://developers.google.com/admob/flutter/test-ads · https://developers.google.com/admob/flutter/privacy |
| AdMob | Soglia di pagamento | 70 € | — | https://support.google.com/admob/answer/2772208 |
| Banca d'Italia / BCE | Cambio dell'11 novembre 2026 | 1,1127 USD per euro | — | https://www.bancaditalia.it/compiti/operazioni-cambi/cambio/cambi_rif_20261111 |

**Da confermare prima di spendere:**
- il listino HERE;
- le righe Gemini segnate «dal riassunto»;
- se Geoapify fattura le risposte 304 e se permette di tenere i riquadri;
- il livello SKU degli orari di apertura su Google;
- il prezzo di un dominio;
- gli eCPM italiani (solo da AdMob, con un account attivo);
- l'egress reale di Supabase (pannello Usage).

### 16.2 Formule

Simboli: `gv` giorni in viaggio, `gp` giorni di pianificazione, `sv`/`sp` sessioni di mappa al giorno, `rv`/`rp` riquadri per sessione, `n` tester, `M` = 1,2 (margine per tentativi ripetuti e picchi).

- **F1 · Crediti Geoapify al mese per tester** = 0,25 × riquadri + 1,2 × ricerche + geocodifiche + percorsi di navigazione + percorsi dinamici + trasporto pubblico + orari + ricerche nei dintorni. I riquadri sono `gv·sv·rv + gp·sp·rp`.
- **F2 · Crediti in un giorno di viaggio** = 0,25·sv·rv + 1,2·ricerche al giorno + navigazioni al giorno + ricalcoli al giorno × tratti + trasporto pubblico al giorno + dintorni al giorno. Il risultato si limita a 710 con il tetto attuale.
- **F3 · Picco giornaliero** = M × [⌈n × quota in viaggio⌉ × min(710, F2) + ⌈n × quota in pianificazione⌉ × crediti di un giorno di pianificazione]. **Piano Geoapify** = il piano più piccolo con crediti al giorno ≥ F3.
- **F4 · Mapbox** = max(0, ricerche − 2.500) × 11,50/1.000 + (tappe salvate + geocodifiche) × 5/1.000 + max(0, percorsi − 100.000) × 2/1.000 + max(0, dintorni − 25.000) × 1,70/1.000. Per la variante con `flutter_map` si aggiunge max(0, riquadri − 200.000) × 0,50/1.000. Tutti i volumi si moltiplicano per n × M.
- **F5 · Google** = max(0, 1,5 × ricerche − 10.000) × 2,83/1.000 + max(0, 2 × salvate − 10.000) × 5/1.000 + max(0, orari − 1.000) × 20/1.000 + max(0, dintorni − 5.000) × 32/1.000 + max(0, percorsi + trasporto pubblico − 10.000) × 5/1.000. Il fattore 1,5 sulle ricerche viene da tre richieste per ricerca di cui metà senza scelta. Il fattore 2 sulle tappe salvate copre il rinnovo delle coordinate a 30 giorni. Per la variante con `flutter_map` si aggiunge max(0, riquadri − 100.000) × 0,60/1.000.
- **F6 · HERE (indicativo)** = per ciascun servizio max(0, volume − 30.000) × 0,83/1.000, con il trasporto pubblico × 10 transazioni.
- **F7 · Invocazioni Supabase** = n × M × (riquadri + 1,2 × ricerche + geocodifiche + percorsi + trasporto pubblico + orari + dintorni + chiamate AI).
- **F8 · Egress Supabase (GB)** = M × (n × riquadri × 25 KB + n × MB di REST) / 10⁶ KB per GB.
- **F9 · Totale annuo** = 12 × (mappe + Supabase + AI) × 0,90 + altri servizi + 15% dei costi operativi + fissi del primo anno (126,60 €).
- **F10 · MAU di pareggio** = costi fissi mensili / (ricavo pubblicitario per utente al mese − costo variabile per utente al mese). Il pareggio esiste solo se il denominatore è positivo.
- **AI:** costo per operazione = (token in × prezzo in + token out × prezzo out) / 10⁶. Costo mensile = M × Σ(operazioni × costo) + ricerche web × (0,010 $ + 3.000 × prezzo in / 10⁶).

Il calcolo è stato fatto con uno script Python temporaneo, fuori dal progetto, che applica esattamente queste formule ai parametri del §4. Ripetendolo con i parametri misurati nella beta si aggiornano tutte le tabelle.
