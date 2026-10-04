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

### Il periodo si sceglie, non si scrive

Il periodo di un'idea si sceglie fra **i dodici mesi che vengono e le quattro stagioni che vengono**, oppure "non lo so ancora". Non si scrive a mano.

Il motivo è la regola dell'archivio: un'idea ci va quando il suo periodo è passato, e "un weekend di primavera" scritto a mano non dice quando passa. Un mese o una stagione sì. "Non lo so ancora" vale dodici mesi dalla creazione, come già deciso.

Sul server il periodo resta testo, nella forma in cui si legge — `agosto 2027`, `estate 2027`, `inverno 2027–28` — e l'app sa rileggerlo. Le stagioni sono quelle meteorologiche, tre mesi interi ciascuna: l'inverno comincia a dicembre e prende il nome da due anni. Quello che si perde è la sfumatura del "weekend": si recupera con le note dell'idea, quando ci saranno.

### Come si avvisa prima di archiviare

"Prima di archiviare si avvisa, una volta sola" diventa così:

- **Il sollecito compare nelle ultime due settimane del periodo**, e dopo: sulla scheda nell'elenco ("Ancora un'idea?") e dentro l'idea, con il giorno in cui andrà in archivio. È un avviso che sta dove si guarda, non una notifica che interrompe: quella arriva con le notifiche ([14](../prodotto/14-notifiche.md)).
- **L'idea va in archivio quando il periodo è passato e il sollecito è stato visibile da almeno due settimane.** Chi riapre l'app dopo mesi non trova l'idea già sparita: trova il sollecito, e due settimane per decidere.
- Il sollecito si conta **per telefono**: è la persona che deve averlo visto. Un periodo cambiato vuole un sollecito nuovo.

Dall'archivio un'idea si riprende con un periodo nuovo — quello vecchio è passato — oppure fissando direttamente le date.

### "In corso" e "chiuso" li decide il calendario

Un viaggio definito è **in corso** dal primo all'ultimo giorno ed è **concluso** dal giorno dopo: l'app lo ricava dalle date ogni volta che lo mostra, senza scrivere niente. Sul server lo stato resta "definito" finché non arriva la chiusura ([piano di costruzione](../piano-di-costruzione.md), 4.1), che ha conseguenze sue — verifica, traguardi, riepilogo — e allora lo scriverà.

### Tetto strutturale alle tappe, invece di un campanello d'allarme

Nessun monitoraggio di chi mette troppe tappe: ognuno riempie il viaggio come vuole. Il limite è nel modello — ogni tappa ha un tempo stimato, e se la somma sfora la giornata la tappa non si aggiunge.

E il tetto non è un generico "24 ore": è **la finestra reale del giorno**, che lo scheletro conosce già dagli orari di arrivo e partenza. È l'esempio migliore del perché lo scheletro viene prima di tutto il resto.

*Da risolvere in fase di design*: se il tempo stimato è obbligatorio diventa un campo in più sul gesto più frequente dell'app — esattamente quello che H2 misura. Va precompilato con una durata sensata da correggere, non chiesto a vuoto.

**Risolto nella fase 1.2: la durata la propone il tipo.** Ogni tappa ha un tipo, e il tipo porta la sua durata: visita 1 h 30, museo 2 h, pasto 1 h 30, passeggiata 1 h, spettacolo 2 h, escursione 4 h, pausa 30 min, altro 1 h. Una tappa nuova nasce visita, quindi con 1 h 30 già scritta; si corregge di un quarto d'ora alla volta. Cambiare tipo cambia la durata finché la persona non l'ha toccata a mano. Il tipo serve anche a riconoscere la tappa a colpo d'occhio, con un colore e un'icona. Le tappe che arriveranno da un itinerario incollato (1.6) possono non averlo.

**Quando una tappa non entra** si dice quanto manca e si propone, nell'ordine: accorciarla al tempo che resta (se resta almeno un quarto d'ora), metterla nel giorno più vicino in cui entra così com'è (a pari distanza, quello dopo), o togliere qualcosa dalla giornata. Una tappa che resta nel suo giorno e non si allunga non si rifiuta mai, anche se la giornata è già troppo piena: quella si sistema togliendo, non bloccando chi corregge un titolo.

