# Decisioni di prodotto

Le scelte già prese, con il motivo per cui sono state prese. Non sono ipotesi da validare: il costo è accettato in partenza e non serve un test per autorizzarle.

Vivono qui e non dentro i documenti di discovery perché una decisione non è una domanda: metterle insieme rendeva illeggibili entrambe.

---

## Struttura del viaggio

### Due stati: idea e definito

Date e orari **non sono obbligatori per creare** un viaggio: bastano la destinazione e un periodo qualsiasi ("agosto", "un weekend di primavera") e il viaggio esiste. È così che la fase "decisione" sta in piedi accanto allo scheletro.

Diventano obbligatori per passare allo stato **definito**, ed è quel passaggio a sbloccare il resto del prodotto.

| | Stato **idea** | Stato **definito** |
|---|---|---|
| Cosa serve | Destinazione e un periodo approssimativo | Date, giorni, orari di arrivo e partenza |
| Cosa c'è dentro | Compagni invitati, elenco di posti e idee, budget di massima, note | Tutto: itinerario per giornate, documenti agganciati ai giorni, spese, fase live |

Il criterio è uno solo: **entra nello stato idea tutto ciò che non ha bisogno di un giorno preciso.** Quello che un giorno preciso lo richiede aspetta.

### Le idee non scadono, si archiviano

Nessuna cancellazione: un'idea costa pochi byte e cancellare i progetti di qualcuno è il modo più veloce di perdere la sua fiducia. Nessun limite al numero di idee aperte.

Un'idea è **abbandonata** quando il periodo che indica è passato senza che sia diventata definita — niente timeout arbitrario, così un'idea nata a gennaio per agosto resta viva sette mesi, com'è giusto. Per le idee senza nessun periodo indicato, 12 mesi.

A quel punto, dopo un sollecito ("questo viaggio è ancora un'idea?"), l'idea finisce **in archivio**: resta consultabile e recuperabile, ma sparisce dalla vista principale, che così rimane pulita.

I 12 mesi del piano gratuito partono dalla **chiusura** del viaggio, quindi un'idea non si chiude mai e non viene mai alleggerita.

### Tetto strutturale alle tappe, invece di un campanello d'allarme

Nessun monitoraggio di chi mette troppe tappe: ognuno riempie il viaggio come vuole. Il limite è nel modello — ogni tappa ha un tempo stimato, e se la somma sfora la giornata la tappa non si aggiunge.

E il tetto non è un generico "24 ore": è **la finestra reale del giorno**, che lo scheletro conosce già dagli orari di arrivo e partenza. È l'esempio migliore del perché lo scheletro viene prima di tutto il resto.

*Da risolvere in fase di design*: se il tempo stimato è obbligatorio diventa un campo in più sul gesto più frequente dell'app — esattamente quello che H2 misura. Va precompilato con una durata sensata da correggere, non chiesto a vuoto.

### Modello paritario tra i partecipanti

Chiunque partecipi al viaggio può aggiungere e modificare — spese, cose da portare, tappe, documenti — e matura gli stessi traguardi di chi il viaggio l'ha creato.

Il modello è paritario **sui contenuti**, non sull'amministrazione: **rimuovere un partecipante è potere di chi ha creato il viaggio**, e solo suo. È l'unica asimmetria dell'MVP, e serve perché in un gruppo davvero paritario non esisterebbe nessuno legittimato a chiudere una situazione che va male.

L'organizzatore con poteri estesi su tutto resta invece una tipologia di viaggio a parte (viaggi di gruppo organizzati da un ente, dove l'invitato segue e non modifica) e non è nell'MVP.

### Conflitti mostrati, non risolti di nascosto

Quando due persone modificano lo stesso punto del viaggio si mostrano le due versioni affiancate e si fa scegliere, come un diff. Chi salva per primo su un viaggio vuoto fa semplicemente il primo salvataggio; dal secondo in poi si confronta.

