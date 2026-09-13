# Modello di business

## Come genera ricavi

- **Modello**: freemium con **abbonamento premium**, rivolto al consumatore finale. Il premium dà funzioni in più e accesso anticipato alle novità; quali funzioni esattamente è ancora da definire, e non è un rinvio per pigrizia — dipende da H1, cioè da quali funzioni le persone dimostrano di valutare davvero
- **Chi paga**: l'utente stesso. Con il modello paritario ogni partecipante al viaggio è un utente a sé, quindi un potenziale abbonato: non esiste un organizzatore che paga per il gruppo
- **Momento del pagamento**: ricorrente, dopo che l'app ha già dimostrato di funzionare — il momento naturale della richiesta è **la chiusura del primo viaggio andato bene**, non la registrazione
- **In MVP**: nessun pagamento attivo. L'app è gratuita e serve a validare, non a monetizzare
- **Molto più avanti, il booking**: voli, treni, bus e alloggi prenotabili da dentro l'app, che guadagnerebbe dalle **commissioni delle piattaforme**, non dall'utente. È un ricavo separato e indipendente: non sostituisce l'abbonamento e non ci entra in conflitto, perché chi paga è un altro soggetto. L'unico punto di contatto previsto è semmai uno sconto per chi è già abbonato

---

## Il problema di prezzare un'app stagionale

Un'app da viaggio non si usa tutti i giorni: si usa intensamente 2-5 volte l'anno. Questo rompe l'abbonamento mensile classico, perché il comportamento razionale dell'utente è abbonarsi a luglio e disdire ad agosto. Un mensile mal prezzato non produce ricavi ricorrenti, produce ricavi una tantum con in più il costo di gestione di un abbonamento.

Ne discendono tre scelte:

1. **L'annuale è il piano vero**, il mensile esiste solo per chi vuole provare senza impegno, ed è prezzato in modo che l'annuale convenga in modo evidente già al secondo mese.
2. **La stagionalità si combatte con la frequenza, non con i premi.** Ciò che può rendere Trolley un'app non stagionale sono le uscite brevi — i weekend, le gite fuoriporta — perché moltiplicano le occasioni d'uso invece di chiedere alla persona di tornare senza un motivo suo. È l'ipotesi H5, ed è il pilastro su cui poggia questo modello di ricavo. La fase "dopo" — mappamondo, traguardi, profilo — aiuta, ma è una cartolina: non le si può chiedere di giustificare da sola un abbonamento.
3. **Il limite del piano gratuito va sull'accumulo, non sull'uso singolo.** Chi fa un viaggio all'anno resta gratis per sempre, e va benissimo: non avrebbe pagato comunque. Chi accumula viaggi è chi ha reso Trolley parte del proprio modo di viaggiare, ed è a quel punto che pagare ha senso. Questo vale per i **limiti**; le **funzioni riservate** al premium sono una leva diversa e complementare, ed è quella ancora da definire.

---

## Pricing iniziale

| Piano | Prezzo | Per chi | Limiti |
|---|---|---|---|
| **Free** | €0 | Tutti | Tutto il necessario per viaggiare. I limiti stanno sulle funzioni premium, non sullo spazio |
| **Pacchetto viaggio** | €9,99 una tantum | Chi ha un viaggio importante e non vuole abbonarsi | Sblocca tutto per **quel** viaggio, per sempre e per tutti i partecipanti. Finito quello si torna al gratuito |
| **Plus mensile** | €3,99/mese | Chi vuole provare senza impegno | Nessun limite |
| **Plus annuale** | €24,99/anno | Chi viaggia con continuità | Nessun limite. Costa quanto poco più di sei mesi del mensile |

Il prezzo esatto si decide in beta, ma il criterio è già scritto: **l'annuale deve convenire a chi fa almeno tre viaggi l'anno**, e il mensile va prezzato come si prezzano i mensili — abbastanza alto da far scegliere l'annuale.

### Il pacchetto viaggio

Al posto dell'una tantum a vita — scartata perché non copre costi di archiviazione che durano per sempre — si vende **il singolo viaggio**: 9,99 € sbloccano la creazione e la gestione completa di quel viaggio, per sempre, e i successivi tornano in modalità gratuita.