### Le tappe si segnano dal primo giorno, con un tocco

Il gesto da cui dipende la verifica deve costare un tocco ([09](../prodotto/09-durante-il-viaggio.md), regola 10). Nella giornata le tappe sono **punti numerati collegati, come un percorso su una carta**: toccare un punto lo segna fatto, tenerlo premuto lo salta, ritoccarlo lo riporta da fare. Il tratto già percorso diventa verde. È uno schema dell'ordine della giornata, non una mappa: la mappa vera arriva con la 3.2, e gli stessi punti ci andranno sopra. Per riordinare c'è la vista a elenco, dove le tappe si trascinano.

I punti si segnano **dal primo giorno del viaggio**: prima non c'è niente da segnare, e toccare un punto apre la tappa. Dopo l'ultimo giorno si segna ancora, ma non conta per la verifica (04, regola 17). Durante il viaggio la prima tappa da fare della giornata di oggi è evidenziata come **prossima**.

### Modello paritario tra i partecipanti

Chiunque partecipi al viaggio può aggiungere e modificare — spese, cose da portare, tappe, documenti — e matura gli stessi traguardi di chi il viaggio l'ha creato.

Il modello è paritario **sui contenuti**, non sull'amministrazione: **rimuovere un partecipante è potere di chi ha creato il viaggio**, e solo suo. È l'unica asimmetria dell'MVP, e serve perché in un gruppo davvero paritario non esisterebbe nessuno legittimato a chiudere una situazione che va male.

L'organizzatore con poteri estesi su tutto resta invece una tipologia di viaggio a parte (viaggi di gruppo organizzati da un ente, dove l'invitato segue e non modifica) e non è nell'MVP.

### Conflitti mostrati, non risolti di nascosto

Quando due persone modificano lo stesso punto del viaggio si mostrano le due versioni affiancate e si fa scegliere, come un diff. Chi salva per primo su un viaggio vuoto fa semplicemente il primo salvataggio; dal secondo in poi si confronta.

Con il server autoritativo i conflitti nascono solo fra **due persone entrambe online** che modificano la stessa cosa: offline si può soltanto aggiungere. Si riconoscono con un controllo di versione al salvataggio, e a decidere è la persona — mai una fusione automatica, che produrrebbe una terza versione che nessuno ha scritto. Il dettaglio è in [02 — Copia locale, coda e conflitti](../tecnico/02-sincronizzazione-e-offline.md).

### Due versioni: come funziona

Scelto con la fase 2.2 (tela, file 34–36 e 88).

- **Si confronta solo quello che si cambia.** Le due versioni sono i campi che la persona può modificare: per una tappa titolo, tipo, durata, ora, luogo, giorno; per una spesa importo, valuta, data, descrizione; per una voce testo e quante; per un viaggio quando si parte (date, orari, idea e periodo). Se intanto l'altro ha solo segnato la tappa, spuntato la voce, riordinato la giornata o passato il ruolo, si salva sulla versione nuova senza chiedere niente: quei gesti non toccano quello che si stava cambiando. Se l'altro ha scritto proprio la stessa cosa, non c'è niente da scegliere.
- **Anche su campi diversi si chiede.** Se uno ha cambiato il titolo e l'altro l'ora, si mostrano le due versioni: unirle darebbe una tappa che nessuno dei due ha visto.
- **«Tieni la tua» rende la cosa esattamente come la propria scheda**, anche nei campi che aveva cambiato solo l'altro. «Tieni quella di Marco» non scrive niente: è già quella sul telefono.
- **«Tienile tutte e due» solo per le voci**: la propria diventa una voce in più. Una tappa o una spesa no — la cena da 42 o da 48 euro è una cena sola. Le note, che oggi non si riscrivono, lo avranno quando si potranno riscrivere.
- **Una cosa tolta.** Se l'altro l'ha tolta mentre la si cambiava: «Rimettila con la tua» o «Lasciala tolta». Se la si toglie mentre l'altro la cambiava, prima si vede com'è adesso: «Toglila lo stesso» o tienila.
- **Le date del viaggio** usano la stessa schermata: «Tieni la tua» le rifissa, o torna a idea, a seconda di qual era la propria versione.
- **La propria tappa deve ancora entrare.** La capienza è l'unica regola che rifiuta: se intanto il giorno si è riempito, «Tieni la tua» è spento e dice perché.
- **Chiudendo senza scegliere** si torna al foglio, con quello che si era scritto: non si perde niente. La notifica «Due versioni» per chi esce prima di scegliere arriva con le notifiche.
- **La stessa persona su due telefoni** vede «Dall'altro telefono» e «Tieni l'altra», non il proprio nome.
- **Chi e quando** sono di chi ha scritto per ultimo la cosa, anche solo segnandola: se Sara ha segnato la tappa dopo che Marco l'aveva cambiata, l'altra versione è «di Sara». È raro, e dire chi ha scritto cosa campo per campo costerebbe una cronologia che non c'è.

