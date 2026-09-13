# Visione prodotto

> Le scelte già prese stanno in [Decisioni di prodotto](../decisioni/prodotto.md); quelle ancora da chiudere in [Punti aperti](../punti-aperti.md).

## Identità

- **Nome**: Trolley — **nome in codice**, serve a identificare il progetto adesso. Quasi sicuramente non sarà quello finale, e finché non è deciso non si investe sull'identità visiva
- **Tagline**: l'app che ti segue dal "e se andassimo a Lisbona?" al ritorno a casa
- **Categoria**: app mobile consumer / viaggi / organizzazione personale
- **Piattaforma**: iOS in prima release, Android subito dopo. Con Flutter le due versioni condividono il codice, quindi Android è lavoro di rifinitura e non una seconda costruzione

---

## Problema

**Il problema principale.** Organizzare un viaggio produce lavoro: cerchi, decidi, prenoti, scrivi, salvi. Quel lavoro si disperde negli strumenti in cui lo fai — le idee restano in chat, l'itinerario in un documento condiviso, le conferme nella casella email, i biglietti in screenshot nel rullino, le spese da nessuna parte. Il risultato è che nel momento in cui quel lavoro dovrebbe servirti — sei in aeroporto, hai poca rete, poca batteria e zero pazienza — non ce l'hai in un posto solo. E quando torni, non resta niente: il viaggio finisce e con lui sparisce tutto quello che avevi messo insieme.

**Quanto è frequente.** Da 1 a 5 volte l'anno per la maggior parte delle persone, ma con **intensità altissima nei giorni intorno alla partenza**. Non è un problema quotidiano, è un problema concentrato: poche occasioni all'anno in cui però conta moltissimo.

**Perché oggi non è risolto bene.** Gli strumenti esistenti coprono ciascuno una fase sola e si passano male il testimone. Le app di ispirazione ti aiutano a scegliere e poi ti lasciano; i comparatori ti fanno prenotare e poi ti mandano una email; i documenti condivisi reggono la pianificazione di gruppo ma sono inutilizzabili in mobilità; le app di compagnia funzionano solo se qualcuno ha già inserito i dati altrove. Nessuno accompagna la stessa persona lungo l'intero arco, e la conseguenza è che ogni passaggio di fase costa un travaso manuale di informazioni.

**Il segnale che il problema è reale.** Il comportamento che quasi tutti adottano è già una diagnosi: si crea un gruppo in chat per il viaggio, si fissano i messaggi importanti, si fanno screenshot delle prenotazioni "per averle offline". Sono soluzioni di ripiego costruite a mano da persone che non hanno trovato di meglio. Lo stesso vale per il gesto di cercare freneticamente una email di conferma con una barra di segnale sola.

---

## Per chi

- **Utente principale**: chi organizza il viaggio, per sé o per il gruppo. È la persona che tiene insieme date, prenotazioni e informazioni, e che oggi paga il prezzo più alto della frammentazione.
- **Utente secondario**: chi viaggia insieme e non ha creato il viaggio. Non è uno spettatore: aggiunge le proprie spese, le proprie liste, i propri documenti, e matura gli stessi traguardi di chi il viaggio l'ha aperto. Quello che non fa è il lavoro di coordinamento. Oggi riceve informazioni a spizzichi in chat e non ha mai il quadro completo.
- **Caso a parte**: i viaggi di gruppo organizzati da un ente, dove chi definisce il programma è uno solo e gli altri lo seguono. È l'unico contesto in cui ha senso un organizzatore con poteri speciali, ed è fuori dall'MVP.
- **Contesto d'uso**: due contesti opposti che la stessa app deve servire. A casa, con calma, mentre pianifica. In movimento, di fretta, con rete incerta, mentre viaggia.

---

## Proposta di valore

