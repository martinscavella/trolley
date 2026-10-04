# Punti aperti

Quello che non è ancora chiuso, e per ciascuna cosa **che cosa la chiude**.

Le decisioni già prese non stanno qui: stanno in [Decisioni di prodotto](decisioni/prodotto.md). Le domande a cui era possibile rispondere subito sono state chiuse e riportate lì — questo documento tiene solo ciò che richiede lavoro o misure.

Due sezioni:

- **A fare** — non sono domande, sono cose da costruire o da stimare.
- **Da misurare** — la risposta arriva dai numeri della beta, e qui è scritto quali.

---

## A fare

### Prerequisiti operativi — prima della Fase 0

Cose fuori dal codice senza le quali la [Fase 0](piano-di-costruzione.md) non si chiude.

| Voce | Perché blocca | Stato |
|---|---|---|
| **Iscrizione all'Apple Developer Program** | Senza, niente link universali, accesso con Apple e TestFlight: il deep link differito non si può provare su un'installazione vera. Serve anche per far provare l'app al team | Rimandata di proposito: si va avanti con l'account gratuito finché si prova da soli |
| **Dominio per i link d'invito** | Ospita il file di associazione per iOS e la pagina che rimanda allo store. Cambiarlo dopo rompe i link già inviati: meglio un dominio neutro, indipendente dal nome definitivo | Provvisorio: `trolleyapp.vercel.app`. Il dominio proprio va preso prima di mandare inviti fuori dal team |
| **Progetto Supabase**, region UE | Il server dei dati | ✅ `trolley-db`, eu-west-1 |
| **Strumenti locali**: Flutter, Supabase CLI, CocoaPods | Il minimo per compilare l'app | ✅ |
| **Conferma email in Supabase** | Il link di conferma deve tornare nell'app: `trolley://accesso` va tra gli URL consentiti (Authentication → URL Configuration) | Da fare |
| **Accesso con Google** | Credenziali OAuth di Google configurate in Supabase | Da fare |
| **Data dell'ondata 1** | "Sei mesi alla beta" va ancorato a una data scritta, altrimenti non si vede quando slitta | Da fissare |
| **Protezione dalle password compromesse** (Supabase Auth) | Con l'accesso via email è la difesa più economica contro le password già rubate altrove. La segnala il controllo di sicurezza di Supabase | Da attivare (Authentication → Policies) |
| **Funzione `public.rls_auto_enable()`** | Non viene dalle nostre migrazioni: l'ha creata Supabase, ed è eseguibile anche senza accesso. Il controllo di sicurezza la segnala | Da capire se serve; se no, togliere l'esecuzione ad `anon` |

### Rimasto fuori dalla 1.1

La fase 1.1 (stati idea e definito, giorni, capienza) è costruita. Restano, ciascuno con la sua fase:

| Voce | Perché aspetta | Quando |
|---|---|---|
| **Notifica "è ancora un'idea?"** | Oggi il sollecito sta dentro l'app, sulla scheda e nell'idea. La notifica ha bisogno del permesso, che si chiede quando serve davvero ([14](prodotto/14-notifiche.md)) | Con le notifiche |
| **Chiusura del viaggio** | "In corso" e "concluso" si ricavano dalle date; scriverli sul server, con verifica e traguardi, è la 4.1 | Fase 4.1 |

### Rimasto fuori dalla 1.2