È la risposta al costo che il modello paritario ha aggiunto a H4: con più autori e poca rete i conflitti esistono davvero, e una fusione automatica silenziosa fa sparire il lavoro di qualcuno senza che se ne accorga. Il dettaglio si progetta insieme al modello di sincronizzazione, nella documentazione tecnica.

---

## Itinerario generato

### Prompt in uscita, risultato incollato indietro

Nell'MVP Trolley non chiama nessun modello. Costruisce un prompt dettagliato a partire dallo scheletro del viaggio, l'utente lo porta sull'LLM che già usa e paga, e incolla indietro il risultato: Trolley lo interpreta e lo rende leggibile — giorni, orari e luoghi agganciati alla mappa e alle spese. La chiamata nativa all'API arriva nella versione validata, quando esiste un budget che la regge.

Tre ragioni, in ordine di peso:

1. In beta il budget è zero, e un costo per chiamata è **variabile e senza tetto**: un ciclo sbagliato o un client manomesso si scoprono a bolletta arrivata. È la variabilità, più del livello — $20–70 l'anno a volumi da beta — a renderlo inaccettabile adesso.
2. Evita il **backend proxy**, che era la dipendenza vera dell'integrazione nativa: la chiave API non può stare nell'app, e dietro al proxy vengono quote, anti-abuso e un server da mantenere.
3. I dati del viaggio li manda l'utente dal proprio account, quindi non si aggiunge un responsabile del trattamento all'informativa — che con i documenti d'identità già in gioco non è una formalità.

Il prezzo è un cambio di app in mezzo al percorso. **Ciò che lo rende accettabile è il ritorno**: se il risultato non rientrasse in Trolley, la persona resterebbe a scorrere un muro di testo dentro l'LLM, che è esattamente l'esperienza da battere. Il parsing dell'incollato non è idraulica, è la funzione.

### Regola di decisione asimmetrica, scritta prima di guardare i numeri

Il giro manuale misura la domanda di itinerario generato, ma la misura bene **in una sola direzione**. Chi accetta di cambiare app, incollare e tornare indietro dimostra di volere quella funzione molto più di chi premerebbe un pulsante.

- **Utilizzo alto** = la generazione nativa è dimostrata, si costruisce appena c'è budget, senza altri test.
- **Utilizzo basso** = nessuna conclusione, perché non si distingue "non voglio un itinerario generato" da "non faccio il copia-incolla su un telefono". Non si cancella la funzione: si prova a cambiarne la forma — meno passaggi, ritorno più semplice — e si rimisura.

### Quali modelli suggerire

Si indicano modelli di **fascia medio-alta** — il livello dei modelli a pagamento dei principali assistenti, non quelli gratuiti e leggeri — perché un itinerario mediocre torna indietro come colpa di Trolley. Riferimento al momento in cui scrivo: **Claude Sonnet 5 o superiore** come soglia minima di qualità, e i modelli di punta equivalenti degli altri assistenti.

Due accorgimenti contano più della lista stessa:

1. L'elenco **non va scritto dentro l'app** ma letto da una configurazione aggiornabile da remoto. Altrimenti al primo cambio di nomi si consigliano modelli che non esistono più, e per correggere serve un rilascio su App Store.
2. Un avviso esplicito che il risultato lo produce un servizio di terzi e che Trolley non risponde della sua qualità — tenendo presente che la tutela vera non è la scritta, è che tutto ciò che arriva resta modificabile.

### Dove va speso il tempo, funzione per funzione

Non tutte le funzioni aggregate devono battere lo specialista.