- **Promessa principale**: tutto il tuo viaggio in un posto solo, dalla prima idea al ritorno — e disponibile proprio quando serve.
- **Differenza rispetto alle alternative**: raccoglie in un posto solo funzioni che oggi stanno su due o tre app diverse, nessuna delle quali è nata per i viaggi — le cose da portare, la divisione delle spese, l'itinerario e le attrazioni, i documenti, la mappa — e le tiene insieme lungo l'arco intero invece che in una fase sola. Quello che scrivi mentre pianifichi è esattamente quello che ti ritrovi in mano quando parti, senza travasi.
- **Differenza difficile da copiare**: la parte pubblica. Il profilo di viaggiatore, i traguardi e la possibilità di incontrare altri che usano l'app sono l'unica cosa che nessuno degli strumenti sostituiti ha — ed è anche la meno dimostrata di tutte (ipotesi H7). I collegamenti sono reciproci, come su LinkedIn: uno chiede, l'altro accetta. Non si accumula un pubblico, si conosce qualcuno. **Nell'MVP c'è anche il matching**: cercare e collegarsi ad altri viaggiatori, e perfino scoprire chi sta viaggiando nella tua stessa città — quest'ultima in una versione volutamente smussata, granularità solo città e attivazione esplicita per singolo viaggio, perché unire sconosciuti, posizione e presente è la cosa più delicata che questo prodotto fa.
- **Beneficio funzionale**: niente informazioni sparse, niente ricerca affannosa di una conferma, niente dipendenza dalla rete nel momento peggiore. E i documenti restano **sul tuo telefono**, non su un nostro server: la cosa più delicata che l'app tocca non la custodiamo noi.
- **Beneficio emotivo**: la tranquillità di chi sa di avere tutto con sé — e, al ritorno, la soddisfazione di vedere che il viaggio ha lasciato un segno.

---

## Perché adesso

- **Driver di mercato**: i viaggi sono tornati a volumi pieni e si organizzano quasi interamente da telefono, ma gli strumenti restano frammentati per fase. Nel frattempo le persone si aspettano che un'app funzioni anche senza rete, cosa che dieci anni fa era un requisito da specialisti.
- **Opportunità specifica**: nessuno presidia bene il **passaggio tra le fasi**. È lo spazio dove la frammentazione fa più male e dove un prodotto continuo ha un vantaggio strutturale, difficile da replicare per chi è nato come strumento di una fase sola.

---

## Alternative attuali

| Alternativa | Cosa fanno oggi le persone | Limite principale |
|---|---|---|
| Chat di gruppo | Coordinano il viaggio a messaggi, fissano quelli importanti | L'informazione scorre via, non ha struttura, ritrovarla è impossibile |
| Documenti e fogli condivisi | Scrivono l'itinerario a più mani | Ottimi da desktop, inutilizzabili in mobilità e senza rete |
| Casella email | Lasciano lì le conferme di prenotazione | Servono ricerca e connessione proprio quando non ce n'è |
| Screenshot nel rullino | Salvano biglietti e codici "per sicurezza" | Si mescolano a migliaia di foto, senza ordine né scadenze |
| App di pianificazione | Costruiscono itinerari elaborati | Abbandonano l'utente alla partenza, quando servirebbero di più |
| Note e liste | Segnano cosa mettere in valigia e cosa non dimenticare | Strumento generico, scollegato dalle date del viaggio e da chi viaggia con te |
| App per dividere le spese | Tengono il conto di chi ha pagato cosa | Un'app in più da far installare a tutti, e del viaggio conosce solo i soldi |
| Mappe | Orientarsi e salvare i posti | I posti salvati non sanno niente del giorno in cui ci vai né del resto del programma. Trolley non prova a essere una mappa migliore: prova a essere una mappa **che sa cosa hai in programma oggi** |
| Social e foto | Raccontano il viaggio dopo | Nessun legame con quello che era stato organizzato prima |

Il punto non è che queste alternative funzionino male: è che sono **nove strumenti diversi per un'esperienza sola**, e ogni confine tra loro è un punto in cui si perde qualcosa. Per un viaggio solo una persona finisce per scaricare due o tre app che non sono state pensate per i viaggi, e usarle per un viaggio è scomodo proprio perché non lo sanno.

---

## Ambizione del prodotto

