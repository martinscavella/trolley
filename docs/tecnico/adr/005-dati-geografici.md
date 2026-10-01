# ADR-005 — Dati geografici

**Stato**: accettata

## Contesto

Servono per due cose molto diverse:

1. **Destinazioni e mappamondo** — scegliere "Lisbona, Portogallo" quando si crea un viaggio, e grattare paesi e città sul mappamondo. Insieme chiuso, valori stabili, serve **anche senza rete** perché la destinazione fa parte dei dati base del viaggio.
2. **Luoghi delle tappe** — "quel ristorante", "il museo": insieme aperto, sterminato, e nessuno se lo aspetta senza rete.

Trattarli come un problema solo porta a sbagliarne uno dei due.

## Decisione

**Due strade separate.**

**Per destinazioni e mappamondo: un elenco incorporato nell'app.** Paesi e città principali, con coordinate e codice del paese. Pesa poco, funziona senza rete, costa zero per sempre e non dipende da nessuno. Si aggiorna con i rilasci, cosa che per l'elenco dei paesi del mondo è una cadenza più che sufficiente.

**Per i luoghi delle tappe: la ricerca del fornitore di mappe**, quello già scelto in [ADR-006](006-mappe-e-percorsi.md). Richiede rete, ed è accettabile: si aggiunge una tappa mentre si pianifica, non mentre si è persi in una città senza segnale.

## Conseguenze

- **Il mappamondo non dipende da nessun servizio esterno.** La parte del prodotto che deve durare anni — la storia di viaggio di una persona — non poggia su un fornitore che può cambiare condizioni.
- **Una tappa può esistere senza coordinate.** Se la ricerca non trova il luogo o non c'è rete, la tappa si crea lo stesso con il solo nome: resta nell'itinerario, non compare sulla mappa, e si può completare dopo. Una funzione che rifiuta un inserimento perché manca la rete sarebbe contro il principio di tutta l'architettura.
- **Le destinazioni sono un insieme chiuso**, quindi il mappamondo non dovrà mai indovinare a quale paese appartiene una città.
- **Una città scritta a mano che non è nell'elenco** non gratta il mappamondo. È un caso da gestire nell'interfaccia, non da nascondere.

## Realizzazione

- **Le fonti non chiedono attribuzione.** Paesi e settemila città del mondo da **Natural Earth** (pubblico dominio, versione fissata: rigenerare dà lo stesso elenco), con i nomi in italiano — Lisbona, Monaco di Baviera. I **comuni italiani** da **Wikidata** (CC0), perché Natural Earth ne ha una cinquantina: Firenze sì, Matera e Positano no. Chi fa una gita di un giorno cerca spesso un paese piccolo.
- **Lo scrive `app/tool/genera_destinazioni.dart`**, che scarica le fonti e produce `app/assets/destinazioni.tsv` (paesi e città per la ricerca, circa 650 KB) e `app/lib/dati/paesi.dart` (i nomi dei paesi, per scriverli senza caricare l'elenco).
- **La ricerca è tollerante e pesa la probabilità.** Maiuscole, accenti e apostrofi non contano; si trova anche col nome inglese (Munich, Florence). Conta come corrisponde — il nome intero, l'inizio, l'inizio di una parola — e quanto è grande e vicina la meta: chi usa l'app è italiano, quindi Valencia è in Spagna prima che in Venezuela, e "roma" dà Roma, poi la Romania.
- **I comuni omonimi si distinguono con la provincia** (Samone TO e Samone TN), le città omonime nello stesso paese con la regione. Gli stati-città compaiono una volta sola, come paese.
- **Quello che l'elenco non conosce si scrive com'è**, e poi si sceglie il paese — o nessuno, dicendo che sul mappamondo non comparirà. Si va anche in un paese intero, senza città.
- Per ora il viaggio conserva solo il nome e il codice del paese: le coordinate stanno nell'elenco, e si ritrovano da lì quando serviranno a mappa e verifica.
