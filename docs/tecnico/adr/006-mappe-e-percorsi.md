# ADR-006 — Mappe, percorsi e il tetto alla spesa

**Stato**: accettata. Il fornitore è **Geoapify**, scelto alla realizzazione (fase 3.2, 4 ottobre 2026)

## Contesto

La navigazione è **dentro** Trolley: mappa, percorso disegnato, indicazioni passo passo, posizione in tempo reale. Servono tre cose dallo stesso ambito — riquadri di mappa, calcolo dei percorsi, ricerca dei luoghi — e tutte e tre si pagano a chiamata.

È il primo costo del prodotto che **cresce con l'uso** e non con le registrazioni: una persona che naviga tutto il giorno costa più di dieci che aprono l'app due volte. Va contro la regola che ci si è dati — *nessun costo variabile senza tetto* — e quindi il tetto fa parte della funzione, non è una precauzione successiva.

## Decisione

**Un fornitore solo per tutte e tre le cose, dietro un'interfaccia interna, con un tetto applicato dal client.**

**Un fornitore solo**: riquadri, percorsi e ricerca luoghi dallo stesso ambito. Due fornitori significano due integrazioni, due contratti e due comportamenti diversi sugli stessi dati.

**Dietro un'interfaccia interna**: nessuna schermata parla con il fornitore. Sostituirlo dev'essere un file.

**Il fornitore preciso si conferma alla realizzazione**, verificando condizioni e piani gratuiti nel momento in cui si integra — le tariffe di questo settore cambiano più in fretta di quanto invecchi un documento, e scriverne una qui significherebbe scrivere una cosa falsa fra sei mesi. I criteri di scelta, quelli sì, valgono: copertura delle tre funzioni, piano gratuito che regga la fase interna, plugin Flutter mantenuto, e possibilità di leggere il consumo in corso d'opera — senza quest'ultima il tetto non si può applicare.

## Il fornitore: Geoapify

Confermato alla realizzazione, come chiedeva questa decisione. Il criterio che ha deciso non era nell'elenco, e va aggiunto: **le coordinate di un luogo cercato si devono poter conservare.** La tappa le tiene sul server, perché la vedano tutti i partecipanti e perché restino senza rete ([01](../01-modello-dati.md), [ADR-005](005-dati-geografici.md)). Su questo i fornitori si dividono:

| | Riquadri, percorsi, ricerca | Conservare le coordinate di un posto cercato | Piano gratuito | Perché no |
|---|---|---|---|---|
| **Geoapify** (dati OpenStreetMap) | Tutti e tre, indicazioni in italiano | **Sì, senza limiti** | 3000 crediti al giorno, senza carta, uso commerciale con l'attribuzione | — |
| Mapbox | Tutti e tre | No: i risultati della Search Box sono temporanei; la geocodifica permanente non ha i luoghi con un nome | 25 000 utenti al mese, carta richiesta | La tappa perderebbe le coordinate |
| Google Maps | Tutti e tre, i dati migliori sui luoghi | Al massimo 30 giorni; per sempre solo l'identificativo del luogo | 10 000 chiamate al mese per tipo, carta richiesta | Le coordinate andrebbero richieste di continuo |
| Apple MapKit | Tutti e tre, gratis | Incerto | Senza conto | Solo iOS, aspetto non modificabile (la tela no), plugin Flutter poco curato |

Il punto debole di Geoapify è nei dati: un negozio piccolo a volte non è su OpenStreetMap. Per quel caso la tappa si crea con il nome scritto a mano (ADR-005), e «Apri in Mappe» consegna il nome alle Mappe del telefono.

**Come si usa.**