- **MVP**: un'app che copre l'arco completo in modo essenziale. Crei il viaggio anche quando è solo un'idea — destinazione e un periodo qualsiasi, "agosto", "un weekend di primavera" — e da lì esiste già. Quando le date si fissano lo completi con giorni e orari di arrivo e partenza, ed è **quel passaggio a sbloccare tutto il resto**: itinerario, documenti agganciati ai giorni, fase live. Le idee che non diventano viaggi non vengono cancellate: finiscono in archivio. Poi ci metti dentro quello che serve: tappe, cose da portare, spese da dividere, documenti. Ogni tappa ha un tempo stimato e la giornata ha una capienza: quando è piena, l'app non ti lascia incastrare altro dentro — e il tetto non è un'ora generica, è la finestra reale del giorno che lo scheletro conosce già. Se l'itinerario non hai voglia di scriverlo, Trolley ti prepara il prompt da dare all'LLM che già usi e poi interpreta il risultato che incolli: quello che in chat sarebbe un muro di testo da scorrere, qui diventa giorni, orari e luoghi agganciati alla mappa e alle spese. Ti accompagna dal vivo e alla chiusura ti restituisce i traguardi guadagnati e le mete grattate sul mappamondo. Viaggi condivisi e paritari fin da subito, dove ognuno aggiunge la propria parte. Si possono registrare anche i viaggi già fatti, come ricordo.
- **Versione validata**: la generazione dell'itinerario avviene dentro l'app, senza il giro esterno — è una funzione a costo variabile e arriva quando c'è un budget che la regge. Sparisce l'attrito di inserimento (le prenotazioni si importano), la community diventa un motivo di ritorno autonomo, arriva Android.
- **Versione scalabile**: si prenotano voli, treni, bus e alloggi da dentro l'app, che diventa un posto dove si entra anche solo per guardare le offerte. Trolley è il posto dove le persone tengono la propria storia di viaggio, e quella storia — traguardi, mete, abitudini — è ciò che rende l'app difficile da abbandonare.

---

## Vincoli iniziali

- **Budget**: tendente a zero sull'infrastruttura. Due costi però esistono e vanno accettati: **99$/anno** di Apple Developer Program, necessari già per distribuire su TestFlight, e la **commissione Apple del 15–30%** su qualsiasi acquisto in-app. Vale però una regola in più: in beta **nessun costo variabile senza tetto**. Un costo a consumo — per esempio la generazione dell'itinerario via API — si scopre a bolletta arrivata, ed è la variabilità più del livello a renderlo insostenibile adesso. È il motivo per cui nell'MVP la generazione passa dall'LLM dell'utente.
- **Tempo**: obiettivo dichiarato di sei mesi alla prima beta, a fronte di uno scope che ne richiede realisticamente nove. La roadmap tiene la tensione esplicita invece di nasconderla.
- **Team**: solo founder.
- **Vincoli normativi**: GDPR. Trolley tratta documenti d'identità e dati di viaggio, che rivelano spostamenti di persone fisiche; con la parte pubblica tratta anche dati resi visibili ad altri, inclusi quelli dei compagni di viaggio. Non è un'app dove la privacy si sistema alla fine. Da qui discendono tre paletti già decisi: **16 anni** per usare l'app e **18** per la parte pubblica, **numero di telefono verificato** per attivare profilo e matching, e nessuna posizione più precisa della città. La modalità in tempo reale, unendo posizione e sconosciuti, è la parte che con ogni probabilità richiede una valutazione d'impatto formale.
- **Vincolo di piattaforma**: dal momento che esistono contenuti pubblici, l'App Store richiede segnalazione, blocco, filtro dei contenuti e un contatto raggiungibile. Senza, l'app non viene approvata.

---

## Criterio di esistenza del prodotto

**Trolley ha senso se** le persone che lo usano per pianificare lo tengono aperto anche durante il viaggio, e tornano a crearne un secondo. È l'unica prova che la continuità — l'unica cosa che rende Trolley diverso — viene percepita davvero.

**Trolley va ripensato se** viene usato solo in una fase e abbandonato nelle altre. Se le persone pianificano altrove e lo aprono solo in viaggio, o lo riempiono prima di partire e non lo toccano più una volta partite, allora l'arco completo non è un valore ma un'ambizione nostra: meglio scegliere la fase che regge da sola e costruire quella.
