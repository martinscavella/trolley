# Valutazione d'impatto — Chi c'è in città

Bozza del 10 ottobre 2026 (fase 5.2), scritta prima di costruire la presenza in città (fase 5.5). Da rivedere con chi fa la revisione privacy e da firmare dal titolare prima della seconda ondata della beta.

La presenza in città si usa solo con il profilo pubblico acceso: tutto quello che vale per la parte pubblica vale anche qui, ed è in [la parte pubblica fra sconosciuti](valutazione-impatto-parte-pubblica.md) — chi sono le persone, il numero verificato, il blocco, la segnalazione, la moderazione. Questa valutazione guarda solo quello che la presenza aggiunge: **dire a sconosciuti in che città si è, adesso**.

---

## In breve

- **Che cosa si valuta**: chi è in viaggio accende, per quel viaggio, «Mostrami a Porto»; vede chi altro l'ha accesa a Porto, e quelle persone vedono lei. Si spegne da sola alla fine del viaggio, e la riga sul server si cancella.
- **È il trattamento più delicato del prodotto**: dice dove si trova adesso una persona fisica, a persone che non conosce. Le decisioni di prodotto lo sapevano già, e lo hanno smussato: solo la città, solo per un viaggio, spenta di partenza, reciproca, senza storico, e la città viene dalla meta del viaggio e non dalla posizione ([decisioni](../decisioni/prodotto.md)).
- **Leggendo i disegni sono emersi due buchi.** La meta è *dichiarata*: chiunque può creare un viaggio a Porto con le date di oggi e guardare chi c'è, senza esserci. E la tela mostra fino a quando ciascuno resta: un dato sul futuro di una persona. Più un terzo: in un comune di trecento abitanti «la città» è quasi un indirizzo.
- **Le misure C1–C8 li riducono**, appoggiandosi a cose già costruite: la verifica sul posto della 3.4, che il telefono fa da sé e di cui al server arriva solo un sì, e l'elenco delle destinazioni con la popolazione.
- **Decise il 10 ottobre 2026**: C1, la presenza si accende solo dopo il «sul posto» del telefono; C2, la data di fine la vede solo la persona. **C3, la soglia di abitanti, non è stata adottata**: la presenza vale per tutte le mete dell'elenco, e il rischio dei posti piccoli resta medio (R3).
- **Con C1 e C2 il rischio che resta è medio, non alto.** Senza C1 e C2 sarebbe alto, e la funzione non dovrebbe uscire.

---

## 1. Perché una valutazione

Qui i criteri WP248 sono quattro: dati di localizzazione, che le linee guida contano fra quelli «di carattere molto personale»; un uso nuovo, che mette in relazione sconosciuti per il luogo in cui sono; persone potenzialmente vulnerabili, perché chi viaggia è lontano da casa e spesso solo; e un effetto diretto sulla vita fuori dallo schermo. Era la valutazione che le decisioni di prodotto davano già per probabile.

C'è anche una ragione semplice: è l'unica funzione in cui un errore aiuta qualcuno a trovare fisicamente un'altra persona.

---

## 2. Il trattamento

### Chi

- **Interessati**: chi accende la presenza per un viaggio in corso. Ha il profilo pubblico acceso, quindi almeno 18 anni, un numero verificato, le condizioni accettate.
- **Chi vede**: solo chi ha acceso la presenza nella stessa città, per un viaggio in corso, ed escluso chi si blocca a vicenda. Chi guarda è visto: non esiste guardare senza farsi vedere.
- **I compagni di viaggio** non compaiono: la presenza è di ciascuno, non del viaggio. Se Giulia la accende, Marco, che è con lei, non si vede.

### Che cosa, e dove