**Si compra solo prima del viaggio**, mai dopo. Un pacchetto acquistabile a viaggio finito diventerebbe un piano di recupero contro la cancellazione dei 12 mesi, e si metterebbe in concorrenza con l'abbonamento proprio nel momento in cui l'abbonamento converte meglio. **Due partecipanti che comprano il pacchetto per lo stesso viaggio non sono un problema**: vuol dire che entrambi volevano le funzioni premium, e non c'è niente da impedire né da rimborsare. Semmai è da valutare l'opposto — un **bundle di gruppo** a prezzo scontato che copra tutti i partecipanti in un colpo solo. **Non nell'MVP però**: sarebbe un quarto prodotto a listino prima di sapere se qualcuno paga per i primi tre. Se ne riparla quando H6 dà un segnale, e il numero che reggerebbe è €19,99 per l'intero viaggio a prescindere da quanti sono — conviene da due paganti in su, e tre viaggi a bundle costerebbero €59,91 contro €24,99 di abbonamento, quindi non cannibalizzerebbe l'annuale.

Su un prodotto stagionale funziona per tre ragioni. Chiede i soldi **nel momento di massimo valore percepito**, cioè mentre stai organizzando il viaggio che ti sta a cuore, invece che in astratto a un utente appena registrato. Non ha disdetta, quindi si porta dietro zero attrito psicologico. E soprattutto **non cannibalizza l'annuale**, a patto che il prezzo resti tarato così com'è: tre viaggi a pacchetto costano 29,97 € contro 24,99 € di abbonamento, quindi il pareggio cade fra il secondo e il terzo viaggio. Non è un caso che sia lì: tre viaggi l'anno è anche la frequenza che rende sensato l'abbonamento.

### Cosa sblocca chi paga: la regola

> **Il premium sblocca la persona per le funzioni individuali, e il viaggio per le funzioni collaborative.**

Se tre amici viaggiano insieme e uno solo è abbonato (o ha comprato il pacchetto), le funzioni che riguardano **il viaggio** valgono per tutti: aggiornamento dell'itinerario, funzioni condivise, tutto ciò che ha senso solo se lo vedono tutti. Le funzioni che riguardano **la persona** restano di chi paga: statistiche sulle proprie spese, archivio, passaporto, reimportazione.

Tre motivi, in ordine di forza:

1. **Trasforma chi paga nell'eroe del gruppo.** "Lo prendo io così ce l'abbiamo tutti" è un incentivo sociale molto più forte di uno sconto, e arriva proprio mentre il gruppo sta decidendo come organizzarsi.
2. **Fa provare il premium a chi non paga, nel momento migliore.** I tre amici usano le funzioni collaborative per tutto il viaggio. Al ritorno, quando ognuno va a guardare le proprie statistiche e trova il muro, a convertire è l'esperienza appena vissuta, non una pagina di prezzi.
3. **L'alternativa è peggio.** Se una funzione collaborativa richiedesse che *tutti* siano abbonati non si accenderebbe mai — basta un amico che non paga e la funzione muore per l'intero gruppo. Una funzione che non si accende non converte nessuno.

**Il rischio da accettare**: i gruppi si organizzeranno, un abbonamento a rotazione invece di tre. Va bene, perché l'alternativa realistica non è tre abbonamenti, è zero. Il contrappeso è che **la fase "dopo" resta individuale** — statistiche, archivio, passaporto e ritorno sui viaggi vecchi sono di chi paga, ed è esattamente la parte che continua a valere fuori dal viaggio, cioè quella su cui poggia il ricavo ricorrente.

La tentazione da evitare è mettere tutto tra le funzioni collaborative perché sono più attraenti: se lo si fa, dentro un gruppo non servirà mai un secondo abbonamento.

**Come si applica, funzione per funzione.** La regola da sola non basta: ogni funzione premium va assegnata a un lato o all'altro quando la si progetta, altrimenti la decisione la prende l'implementazione per conto suo. Questa è una prima assegnazione sulle funzioni che oggi immaginiamo — non è l'elenco definitivo del premium, è il modo in cui si compila.

| Funzione premium | Ambito | Perché |
|---|---|---|
| Aggiornamento dell'itinerario durante il viaggio | **Viaggio** | Ha senso solo se lo vedono tutti: se metà gruppo vede l'orario aggiornato e metà no, la funzione fa danno invece che servizio |
| Documenti del viaggio senza limiti di spazio | **Viaggio** | I documenti sono del viaggio, non di chi li ha caricati |
| Conservazione del viaggio oltre i 12 mesi | **Viaggio** | È esattamente ciò che compra il pacchetto viaggio |
| Statistiche sulle proprie spese | **Persona** | Riguardano i soldi di chi le apre, non del gruppo |
| Archivio storico e passaporto completo | **Persona** | È la storia di quella persona |
| Reimportazione di un archivio scaricato | **Persona** | È legata all'account, non a un viaggio |
| Anteprime beta delle novità | **Persona** | È un rapporto tra Trolley e chi paga |