---

## Itinerario generato

### Prompt in uscita, risultato incollato indietro

Nell'MVP Trolley non chiama nessun modello. Costruisce un prompt dettagliato a partire dallo scheletro del viaggio, l'utente lo porta sull'LLM che già usa e paga, e incolla indietro il risultato: Trolley lo interpreta e lo rende leggibile — giorni, orari e luoghi agganciati alla mappa e alle spese. La chiamata nativa all'API arriva nella versione validata, quando esiste un budget che la regge.

Tre ragioni, in ordine di peso:

1. In beta il budget è zero, e un costo per chiamata è **variabile e senza tetto**: un ciclo sbagliato o un client manomesso si scoprono a bolletta arrivata. È la variabilità, più del livello — $20–70 l'anno a volumi da beta — a renderlo inaccettabile adesso.
2. Evita il **backend proxy**, che era la dipendenza vera dell'integrazione nativa: la chiave API non può stare nell'app, e dietro al proxy vengono quote, anti-abuso e un server da mantenere.
3. I dati del viaggio li manda l'utente dal proprio account, quindi non si aggiunge un responsabile del trattamento all'informativa — che con i documenti d'identità già in gioco non è una formalità.

Il prezzo è un cambio di app in mezzo al percorso. **Ciò che lo rende accettabile è il ritorno**: se il risultato non rientrasse in Trolley, la persona resterebbe a scorrere un muro di testo dentro l'LLM, che è esattamente l'esperienza da battere. Il parsing dell'incollato non è idraulica, è la funzione.

### Come funziona il giro (fase 1.6)

- Dalla schermata del viaggio, sotto i giorni: **«Un itinerario con il tuo assistente»**. Ci sono solo se il viaggio ha date e una meta.
- Si sceglie il **ritmo** (tranquillo, equilibrato, intenso), facoltativamente **cosa piace** (arte e musei, cibo, storia, natura, panorami, shopping, vita notturna) e una riga libera. La richiesta porta anche le tappe già in programma, perché l'assistente non le ripeta.
- «Copia la richiesta» la mette negli appunti; l'icona di condivisione la manda direttamente all'app dell'assistente. Funziona senza rete.
- «Ho la risposta» apre il foglio dove la si incolla, col pulsante «Incolla» o tenendo premuto. **Leggere richiede la rete**, perché prima si salva la nota.
- L'**anteprima** mostra le tappe giorno per giorno, già scelte nell'ordine finché entrano; le altre restano fuori e dicono quanto manca. Una giornata che sfora non si aggiunge. Se la risposta parla di un altro posto, lo dice.
- Una risposta senza tappe leggibili porta a una schermata che dice che il testo è salvo, cosa si cercava, e propone di incollarne un'altra o di copiare di nuovo la richiesta.
- Le **note** stanno nella schermata del viaggio; da una nota si rilegge l'itinerario quando si vuole.