| Dato | Da dove viene | Chi lo vede | Per quanto |
|---|---|---|---|
| La città | La meta del viaggio, scelta dall'elenco delle destinazioni. **Mai** la posizione del telefono | Chi ha la presenza accesa nella stessa città | Fino alla fine del viaggio, poi la riga si cancella |
| Fino a quando | La fine del viaggio | Solo la persona (C2; la tela la mostrava a tutti) | Come sopra |
| Il profilo pubblico | Quello della parte pubblica | Come sopra, con le regole della parte pubblica | Come il profilo |
| «Sul posto» (dalla 3.4, con C1) | Il telefono confronta la sua posizione con la meta, entro 50 km dal centro; al server arriva solo il sì con l'ora | Nessuno: è una condizione, non si mostra | Già sul server per la verifica del viaggio (`partecipazione.sul_posto_il`) |

La tabella del server è `presenza_citta`: chi, quale viaggio, quale città, fino a quando. Nessuna coordinata, nessuna distanza, nessuna riga che sopravviva al viaggio ([05](../tecnico/05-community-e-sicurezza.md)).

### Come scorre

1. Con un viaggio in corso, nella Community compare «Chi c'è a Porto». Prima di accenderla si dice tutto: solo la città, chi guarda è visto, quando si spegne, nessuno storico (tela, 79).
2. La persona accende «Mostrami a Porto». Il server controlla le condizioni — profilo pubblico acceso, viaggio in corso, il «sul posto» del telefono per quel viaggio (C1) — e scrive la riga.
3. Vede chi altro c'è, «a Porto adesso» e senza dire fino a quando (C2), con il numero dei paesi e «Collegati» o «Scrivi» se siete già collegati (tela, 80). Nessuno, che è il caso normale nella beta, si dice senza far sembrare rotta la schermata (81).
4. La spegne quando vuole; altrimenti si spegne da sola alla fine del viaggio, e la riga sparisce.

---

## 3. Necessità e proporzionalità

- **Finalità**: far conoscere persone che sono nello stesso posto nello stesso momento. Senza la città la funzione non esiste: il dato è necessario. Più preciso della città non serve, e per questo non c'è.
- **Base giuridica**: il contratto, come per la parte pubblica; ma qui la funzione si accende viaggio per viaggio, e potrebbe essere più onesto trattarla come un consenso (domanda C-1).
- **Minimizzazione**: la città, non la posizione; nessuna distanza; nessun ordine che dica chi è arrivato prima; nessuna copia sul telefono dell'elenco di chi c'è (C6). Che cosa non si raccoglie è la protezione più forte: il server non ha mai saputo dove sei dentro la città.
- **Conservazione**: nessuno storico, né sul server né sul telefono. **Con un limite da dire**: le copie di sicurezza del database. Oggi il progetto è sul piano gratuito di Supabase, che non ne fa; sul piano Pro le copie giornaliere durano sette giorni, e una riga cancellata ci resta per quel tempo. Va scritto nell'informativa se e quando si cambia piano (domanda C-3).
- **Il controllo della persona**: spenta di partenza; si spegne in un tocco; si spegne da sola; vale per un viaggio solo.

---

## 4. I rischi per le persone

