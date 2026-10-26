# 04 — Itinerario

## A cosa serve

Costruire il programma dei giorni. È la funzione con più attrito potenziale dell'app, ed è quella su cui poggia l'ipotesi H2: se lo scheletro non invoglia il gesto successivo, il viaggio resta un contenitore vuoto.

---

## Schermate

- **Giorni** — l'elenco delle giornate con la loro capienza
- **Giornata** — la linea del tempo dalle 0 alle 24, con le tappe ai loro orari
- **Nuova tappa** — luogo, durata stimata, orario
- **Genera itinerario** — prepara il prompt, lo consegna, riceve indietro il risultato

---

## Regole di comportamento

1. **L'itinerario esiste solo nello stato definito**, perché ha bisogno dei giorni.
2. **Ogni tappa ha una durata stimata e un orario.** Tutti e due sono **precompilati** — la durata secondo il tipo di tappa, l'orario subito dopo l'ultima tappa del giorno (regola 19): non si chiede mai a vuoto.
3. **Ogni giornata ha una capienza**, che è la finestra reale del giorno — dagli orari di arrivo e partenza per il primo e l'ultimo giorno, dall'intera giornata per quelli in mezzo.
4. **Quando la somma delle durate supera la capienza, la tappa non si aggiunge.** Si dice quanto manca e si propone di accorciare, spostare a un altro giorno o togliere qualcosa. Con gli orari la regola resta, e si fa più precisa: una tappa non si salva neppure dove si sovrapporrebbe a un'altra (regole 19–30).
5. **Nessun limite al numero di tappe** oltre quello che la capienza impone da sé. Non c'è nessun avviso su chi "ne mette troppe": il limite è nel modello, non nella sorveglianza.
6. **Le tappe si possono spostare fra giornate**, e la capienza si ricalcola su entrambe. L'orario resta, se nel giorno nuovo è libero; altrimenti valgono le proposte della regola 22.

### Generazione dell'itinerario

7. **Trolley non chiama nessun modello.** Costruisce un prompt a partire da destinazione, giorni, orari e preferenze, e lo consegna perché la persona lo porti sull'assistente che già usa.
8. **Il prompt chiede una risposta in un formato preciso**, dentro un blocco di codice, così che il ritorno sia un solo tocco e non una selezione di testo fatta a dito.
9. **Il ritorno si incolla in un campo**, con il gesto della persona. L'app non legge gli appunti da sola.
10. **L'interpretazione è tollerante**: chiacchiere prima e dopo, campi mancanti, formattazione approssimativa. Si importa il parziale invece di rifiutare tutto.
11. **Il testo incollato si salva sempre**, anche quando l'interpretazione fallisce: diventa una nota del viaggio. Nessuno deve rifare il giro da capo.
12. **Si suggeriscono modelli di fascia medio-alta**, da un elenco aggiornabile da remoto e non scritto nel codice.
13. **Si avvisa che il risultato lo produce un servizio di terzi** e che Trolley non risponde della sua qualità. La tutela vera però è che tutto ciò che arriva resta modificabile.
14. **Le tappe generate entrano come tutte le altre**, capienza della giornata compresa: se l'assistente propone dodici ore di visite in una giornata da otto, l'eccedenza si vede e si sistema.

### Stato delle tappe

15. **Ogni tappa ha uno stato**: *da fare*, *completata*, *saltata*.
16. **Si marca durante il viaggio**, dalla schermata di oggi o dalla mappa, in un tocco solo. **Funziona anche senza rete**, come aggiungere una tappa.
17. **Marcare dopo la chiusura si può, ma non conta per la verifica.** La verifica misura cosa è successo durante, non cosa è stato ricostruito dopo.
18. **A fine giornata, se restano tappe non marcate, l'app lo ricorda una volta.** È il gesto da cui dipende la verifica del viaggio: vale un promemoria, non vale un assillo.

### Gli orari

Chiesti dall'utente il 26 ottobre 2026, al posto delle tappe in fila: la giornata è una linea del tempo dalle 0 alle 24, e le tappe stanno ai loro orari ([decisioni](../decisioni/prodotto.md#gli-orari-delle-tappe-e-la-linea-del-tempo-26-ottobre-2026)).

19. **Ogni tappa ha un orario d'inizio**, e occupa la giornata da lì per quanto dura. Come la durata, l'orario è **precompilato**: subito dopo la fine dell'ultima tappa del giorno; se lì non entra, nel primo spazio libero dalle 9 — dall'arrivo, il primo giorno —; se dalle 9 in poi non c'è, anche prima. Gli orari vanno a passi di cinque minuti.
20. **Una tappa sta tutta dentro la sua giornata**: non comincia prima dell'arrivo, non finisce dopo la partenza, e non attraversa la mezzanotte. Una serata che finisce all'una si divide in due tappe.
21. **Due tappe non si sovrappongono.** Toccarsi sì: una che finisce alle 11 e una che comincia alle 11 vanno bene. Vale anche in gruppo: il programma è uno solo.
22. **Quando una tappa non può stare dove la si vuole non si salva, e si dice perché** — con quale tappa si scontra, a che ora si arriva o si riparte —, **e si propone solo quello che si può fare**, in quest'ordine:
    - **all'orario libero più vicino** a quello scelto, prima o dopo (a pari distanza, dopo), dove entra così com'è;
    - **tenere l'orario e spostare in avanti le tappe dopo**, di quanto serve e non di più, se stanno ancora tutte nella giornata. Non si spostano le tappe già segnate, né una già cominciata a quell'ora;
    - **accorciarla** a quello che resta fino alla tappa dopo, o alla fine della giornata, se è almeno un quarto d'ora;
    - **metterla nel giorno più vicino** in cui entra così com'è — alla stessa ora se lì è libera, altrimenti all'orario proposto; a pari distanza, il giorno dopo;
    - **togliere qualcosa** da quel giorno, sempre.