Il formato e le ragioni tecniche sono in [ADR-010](../tecnico/adr/010-itinerario-incollato.md).

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

## Inviti, documenti, valute, liste

### Invito: un link, e il viaggio si apre dopo l'installazione

Si invita condividendo un **link** con i mezzi normali del telefono — messaggi, chat, email. Il link apre l'app se è installata; se non lo è porta alla pagina su App Store, e dopo l'installazione l'app apre direttamente il viaggio a cui si era invitati.

Tecnicamente serve un **deep link differito**: dopo l'installazione l'app deve sapere a quale viaggio si riferiva il link toccato prima di scaricarla. Non è gratis, è un meccanismo da scegliere e da provare, ed è il genere di cosa che si rompe in silenzio. Siccome H3 è l'unico canale di acquisizione, se quel pezzo non funziona non c'è crescita: va provato per primo e sorvegliato sempre.

**Conseguenza sulla soglia di H3**: l'invitato **non vede il viaggio prima di installare**. Decide di scaricare sulla fiducia in chi lo invita e su quello che promette la pagina dello store, non su un'anteprima del contenuto. È la variante più esigente, e va tenuta presente quando si legge il 35%.

### Chi c'è e gli inviti: come funziona (fase 2.1)

- **Il ruolo si chiama «responsabile del viaggio».** Nei dati resta `creatore`; nell'app no, per due ragioni: il ruolo si può passare, e dopo un passaggio «ha creato il viaggio» non sarebbe più vero; e «creatore/creatrice» presuppone il genere di chi lo è, che non conosciamo. Chi ha creato il viaggio davvero resta scritto in `viaggio.creato_da`.
- **Nel viaggio, «Chi c'è» è una riga sola** sotto il biglietto: le iniziali, i nomi, chi è responsabile. Toccandola si apre l'elenco. Da soli dice «Solo tu, per ora» e invita a invitare.
- **Ogni «Invita qualcuno» crea un link nuovo.** Gli **inviti in sospeso** sono i link ancora validi: l'elenco dice quanti sono e chi ha creato l'ultimo, e si possono **ritirare tutti insieme** — è la risposta al link inoltrato a chi non doveva averlo (03, casi limite). Li ritira chiunque partecipi: non è un potere, è una difesa.
- **Chi è responsabile tocca «…» su una persona**: renderla responsabile, o toglierla dal viaggio, sempre con una conferma.
- **Togliere qualcuno ritira anche i link d'invito ancora validi**: quello con cui è entrato potrebbe essere passato di mano. Chi deve ancora entrare riceve un link nuovo.
- **Chi è stato tolto rientra solo con un link nuovo di chi è responsabile.** Con nessun altro: rientrare è l'inverso di togliere, e sta con lo stesso potere. Prima della 2.1 chi era tolto non rientrava mai, e un errore non si poteva rimediare.
- **Chiunque esce da solo.** Chi è responsabile prima sceglie a chi passare il ruolo, nello stesso gesto. Chi è responsabile ed è **da solo non esce**: il viaggio resterebbe senza nessuno. Eliminare un viaggio non è nell'MVP.
- **Uscendo, i propri documenti di quel viaggio si cancellano dal telefono**, dopo che il server ha detto sì, e la conferma lo dice prima con il numero. Uscire è una scelta: tenere file che nessuna schermata mostra più non servirebbe a niente.
- **Se ti tolgono, o esci da un altro telefono**, l'elenco dei viaggi lo dice invece di far sparire il viaggio in silenzio: perché, quante cose fatte senza rete non sono arrivate, e quanti tuoi documenti restano sul telefono, da guardare o eliminare. Qui non si cancellano da soli: non l'hai scelto tu, e possono essere il tuo biglietto.
- **Il primo minuto di chi entra da un invito** (03, regola 9): il viaggio completo, e in cima «Sei dentro!» con tre cose sue da fare — il biglietto, una spesa, le cose da portare (biglietto e spesa solo con le date). Sparisce al primo contributo, o con la ×.
- **«Non ci sono più»**: in fondo all'elenco chi è uscito o è stato tolto, senza distinguere i due casi, con quello che ha aggiunto che resta nel viaggio.
- Senza rete l'elenco si legge; invitare, togliere, passare il ruolo, uscire e vedere gli inviti in sospeso richiedono la rete, e lo dicono prima.