Nota che **non tutte le funzioni sono in questa tabella**: ci finisce solo ciò che è premium. Tutto quello che serve per viaggiare resta gratuito per chiunque, e quella riga non si sposta.

### Cosa non viene mai limitato

Tre cose restano illimitate anche nel piano gratuito, perché limitarle significherebbe rompere i motori del prodotto:

- **I compagni di viaggio.** Sono il canale di acquisizione: metterci un limite significa far pagare l'utente per portarci utenti nuovi.
- **I badge e i traguardi.** Un profilo di viaggiatore mutilato dal piano gratuito non è esponibile, e una community fatta di profili mutilati non decolla.
- **Il viaggio in corso.** Nessuno deve trovarsi bloccato da un limite commerciale mentre è in aeroporto. È una scelta di prodotto prima che commerciale, e non si tocca.

**E allora dove morde il limite?** In nessun posto che riguardi i dati. Il piano gratuito è completo per viaggiare e per ricordare: quello che manca sono le **funzioni premium**, non i contenuti che hai messo dentro.

### I viaggi vecchi non si cancellano

C'era una regola che dopo 12 mesi alleggeriva i viaggi chiusi dei non paganti. **È stata tolta.** Esisteva per contenere i costi di archiviazione, e quei costi erano quasi interamente i documenti: da quando i documenti stanno sul telefono, un viaggio vecchio è qualche kilobyte di testo e conservarlo per sempre non costa niente.

Senza giustificazione economica sarebbe rimasta una punizione gratuita proprio sul ricordo, cioè sulla parte del prodotto che dovrebbe costruire affezione — e su un'app che si usa poche volte l'anno, l'affezione è l'unica cosa che porta a un secondo viaggio.

**Cosa si perde e come si sostituisce.** Si perde il momento di conversione più forte che il prodotto avesse: l'avviso di cancellazione in arrivo cadeva esattamente quando la persona stava ripensando a partire. Quel momento però esiste lo stesso, ed è il ritorno a distanza di un anno: al suo posto va un promemoria gentile sul viaggio dell'anno prima — "un anno fa eri a Lisbona" — che intercetta la stessa persona nello stesso istante senza minacciare di cancellarle niente.

**L'esportazione è gratuita, la reimportazione è premium.** Non c'è più nessun contatore da azzerare, ma la distinzione resta giusta per un'altra ragione: portarsi via i propri dati è un diritto, rimetterli dentro l'app è un servizio. Rendere premium anche l'esportazione non sarebbe comunque praticabile: il GDPR dà a chiunque il diritto di ricevere i propri dati in un formato leggibile da una macchina, e gratuitamente. La linea giusta passa un metro più in là ed è altrettanto efficace: **scaricare il proprio archivio è sempre gratis, rimetterlo dentro Trolley è una funzione a pagamento.** Chi prova a fare il furbo si ritrova con un file in mano e nessun modo di riportarlo nell'app — esattamente il risultato voluto, senza calpestare un diritto.

**Quello che manca ancora.** I limiti qui sopra sono metà del piano. L'altra metà sono le **funzioni esclusive del premium** e l'**accesso anticipato alle novità**, che è la parte capace di rendere l'abbonamento desiderabile invece che semplicemente necessario. Quali funzioni ci vadano è deliberatamente aperto: sceglierle adesso significherebbe mettere dietro il pagamento una funzione a caso e scoprire in beta che era proprio quella che teneva in piedi l'app. La decisione si prende con i risultati di H1 in mano.

---

## Costi reali