La fase 1.2 (tappe: durata, ordine, stato, la coda per aggiungerle e segnarle senza rete) è costruita. Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
| **Promemoria di fine giornata** sulle tappe non segnate (04, regola 18) | È una notifica, e il permesso si chiede quando serve davvero ([14](prodotto/14-notifiche.md)) | Con le notifiche |
| **Copia delle tappe solo di oggi e domani** (01, "Dove vive ogni entità") | Oggi la copia prende tutte le tappe dei viaggi: pesano pochi byte. La copia selettiva e la preparazione prima della partenza sono la 3.3 | Fase 3.3 |
| **Togliere il segno di eccedente** da una tappa | Il segno resta sulla riga; la giornata lo mostra solo finché sfora davvero, quindi sistemata la giornata sparisce dalla vista | Se servirà a qualcosa |
| **Spostare una tappa trascinandola in un altro giorno** | Oggi si sposta dal foglio della tappa, scegliendo il giorno; trascinare vale dentro la giornata | Se la beta lo chiede |
| **La capienza di una giornata intera è di 24 ore** | È la regola scritta (01): in mezzo, giornata intera. Ma con 24 ore il "non entra" capita quasi solo il primo e l'ultimo giorno. Se si vuole che il tetto morda, serve una finestra di veglia (per esempio 8–22) | Da decidere |

### Rimasto fuori dalla 1.3

