# Valutazione d'impatto — La parte pubblica fra sconosciuti

Bozza del 10 ottobre 2026 (fase 5.2), scritta prima di costruire il profilo pubblico, la ricerca, i collegamenti e i messaggi (fasi 5.3 e 5.4), perché quello che dice possa ancora cambiarli. Da rivedere con chi fa la revisione privacy e da firmare dal titolare prima della seconda ondata della beta.

La presenza in città ha una valutazione sua, che si appoggia a questa: [presenza in città](valutazione-impatto-presenza-in-citta.md). Il quadro dei dati di tutta l'app e le domande già aperte sono in [per la revisione](per-la-revisione.md).

---

## In breve

- **Che cosa si valuta**: persone maggiorenni che non si conoscono si trovano per le mete già viste e per cosa piace loro in viaggio, chiedono di collegarsi e, se l'altro accetta, si scrivono.
- **Il rischio vero non è sui dati, è sulle persone**: molestie, una persona cercata apposta, un incontro di persona andato male. I dati in gioco sono pochi e scelti: nome, numeri del passaporto, viaggi già chiusi, una lista chiusa di gusti, i messaggi fra due persone collegate.
- **Gran parte delle difese è già costruita** (5.1): età, numero verificato, condizioni d'uso accettate, blocco reciproco, segnalazione che fotografa il contenuto, sospensione motivata, interruttore della parte pubblica, viaggi futuri irraggiungibili per regola del server.
- **Leggendo i disegni della 5.3 e della 5.4 sono emerse dieci misure in più** (M1–M10). Il 10 ottobre 2026 ne sono state decise cinque — chi guarda è visibile, niente ricerca per nome, ogni viaggio si può nascondere, del viaggio solo la meta e quando, un viaggio compare solo dopo la sua fine — più due che sono il modo di costruire. Il tetto alle richieste e il divieto di richiedere dopo un no restano proposte, per ora non adottate.
- **Con quelle misure il rischio che resta è medio, non alto**: secondo questa bozza non serve consultare il Garante prima (art. 36). È la conclusione da confermare.

---

## 1. Perché una valutazione

L'art. 35 del GDPR la chiede quando un trattamento «può presentare un rischio elevato per i diritti e le libertà». Con i criteri delle linee guida europee (WP248, fatte proprie dall'EDPB) la parte pubblica ne tocca tre:

| Criterio | Perché lo tocca |
|---|---|
| Valutazione o *matching* sulla base di interessi e spostamenti | La ricerca mette in fila le persone per mete viste e gusti in comune |
| Dati di carattere molto personale | I viaggi chiusi dicono dove una persona è stata e quando; i messaggi sono comunicazioni private |
| Uso innovativo, con effetti sulla vita fuori dallo schermo | Lo scopo dichiarato è che due sconosciuti si incontrino, anche di persona |

L'elenco del Garante (provvedimento n. 467 dell'11 ottobre 2018) mette fra i trattamenti da valutare la profilazione, anche tramite app, che riguarda «preferenze o interessi personali» e «ubicazione o spostamenti». Il nostro *matching* è semplice — conta le cose in comune, non predice niente e non decide niente — e nella beta riguarda poche decine di persone, quindi non è «su larga scala». Lo si valuta lo stesso: la decisione era già presa ([06](../tecnico/06-privacy-e-conformita.md)), e il danno possibile è di quelli che non si riparano dopo.

---

## 2. Il trattamento

### Chi

- **Interessati diretti**: chi accende il profilo pubblico. Ha almeno 18 anni (data di nascita dichiarata), un numero di telefono verificato, ha accettato le condizioni d'uso, non è sospeso.
- **Interessati indiretti**: i compagni dei viaggi che compaiono sul profilo di qualcuno, e chi è nominato in un messaggio. Non hanno acceso niente, e la valutazione li tratta per questo come i più esposti (R6).
- **Chi vede**: le altre persone con il profilo pubblico acceso (se si sceglie M1), tranne chi si blocca a vicenda.
- **Chi tratta**: noi, con Supabase (database, accesso, funzioni, in Irlanda) e Twilio (solo per il codice SMS, già nella 5.1).

### Che cosa, e dove

