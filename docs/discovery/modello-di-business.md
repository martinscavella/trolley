# Modello di business

## Come genera ricavi

- **Modello**: freemium con abbonamento, rivolto al consumatore finale
- **Chi paga**: l'utente stesso, tipicamente chi organizza il viaggio
- **Momento del pagamento**: ricorrente, dopo che l'app ha già dimostrato di funzionare — il momento naturale della richiesta è **la chiusura del primo viaggio andato bene**, non la registrazione
- **In MVP**: nessun pagamento attivo. L'app è gratuita e serve a validare, non a monetizzare

---

## Il problema di prezzare un'app stagionale

Un'app da viaggio non si usa tutti i giorni: si usa intensamente 2-5 volte l'anno. Questo rompe l'abbonamento mensile classico, perché il comportamento razionale dell'utente è abbonarsi a luglio e disdire ad agosto. Un mensile mal prezzato non produce ricavi ricorrenti, produce ricavi una tantum con in più il costo di gestione di un abbonamento.

Ne discendono tre scelte:

1. **L'annuale è il piano vero**, il mensile esiste solo per chi vuole provare senza impegno, ed è prezzato in modo che l'annuale convenga in modo evidente già al secondo mese.
2. **Il valore deve continuare fuori dal viaggio**, altrimenti nulla giustifica un abbonamento continuativo. È esattamente il compito della fase "dopo": traguardi, storia di viaggio, profilo. Non è un contorno del prodotto, è ciò che rende difendibile il modello di ricavo.
3. **Il limite del piano gratuito va sull'accumulo, non sull'uso singolo.** Chi fa un viaggio all'anno resta gratis per sempre, e va benissimo: non avrebbe pagato comunque. Chi accumula viaggi è chi ha reso Trolley parte del proprio modo di viaggiare, ed è a quel punto che pagare ha senso.

---

## Pricing iniziale

| Piano | Prezzo | Per chi | Limiti |
|---|---|---|---|
| **Free** | €0 | Tutti | 2 viaggi consultabili in archivio, 100 MB di documenti |
| **Plus mensile** | €3,99/mese | Chi vuole provare senza impegno | Nessun limite |
| **Plus annuale** | €24,99/anno | Chi viaggia con continuità | Nessun limite. Costa quanto poco più di sei mesi del mensile |

### Cosa non viene mai limitato

Tre cose restano illimitate anche nel piano gratuito, perché limitarle significherebbe rompere i motori del prodotto:

- **I compagni di viaggio.** Sono il canale di acquisizione: metterci un limite significa far pagare l'utente per portarci utenti nuovi.
- **I badge e i traguardi.** Un profilo di viaggiatore mutilato dal piano gratuito non è esponibile, e una community fatta di profili mutilati non decolla.
- **Il viaggio in corso.** Nessuno deve trovarsi bloccato da un limite commerciale mentre è in aeroporto. È una scelta di prodotto prima che commerciale, e non si tocca.

Il limite morde quindi in un punto solo e ben preciso: **rileggere i viaggi vecchi** e **accumulare documenti**. Entrambi crescono con il tempo e nessuno dei due serve mentre stai viaggiando.

---

## Costi reali

| Voce | Fase MVP | Note |
|---|---|---|
| Sviluppo | €0 | Solo founder, tempo proprio |
| Infrastruttura | €0 tendenziale | Piani gratuiti finché i volumi lo permettono. **L'archiviazione documenti è la voce che sfonda per prima**: sono file pesanti che nessuno cancella mai |
| **Apple Developer Program** | **99$/anno** | Obbligatorio, e serve **già per TestFlight** — quindi è un costo della beta, non del lancio |
| **Commissione Apple** | **15%** | 15% con lo Small Business Program (sotto 1M$ di ricavi annui), 30% oltre. Su un annuale da €24,99 restano circa €21 |
| Dati geografici | da definire | Dipende dall'ADR sui dati geografici: un elenco incorporato costa zero, un servizio esterno costa a chiamata |
| **Moderazione** | **tempo tuo** | Con contenuti pubblici c'è un impegno ricorrente che non finisce al rilascio. Non è zero, ed è l'unico costo che non scala con i soldi ma con le ore |

**Nota onesta sul "costo zero".** L'infrastruttura può stare nei piani gratuiti a lungo, ma Trolley non è un'app a costo zero: 99$/anno partono comunque, e la moderazione è un impegno continuativo. La differenza è che sono costi prevedibili e piccoli, non che non esistano.

---

## Unità economiche (stime iniziali)

- **Costo di acquisizione**: tendente a zero in fase iniziale — nessuna pubblicità a pagamento, la crescita passa dagli inviti ai compagni di viaggio
- **Ricavo netto per utente pagante**: circa **€21/anno** sul piano annuale, al netto della commissione Apple al 15%
- **Margine lordo**: alto, ma eroso dall'archiviazione documenti, che è l'unico costo che cresce linearmente con gli utenti attivi
- **Soglia rilevante**: il primo traguardo economico non è il pareggio, è **coprire i 99$ annui di Apple**. Bastano circa cinque abbonati annuali. È un obiettivo volutamente piccolo, ma è il primo segnale reale che qualcuno è disposto a pagare

---

## Rischi economici

| Rischio | Perché è concreto | Come lo affronto |
|---|---|---|
| Il piano gratuito basta a tutti | Chi fa un viaggio l'anno non raggiunge mai i limiti | Accettato consapevolmente: quell'utente non avrebbe pagato, ma porta compagni. È acquisizione, non mancato ricavo |
| L'abbonamento mensile cannibalizza l'annuale | L'utente si abbona un mese, poi disdice | Differenziale di prezzo netto a favore dell'annuale, e valore che continua fuori dal viaggio |
| I documenti fanno esplodere i costi di archiviazione | I file sono pesanti, nessuno li cancella, restano per sempre | Quota per piano, compressione, e politica di conservazione scritta prima che il problema si presenti |
| La moderazione diventa insostenibile | Una persona sola non regge un flusso di segnalazioni crescente | Superficie pubblica volutamente stretta in partenza, con processo operativo scritto per una persona sola |
| Nessuno paga | H6 cade | Il segnale arriva in beta, prima che i limiti del piano gratuito siano scolpiti nel prodotto |

---

## Domande aperte

- Ha senso un'opzione **una tantum a vita**? Su un'app stagionale è attraente per l'utente e chiude il problema della disdetta, ma non copre costi di archiviazione che durano per sempre.
- Il limite del piano gratuito va sul **numero di viaggi archiviati** o sulla **finestra temporale** (per esempio "gli ultimi 12 mesi")? Il secondo è più gentile e più difficile da percepire come punitivo.
- €24,99/anno è il prezzo giusto per un'app che si usa poche volte l'anno, o è meglio un prezzo più basso con conversione più larga? Da testare in beta, non da decidere adesso.
- Chi organizza paga per tutti o ciascuno per sé? Se il valore lo riceve il gruppo ma il costo lo sostiene una persona sola, il modello scarica il prezzo sulla persona sbagliata.