- **Riquadri**: raster, lo stile `positron` (grigio chiaro con le strade bianche, il più vicino alla carta della tela; `positron-blue` è troppo blu), disegnati da **flutter_map**, che è tutto Flutter: i segni sopra la mappa sono widget, con i caratteri e i colori della tela, letti da VoiceOver, e le prove li vedono. Un riquadro costa un quarto di credito.
- **Ricerca**: `/v1/geocode/autocomplete` in italiano, quando si smette di scrivere e da tre lettere in su. Si cerca **entro 40 km** dalle tappe del viaggio o dalla sua meta (`filter=circle`), e solo se lì non c'è niente, ovunque: provata il 5 ottobre 2026, la sola vicinanza (`bias=proximity`) pesa poco — «majestic» dava gli Stati Uniti prima del Café Majestic di Porto. Un credito a ricerca, due col ripiego.
- **Percorsi**: `/v1/routing` a piedi, con le indicazioni in italiano e `details=instruction_details`: senza, le indicazioni hanno il testo ma non il tipo di svolta. Un credito a percorso. La posizione al fornitore va solo come partenza di un percorso chiesto dalla persona.
- **La chiave** non sta nel codice: il repository è pubblico. Si passa alla compilazione da `app/chiavi.json`, fuori da git (`--dart-define-from-file=chiavi.json`). Senza chiave la mappa degrada come senza rete.
- **L'attribuzione** «Powered by Geoapify · © OpenMapTiles · © OpenStreetMap» sta sulla mappa e sotto la ricerca.
- **Tutto passa da `app/lib/dati/mappe.dart`**: l'interfaccia `Mappe`, Geoapify dietro. La posizione del telefono sta dietro `Posizione` (`dati/posizione.dart`), le Mappe del telefono dietro `MappeDelTelefono` (`dati/mappe_del_telefono.dart`).

## Il tetto

1. **Un limite di chiamate per viaggio e per persona**, non un limite globale: un tetto complessivo lo esaurirebbe il primo utente attivo e romperebbe l'app a tutti gli altri.
2. **Al raggiungimento la navigazione degrada**, non si spegne: restano mappa e tappe, si consegna all'app di mappe del telefono per la guida. Chi sta viaggiando non resta mai senza indicazioni per una questione di budget — è la stessa regola per cui nessun limite commerciale tocca un viaggio in corso.
3. **Il consumo si misura**, per persona e per viaggio, e va guardato dal primo giorno: serve a sapere quanto costa davvero una persona che viaggia, che oggi è un numero che nessuno conosce.
4. **I riquadri di mappa già scaricati si tengono in cache** per la sessione: è la riduzione più facile e non cambia niente per chi usa l'app.

Nella fase interna — il team, una decina di persone — i piani gratuiti bastano e la valutazione è rimandata di proposito. **Il tetto è prerequisito per aprire fuori dal team**, non per la prima riga di codice.

**Cosa c'è dalla fase 3.2.** Il consumo si conta sul telefono — i riquadri scaricati davvero (quelli già in memoria non si pagano), le ricerche, i percorsi — e si registra con l'evento `consumo_mappe`, per viaggio, quando si chiude la mappa, la navigazione o la ricerca ([07](../07-misurazione.md)): la persona è quella dell'evento. Una navigazione non chiede più di otto strade nuove, una ogni venti secondi al massimo; oltre, consegna alle Mappe del telefono. I riquadri si tengono in una memoria sul telefono (fino a 200 MB, che il sistema può svuotare): oltre la sessione, ma senza diventare le mappe scaricabili che il prodotto lascia fuori ([08](../../prodotto/08-mappa.md)) — senza rete la mappa non si mostra comunque. **Il limite per persona e per viaggio non c'è ancora**: si fissa guardando i numeri della fase interna, prima di aprire fuori dal team ([punti aperti](../../punti-aperti.md)).

## Conseguenze

- **La navigazione è l'unica funzione dell'app con un limite tecnico**, e quel limite va progettato bene: degradare con grazia è parte della funzione.
- **Il consumo per persona diventa un'unità economica**, accanto al ricavo per persona: è il primo costo di Trolley che si può attribuire a un singolo utente.
- **Se il fornitore cambia condizioni**, l'interfaccia interna limita il danno a una sostituzione — purché nessuno la aggiri per comodità, il che succede sempre se non c'è una revisione che lo impedisce.