| Dato | Da dove viene | Chi lo vede | Per quanto |
|---|---|---|---|
| Nome (come lo si è scritto nell'account), iniziale come immagine | Account | Chi ha il profilo pubblico acceso | Finché il profilo è acceso; spento, sparisce dalla ricerca e dai profili |
| «Su Trolley da» (mese e anno) | Account | Come sopra | Come sopra |
| Numeri del passaporto: viaggi, paesi, traguardi | Calcolati dai viaggi chiusi | Come sopra | Come sopra |
| Viaggi chiusi: meta, mese e anno, giorni, timbro «verificato» | Viaggi della persona | Come sopra | Come sopra |
| Cosa piace in viaggio, da una lista chiusa | Scelto dalla persona (5.3) | Come sopra | Come sopra |
| «In comune» | Calcolato al momento fra chi guarda e chi è guardato | Solo chi guarda | Non si conserva |
| Richiesta di collegamento, con un messaggio di 200 caratteri | Scritta da chi chiede | Solo chi la riceve | Finché non si risponde; poi M9 |
| Collegamento accettato | Le due persone | Le due persone | Finché uno dei due non lo toglie, o chiude l'account |
| Messaggi | Le due persone collegate | Solo loro due | Da fissare (domanda P6) |
| Blocchi | Chi blocca | Solo chi blocca | Finché non sblocca (5.1) |
| Segnalazioni e contenuto segnalato | Chi segnala; la fotografia la fa il server | Chi modera; chi segnala vede solo lo stato | Da fissare (domanda 21) |
| Numero di telefono | Chi accende il profilo | Nessuno: schema privato del server | Finché c'è l'account (5.1) |
| Eventi di misurazione | Il telefono, o il server | Il team, in aggregato | Come gli altri eventi: azioni, mai contenuti |

**Che cosa non c'è, di proposito**: cognome, foto, età, città di residenza, biografia libera, viaggi in programma o in corso in qualunque forma, compagni di viaggio, tappe, spese, note, documenti. Non è un'impostazione: per i viaggi futuri è una regola di lettura del server ([05](../tecnico/05-community-e-sicurezza.md)).

### Come scorre

1. La persona accende il profilo pubblico (5.1): vede prima che cosa vedono gli altri e che cosa mai, verifica il numero, accetta le condizioni. Il server ricorda quale versione.
2. Sceglie che cosa le piace (5.3). Vede «Così ti vedono», l'anteprima esatta del suo profilo.
3. Cerca per una meta e per gusti; i risultati dicono quante cose avete in comune. Apre un profilo.
4. Chiede di collegarsi, con un messaggio breve. L'altra persona accetta o rifiuta; chi ha chiesto vede solo che non è stata accettata.
5. Collegati, si scrivono. Da un profilo, da una conversazione e da un messaggio si segnala o si blocca, in due tocchi.
6. Chi modera, una persona sola, guarda le segnalazioni dall'editor SQL di Supabase e può archiviare, sospendere, togliere un messaggio ([moderazione](../sicurezza/moderazione.md)).

---

## 3. Necessità e proporzionalità

- **Finalità**: permettere a chi viaggia di trovare altri viaggiatori con mete e gusti simili, e di parlarsi se entrambi vogliono. È l'ipotesi H7 del prodotto, e la ragione per cui la parte pubblica esiste.
- **Base giuridica**: il contratto (art. 6.1.b), per un servizio che la persona chiede accendendolo, spento di partenza. Da confermare (domanda P1).
- **Minimizzazione**: ogni dato della tabella serve a una delle due cose — decidere se vale la pena collegarsi, o parlarsi. Il resto è escluso dall'elenco sopra. Le cose in comune si calcolano al momento e non si salvano: non esiste un punteggio di affinità che descrive una persona.
- **Il controllo della persona**: il profilo si spegne in un tocco e sparisce subito dalla ricerca; con M3 si sceglie viaggio per viaggio che cosa mostrare; si blocca senza spiegazioni; si chiude l'account dall'app, e con lui numero, profilo, collegamenti.
- **Nessuna decisione automatica**: nessun controllo automatico sospende o declassa qualcuno. La moderazione la fa una persona, sulle segnalazioni, e la sospensione si motiva (12, regole 5 e 9).
- **Fornitori**: Supabase e Twilio, già nell'informativa e nelle domande 9, 11 e 18. La parte pubblica non ne aggiunge altri.

---

## 4. I rischi per le persone

Probabilità e gravità sono stimate prima delle misure, su tre livelli. «Già fatto» è quello che c'è dalla 5.1; «In più» rimanda alle misure della sezione 5.

| | Rischio | Prima delle misure | Già fatto | In più | Resta |
|---|---|---|---|---|---|
| R1 | **Molestie**: messaggi indesiderati, insistenza, insulti | Probabile · Grave | Collegamento reciproco: prima del sì passa solo un messaggio di 200 caratteri; blocco immediato e reciproco; segnalazione in due tocchi; sospensione | M8 (un tetto alle richieste) e M9 (dopo un no non si richiede): proposte, non adottate | Medio: chi insiste dopo un no può richiedere, e lo ferma il blocco di chi riceve. Con M8 e M9 sarebbe basso |
| R2 | **Una persona cercata apposta** da chi la conosce: un ex, un collega, chi l'ha già bloccata altrove | Possibile · Molto grave | Blocco; un numero per account, quindi un account nuovo costa un numero nuovo | M2 (niente ricerca per nome); M1 (chi guarda deve essere a sua volta visibile e segnalabile) | Medio: chi conosce le mete di una persona può ancora riconoscerla dal nome e dai viaggi |
| R3 | **Un incontro di persona che va male**, fino al danno fisico | Possibile · Molto grave | Solo maggiorenni con numero verificato; le condizioni (sezione 7) lo dicono; segnalazione e 112 nella schermata delle segnalazioni | M10 (due righe di prudenza al primo collegamento) | Medio: è il rischio di ogni servizio che fa incontrare persone, e non si toglie con il software |
| R4 | **Un minore** che mente sull'età, o un adulto che cerca minori | Possibile · Molto grave | 18 anni per la parte pubblica, dichiarati e non modificabili dalla persona; motivo di segnalazione «potrebbe avere meno di 18 anni», da gestire entro 24 ore con sospensione | — | Medio: la verifica con documento è esclusa di proposito (12); domanda 23 |
| R5 | **I viaggi chiusi raccontano troppo**: abitudini, assenze ricorrenti, un viaggio appena finito | Possibile · Limitata | Solo viaggi chiusi, per regola del server; mai date precise, solo mese e anno | M4 (compare solo dopo la fine vera); M3 (si sceglie quali mostrare) | Basso |
| R6 | **I dati dei compagni di viaggio** finiscono sul profilo di un altro: chi c'era, che cosa hanno fatto, o una meta scritta a mano da chi ha creato il viaggio («Baita di Marco») | Possibile · Limitata | I compagni non compaiono mai; il viaggio non ha un titolo libero, solo la meta | M5 (del viaggio solo meta, mese e anno, giorni); M3 (la persona vede l'elenco e nasconde quello che non vuole) | Basso |
| R7 | **Categorie particolari dedotte**: una meta può rivelare una religione (un pellegrinaggio), la salute, l'orientamento; un gusto scritto a mano anche | Possibile · Grave | Nessuna biografia libera nel disegno | M3 (nascondere un viaggio); M6 (lista dei gusti chiusa, senza voci dell'art. 9) | Basso: quello che resta è reso pubblico dalla persona, viaggio per viaggio (art. 9.2.e, domanda P3) |
| R8 | **Profili falsi e truffe**: finti viaggiatori che chiedono soldi o dati | Possibile · Grave | Numero verificato; motivo «profilo falso»; sospensione | M8 | Medio: un numero si compra; il tetto di Twilio ne limita il costo per noi, non per chi truffa |
| R9 | **Raccolta in massa dei profili**, da uno script o da un account che scorre tutto | Possibile · Limitata | Profili leggibili solo con il profilo pubblico acceso | M1, M2 (risultati limitati, ricerche contate e con un tetto, nessun elenco di tutti) | Basso |
| R10 | **Messaggi letti da chi non dovrebbe**: una violazione del server, o un accesso interno | Improbabile · Grave | Regole per riga: un messaggio lo leggono le due persone; chi modera vede solo il contenuto fotografato da una segnalazione; l'accesso al progetto ha la verifica in due passaggi | M7 (i messaggi si leggono e scrivono solo da funzioni, mai con una lettura libera della tabella) | Basso. Non è una cifratura da capo a capo, e l'informativa deve dirlo |
| R11 | **Segnalazioni usate come arma**, per far sospendere qualcuno | Possibile · Limitata | Decide una persona, non un conteggio; le segnalazioni infondate ripetute sono vietate dalle condizioni | — | Basso |
| R12 | **Una sospensione sbagliata** | Improbabile · Limitata | La persona legge il motivo e la regola, e a chi scrivere; `riattiva`; i suoi viaggi restano suoi | — | Basso. Domanda 20, sul reclamo interno |
| R13 | **Il numero di telefono** usato per rintracciare qualcuno | Improbabile · Grave | Non compare da nessuna parte; il server non dice nemmeno a quale account appartiene un numero già usato | — | Basso |
| R14 | **La misurazione dice troppo** | Improbabile · Limitata | Eventi di azioni, mai contenuti, mai chi: `collegamento_richiesto` non dice a chi | — | Basso |