| Funzione | Ambizione | Perché |
|---|---|---|
| Cose da portare | **Alla pari o meglio** | È semplice da fare bene, e legata alle date del viaggio e ai compagni è già superiore a una nota generica |
| Divisione delle spese | **Alla pari o meglio** | Stessa ragione, ed è la funzione che gli invitati toccano per prima: è lì che si gioca H3 |
| Generazione dell'itinerario | **Buona** | Non deve battere nessuno, deve non deludere |
| Documenti | **Alla pari** | Il valore è averli offline nel momento giusto, non la gestione dei file |
| Mappa e navigazione | **Utile, non la migliore** | C'è nell'MVP, navigazione compresa: vedi dove sono le tappe del giorno e ti ci porti. Non prova a battere le mappe di Google sulla qualità dei dati o sulla guida passo passo — ma sa una cosa che loro non sanno, cioè che quei punti sono le tappe di *questo* viaggio, in *questo* giorno |

---

## Community e sicurezza

### Matching nella prima release

Trovare altri viaggiatori entra nella beta: senza, la beta attraverserebbe dodici mesi senza sapere niente sul differenziatore.

Ne consegue che i presidi di sicurezza — segnalazione, blocco, verifica dell'identità, nessuna esposizione dei viaggi futuri, processo di moderazione scritto per una persona sola — sono lavoro **della prima release**. La stima è in [Punti aperti](../punti-aperti.md).

### Modalità "chi c'è adesso in città": dentro, ma smussata

Entra anch'essa nella beta, in una versione deliberatamente ridotta. Il codice è poca cosa; la responsabilità no.

**Quello che entra:**

- granularità **solo città** — mai coordinate, mai distanza, mai un puntino sulla mappa
- **attivazione esplicita per singolo viaggio**, spenta di default
- si spegne da sola alla fine del viaggio
- visibile solo a chi a sua volta l'ha attivata
- nessuno storico: non si può sapere dove eri ieri

**Quello che resta fuori** è ciò che la renderebbe pericolosa: posizione continua in background, distanza, mappa, cronologia.

Con questi paletti sono pochi giorni di lavoro invece di una funzione da riprogettare. Va però messo nel conto che **posizione in tempo reale più sconosciuti** è la combinazione che più probabilmente richiede una valutazione d'impatto sulla protezione dei dati formale.

### Collegamento reciproco, non seguito unilaterale

Ci si collega come su LinkedIn: uno chiede, l'altro accetta, e solo allora esiste un contatto. Niente seguito alla Instagram, dove si accumula un pubblico senza che nessuno abbia detto di sì.

È prima di tutto una scelta di sicurezza — il consenso è la porta d'ingresso e non un'impostazione da andare a cercare — e di conseguenza è anche la definizione di "contatto che arriva a qualcosa" nelle metriche di H7.

### Verifica dell'identità: numero di telefono

**Numero di telefono verificato** per attivare il profilo pubblico e il matching. È una barriera reale — creare account falsi in serie costa qualcosa — senza essere ostile, ed è lo standard di fatto delle app che fanno incontrare persone.

Niente documento d'identità: costa, allontana, e metterebbe in mano dati che non conviene custodire. L'email verificata da sola non basta per la parte pubblica.

*Nota di costo*: la verifica via SMS si paga a messaggio. È un costo variabile, ma **limitato dal numero di registrazioni** e non dall'uso, quindi molto più prevedibile di una chiamata a consumo. Va comunque messo un tetto.

### Età minima: 16 per l'app, 18 per la parte pubblica

**Il quadro normativo.** Il GDPR (art. 8) fissa a **16 anni** l'età in cui un minore può prestare da solo il consenso per i servizi della società dell'informazione, lasciando agli Stati la facoltà di abbassarla fino a 13: **l'Italia l'ha portata a 14**. Chi pubblica nell'Unione si trova quindi una soglia che cambia da paese a paese fra 13 e 16.

**La scelta.** Tenere **16 anni per l'app** evita del tutto la logica per paese — che per una persona sola è lavoro vero — e non costa niente sul pubblico di riferimento, visto che chi organizza viaggi ha trent'anni.