| | Rischio | Prima delle misure | Già deciso | In più | Resta |
|---|---|---|---|---|---|
| R1 | **Guardare senza esserci**: un viaggio finto a Porto, con le date di oggi, basta per vedere chi c'è. «Chi guarda è visto» non protegge se chi guarda non è davvero lì | Probabile · Molto grave | Profilo pubblico, quindi numero verificato e condizioni | **C1**: la presenza si accende solo dopo il «sul posto» del telefono, per quel viaggio | Medio: il «sul posto» lo decide l'app, e il server controlla solo chi e quando (`segna_sul_posto`). Passa chi falsifica la posizione del telefono, o chi chiama il server direttamente con il proprio accesso. Costa competenza e lascia un account con un numero verificato, segnalabile |
| R2 | **Sapere dove sarà una persona**: «Fino al 14 ott» dice per quanti giorni ancora la si trova lì. È un dato sul futuro, quello che il profilo pubblico esclude per regola | Probabile · Grave | — | **C2**: la data di fine la vede solo la persona | Basso |
| R3 | **Una città troppo piccola** è quasi un indirizzo: l'elenco delle destinazioni ha 2.441 posti sotto i mille abitanti e 6.371 sotto i cinquemila, perché tiene tutti i comuni italiani | Possibile · Molto grave | Solo città, mai coordinate | C1: chi guarda deve essere lì anche lui, ed è visto. **C3**, una soglia di abitanti: non adottata | Medio: in un paese piccolo, chi c'è davvero e si fa vedere può trovare l'altra persona. Con C3 sarebbe basso |
| R4 | **Pochi in città**: con una sola altra persona, si sa esattamente chi c'è | Certo, nella beta · Limitata | Reciprocità: anche lei vede te; blocco | — | Basso: è il senso della funzione, e lo si dice prima di accenderla |
| R5 | **Lo storico ricostruito**: qualcuno che guarda ogni giorno e prende appunti; o un registro del server che conserva le città richieste | Possibile · Grave | Nessuno storico sul server; la riga si cancella | **C5**: le letture passano da una funzione con la città nel corpo della richiesta, mai nell'indirizzo che finisce nei registri; nessun evento porta la città; **C6**: niente copia sul telefono | Basso per il server. Quello che una persona annota a mano non si impedisce |
| R6 | **Dimenticarla accesa**, o un viaggio che cambia: date spostate, meta cambiata, ritorno anticipato | Possibile · Grave | Si spegne alla fine del viaggio | **C4**: cambiare meta o date la spegne; chiudere il viaggio a mano la spegne; la riga è invisibile appena passata la fine, anche se la cancellazione tarda | Basso |
| R7 | **Casa vuota**: chi è a Porto non è a casa | Possibile · Limitata | Lo vede solo chi è a Porto anche lui; il profilo non dice dove si abita | — | Basso |
| R8 | **I compagni di viaggio** rivelati da chi accende | Possibile · Limitata | La presenza è di ciascuno | — | Basso |
| R9 | **Due presenze insieme**, per guardare due città | Possibile · Limitata | Un viaggio in corso alla volta, di solito | **C7**: una sola presenza accesa per persona | Basso |
| R10 | **L'ora di arrivo** si deduce da quando una persona compare | Possibile · Limitata | — | **C8**: nessun «da quando», ordine alfabetico, mai per arrivo | Basso |

---

## 5. Le misure in più

C1 e C2 sono la condizione perché la funzione esca, e sono decise. C3 non è stata adottata. C4–C8 sono il modo di costruire la 5.5, da confermare quando la si costruisce. Tutte cambiano quello che la tela disegna.