23. **La capienza resta la regola di fondo** (regola 4): con tappe che non si sovrappongono e stanno dentro la giornata, la somma delle durate non la supera mai. Una giornata può però avere abbastanza tempo libero e nessun buco lungo abbastanza: è il caso di «sposta in avanti le tappe dopo».
24. **Cambiare l'orario, la durata o il giorno di una tappa segue le stesse regole.** Cambiarne solo il nome, il tipo o il posto no: una tappa già fuori posto non blocca chi le corregge il titolo.
25. **L'ordine della giornata è quello degli orari.** Non si riordina più un elenco trascinando: si sposta una tappa sulla linea del tempo, e l'ordine segue. Ovunque le tappe compaiano in fila — «Adesso», la mappa, la navigazione, l'anteprima di un itinerario — è l'ordine degli orari.
26. **Sulla linea del tempo una tappa si trascina** tenendola premuta: va a passi di cinque minuti, dice l'orario mentre si muove, e diventa rossa dove si sovrapporrebbe o uscirebbe dalla giornata. Lasciata lì, torna al suo posto. Spostarla richiede la rete, come cambiarla (02): senza, la linea lo dice. Il cerchio a sinistra della tappa resta quello che segna: un tocco fatta, tenuto premuto saltata.
27. **Una tappa senza orario** — da un itinerario incollato che non le dava un'ora, o aggiunta prima di questa regola — si mette in fila da sola: nell'ordine in cui è, nel primo spazio libero dopo quella che la precede. L'orario si mostra come proposto finché qualcuno non lo conferma o lo cambia.
28. **Una tappa aggiunta senza rete che all'invio si sovrappone** a una arrivata nel frattempo entra comunque, segnata, come quella che sfora la capienza (casi limite): la giornata la mostra in rosso finché non si sistema, con le proposte della regola 22.
29. **Il primo e l'ultimo giorno**, prima dell'arrivo e dopo la partenza, la linea del tempo è chiusa e lo dice («Arrivi alle 10:00»). Se le date o gli orari cambiano, le tappe che non ci stanno più non si cancellano: restano in rosso, da sistemare (02, casi limite).
30. **Toccando uno spazio libero** della linea del tempo si apre una tappa nuova a quell'ora, arrotondata al quarto d'ora; il pulsante «Aggiungi una tappa» usa l'orario proposto.

---

## Casi limite

| Situazione | Comportamento |
|---|---|
| L'interpretazione del testo incollato fallisce | Il testo si salva come nota, si spiega cosa non si è capito, si propone di riprovare. Mai una schermata di errore che non lascia niente |
| L'itinerario generato riguarda una destinazione diversa | Si segnala prima di importare. Capita quando qualcuno riusa un prompt vecchio |
| La durata stimata è palesemente sbagliata | È modificabile sempre, e la stima proposta non è mai vincolante |
| Due persone modificano la stessa tappa insieme, online | Conflitto: si mostrano le due versioni e si sceglie |
| Una tappa aggiunta senza rete sfora la capienza, perché nel frattempo altri ne hanno aggiunte | Entra comunque, **segnalata come eccedente**, e si chiede cosa togliere. Rifiutarla dopo che è stata nell'app per due giorni sarebbe peggio |
| Una tappa aggiunta senza rete trova il suo orario preso da un'altra | Lo stesso: entra, in rosso, con le proposte per spostarla (regola 28) |
| Due persone mettono una tappa alla stessa ora quasi insieme, online | La seconda salva su una copia che non ha ancora la prima: entra, e si vede in rosso come quella arrivata senza rete. Il server non fa rispettare gli orari: le regole di dominio stanno nell'app |
| Un itinerario incollato dà due tappe alla stessa ora, o una ora già presa | Nell'anteprima la seconda va nel primo spazio libero dopo, e si dice che è stata spostata. Se nella giornata non c'è posto vale la capienza (regola 14) |

---

## Cosa resta fuori

- Chiamata diretta a un modello dall'app
- Suggerimenti automatici di attrazioni o percorsi ottimizzati
- Tempi di spostamento calcolati fra una tappa e l'altra: la capienza somma le durate, non i trasferimenti. Sulla linea del tempo lo spostamento è lo spazio libero che si lascia fra due tappe
- Tappe in parallelo, per un gruppo che si divide: il programma è uno solo
- Tappe che attraversano la mezzanotte