La fase 1.3 (documenti sul telefono: scansione, foto, file; elenco con oggi in cima; a un tocco dal viaggio in corso) è costruita, solo iOS. Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
| **Android** | Il canale `trolley/documenti` esiste solo in Swift ([ADR-008](tecnico/adr/008-documenti-sul-telefono.md)): va scritto in Kotlin, e va capito il backup (l'Auto Backup si ferma a 25 MB per app) | Prima della prima build Android |
| **Schermata di chiusura account** | 03 vuole che dica che disinstallare porta via i documenti. Oggi l'avviso sta al primo documento e nel dialogo "Esci"; la chiusura account non esiste ancora | Con la chiusura account |
| ~~**Rimuovere un viaggio dal telefono**~~ | Fatto nella 2.1: uscendo da un viaggio i propri documenti si cancellano, dopo una conferma che li conta. Se invece il viaggio sparisce perché ti tolgono, i documenti restano e l'elenco dei viaggi lo dice, con «Guardali» ed «Eliminali» | ✅ Fase 2.1 |
| **Il documento di adesso** | La schermata "adesso" mostrerà il documento agganciato a questo momento ([09](prodotto/09-durante-il-viaggio.md)) | Fase 3.1 |
| **Luminosità al massimo** mostrando un codice a barre | Comodo al gate; non chiesto dai documenti | Se la beta lo chiede |
| **Rivedere sulla tela le schermate 10–14** | Disegnate e costruite insieme il 3 ottobre 2026; l'utente non le ha ancora viste | Prima di chiudere la 1.3 |

### Rimasto fuori dalla 1.4

La fase 1.4 (spese: valuta predefinita, tasso di cambio, ultimo valore noto offline; registrare anche senza rete) è costruita. Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
| **Divisione: chi paga, chi partecipa, quote e saldi** | È la 2.3. Oggi ognuno registra le spese che ha pagato lui, senza quote, e il totale dice quanto è suo. La 2.3 deve decidere come valgono le spese registrate prima, senza quote: la proposta è in parti uguali fra chi c'era | Fase 2.3 |
| **La stessa spesa registrata da due persone** (06, casi limite) | Si segnala quando c'è più di un pagante, cioè con la divisione | Fase 2.3 |
| **Avviso prima di rimuovere chi ha saldi aperti** | La rimozione c'è dalla 2.1; il saldo no | Fase 2.3 |
| **Due persone cambiano la stessa spesa** | Oggi la seconda viene rifiutata e la copia si riscarica; le due versioni affiancate sono la 2.2 | Fase 2.2 |
| **Budget di massima allo stato idea** (06, regola 1) | Non è nel piano di costruzione: è un'altra cosa rispetto alle spese | Da decidere |
| **Statistiche aggregate delle spese** (06, regola 11) | Funzione premium individuale | Fase 6 |
| **Rivedere sulla tela le schermate 15–18** | Disegnate e costruite insieme il 3 ottobre 2026; l'utente non le ha ancora viste | Prima di chiudere la 1.4 |
| **La migrazione `spese_e_tassi` non è nell'elenco delle versioni del server** | È stata applicata dall'editor SQL di Supabase, che non la registra: lo schema c'è, la riga in `supabase_migrations.schema_migrations` no. Il file porta la versione `20261003090000` | Da registrare, o da lasciare scritto qui |

### Rimasto fuori dalla 1.5

La fase 1.5 (cose da portare: la propria lista, anche nelle idee, spuntabile senza rete) è costruita. Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
| **La lista del viaggio e chi porta cosa** (05, regole 1 e 2) | Oggi ognuno ha la sua lista personale. Il server sa già assegnare una voce solo a chi è del viaggio; mancano la lista comune, l'assegnazione e lo spostamento di una voce da una lista all'altra | Fase 2.4 |
| **Un assegnatario esce dal viaggio: le sue voci tornano libere, con un avviso** (05, casi limite) | L'uscita c'è dalla 2.1; l'assegnazione no | Fase 2.4 |
| **Due persone cambiano il testo della stessa voce** | Oggi la seconda viene rifiutata e la copia si riscarica, con il testo che si stava scrivendo ancora nel campo; le due versioni affiancate sono la 2.2 | Fase 2.2 |
| **Aggiungere una voce senza rete** | Non è uno dei quattro gesti: senza rete il campo si spegne e lo dice. Si allarga solo se H4 lo chiede | Se H4 lo chiede |
| **Notifica prima della partenza con le cose non spuntate** (14-notifiche) | Le notifiche non ci sono ancora | Con le notifiche |
| **Liste suggerite e modelli da riusare** (05, cosa resta fuori) | Fuori dal perimetro | Da decidere |
| **Rivedere sulla tela le schermate 19–23** | Disegnate e costruite insieme il 3 ottobre 2026; l'utente non le ha ancora viste | Prima di chiudere la 1.5 |
| **La migrazione `cose_da_portare` non è nell'elenco delle versioni del server** | Applicata il 3 ottobre 2026 dall'editor SQL di Supabase, che non la registra: lo schema c'è e le 9 prove di `supabase/tests/liste.sql` passano, la riga in `supabase_migrations.schema_migrations` no. Il file porta la versione `20261003170049` | Da registrare, o da lasciare scritto qui |

### Rimasto fuori dalla 1.6

La fase 1.6 (l'itinerario con un assistente: richiesta da copiare, risposta incollata, anteprima con la capienza, nota sempre salvata) è costruita. Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
| **Scrivere una nota a mano** (02, regola 2) | La tabella c'è (`origine = 'scritta'`); manca la schermata. Nella 1.6 le note nascono solo dalle risposte incollate | Da decidere |
| **Cambiare il testo di una nota** | Il server lo permette, con la versione; l'app per ora la legge, la copia e la elimina | Con le note scritte a mano |
| **Tempi di spostamento e orari che si accavallano** | L'anteprima somma le durate come la capienza (04, cosa resta fuori); due tappe proposte alla stessa ora entrano tutte e due | Se la beta lo chiede |
| **Leggere la risposta senza rete** | La nota va salvata prima di leggere, e salvare richiede la rete. Chi incolla di solito è appena stato sull'assistente, quindi online | Se H4 lo chiede |
| **La generazione nativa** | Dipende dalla regola asimmetrica: si costruisce se `prompt_esportato` e `incollato_riuscito` dicono che il giro viene fatto | Dopo la beta |
| **Rivedere sulla tela le schermate 24–28** | Disegnate e costruite insieme il 3 ottobre 2026; l'utente non le ha ancora viste | Prima di chiudere la 1.6 |
| **La migrazione `itinerario_incollato` non è nell'elenco delle versioni del server** | Applicata dall'editor SQL di Supabase, che non la registra: lo schema c'è e le 6 prove di `supabase/tests/note.sql` passano (verificato il 4 ottobre 2026), la riga in `supabase_migrations.schema_migrations` no. Il file porta la versione `20261003174945` | Da registrare, o da lasciare scritto qui |

### Rimasto fuori dalla 2.1

La fase 2.1 (chi c'è, inviti e inviti in sospeso, togliere qualcuno e passare il ruolo, uscire, il primo minuto di chi entra da un invito, il viaggio lasciato che non sparisce in silenzio) è costruita. Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
| **La migrazione `partecipanti` non è nell'elenco delle versioni del server** | Applicata il 4 ottobre 2026 dall'editor SQL di Supabase, che non la registra: le funzioni ci sono e le 9 prove di `supabase/tests/partecipanti.sql` passano, la riga in `supabase_migrations.schema_migrations` no. Il file porta la versione `20261004093000` | Da registrare, o da lasciare scritto qui |
| **Eliminare un viaggio** | Chi è responsabile ed è da solo non può uscire: il viaggio resterebbe senza nessuno. Per un'idea c'è l'archivio; per un viaggio definito che non si farà, oggi non c'è niente | Da decidere |
| **Avvisare chi viene tolto** | Oggi lo scopre aprendo l'app: l'elenco dei viaggi lo dice. Una notifica è dell'insieme delle notifiche ([14](prodotto/14-notifiche.md)) | Con le notifiche |
| **Saldi aperti prima di togliere qualcuno** | Non c'è ancora il saldo | Fase 2.3 |
| **Le voci assegnate a chi esce tornano libere** | Non c'è ancora l'assegnazione | Fase 2.4 |
| **`primo_contributo_invitato` guarda il ruolo di adesso** | Dopo un passaggio di ruolo chi ha creato il viaggio risulta partecipante: se non aveva mai aggiunto niente, il suo primo contributo conterebbe come quello di un invitato. Il caso è raro (chi crea un viaggio di solito ci mette qualcosa), e distinguerlo vorrebbe un campo in più sulla partecipazione | Se i numeri di H3 lo mostrano |
| **Rivedere sulla tela le schermate 29–33** | Disegnate e costruite insieme il 4 ottobre 2026; l'utente non le ha ancora viste | Prima di chiudere la 2.1 |

### Rimasto fuori dalla 2.2

La fase 2.2 (due versioni della stessa cosa: tappa, spesa, voce, date del viaggio; chi e quando; tienila, tieni l'altra, tutte e due per le voci; una cosa tolta) è costruita. Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
| **La migrazione `chi_ha_scritto` va applicata** | Aggiunge `modificato_da` e il trigger che lo scrive (viaggio, tappa, spesa, voce, nota). Senza, l'app funziona lo stesso ma l'altra versione dice «già salvata» invece di «di Marco». Il file porta la versione `20261004150000`; le prove sono in `supabase/tests/conflitti.sql`. Applicata dall'editor SQL non finisce in `schema_migrations` | Da applicare |
| **La notifica «Due versioni»** per chi esce prima di scegliere | Oggi chiudendo si torna al foglio, con quello che si era scritto; chiudendo anche il foglio la propria versione si perde, come per ogni foglio lasciato a metà. La notifica è dell'insieme delle notifiche ([14](prodotto/14-notifiche.md)) | Con le notifiche |
| **«Tienile tutte e due» per le note** | Le note oggi non si riscrivono: non possono trovarsi in due versioni | Con le note scritte a mano |
| **«Tienile tutte e due» per una voce della lista del viaggio** | Oggi la voce in più nasce nella propria lista personale, l'unica che c'è. Con la lista del viaggio dovrà nascere nella stessa lista dell'altra | Fase 2.4 |
| **Le quote di una spesa divisa** nelle due versioni | Con la divisione (2.3) una spesa ha anche chi ha pagato e per chi: vanno nel confronto | Fase 2.3 |
| **Rivedere sulla tela le schermate 34–36 e 88** | 34–36 disegnate prima, 88 (una tolta) disegnata e costruita il 4 ottobre 2026 | Prima di chiudere la 2.2 |

### Impianto di sicurezza del matching — stima

Il matching è nella prima release, e con esso una lista di lavori che prima erano "dopo". Questa è la stima, per una persona sola su iOS.

| Voce | Stima |
|---|---|
| Segnalazione di profilo e contenuto: modulo, coda di gestione, stati | 3–4 giorni |
| Blocco reciproco: invisibilità bidirezionale in ricerca, profili, messaggi | 2–3 giorni |
| Viaggi futuri mai esposti, anche nei profili pubblici e nella ricerca | 1 giorno |
| Verifica del numero di telefono (codice via SMS attraverso un servizio esterno) | 2–3 giorni |
| Età: raccolta della data di nascita, blocco della parte pubblica sotto i 18 | 1 giorno |
| Processo di moderazione scritto, più gli strumenti minimi per applicarlo (sospendere, rimuovere) | 2–3 giorni |
| Contatto raggiungibile e instradamento delle segnalazioni | mezza giornata |
| Condizioni d'uso e informativa aggiornate | 1–2 giorni, più la revisione legale |
| Modalità "chi c'è adesso in città", versione smussata | 3–4 giorni |
| **Totale** | **16–22 giorni, cioè 3–4 settimane e mezzo** |

Fuori da questa stima restano due cose: il **tempo ricorrente di moderazione**, che non finisce al rilascio, e l'eventuale **valutazione d'impatto sulla protezione dei dati**, che la modalità in tempo reale con ogni probabilità richiede.

### Deep link differito — da provare per primo

L'invito è un link che apre l'app se installata e la pagina dello store se non lo è; dopo l'installazione l'app deve aprire **quel** viaggio. È un meccanismo da scegliere e da verificare sul campo, e si rompe in silenzio: nessun errore, semplicemente l'invitato installa e si ritrova davanti a un'app vuota.

Siccome H3 è l'unico canale di acquisizione e non ha un piano B, questo è il pezzo che va costruito e provato **per primo**, prima di qualunque funzione.

### La conseguenza sul calendario

L'obiettivo dichiarato è **sei mesi alla beta**, su uno scope che la visione stima già in nove. Aggiungere tre settimane e mezzo non rompe un piano solido: rende esplicito che il piano non lo era. Va detto che togliendo gli esperimenti preliminari si sono liberate un paio di settimane, che però non compensano — quelle servivano a evitare di costruire la cosa sbagliata, non a costruire più in fretta.

**Decisione presa: beta in due ondate.** Le alternative erano spostare la data di un mese, oppure tenerla tagliando qualcosa — e l'unico candidato al taglio sarebbe stato il matching, che era stato rimesso dentro apposta.

**Come funziona.**

- **Fase interna**, prima di tutto: solo il team. Serve a vedere se l'app regge un viaggio vero, non a validare niente — i suoi numeri restano fuori da ogni soglia.
- **Ondata 1**, alla data prevista: tutto tranne la parte pubblica. Viaggi, stato idea e stato definito, itinerario, spese, liste, documenti, funzionamento senza rete, passaporto e mappamondo. Nessun profilo pubblico e nessun matching, quindi **nessuna voce di sicurezza è bloccante**.
- **Ondata 2**, quattro-sei settimane dopo: profilo pubblico, matching, modalità città, con tutto l'impianto di sicurezza.

**Perché è meglio delle altre due.**

- La beta **non slitta**. Si comincia a raccogliere dati su H1, H2, H3, H4 e H5 un mese prima.
- La funzione più rischiosa del prodotto non esce il primo giorno davanti a sconosciuti, ma davanti a persone che hai già visto usare l'app per un mese. Se qualcosa va storto, va storto in piccolo.
- L'impianto di sicurezza si costruisce **mentre** l'ondata 1 è già in mano alla gente: non è tempo morto, è tempo in cui stai già imparando qualcosa.
- H6 e H7 si misurano lo stesso, su una finestra più corta. H7 aveva già sei mesi davanti, che restano abbondanti.

**L'unico costo**: gli utenti dell'ondata 1 vanno riavvisati quando esce la parte pubblica, e il loro profilo nasce vuoto. Si risolve con un messaggio.

---

## Da misurare

| Punto | Cosa lo chiude | Quando |
|---|---|---|
| Quali funzioni sono davvero premium, e quali stanno dal lato "viaggio" e quali dal lato "persona" | I numeri di **H1** in beta: quali funzioni vengono usate davvero. Sono le candidate naturali al premium, ma sono anche quelle che rendono l'app utile a tutti. La tabella attuale è una prima passata di esempi | Beta, ondata 1 |
| Se €24,99/anno è il prezzo giusto | Misurazione in beta. Il criterio è già scritto: deve convenire a chi fa tre viaggi l'anno | Beta |
| Se Marco diventa il Giulia del prossimo viaggio | Quanti utenti arrivati da invito creano poi un viaggio proprio. Se è basso, gli inviti portano utenti ma non organizzatori, e la crescita si ferma alla prima generazione | Beta |
| Se 10 collegamenti reciproci su 100 utenti è la soglia giusta | I numeri veri dei primi mesi di parte pubblica | Ondata 2 |
| Se i coefficienti di peso dei viaggi distinguono qualcosa | Il mix reale dei primi cinquanta viaggi. Se è quasi tutto breve, il peso non sta distinguendo niente e tanto vale contare i viaggi | Dopo 50 viaggi |
| Se il bundle di gruppo serve, e a che prezzo | Un segnale da **H6**. Il numero che reggerebbe è €19,99 per l'intero viaggio | Dopo la beta |
| Quali modelli suggerire, nome per nome | Vive nella tabella `configurazione` di Supabase, chiave `modelli_suggeriti` (ADR-010), non nel codice: si aggiorna dal pannello quando cambiano i modelli | Continuo |
| Il nome definitivo del prodotto | "Trolley" è un nome in codice. Nessun investimento sull'identità visiva prima | Prima del lancio pubblico |

### Dalla tela di Claude Design

La grafica viene dalla tela "Trolley — design dell'app", stile «Biglietti» ([ADR-007](tecnico/adr/007-interfaccia-e-liquid-glass.md), revisione del 2026-10-02). Quello che l'app non fa ancora come la tela, e perché:

| Voce | Perché aspetta | Quando |
|---|---|---|
| **Foto della destinazione sul biglietto** | La tela attacca una piccola foto, storta, sulla carta d'imbarco del viaggio in corso. Serve un fornitore di immagini (licenza, attribuzione, costo), dietro un'interfaccia come gli altri servizi esterni ([04](tecnico/04-integrazioni.md)). Intanto il biglietto vive senza: il codice di tre lettere basta a riconoscerlo | Da scegliere il fornitore |
| **Tema scuro** | La tela è solo chiara, e l'app pure: col telefono in scuro resta chiara | Quando la tela disegna lo scuro |
| **Le schermate delle fasi 2.2–6 sono disegnate, non ancora riviste** | Disegnate il 4 ottobre 2026 sulla tela (34–87, una fila per fase, più le notifiche) perché le correzioni arrivino prima di costruire. Ogni fila ha una nota arancione con le scelte e le domande aperte (per esempio: i rimborsi nei saldi, i colori dei giorni sulla mappa, quali traguardi, «cosa ti piace» nel profilo pubblico). Quando si costruisce una fase si rilegge la sua fila: l'utente può averla corretta | Prima di costruire ciascuna fase |
| **Mappa e Community nella barra in basso** | La tela le ha; nell'app la barra mostra solo le sezioni che esistono (Viaggi, +, Profilo) | Con le fasi 3.2 e 5 |