---

## 5. Le misure in più

Decise il 10 ottobre 2026: M1, M2, M3, M4 e M5 cambiano quello che la tela disegna per la 5.3; M6 e M7 sono il modo di costruirla. M8, M9 e M10 restano proposte.

| | Misura | Contro | Che cosa cambia | Stato |
|---|---|---|---|---|
| **M1** | **Guarda solo chi si fa guardare**: ricerca e profili degli altri solo con il proprio profilo pubblico acceso. È la regola della presenza in città («chi guarda è anche visto») estesa a tutta la parte pubblica | R2, R9 | La regola di lettura di 05 per i profili; la Community, con il profilo spento, dice come accenderlo invece di mostrare la ricerca | Decisa |
| **M2** | **Niente ricerca per nome.** Si cerca solo per meta (dall'elenco delle destinazioni) e per gusti. I risultati sono al più trenta, le ricerche si contano e hanno un tetto al giorno, e passano da una funzione del server con i criteri nel corpo della richiesta, non nell'indirizzo che finisce nei registri | R2, R9 | Tela 74 (la casella cerca mete, non persone); `cerca_viaggiatori` come funzione, non come lettura di tabella | Decisa |
| **M3** | **Il viaggio si nasconde dal profilo pubblico**, uno per uno. Accendendo il profilo si vede l'elenco di quello che comparirà | R5, R7 | Tela 75 e la 68 della 5.1; una colonna per partecipazione, perché un viaggio condiviso è di ciascuno | Decisa |
| **M4** | **Un viaggio compare solo dopo la sua fine.** Chi ne è responsabile può chiuderlo prima, a mano (4.1): chiuso non vuol dire finito. La regola del server diventa «chiuso e con la fine passata» | R5 | La regola «Viaggi sul profilo» di 05 | Decisa: è la regola «mai i viaggi in corso» applicata a un viaggio chiuso prima della fine |
| **M5** | **Del viaggio solo la meta, il mese e l'anno, i giorni.** Il viaggio non ha un titolo libero: il suo nome è già la meta. Una meta scritta a mano, fuori dall'elenco, compare com'è scritta: la persona la vede nell'elenco dei viaggi sul profilo, e la può nascondere (M3) | R6, R7 | Tela 73 e 74: «Kyoto e Osaka» diventa «Kyoto» | Decisa |
| **M6** | **La lista dei gusti resta chiusa** e senza voci che dicono una religione, la salute, l'orientamento, la politica. Oggi sono quelle dell'itinerario (cibo, arte e musei, storia, natura, panorami, shopping, vita notturna): vanno bene. Una voce nuova si controlla con questa regola | R7 | Niente oggi: è una regola per dopo | Decisa |
| **M7** | **Collegamenti e messaggi si toccano solo con funzioni del server** (`chiedi_collegamento`, `rispondi`, `scrivi`, `i_miei_messaggi`), che controllano blocco, collegamento e tetti in un posto solo, come `segnala` | R1, R10 | Come si costruisce la 5.4 | Decisa |
| **M8** | **Un tetto alle richieste di collegamento**: venti al giorno, come le segnalazioni. Non giudica nessuno e non guarda quante vengono accettate (12, regola 5): impedisce solo di scriverne cento | R1, R8 | Una riga in `configurazione`; il caso limite di 11 «molte richieste senza risposta» resta vero per il resto | Proposta, non adottata |
| **M9** | **Dopo un no non si richiede.** La richiesta rifiutata resta sul server, invisibile, per impedire la seconda; chi aveva chiesto vede «non accettata» per sempre | R1 | Lo stato `rifiutato` di `collegamento` non si cancella | Proposta, non adottata |
| **M10** | **Due righe di prudenza** quando un collegamento è accettato: incontrarsi in un posto pubblico, dirlo a qualcuno, che cosa fare se qualcosa non va. Una volta sola | R3 | Una scheda nella tela della 5.4 | Proposta |

---

## 6. Che cosa resta, e la conclusione

Con le misure della 5.1 e quelle decise, nessun rischio resta alto. Restano medi quattro rischi che sono di ogni servizio che fa incontrare persone — chi già conosce qualcuno lo riconosce (R2), un incontro di persona (R3), un minore che mente (R4), un truffatore con un numero comprato (R8) — e che il software riduce senza togliere. Per questi le difese sono le persone: chi segnala, chi modera entro 24 ore, chi blocca. Resta medio anche R1, l'insistenza dopo un no, per la scelta di non adottare per ora M8 e M9: sono le prime misure da riprendere se le segnalazioni per molestie arrivano dalle richieste di collegamento.

**Conclusione proposta**: il rischio residuo non è elevato, e non serve la consultazione preventiva del Garante (art. 36). La parte pubblica può aprire nella seconda ondata se:

1. le misure decise, M1–M7, sono costruite, con le loro prove sul server;
2. i prerequisiti della 5.1 sono chiusi: conto Twilio vero, numero di prova tolto, contatto della moderazione, condizioni d'uso pubblicate ([punti aperti](../punti-aperti.md));
3. chi modera può davvero guardare la coda ogni giorno: altrimenti la parte pubblica si apre chiusa ai nuovi.

### Quando si rivede

- se le persone con il profilo pubblico superano qualche migliaio, che è vicino alla «larga scala»;
- se si aggiunge qualcosa che questa valutazione esclude: foto, ricerca per nome, biografia libera, età visibile, viaggi futuri in qualunque forma;
- dopo un episodio grave, o se le segnalazioni per molestie superano quelle che una persona sola gestisce;
- in ogni caso a un anno dall'apertura.

### Pareri

- **Responsabile della protezione dei dati**: non è stato nominato. Domanda P5.
- **Le persone interessate** (art. 35.9): chi usa l'ondata 1 può dire che cosa si aspetta di vedere e di non vedere in un profilo pubblico, prima che la 5.3 sia finita. Proposta: cinque domande a chi è già dentro, prima di aprire.

---

## 7. Domande per chi fa la revisione

Continuano quelle di [per la revisione](per-la-revisione.md); qui con il prefisso P.

- **P1.** Il contratto come base per un servizio che la persona accende da sé, spento di partenza, va bene? O per la ricerca, che mette in fila le persone per gusti e mete, serve il consenso?
- **P2.** La valutazione è obbligatoria, con poche decine di persone nella beta, o è solo prudente? Cambia qualcosa nel come va tenuta?
- **P3.** Una meta che rivela una religione, mostrata sul profilo da chi l'ha scelto viaggio per viaggio (M3): basta l'art. 9.2.e, dati «resi manifestamente pubblici dall'interessato»? Le persone viste sono le altre con il profilo acceso, non chiunque: è «manifestamente pubblico»?
- **P4.** La ricerca che conta le cose in comune è «profilazione» ai sensi dell'art. 4.4? Se sì, che cosa va scritto in più nell'informativa?
- **P5.** Serve nominare un responsabile della protezione dei dati (art. 37), oggi o a quale soglia?
- **P6.** **Per quanto si tengono i messaggi**, e che cosa succede ai messaggi di chi chiude l'account o toglie il collegamento: si cancellano anche per l'altra persona, o restano a lei con «Account chiuso», come i contributi nei viaggi?
- **P7.** I messaggi non sono cifrati da capo a capo: li protegge l'accesso al server. Va detto nell'informativa con queste parole? Basta?
- **P8.** M9 tiene una richiesta rifiutata per sempre, solo per impedire la seconda. È un trattamento proporzionato, o serve un limite di tempo?
- **P9.** M10, le righe di prudenza: aiutano a dimostrare la diligenza, o rischiano di sembrare un'assunzione di responsabilità per gli incontri?