**18 anni per profilo pubblico, matching e messaggi.** Mettere in contatto sconosciuti perché viaggino insieme ricade nella stessa categoria delle app di incontri, che su App Store stanno a 17+/18+. Con minorenni raggiungibili cambierebbero classificazione, obblighi e livello di attenzione della revisione.

**Come si applica.** Data di nascita raccolta alla registrazione e non modificabile dall'utente da sola. Dichiarazione, non verifica documentale: è lo standard ed è proporzionato. Nessuna pubblicità profilata — non è prevista, ma va scritto, perché il DSA la vieta verso i minori.

> Questo è il punto in cui vale la pena farsi confermare le scelte da un avvocato prima del lancio. Trolley tratta documenti d'identità **e** mette in contatto sconosciuti: sono le due cose che alzano di più il profilo di rischio, e messe insieme non si compensano.

### Nessun controllo automatico sul tasso di accettazione

Chi manda molte richieste senza risposta non fa scattare niente: è lo stesso comportamento di chi segue cento profili privati su un social senza ricevere nulla indietro. Il numero resta visibile in aggregato come indicatore di salute, e la verifica manuale scatta sulle **segnalazioni**, non sui volumi.

---

## Inviti, documenti, valute

### Invito: un link, e il viaggio si apre dopo l'installazione

Si invita condividendo un **link** con i mezzi normali del telefono — messaggi, chat, email. Il link apre l'app se è installata; se non lo è porta alla pagina su App Store, e dopo l'installazione l'app apre direttamente il viaggio a cui si era invitati.

Tecnicamente serve un **deep link differito**: dopo l'installazione l'app deve sapere a quale viaggio si riferiva il link toccato prima di scaricarla. Non è gratis, è un meccanismo da scegliere e da provare, ed è il genere di cosa che si rompe in silenzio. Siccome H3 è l'unico canale di acquisizione, se quel pezzo non funziona non c'è crescita: va provato per primo e sorvegliato sempre.

**Conseguenza sulla soglia di H3**: l'invitato **non vede il viaggio prima di installare**. Decide di scaricare sulla fiducia in chi lo invita e su quello che promette la pagina dello store, non su un'anteprima del contenuto. È la variante più esigente, e va tenuta presente quando si legge il 35%.

### Documenti: solo sul telefono

I documenti stanno in una cartella locale dell'app, non su un server.

**Quello che si guadagna**: nessun archivio da proteggere, nessun costo di archiviazione che cresce con gli utenti, e una superficie GDPR molto più piccola proprio sul dato più delicato che l'app tratta. Il backup di sistema del telefono li porta sul dispositivo nuovo, quindi cambiare telefono non li perde.

**Quello che si perde, consapevolmente**: in un viaggio condiviso **i documenti non si condividono**. Se è Giulia a prenotare per tutti, il biglietto di Marco resta sul telefono di Giulia e Marco continua a riceverlo in chat.

È una rinuncia accettata, non una svista. Trolley risolve il problema di **ritrovare** un documento nel momento peggiore — in aeroporto, senza rete, con l'imbarco fra dieci minuti — non quello di passarselo. Le alternative (un archivio nostro da proteggere, oppure un passaggio diretto fra telefoni) costavano entrambe più di quanto quel pezzo di problema valga, e la prima rimetteva in piedi proprio l'archivio di documenti d'identità che questa scelta serve a non avere.

### Valuta e cambio: servizio esterno, ultimo valore noto offline

Il tasso di cambio arriva da un servizio esterno. Senza rete si usa **l'ultimo tasso recuperato**, dicendo esplicitamente che il valore può essere cambiato perché non è in tempo reale.

Due conseguenze: il tasso più recente entra nell'insieme dei dati essenziali offline di H4, e il servizio diventa la terza dipendenza esterna del prodotto dopo l'invio degli SMS e lo store — con un costo che, se il piano gratuito del fornitore non basta, torna a essere variabile.

---

## Ricordo e traguardi

### Badge e mappamondo digitale

