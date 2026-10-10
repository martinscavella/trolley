# 06 — Privacy e conformità

Trolley tratta **documenti d'identità** e **dati che rivelano gli spostamenti di persone fisiche**, e mette in contatto **sconosciuti**. Sono le tre cose che alzano di più il profilo di rischio, e messe insieme non si compensano: questo capitolo non è una formalità di fine progetto.

> Le scelte qui descritte sono ragionate, non certificate. Prima di aprire fuori dal team vanno **confermate da un avvocato**: è il punto del progetto in cui quella spesa si ripaga da sola.

---

## Cosa si tratta, e dove sta

| Dato | Dove | Nota |
|---|---|---|
| Email, data di nascita | Server | Necessari per l'account e per l'età |
| Numero di telefono | Server, schema privato | Solo per chi attiva la parte pubblica. Lo verifica Twilio con un codice SMS, attraverso la nostra funzione `telefono` ([ADR-011](adr/011-verifica-del-telefono.md)); non lo legge nessun altro, e chiudendo l'account si cancella |
| Blocchi e segnalazioni | Server | Chi blocca chi lo sa solo chi blocca; chi segnala chi lo sa solo chi modera. La segnalazione conserva il contenuto segnalato com'era (5.1) |
| Viaggi, tappe, spese, liste | Server | Rivelano dove una persona è stata e con chi |
| **Documenti d'identità e biglietti** | **Solo telefono** | Non esiste un endpoint che li accetti |
| **Posizione durante la navigazione** | **Solo telefono** | Va al fornitore di mappe (Geoapify) solo come partenza di un percorso chiesto dalla persona, mai a noi. Si chiede «mentre si usa l'app», mai in sottofondo, e solo per un viaggio in corso o per farsi portare a una tappa |
| **Posizione per la verifica** | **Solo telefono** | Il confronto con la meta lo fa il telefono, con l'elenco delle destinazioni che ha dentro (ADR-005): nessun fornitore la vede. Al server arriva solo il sì, con il momento (`partecipazione.sul_posto_il`), una volta per viaggio. Si guarda solo mentre il viaggio è in corso, e solo finché non si è trovato il sì |
| Presenza in città | Server | Ricavata dalla destinazione del viaggio, non dalla posizione rilevata. Cancellata a fine viaggio |
| Eventi di misurazione | Server | Azioni, mai contenuti |

**La riga che vale più di tutte le altre**: l'architettura è fatta in modo che i dati più delicati non ci arrivino proprio. Non è una promessa di buona condotta, è un'assenza di strada.

---

## Età

- **16 anni** per l'account. Il GDPR fissa il consenso autonomo per i servizi online a 16, lasciando agli Stati la facoltà di scendere fino a 13 — l'Italia è a 14. Tenere 16 evita la logica per paese e non costa niente su un pubblico di adulti.
- **18 anni** per profilo pubblico, matching e messaggi.
- Data di nascita raccolta alla registrazione, **non modificabile dalla persona**.
- Dichiarazione, non verifica documentale: è la misura proporzionata.
- **Nessuna pubblicità profilata**, a nessuna età.

---

## Conservazione

| Dato | Per quanto |
|---|---|
| Viaggi, anche chiusi | **Finché la persona non li cancella.** Nessuna cancellazione automatica |
| Presenza in città | Fino alla fine del viaggio, poi cancellata |
| Segnalazioni e contenuti segnalati | Il tempo necessario a gestirle, più il periodo utile a difendersi da una contestazione: il periodo è da fissare con l'avvocato, e manca il lavoro che le toglie. Chiudendo l'account le proprie restano, senza più diventare eventi a proprio nome |
| Numero di telefono | Finché c'è l'account; i tentativi di verifica una settimana |
| Eventi di misurazione | Aggregati oltre un orizzonte breve: non servono a lungo nel dettaglio |
| Conto delle mappe per il tetto | Una settimana: serve solo a sapere se oggi si è sotto il tetto ([ADR-006](adr/006-mappe-e-percorsi.md)). Quante chiamate, mai dove né cosa |
| Account chiuso | Dati personali cancellati, e l'accesso con loro; i viaggi in cui si era da soli cancellati; i contributi nei viaggi altrui restano, attribuiti a un partecipante non più presente («Account chiuso»). Gli eventi di misurazione restano sotto un id nuovo che non porta alla persona; quelli di un account interno si cancellano |

L'ultima riga va spiegata alla persona **prima** che chiuda l'account: le spese che ha pagato non si cancellano dai saldi altrui, perché sparire non estingue un debito.

---

## Diritti delle persone

- **Esportazione sempre gratuita**, in un formato leggibile da una macchina. È un diritto, non una funzione a pagamento: la reimportazione invece è un servizio e può essere premium. Dal profilo, «I tuoi dati»: un file JSON con il profilo, i viaggi come la persona li vede, i traguardi e gli eventi (U.1; [decisioni](../decisioni/prodotto.md)).
- **Cancellazione dell'account** raggiungibile dall'app, non solo scrivendo a un indirizzo. Dallo stesso posto, dopo aver detto che cosa succede (`chiudi_account`).
- **Pagina leggibile su cosa si misura**, con la possibilità di rifiutare senza perdere funzioni: `sito/misurazione.html`, su `trolleyapp.vercel.app/misurazione`, aperta dal profilo (U.3).
- **Informativa** in `sito/privacy.html`, su `trolleyapp.vercel.app/privacy`: dall'accesso, prima di creare l'account, e dal profilo. In bozza, con le domande per l'avvocato in [per la revisione](../legale/per-la-revisione.md).
- **Condizioni d'uso della parte pubblica** in `sito/condizioni.html` (5.1): si accettano accendendo il profilo pubblico, e il server ricorda quale versione. Sono le regole che la moderazione fa rispettare, numerate.
- **Il motivo di una sospensione** lo legge la persona sospesa, nel suo profilo pubblico, con a chi scrivere se pensa che sia un errore.

---

## Le due valutazioni d'impatto probabili

Due funzioni, per conto loro, fanno scattare l'obbligo di valutare formalmente l'impatto sulla protezione dei dati:

1. **La presenza in città**, perché mette in relazione persone in base a dove si trovano. È mitigata parecchio dal fatto che la città arriva dalla destinazione del viaggio e non dalla posizione rilevata, e che non esiste storico — ma va scritta, non dedotta.
2. **Il matching fra sconosciuti**, per la combinazione di dati sociali e rischio sulle persone.

Vanno fatte **prima** della seconda ondata, non dopo.

---

## Fornitori

Ogni servizio esterno è un responsabile del trattamento e va nell'informativa: mappe e percorsi, invio SMS (Twilio Verify, dalla 5.1: riceve solo il numero, dal nostro server), tassi di cambio, e — se scelto — il servizio per il deep link differito.

Le mappe passano dal nostro server (U.2): il fornitore riceve le zone guardate, il testo cercato e i capi di un percorso, ma non l'indirizzo del telefono né chi chiede. Ricerche e percorsi viaggiano nel corpo delle richieste, fuori dai registri del server; le zone di mappa sono nell'indirizzo di ogni riquadro, e i registri delle funzioni di Supabase le tengono per il loro breve periodo.

Il fornitore dei modelli per la generazione dell'itinerario **non è nostro fornitore**: è la persona che porta il prompt sul proprio assistente, con il proprio account. È una delle ragioni per cui l'MVP funziona così.