| | Misura | Che cosa cambia | Stato |
|---|---|---|---|
| **C1** | **Solo dopo il «sul posto».** La presenza si accende solo se il telefono ha già trovato la persona entro 50 km dalla meta, per quel viaggio (`partecipazione.sul_posto_il`, 3.4). Al server non arriva niente di nuovo: il sì c'è già. È una barriera, non una prova: il server si fida dell'app (R1). Senza, la schermata dice «Quando sarai a Porto» | Tela 79; la funzione che accende la presenza controlla `sul_posto_il`. **Usa per un fine nuovo un dato raccolto per la verifica**: va detto nell'informativa (domanda C-2) | Decisa |
| **C2** | **La data di fine la vede solo la persona.** Gli altri leggono «a Porto adesso» | Tela 80: via «Fino al 14 ott» dalle righe degli altri; resta «Sei visibile fino a domenica» per sé | Decisa |
| **C3** | **Solo città con almeno 50.000 abitanti**, secondo l'elenco delle destinazioni. Un viaggio in un paese intero, o in una meta scritta a mano, non ha presenza | La regola di 11; la soglia sta in `configurazione`, così si cambia senza un rilascio. Positano (3.729) no, Matera (59.685) sì | Non adottata |
| **C4** | **Cambiare la meta o le date la spegne**, e così chiudere il viaggio prima della fine. La lettura esclude da sé le righe scadute | Il server, nelle funzioni che cambiano il viaggio; la regola di lettura di `presenza_citta` | Da confermare con la 5.5 |
| **C5** | **Letture da una funzione**, con la città nel corpo della richiesta, non nell'indirizzo; nessun evento di misurazione porta la città | Come si costruisce la 5.5; `presenza_attivata` senza la città, come già `passaporto_compilato` senza il dove (07) | Da confermare con la 5.5 |
| **C6** | **Niente copia sul telefono** dell'elenco di chi c'è: si chiede ogni volta, e senza rete la schermata lo dice | È una delle funzioni «dipendenti dalla rete» (02) | Da confermare con la 5.5 |
| **C7** | **Una presenza alla volta** per persona | Un vincolo sulla tabella | Da confermare con la 5.5 |
| **C8** | **Nessun «da quando»**, e l'elenco in ordine di nome | Tela 80 | Da confermare con la 5.5 |

---

## 6. Che cosa resta, e la conclusione

Con C1, C2 e C4–C8 nessun rischio resta alto. Restano medi due rischi. R1, per chi è disposto a falsificare la posizione del telefono o a chiamare il server senza passare dall'app: è un'azione deliberata, contro le condizioni d'uso, e lascia un account con un numero verificato che si può segnalare e sospendere. Se succedesse, la misura successiva è far provare al server che la richiesta viene dall'app vera (App Attest di Apple, con il programma sviluppatori). E R3, i posti piccoli, per la scelta di non mettere una soglia: chi può vedere qualcuno a Positano è a sua volta a Positano, visibile e bloccabile, ma in un paese di pochi vicoli trovarsi è facile. È la prima misura da riprendere se una segnalazione riguarda la presenza in un posto piccolo, ed è la domanda C-5.

**Conclusione proposta**: con C1 e C2 il rischio residuo non è elevato e non serve la consultazione preventiva del Garante. **Senza quelle due, sì**: la presenza in città non dovrebbe uscire.

### Quando si rivede

- se la presenza dovesse usare la posizione del telefono invece della meta: è una funzione nuova, con una valutazione nuova ([05](../tecnico/05-community-e-sicurezza.md));
- se si aggiunge una distanza, una mappa, un quartiere, o qualunque cosa più precisa della città;
- se si cambia piano di Supabase, per le copie di sicurezza;
- dopo un episodio in cui qualcuno è stato trovato attraverso la presenza;
- in ogni caso a un anno dall'apertura.

---

## 7. Domande per chi fa la revisione

- **C-1.** Il contratto basta, o per la presenza — accesa viaggio per viaggio, con un dato di luogo — serve il consenso dell'art. 6.1.a, revocabile spegnendola?
- **C-2.** C1 usa il «sul posto» della verifica del viaggio come condizione per accendere la presenza. È un fine compatibile (art. 6.4), o va chiesto a parte? Il sì stesso è un dato di localizzazione (domanda 4)?
- **C-3.** Le copie di sicurezza del database, se si passa a un piano che le fa, conservano per sette giorni righe che diciamo cancellate. Basta dirlo nell'informativa?
- **C-4.** La città come meta di un viaggio, dichiarata e poi confermata dal telefono, è un «dato di ubicazione» ai sensi della direttiva ePrivacy, o un dato personale ordinario? Cambia gli obblighi?
- **C-5.** Abbiamo scelto di non mettere una soglia di abitanti: la presenza vale anche in un comune di trecento persone, con C1 e C2 come difese. È difendibile come proporzionalità, o una soglia (50.000 abitanti, o le sole città dell'elenco mondiale) è una misura che il titolare deve adottare?