Sono una cartolina, non un motore. Servono a chiudere il viaggio con qualcosa in mano e a dare una forma alla storia di chi viaggia.

Vanno costruiti, non misurati come leva di ritorno — e soprattutto non vanno caricati di un'aspettativa che non possono sostenere.

### Viaggi passati: il passaporto digitale

Si possono inserire viaggi già fatti. Riempiono il mappamondo e danno senso al profilo fin dal primo giorno, ma l'inquadramento è quello di un **passaporto**: un promemoria di dove si è stati, e si ferma lì. I viaggi che contano per il prodotto sono quelli futuri, fatti *con* l'app.

Due conseguenze che non si negoziano:

- **Restano fuori dalla North Star.** Un viaggio del 2019 inserito in trenta secondi non dimostra niente sull'uso dell'app, e contarlo come "viaggio chiuso" fa mentire proprio la metrica che dovrebbe dire la verità. Nelle metriche compare come numero a sé, letto come **curiosità e non come adozione**.
- **Sono marcati visivamente come importati.** Non possiamo certificare che siano stati fatti davvero, e il segno visibile è ciò che protegge l'economia dei traguardi: un traguardo verificato e uno dichiarato non devono somigliarsi.

---

## Progetto

### Stack: Flutter

Si sviluppa in **Flutter**, un solo codice per iOS e Android. La motivazione completa e le alternative scartate stanno in [ADR-001](../tecnico/adr/001-stack.md).

Due conseguenze immediate: **Android smette di essere una seconda costruzione** e diventa quasi solo lavoro di rifinitura, il che cambia il significato della riga "Android in fase successiva" nella visione; e i punti in cui Flutter è meno naturale — file locali, permessi, comportamento in background — coincidono proprio con le parti delicate di questo prodotto, quindi vanno affrontati per primi invece che per ultimi.

### "Trolley" è un nome in codice

Serve a identificare il progetto adesso, quasi sicuramente non sarà il nome finale. Non si investe un'ora sull'identità visiva finché non è deciso.

## Decisioni registrate altrove

Queste sono decise, ma il loro posto naturale è dentro il documento che le motiva.

| Decisione | Dove |
|---|---|
| Pacchetto viaggio a €9,99, acquistabile solo prima del viaggio | [Modello di business](../discovery/05-modello-di-business.md) |
| Il premium sblocca la persona per le funzioni individuali, il viaggio per quelle collaborative | [Modello di business](../discovery/05-modello-di-business.md) |
| Niente bundle di gruppo nell'MVP | [Modello di business](../discovery/05-modello-di-business.md) |
| Esportazione gratuita, reimportazione a pagamento | [Modello di business](../discovery/05-modello-di-business.md) |
| Booking come ricavo da commissioni, separato dall'abbonamento | [Modello di business](../discovery/05-modello-di-business.md) |
| Regola di verifica del viaggio, con deroga amministrativa per le prove | [Funzionale 02 — Il viaggio](../prodotto/02-il-viaggio.md) |
| Navigazione disegnata dentro Trolley, con percorso e posizione in tempo reale | [Funzionale 08 — Mappa](../prodotto/08-mappa.md) |
| Valuta predefinita scelta dalla persona, euro iniziale | [Funzionale 06 — Spese](../prodotto/06-spese.md) |
| Accesso con email, Google e Apple | [Funzionale 01 — Account e profilo](../prodotto/01-account-e-profilo.md) |
| Peso dei viaggi nella North Star: 1 + 0,1 per giorno, tetto a 2 | [Metriche di successo](../discovery/04-metriche-di-successo.md) |
| Le idee contano a parte, non come viaggi creati | [Metriche di successo](../discovery/04-metriche-di-successo.md) |
| Profondità del viaggio esclusa dalle metriche | [Metriche di successo](../discovery/04-metriche-di-successo.md) |
| Community misurata separatamente, a cadenza mensile | [Metriche di successo](../discovery/04-metriche-di-successo.md) |