### Documenti: solo sul telefono

I documenti stanno in una cartella locale dell'app, non su un server.

**Quello che si guadagna**: nessun archivio da proteggere, nessun costo di archiviazione che cresce con gli utenti, e una superficie GDPR molto più piccola proprio sul dato più delicato che l'app tratta. Il backup di sistema del telefono li porta sul dispositivo nuovo, quindi cambiare telefono non li perde.

**Quello che si perde, consapevolmente**: in un viaggio condiviso **i documenti non si condividono**. Se è Giulia a prenotare per tutti, il biglietto di Marco resta sul telefono di Giulia e Marco continua a riceverlo in chat.

È una rinuncia accettata, non una svista. Trolley risolve il problema di **ritrovare** un documento nel momento peggiore — in aeroporto, senza rete, con l'imbarco fra dieci minuti — non quello di passarselo. Le alternative (un archivio nostro da proteggere, oppure un passaggio diretto fra telefoni) costavano entrambe più di quanto quel pezzo di problema valga, e la prima rimetteva in piedi proprio l'archivio di documenti d'identità che questa scelta serve a non avere.

### Documenti: come funzionano (fase 1.3)

- Si aggiungono da **scansione** (le pagine diventano un PDF), **foto** o **file**. Un'immagine si comprime e perde i metadati, compreso il luogo dello scatto.
- Ognuno serve **un giorno** (con un'ora, se si vuole) oppure **tutto il viaggio**. L'elenco: oggi, domani, tutto il viaggio, gli altri giorni, i giorni passati in fondo; dentro un giorno prima quelli con l'ora.
- Nella schermata del viaggio stanno **tutti quelli di oggi**, o se oggi non ne ha i primi tre dell'elenco: sono a un tocco.
- In un'idea non si aggiungono e non si vedono; se un viaggio torna idea, si dice quanti ne restano sul telefono.
- Tutto, anche cambiarli ed eliminarli, funziona senza rete: la rete non c'entra.
- Se il telefono non ha un codice di sblocco, l'elenco lo dice: senza, la cifratura non protegge niente.

### Dividere le spese: come funziona (fase 2.3)

Scelto con la fase 2.3 (tela, file 37–41 e 89).

- **Da soli non si parla di dividere** (06, regola 3): né nel foglio né nell'elenco. Appena nel viaggio c'è, o c'è stato, qualcun altro, la spesa dice chi ha pagato e per chi.
- **Registrare resta un gesto da due secondi**: ha pagato «tu», per «tutti» quelli che sono nel viaggio adesso, in parti uguali. Si cambia solo se serve. Le parti uguali tornano sempre al centesimo: quelli che avanzano vanno ai primi dell'elenco, uno ciascuno.
- **Importi diversi** si scrivono in un foglio a parte: si vede quanto manca, e «Registra» si accende solo quando le parti fanno l'importo pagato. Che tornino lo controlla l'app; il server controlla solo che le quote siano di qualcuno del viaggio, come il pagante.
- **Le quote viaggiano con la spesa**, anche senza rete: registrare una spesa resta uno solo dei quattro gesti, e spesa e quote arrivano insieme o niente. Cambiarle richiede la rete e la versione, come ogni modifica: chi ha pagato e per chi entrano nelle due versioni.
- **Le spese di prima della divisione** (senza quote) valgono in parti uguali fra chi era nel viaggio quando sono state registrate: chi è entrato dopo non le divide.
- **La propria parte e quanto si è pagato** stanno sotto il totale; sotto ancora, quanto ti devono o devi, che porta ai saldi.
- **Saldi: il giro più corto** (06, regola 9), nella valuta della persona con l'ultimo tasso, dicendo di quando è. Prima si accoppia chi deve esattamente quanto un altro aspetta, poi sempre il debito più grande con il credito più grande. Chi ha lasciato il viaggio resta, tratteggiato. Una spesa in una valuta senza tasso resta fuori dai saldi, e si dice.
- **«Li ho ricevuti» registra un rimborso**: una spesa pagata da chi dà i soldi, tutta per chi li riceve, segnata come rimborso, così il totale del viaggio la lascia fuori. Lo tocca solo chi riceve — chi dà legge che a segnarlo sarà chi riceve, con il suo nome — e funziona anche senza rete, perché è registrare una spesa. Un rimborso segnato per sbaglio si toglie, con la rete. I soldi passano fuori da Trolley.
- **La stessa spesa registrata da due persone** (stesso importo e valuta, a meno di dieci minuti) si segnala a chi l'ha registrata dopo: «È la stessa: togli la mia» o «Sono due spese». La seconda risposta resta su quel telefono.
- **Togliere qualcuno con un saldo aperto** lo dice nel dialogo, con quanto deve o deve ricevere e da chi. Non lo impedisce, e il saldo resta.

### Valuta e cambio: servizio esterno, ultimo valore noto offline

Il tasso di cambio arriva da un servizio esterno. Senza rete si usa **l'ultimo tasso recuperato**, dicendo esplicitamente che il valore può essere cambiato perché non è in tempo reale.

Due conseguenze: il tasso più recente entra nell'insieme dei dati essenziali offline di H4, e il servizio diventa la terza dipendenza esterna del prodotto dopo l'invio degli SMS e lo store — con un costo che, se il piano gratuito del fornitore non basta, torna a essere variabile.

### Cose da portare: una lista sola, personale, fino alla 2.4 (fase 1.5)

Nella fase 1.5 ogni persona ha **una lista per viaggio, ed è personale**: la vede solo lei, anche quando nel viaggio arriva qualcun altro. La lista del viaggio da dividere con i compagni, e chi porta cosa, arrivano con la 2.4 (più sotto).

**Perché personale e non del viaggio**: chi viaggia da solo scrive la lista per sé — lo spazzolino, le medicine. Se la lista nascesse del viaggio, il primo invitato si troverebbe davanti le cose di un altro senza che nessuno l'abbia scelto (05, regola 3). Il contrario non fa danni: quando arriva la 2.4, una voce si potrà spostare nella lista comune.

Come funziona:
- C'è anche nelle **idee**: non ha bisogno di date (05, regola 4).
- Si aggiunge dal **campo in fondo**: scrivi, invio, e il campo è pronto per la prossima. Ogni voce ha **quante** (da 1 a 99): cinque magliette sono una voce, non cinque.
- Spuntata, una voce **resta un attimo al suo posto e poi scende in «In valigia»**; non sparisce mai (regola 6). Quando è tutto dentro, il timbro **FATTA**.
- **«Rimetti tutto da mettere»** toglie tutte le spunte, per rifare la valigia al ritorno. Sono spunte: funziona anche senza rete.
- Senza rete si legge e si spunta; **aggiungere, cambiare ed eliminare richiedono la rete** (regola 5). Aggiungere una voce non è uno dei quattro gesti offline: la colonna si allarga solo se H4 lo chiede.

### La lista del viaggio: come funziona (fase 2.4)

Scelto con la fase 2.4 (tela, file 42–44).

- **Due liste, solo quando servono.** Con qualcun altro nel viaggio, in cima alle cose da portare c'è il selettore: «Del viaggio», che vedono tutti, e «Mie», che vede solo la persona (05, regole 1–3). Da soli c'è la propria e basta, come nella 1.5. Se gli altri escono e la lista del viaggio ha ancora delle voci, il selettore resta: le voci non spariscono.
- **Si apre sulla lista del viaggio**, a meno che sia vuota e la propria no: chi aveva scritto la sua lista prima che arrivassero gli altri la ritrova. Una volta aperta, la scelta non cambia da sola mentre si guarda.
- **Ogni voce del viaggio dice chi la porta**, con le sue iniziali, o «Libera». Nella voce: «Chi la porta?» — nessuno, tu, o uno di quelli che sono nel viaggio adesso. Chi è uscito non si sceglie. Chi l'ha aggiunta si legge sotto il titolo.
- **Chi spunta una voce del viaggio: chiunque.** Spuntato è spuntato (02 §2), anche quando la porta un altro: chi vede Marco mettere in valigia l'adattatore può segnarlo. Spuntare resta uno dei quattro gesti offline, nelle due liste.
- **«Chi la porta» entra nelle due versioni** (02 §3): se due persone prendono la stessa voce insieme, si mostrano tutte e due. È proprio il caso dei due caricabatterie. «Tienile tutte e due» fa nascere la voce in più nella stessa lista dell'altra, con chi la porta.
- **Spostare una voce da una lista all'altra.** Dal foglio della voce: «Spostala nella tua lista» per una voce del viaggio libera o tua (quella che porta un altro gli sparirebbe di mano); «Spostala nella lista del viaggio» per una propria, che allora la porti tu, perché la tenevi fra le tue. La spunta resta. Sul server la voce si toglie da una lista e ne nasce una nuova nell'altra, insieme o niente: chi aveva la vecchia la vede togliere, come ogni voce tolta. Quello che si è cambiato nel foglio si salva prima; se intanto un altro l'ha presa, resta dov'è e lo si dice.
- **Chi lascia il viaggio libera le voci che portava**, nel momento in cui esce o viene tolto: lo fa il server, nella stessa operazione, e ricorda chi le portava. In cima alla lista del viaggio un avviso dice «Luca ha lasciato il viaggio: Crema solare e Ombrellone, che portava, sono tornate libere», finché non si tocca «Ho capito» (su quel telefono) o qualcuno le prende. Il dialogo per uscire e quello per togliere qualcuno lo dicono prima.
- **Rifare la valigia al ritorno**: nella propria lista «…» rimette tutto da mettere; in quella del viaggio solo quello che porti tu, perché le altre spunte sono le valigie degli altri.
- **Nella schermata del viaggio** conta la propria valigia: le proprie voci e quelle del viaggio che porta la persona. Le voci del viaggio che non porta ancora nessuno si contano a parte.
- **Prendere una voce del viaggio è un contributo**: per chi è appena entrato da un invito conta come primo contributo (H3) e chiude il benvenuto, come aggiungerne una (03, regola 9).
- Senza rete le liste si leggono e si spuntano; aggiungere, cambiare, scegliere chi porta e spostare richiedono la rete, e lo dicono prima (05, regola 5).

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
| Server autoritativo con copia locale e quattro gesti scrivibili offline | [Tecnico 00 — Architettura](../tecnico/00-architettura.md) |
| Beta in due ondate: prima tutto tranne la parte pubblica, poi matching e sicurezza | [Punti aperti](../punti-aperti.md) |
| Regola di verifica del viaggio, con deroga amministrativa per le prove | [Funzionale 02 — Il viaggio](../prodotto/02-il-viaggio.md) |
| Navigazione disegnata dentro Trolley, con percorso e posizione in tempo reale | [Funzionale 08 — Mappa](../prodotto/08-mappa.md) |
| Valuta predefinita scelta dalla persona, euro iniziale | [Funzionale 06 — Spese](../prodotto/06-spese.md) |
| Accesso con email, Google e Apple | [Funzionale 01 — Account e profilo](../prodotto/01-account-e-profilo.md) |
| Peso dei viaggi nella North Star: 1 + 0,1 per giorno, tetto a 2 | [Metriche di successo](../discovery/04-metriche-di-successo.md) |
| Le idee contano a parte, non come viaggi creati | [Metriche di successo](../discovery/04-metriche-di-successo.md) |
| Profondità del viaggio esclusa dalle metriche | [Metriche di successo](../discovery/04-metriche-di-successo.md) |
| Community misurata separatamente, a cadenza mensile | [Metriche di successo](../discovery/04-metriche-di-successo.md) |