| Voce | Fase MVP | Note |
|---|---|---|
| Sviluppo | €0 | Solo founder, tempo proprio |
| Infrastruttura | €0 tendenziale | Piani gratuiti finché i volumi lo permettono. Con i **documenti tenuti sul telefono** e non su un server, quello che resta da archiviare è testo: viaggi, tappe, spese, liste. È poca roba e cresce piano — l'archiviazione ha smesso di essere la voce che sfonda per prima |
| **Apple Developer Program** | **99$/anno** | Obbligatorio, e serve **già per TestFlight** — quindi è un costo della beta, non del lancio |
| **Commissione Apple** | **15%** | 15% con lo Small Business Program (sotto 1M$ di ricavi annui), 30% oltre. Su un annuale da €24,99 restano circa €21 |
| **Generazione itinerario** | **€0 in beta, per scelta** | Nell'MVP la generazione passa dall'LLM dell'utente: nessuna chiamata a pagamento. La versione nativa costerebbe circa **$0,02–0,11 per itinerario** secondo il modello — $20–70 l'anno a volumi da beta, poco ma **variabile e senza tetto**. Diventa una voce di bilancio solo quando c'è un budget che la regge |
| **Mappe e percorsi** | **a chiamata** | La navigazione in tempo reale dentro l'app richiede un servizio di mappe e percorsi che si paga a chiamata. È l'unico costo variabile che cresce con **l'uso** e non con le registrazioni: chi naviga tutto il giorno costa più di dieci persone che aprono l'app due volte. Nella fase interna i piani gratuiti bastano e la valutazione è rimandata; il tetto diventa prerequisito per aprire fuori dal team |
| **Verifica via SMS** | **a messaggio** | Serve per attivare profilo pubblico e matching. È un costo variabile, ma **limitato dal numero di registrazioni** e non dall'uso, quindi molto più prevedibile di una chiamata a consumo. Va comunque messo un tetto |
| Dati geografici | da definire | Dipende dall'ADR sui dati geografici: un elenco incorporato costa zero, un servizio esterno costa a chiamata |
| **Moderazione** | **tempo tuo** | Con contenuti pubblici c'è un impegno ricorrente che non finisce al rilascio. Non è zero, ed è l'unico costo che non scala con i soldi ma con le ore |

**Nota onesta sul "costo zero".** L'infrastruttura può stare nei piani gratuiti a lungo, ma Trolley non è un'app a costo zero: 99$/anno partono comunque, e la moderazione è un impegno continuativo. La differenza è che sono costi prevedibili e piccoli, non che non esistano. **E la prevedibilità è una proprietà scelta, non una fortuna**: in beta non entra nessun costo variabile senza tetto, ed è il motivo per cui la generazione dell'itinerario passa dall'LLM dell'utente invece che dall'API.

---

## Unità economiche (stime iniziali)

- **Costo di acquisizione**: tendente a zero in fase iniziale — nessuna pubblicità a pagamento, la crescita passa dagli inviti ai compagni di viaggio
- **Ricavo netto per utente pagante**: circa **€21/anno** sul piano annuale, al netto della commissione Apple al 15%
- **Margine lordo**: alto. Con i documenti sul telefono non resta nessun costo che cresca linearmente con gli utenti attivi: quello che sincronizziamo è testo
- **Soglia rilevante**: il primo traguardo economico non è il pareggio, è **coprire i 99$ annui di Apple**. Bastano circa cinque abbonati annuali. È un obiettivo volutamente piccolo, ma è il primo segnale reale che qualcuno è disposto a pagare

---

## Rischi economici

| Rischio | Perché è concreto | Come lo affronto |
|---|---|---|
| Il piano gratuito basta a tutti | Chi fa un viaggio l'anno non raggiunge mai i limiti | Accettato consapevolmente: quell'utente non avrebbe pagato, ma porta compagni. È acquisizione, non mancato ricavo |
| L'abbonamento mensile cannibalizza l'annuale | L'utente si abbona un mese, poi disdice | Differenziale di prezzo netto a favore dell'annuale, e valore che continua fuori dal viaggio |
| I documenti sul telefono indeboliscono il viaggio condiviso | Restando locali non si passano ai compagni, e il gruppo torna a scambiarseli in chat — cioè il comportamento che Trolley voleva sostituire | Punto aperto: o si accetta che ognuno tenga i propri, o serve un modo di condividerli che non richieda un archivio nostro |
| La moderazione diventa insostenibile | Una persona sola non regge un flusso di segnalazioni crescente | Superficie pubblica volutamente stretta in partenza, con processo operativo scritto per una persona sola |
| Un solo abbonamento per gruppo | Le funzioni collaborative si sbloccano per il viaggio: tre amici possono farne a turno uno solo | Accettato. L'alternativa realistica non è tre abbonamenti, è zero — e il contrappeso è che la fase "dopo" resta individuale |
| Nessuno paga | H6 cade | Il segnale arriva in beta, prima che i limiti del piano gratuito siano scolpiti nel prodotto |
| Un costo a consumo sfugge di mano | Una funzione a chiamata — generazione dell'itinerario, servizi geografici — produce una bolletta che si scopre dopo, e in beta non c'è margine per assorbirla | Regola: in beta nessun costo variabile senza tetto. Dove serve consumo, passa dall'account dell'utente oppure ha una quota rigida per utente dal primo giorno |
