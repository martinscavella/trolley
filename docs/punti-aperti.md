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
| **Revisione legale** ([06](tecnico/06-privacy-e-conformita.md)) | Le scelte su dati, età, conservazione e chiusura dell'account sono ragionate, non certificate: vanno confermate prima di aprire fuori dal team. Le domande sono in [per la revisione](legale/per-la-revisione.md), con l'informativa in bozza (U.3) | Prima dell'ondata 1 |

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
| ~~**Copia delle tappe solo di oggi e domani**~~ (01, "Dove vive ogni entità") | Deciso nella 3.3: i viaggi non finiti stanno interi, perché pesano pochi byte e le schermate leggono dalla copia; è selettivo che cosa si riscarica e quando ([02](tecnico/02-sincronizzazione-e-offline.md), [decisioni](decisioni/prodotto.md)) | ✅ Fase 3.3 |
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
| ~~**Il documento di adesso**~~ | Fatto nella 3.1: «Adesso» mostra il primo documento di oggi con l'ora non passata da più di un'ora, o quello di oggi senza ora; con la giornata libera, quello di domani | ✅ Fase 3.1 |
| **Luminosità al massimo** mostrando un codice a barre | Comodo al gate; non chiesto dai documenti | Se la beta lo chiede |
| **Rivedere sulla tela le schermate 10–14** | Disegnate e costruite insieme il 3 ottobre 2026; l'utente non le ha ancora viste | Prima di chiudere la 1.3 |

### Rimasto fuori dalla 1.4

La fase 1.4 (spese: valuta predefinita, tasso di cambio, ultimo valore noto offline; registrare anche senza rete) è costruita. Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
| **Budget di massima allo stato idea** (06, regola 1) | Non è nel piano di costruzione: è un'altra cosa rispetto alle spese | Da decidere |
| **Statistiche aggregate delle spese** (06, regola 11) | Funzione premium individuale | Fase 6 |
| **Rivedere sulla tela le schermate 15–18** | Disegnate e costruite insieme il 3 ottobre 2026; l'utente non le ha ancora viste | Prima di chiudere la 1.4 |
| **La migrazione `spese_e_tassi` non è nell'elenco delle versioni del server** | È stata applicata dall'editor SQL di Supabase, che non la registra: lo schema c'è, la riga in `supabase_migrations.schema_migrations` no. Il file porta la versione `20261003090000` | Da registrare, o da lasciare scritto qui |

### Rimasto fuori dalla 1.5

La fase 1.5 (cose da portare: la propria lista, anche nelle idee, spuntabile senza rete) è costruita. Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
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
| **`primo_contributo_invitato` guarda il ruolo di adesso** | Dopo un passaggio di ruolo chi ha creato il viaggio risulta partecipante: se non aveva mai aggiunto niente, il suo primo contributo conterebbe come quello di un invitato. Il caso è raro (chi crea un viaggio di solito ci mette qualcosa), e distinguerlo vorrebbe un campo in più sulla partecipazione | Se i numeri di H3 lo mostrano |
| **Rivedere sulla tela le schermate 29–33** | Disegnate e costruite insieme il 4 ottobre 2026; l'utente non le ha ancora viste | Prima di chiudere la 2.1 |

### Rimasto fuori dalla 2.2

La fase 2.2 (due versioni della stessa cosa: tappa, spesa, voce, date del viaggio; chi e quando; tienila, tieni l'altra, tutte e due per le voci; una cosa tolta) è costruita. Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
| **La migrazione `chi_ha_scritto` non è nell'elenco delle versioni del server** | Applicata il 4 ottobre 2026 dall'editor SQL di Supabase, che non la registra: colonne e trigger ci sono, le righe di prima hanno preso l'autore, e le 7 prove di `supabase/tests/conflitti.sql` passano; la riga in `supabase_migrations.schema_migrations` no. Il file porta la versione `20261004150000` | Da registrare, o da lasciare scritto qui |
| **La notifica «Due versioni»** per chi esce prima di scegliere | Oggi chiudendo si torna al foglio, con quello che si era scritto; chiudendo anche il foglio la propria versione si perde, come per ogni foglio lasciato a metà. La notifica è dell'insieme delle notifiche ([14](prodotto/14-notifiche.md)) | Con le notifiche |
| **«Tienile tutte e due» per le note** | Le note oggi non si riscrivono: non possono trovarsi in due versioni | Con le note scritte a mano |
| **Rivedere sulla tela le schermate 34–36 e 88** | 34–36 disegnate prima, 88 (una tolta) disegnata e costruita il 4 ottobre 2026 | Prima di chiudere la 2.2 |

### Rimasto fuori dalla 2.3

La fase 2.3 (chi ha pagato e per chi, importi diversi, la propria parte, i saldi con il giro più corto, «Li ho ricevuti», la stessa spesa registrata due volte, il saldo nel dialogo di chi si toglie) è costruita. Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
| **La migrazione `divisione_spese` non è nell'elenco delle versioni del server** | Applicata il 4 ottobre 2026 dall'editor SQL di Supabase, che non la registra: `rimborso`, le regole sulle quote, `registra_spesa` e `cambia_spesa` ci sono, e le 10 prove di `supabase/tests/divisione.sql` passano; la riga in `supabase_migrations.schema_migrations` no. Il file porta la versione `20261004170000` | Da registrare, o da lasciare scritto qui |
| **Un rimborso in una valuta diversa da quella di chi lo vede** | «Li ho ricevuti» registra il rimborso nella valuta di chi lo riceve. Chi vede le spese in un'altra valuta lo converte con il suo tasso: il saldo si chiude esatto per chi riceve, al centesimo di cambio per gli altri | Se la beta lo mostra |
| **«Sono due spese» vale solo su quel telefono** | È una risposta all'avviso, non un dato del viaggio. Sull'altro telefono della stessa persona l'avviso torna una volta | Se dà fastidio |
| **Il foglio della spesa dice «Salva», la tela «Registra»** | Il pulsante c'era già dalla 1.4; nel foglio degli importi diversi è «Registra» come sulla tela | Da decidere con la tela |
| **Rivedere sulla tela le schermate 37–41 e 89** | 37–41 disegnate prima, 89 (saldi visti da chi dà, rimborsi già fatti) disegnata e costruita il 4 ottobre 2026 | Prima di chiudere la 2.3 |

### Rimasto fuori dalla 2.4

La fase 2.4 (la lista del viaggio e la propria, chi porta cosa, spostare una voce fra le due, le voci che tornano libere quando chi le portava lascia il viaggio) è costruita. Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
| ~~**La migrazione `lista_del_viaggio` va applicata**~~ | Applicata dall'editor SQL e provata il 4 ottobre 2026 (`supabase/tests/lista_del_viaggio.sql`, tutte «ok»). La versione `20261004200000` non è registrata in `schema_migrations`, come le altre applicate a mano | ✅ |
| **Il foglio della voce ha quante ed «Elimina la voce»**, che il disegno 43 non mostra | Il foglio è quello della 1.5 (tela, 21) con «Chi la porta?» e lo spostamento: la tela li dice nella nota, non nel disegno | Da decidere con la tela |
| **«Ho capito» sulle voci tornate libere vale su quel telefono** | È la risposta a un avviso, come «Sono due spese». L'avviso sparisce comunque appena qualcuno prende quelle voci | Se dà fastidio |
| **Chi porta una voce assegnata da un altro non lo sa** | Se Marco scrive che la crema la porta Sara, Sara lo vede solo aprendo la lista. Dirglielo è delle notifiche ([14](prodotto/14-notifiche.md)) | Con le notifiche |
| **Una voce presa su un altro telefono non chiude il benvenuto qui** | La copia sa chi porta una voce, non chi l'ha scelto: Sara a cui Marco ha dato la crema non ha ancora contribuito. Il benvenuto si chiude al prossimo contributo, o con la × | Se dà fastidio |
| **Rivedere sulla tela le schermate 42–44** | Disegnate prima, costruite il 4 ottobre 2026 | Prima di chiudere la 2.4 |

### Rimasto fuori dalla 3.1

La fase 3.1 (la schermata «Adesso»: la tappa di adesso con «Fatta» e «Salta», cosa viene dopo, il documento di questo momento, la spesa con un tocco, oggi e domani, la giornata libera, senza rete, due viaggi in corso) è costruita. Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
| **Il promemoria di fine giornata** (09, regola 11) | Se restano tappe non marcate l'app lo ricorda una volta sola: è una notifica locale, dell'insieme delle notifiche ([14](prodotto/14-notifiche.md)) | Con le notifiche |
| **Due cose che la tela non disegna** | Il pulsante in alto che apre tutto il viaggio (la tela 45 non ha un'uscita verso il viaggio) e «Per oggi è tutto», quando le tappe di oggi sono tutte segnate (fatto nella forma della giornata libera, 47) | Da disegnare sulla tela |
| **«Adesso» si apre da solo solo all'avvio** | Chi lascia l'app aperta da ieri e la riprende la ritrova dov'era; il viaggio che comincia oggi si apre al prossimo avvio | Se la beta lo chiede |
| **Rivedere sulla tela le schermate 45–49** | Disegnate prima, costruite il 4 ottobre 2026 | Prima di chiudere la 3.1 |

### Rimasto fuori dalla 3.2

La fase 3.2 (la mappa del giorno e del viaggio, la navigazione a piedi con l'arrivo da segnare, gli indirizzi senza rete, «Dove?» cercato) è costruita, con Geoapify ([ADR-006](tecnico/adr/006-mappe-e-percorsi.md)). Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
| ~~**Il tetto per persona e per viaggio** (ADR-006, regola 1)~~ | Costruito con U.2: sul server, per persona, viaggio e giorno | ✅ |
| ~~**La chiave di Geoapify sta nell'app**~~ | Con U.2 sta solo sul server: le restrizioni di Geoapify (IP, referrer, origin) su un telefono non proteggono niente | ✅ |
| **I posti di un'idea sulla mappa** (08, casi limite) | «La mappa mostra i posti dell'elenco idee»: l'elenco dei posti di un'idea (02, regola 2) non esiste ancora. Oggi «Mappa» non apre le idee | Con i posti delle idee |
| **Le tappe incollate prima del 5 ottobre non hanno un posto** | Dal 5 ottobre la richiesta all'assistente chiede anche le coordinate; le tappe incollate prima (i viaggi di prova a Copenaghen e Londra) si cercano a mano in «Dove?», che parte già cercando, oppure si svuota il giorno e si incolla di nuovo. Cercarle tutte insieme costerebbe una ricerca per tappa | Se la beta lo chiede |
| **Quanto sono giuste le coordinate dell'assistente** | Per i posti famosi di solito sì; per un ristorante piccolo possono essere a qualche centinaio di metri, o inventate. Si scartano solo quelle a più di 150 km dal viaggio. Da guardare sulle prime risposte vere: se sbagliano spesso, si passano dalla ricerca di Geoapify prima di salvarle | Alle prime risposte incollate |
| **Lo schermo acceso durante la navigazione** | iOS lo spegne dopo il tempo impostato; tenerlo acceso chiede un pacchetto in più | Se la beta lo chiede |
| **I mezzi e l'auto** | La navigazione è a piedi; per il resto c'è «Apri in Mappe» | Se la beta lo chiede |
| **Rivedere sulla tela le schermate 57–61** | Disegnate il 5 ottobre 2026 dopo la prova sul telefono (la scelta del viaggio nella mappa, con il pulsante «Indietro»; svuotare un giorno e il viaggio; le tappe doppie nell'anteprima) e costruite lo stesso giorno | Prima di chiudere la 3.2 |
| **Rivedere sulla tela le schermate 50–56** | Disegnate prima (la 56 il 4 ottobre 2026, insieme alla costruzione), costruite il 4 ottobre 2026 | Prima di chiudere la 3.2 |
| **Provare la mappa sull'iPhone con la chiave vera** | Le risposte di Geoapify sono verificate dal vivo il 5 ottobre 2026 (ricerca, percorso, riquadri; due registrate in `app/test/dati/risposte/`); installata sull'iPhone il 5 ottobre 2026 (mappa e riquadri veri, centrata sulla meta); manca la prova camminando, con «Portami» fino a una tappa. L'8 ottobre 2026 «Portami» restava a cercare dove si era, finché un'altra app non accendeva il GPS: iOS metteva in pausa la posizione a telefono fermo prima della prima lettura (`pauseLocationUpdatesAutomatically`). Ora non va mai in pausa, e si parte dalla posizione che il telefono sa già se è di meno di un minuto. Lo stesso giorno: con una tappa sola la mappa nasceva a zoom 13 e saltava sulla tappa appena pronta, e restava grigia finché non la si muoveva; ora nasce già inquadrata. Tutte e due provate sull'iPhone l'8 ottobre 2026 | Al primo giro a piedi |

### Rimasto fuori dalla 3.3

La fase 3.3 (la copia che riscarica solo quello che serve, «Prima di partire» con il giro di controllo, «Preparalo per l'uso senza rete», le tappe senza posto da sistemare) è costruita, senza migrazioni. Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
| **La notifica poco prima della partenza** con quello che manca (14-notifiche) | Il giro di controllo si vede aprendo il viaggio; ricordarlo a chi non lo apre è una notifica | Con le notifiche |
| **«Prima di partire» solo da due giorni prima** | Chi parte per un posto senza rete fra una settimana prepara il viaggio comunque: la copia è già intera, e aprendolo si aggiorna. Il giro di controllo prima non si vede | Se la beta lo chiede |
| **Le mappe scaricabili** | La preparazione scarica i dati, non i riquadri: senza rete la mappa non c'è, restano gli indirizzi da aprire nelle Mappe del telefono (08, regola 6; ADR-006) | Se H4 lo chiede |
| **I viaggi finiti fra un'apertura e l'altra** | Non si riscaricano all'apertura dell'app: un rimborso registrato da un altro dopo il ritorno si vede aprendo il viaggio, o le spese da lì | Se dà fastidio |
| **Rivedere sulla tela le schermate 56, 57 e 90–92** | Disegnate (56 e 57 il 4 ottobre, 90–92 il 5 ottobre 2026) e costruite il 5 ottobre 2026 | Prima di chiudere la 3.3 |
| **Provare la preparazione sull'iPhone** | Le prove girano sul server finto; manca il giro vero, due giorni prima di un viaggio, con la rete e poi in modalità aereo | Al primo viaggio vero |

### Rimasto fuori dalla 3.4

La fase 3.4 (le regole della verifica, «sul posto» confrontato sul telefono e mandato come sì, il permesso di posizione con le schermate 58 e 59) è costruita. Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
| ~~**Applicare la migrazione `sul_posto`**~~ | Applicata dall'editor SQL e provata il 6 ottobre 2026 (`supabase/tests/sul_posto.sql`, tutte «ok»). La versione `20261006090000` non è registrata in `schema_migrations`, come le altre applicate a mano | ✅ |
| **Scrivere `viaggio.verificato`, e i traguardi** | La verifica si calcola alla chiusura: è la 4.1, con il riepilogo e l'evento `viaggio_chiuso` | Fase 4.1 |
| **La deroga nella copia locale** | `verifica_per_deroga` sta sul server; l'app la leggerà quando chiude il viaggio | Fase 4.1 |
| **Vicino a un confine il paese può sbagliare** | Il paese di un punto è quello della città più vicina dell'elenco: a Ginevra si può risultare in Francia. Per le mete-città conta la distanza, non il paese | Se la beta lo mostra |
| **50 km dal centro** | Abbastanza per la periferia e l'aeroporto; poco per un parco nazionale scritto come città | Se la beta lo mostra |
| **Rivedere sulla tela le schermate 58 e 59** | Disegnate il 4 ottobre 2026, costruite il 6 ottobre: la domanda «quando chiederla» è decisa (decisioni) | Prima di chiudere la 3.4 |
| **Provare sul telefono, in viaggio** | Le prove girano sul server e sulla posizione finti | Al primo viaggio vero |

### Rimasto fuori dalla 4.1

La fase 4.1 (la chiusura da sola e a mano, la verifica scritta per ciascuno, il riepilogo, i traguardi) è costruita. Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
| ~~**Applicare la migrazione `chiusura`**~~ | Applicata dall'editor SQL e provata il 6 ottobre 2026 (`supabase/tests/chiusura.sql`, tutte «ok»). La versione `20261006120000` non è registrata in `schema_migrations`, come le altre applicate a mano | ✅ |
| ~~**«Guarda il passaporto»** nel riepilogo (tela, 60 e 61)~~ | Costruito con la 4.2 | ✅ |
| **Il promemoria a un anno** («un anno fa eri a Lisbona», 10, regola 9) | È una notifica | Con le notifiche |
| **Quali traguardi** | La prima serie è quella della tela (decisioni). Si rivede con i numeri: se quasi nessuno li prende, la leva è aiutare a segnare le tappe | Dopo la fase interna |
| **Un viaggio chiuso per sbaglio** | Non si riapre: chi è responsabile lo chiude solo dopo una conferma che dice cosa succede | Se capita |
| **Rivedere sulla tela le schermate 60–63, 93 e 94** | 60–63 disegnate il 4 ottobre, 93 e 94 il 6 ottobre 2026, costruite il 6 ottobre | Prima di chiudere la 4.1 |

### Rimasto fuori dalla 4.2

La fase 4.2 (il profilo con i suoi numeri, il passaporto, il mappamondo con i confini veri) è costruita, senza migrazioni. Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
| ~~**Il gesto del grattare** (tela, 66, nota)~~ | Deciso dall'utente e costruito il 6 ottobre 2026: un paese nuovo si gratta col dito (tela, 95–97; decisioni) | ✅ |
| **Grattare su due telefoni** | Che cosa si è grattato si ricorda sul telefono: chi ha due telefoni gratta lo stesso paese su entrambi, nel mese in cui resta da grattare | Se capita |
| **Avvicinare il globo**, e le città come punti | Il globo è grande quanto lo schermo e i confini sono semplificati per quella grandezza (ADR-005): avvicinandolo servirebbero confini più fini | Se la beta lo chiede |
| ~~**«Aggiungi un viaggio passato»** nel passaporto (tela, 65 e 67)~~ | Costruito con la 4.3 | ✅ |
| **La parte pubblica e le notifiche nel profilo** (tela, 64) | Arrivano con le loro fasi | Fase 5.3, notifiche |
| **Una città con due nomi** | Il mappamondo conta le città per nome: «Cracovia» e «Kraków» scritte a mano sarebbero due. Dall'elenco si sceglie sempre lo stesso nome | Se capita |
| **Rivedere sulla tela le schermate 64–66 e 95–97** | 64–66 disegnate il 4 ottobre, 95–97 il 6 ottobre, costruite il 6 ottobre 2026 | Prima di chiudere la 4.2 |

### Rimasto fuori dalla 4.3

La fase 4.3 (i viaggi passati: aggiungerli, cambiarli, toglierli; il biglietto tratteggiato con il timbro «importato») è costruita. Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
| ~~**Applicare la migrazione `viaggi_passati`**~~ | Applicata dall'editor SQL e provata l'8 ottobre 2026 (`supabase/tests/viaggi_passati.sql`, tutte «ok»). La versione `20261006150000` non è registrata in `schema_migrations`, come le altre applicate a mano | ✅ |
| **Un viaggio passato fatto insieme** | È di chi lo aggiunge: ognuno aggiunge il suo, e non ci si invita nessuno | Se la beta lo chiede |
| **I numeri del profilo pubblico** | Nel profilo personale «Viaggi» conta anche i viaggi passati (tela, 64). Quando il profilo diventa pubblico (5.3), un numero che si mostra agli altri deve dire quanti sono verificati e quanti dichiarati: un traguardo verificato e uno dichiarato non devono somigliarsi | Fase 5.3 |
| **Rimettere dentro un archivio scaricato** | È la reimportazione, premium (modello di business): un'altra cosa rispetto ad aggiungere un viaggio a mano | Fase 6 |
| **Rivedere sulla tela le schermate 67 e 98** | 67 disegnata il 4 ottobre, 98 il 6 ottobre, costruite il 6 ottobre 2026 | Prima di chiudere la 4.3 |

### Rimasto fuori da U.1

U.1 (i tuoi dati e chiudere l'account: scaricarli in un file JSON, chiudere l'account dall'app con la lapide, il ruolo che passa e gli eventi che cambiano id) è costruita. Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
| ~~**Applicare la migrazione `chiusura_account`**~~ | Applicata dall'editor SQL e provata l'8 ottobre 2026 (`supabase/tests/chiusura_account.sql`, tutte «ok»). La versione `20261006180000` non è registrata in `schema_migrations`, come le altre applicate a mano | ✅ |
| **Revocare il token di Apple chiudendo l'account** | Lo store lo chiede a chi offre l'accesso con Apple: chiudendo, il server revoca il token con l'API di Apple, che vuole una chiave privata e quindi una funzione sul server, non l'app. Oggi l'accesso con Apple non c'è ancora | Con l'accesso con Apple (prerequisiti) |
| **Un secondo telefono con lo stesso account** | La chiusura svuota il telefono da cui si chiude. Un altro telefono perde l'accesso al primo rinnovo della sessione, ma la sua copia e i suoi documenti restano finché non si esce | Se capita |
| **Rimettere dentro i dati scaricati** | È la reimportazione, premium (modello di business) | Fase 6 |
| **La lapide nella parte pubblica** | Un profilo chiuso non deve comparire in ricerca, collegamenti e messaggi: oggi la parte pubblica non c'è | Fase 5.3 |
| **Rivedere sulla tela le schermate 99–102** | Disegnate il 6 ottobre, costruite e allineate al codice il 7 ottobre 2026 (versione 39) | Prima di chiudere U.1 |

### Rimasto fuori da U.2

U.2 (la chiave di Geoapify sul server, nella funzione `mappe`, e il tetto per persona, viaggio e giorno, con la navigazione che degrada alle Mappe del telefono) è costruita. Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
| **Applicare la migrazione `tetto_mappe`** | `supabase/migrations/20261008090000_tetto_mappe.sql`: il conto, `consuma_mappe`, i numeri in `configurazione`, la pulizia settimanale. Si applica dall'editor SQL e si prova con `supabase/tests/tetto_mappe.sql`; la versione non finirà in `schema_migrations` | Prima di pubblicare la funzione |
| **Una chiave nuova di Geoapify, sul server** | La chiave di prima è stata in ogni app compilata: se ne crea una nuova per il server (segreto `GEOAPIFY_CHIAVE` delle funzioni di Supabase) e la vecchia si cancella da Geoapify, con `app/chiavi.json` | Prima di pubblicare la funzione |
| **Pubblicare la funzione `mappe`** | `supabase functions deploy mappe --project-ref nhdgxlynnudwkmxrrokp --no-verify-jwt`: l'accesso lo controlla `consuma_mappe`, non il gateway. Senza la funzione l'app nuova non ha mappa | Prima di installare l'app nuova |
| **I numeri del tetto** | 2000 riquadri, 150 ricerche, 60 percorsi per persona, viaggio e giorno sono stimati: si correggono in `configurazione` guardando `consumo_mappe` (e i suoi `fermati`) della fase interna | Dopo la fase interna |
| **Il limite di tutta l'app** | Il piano gratuito di Geoapify dà 3000 crediti al giorno per tutti; una persona al tetto ne usa 710. Quando i viaggiatori di uno stesso giorno lo avvicinano serve un piano a pagamento | Quando la beta lo avvicina |
| **Account moltiplicati** | Il tetto è per persona: chi crea molti account e molti viaggi ne ha molti. Non costa soldi (il piano è senza carta), ma consuma i crediti di tutti. Se capita, un tetto per tutta l'app nella stessa funzione | Se capita |
| **Quanto è più lenta la mappa** | Ogni riquadro nuovo passa dal server: circa 370 ms l'uno contro pochi centesimi prima (registri dell'8 ottobre 2026). Da guardare camminando | Al primo giro a piedi |
| **La prova del tetto sul server** | `supabase/tests/tetto_mappe.sql` non è ancora stata lanciata: tocca `configurazione` dentro un blocco che si annulla. Si lancia dall'editor SQL | Prima di chiudere U.2 |

### Rimasto fuori da U.3

U.3 (l'informativa e «Cosa misuriamo» come pagine del sito, aperte dall'accesso e dal profilo) è costruita. Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
| **Titolare e contatto per la privacy** | Nell'informativa ci sono segnaposti: chi è il titolare, con quale indirizzo, e a quale email si scrive. Lo decide il progetto, non il codice | Prima di pubblicare le pagine |
| **Pubblicare le due pagine** | `vercel deploy --prod` dalla cartella `sito/`. Finché non ci sono, i rimandi dell'app aprono una pagina che non c'è | Con titolare e contatto |
| **La revisione legale** | Le diciassette domande di [per la revisione](legale/per-la-revisione.md): basi giuridiche, misurazione accesa di default, verifica, età, chiusura, fornitori, trasferimenti, conservazione | Prima dell'ondata 1 |
| **Gli accordi con i fornitori** (art. 28) | Supabase, Vercel e Geoapify trattano dati per noi: gli accordi vanno accettati o firmati, e Geoapify va identificato con certezza (Germania o Cipro) | Con la revisione legale |
| **Il periodo degli eventi nel dettaglio** | 06 dice «aggregati oltre un orizzonte breve» senza numero; le pagine hanno un segnaposto. Serve il numero, e un lavoro che aggreghi e cancelli | Con la revisione legale |
| **Le dichiarazioni di privacy dell'App Store** | Apple chiede che cosa l'app raccoglie e se è legato alla persona; la nostra lettura è nella domanda 17 | Prima di TestFlight esterno |
| **Il nome e la data di nascita si cambiano solo scrivendoci** | L'informativa lo dice così. Cambiare il nome dall'app è una funzione piccola, se la si vuole | Se la beta lo chiede |

### Rimasto fuori dalla 5.1

La 5.1 (l'interruttore della parte pubblica, il profilo pubblico con il numero verificato e le condizioni d'uso, segnalare, bloccare, la sospensione, la moderazione dall'editor SQL) è costruita. Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
| ~~**Applicare la migrazione `sicurezza`**~~ | Applicata dall'editor SQL il 9 ottobre 2026 e verificata in sola lettura; la versione non è in `schema_migrations`. Prima provata su un Postgres locale (PGlite) con tutte le migrazioni e le prove: 16 su 16 | ✅ |
| **La prova `sicurezza.sql` sul server** | `supabase/tests/sicurezza.sql` cambia `parte_pubblica` dentro un blocco che si annulla: si lancia dall'editor SQL | Prima di aprire la parte pubblica |
| ~~**Pubblicare la funzione `telefono`**~~ | Pubblicata il 9 ottobre 2026 con il numero di prova `+393400000001` (codice `123456`) nel segreto `TELEFONO_PROVA`. Provata sull'iPhone: numero verificato, profilo pubblico acceso, `telefono_verificato` e `profilo_pubblico_attivato` arrivati | ✅ |
| ~~**Il proprio account come account del team**~~ | `interno = true` dal 9 ottobre 2026: vede la parte pubblica mentre è chiusa, ed è fuori da ogni metrica | ✅ |
| **Un conto Twilio con un servizio Verify** | I segreti `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_VERIFY_SID`; sul pannello di Twilio i paesi permessi e le difese contro gli SMS gonfiati ([ADR-011](tecnico/adr/011-verifica-del-telefono.md)) | Prima di aprire la parte pubblica |
| **Togliere `TELEFONO_PROVA`** | Chi conosce un numero di prova si verifica senza telefono | Prima di aprire la parte pubblica |
| **Il contatto della moderazione** | `contatto_moderazione` in `configurazione`, e il segnaposto nelle condizioni d'uso. Lo store lo chiede (12, regola 6) | Prima di aprire la parte pubblica |
| **Pubblicare le condizioni d'uso** | `sito/condizioni.html`, con l'informativa e «Cosa misuriamo» aggiornate (Twilio, il numero, blocchi, segnalazioni). Bozze per l'avvocato: domande 18–26 di [per la revisione](legale/per-la-revisione.md) | Con le altre pagine del sito |
| **«…» su un profilo e su un messaggio** | Segnalare e bloccare sono pronti (`segnala`, `blocca` nelle schermate), ma non c'è ancora niente da cui aprirli | 5.3 e 5.4 |
| **Segnalare un messaggio, e toglierlo** | `segnala` accetta solo i profili; la terza azione della moderazione, `togli_contenuto`, nasce con i messaggi | 5.4 |
| **Le regole della parte pubblica che usano il blocco** | `privato.si_bloccano` c'è e ha la sua prova; le regole di lettura di profili, ricerca e messaggi lo useranno | 5.3 e 5.4 |
| **Conservazione delle segnalazioni** | Il periodo è da fissare con l'avvocato, e manca il lavoro che le toglie | Con la revisione legale |
| **Chi è sospeso e chiude l'account** | Chiudendo, il numero torna libero: con un account nuovo e lo stesso numero si rientra. Tenere un'impronta dei numeri sospesi è un dato in più da giustificare | Se capita, con l'avvocato |
| **I tempi della moderazione** | 24 ore per minori e molestie, 72 per il resto ([moderazione](sicurezza/moderazione.md)): stimati. Li corregge `segnalazione_gestita` | Dopo le prime settimane di parte pubblica |
| **Le condizioni d'uso cambiate** | Il server ricorda quale versione si è accettata; chiedere di riaccettarle quando cambiano non è ancora costruito | Alla prima modifica |
| **Rivedere sulla tela le tavole 103–107** | Disegnate e costruite il 9 ottobre 2026 (versione 43) | Prima di chiudere la 5.1 |

### Rimasto fuori dalla 5.2

La 5.2 sono le due valutazioni d'impatto, scritte in bozza il 10 ottobre 2026 prima di costruire la parte pubblica: [la parte pubblica fra sconosciuti](legale/valutazione-impatto-parte-pubblica.md) e [chi c'è in città](legale/valutazione-impatto-presenza-in-citta.md). Le misure decise sono in [decisioni](decisioni/prodotto.md), «Dopo le valutazioni d'impatto». Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
| **La revisione dell'avvocato e la firma del titolare** | Le bozze concludono che il rischio residuo non è alto e che non serve consultare il Garante: lo deve confermare chi fa la revisione. Le domande sono dentro, P1–P9 e C-1–C-5, e la 26 di [per la revisione](legale/per-la-revisione.md) | Prima della seconda ondata |
| ~~**Ridisegnare sulla tela 73, 74 e 75**~~ | Fatto il 10 ottobre 2026 (versione 45), con le nuove 108–110 e la 105 ritoccata | ✅ |
| **Ridisegnare sulla tela 79 e 80** | Prima del «sul posto», «Quando sarai a Porto» (C1); via «Fino al 14 ott» dalle righe degli altri (C2) | Prima di costruire la 5.5 |
| **M8, M9, M10** | Il tetto alle richieste di collegamento e il divieto di richiedere dopo un no: proposte, per ora non adottate. Le righe di prudenza al primo collegamento: da disegnare, se si vogliono | M8 e M9 se le segnalazioni per molestie arrivano dalle richieste; M10 con la 5.4 |
| **C3, la soglia di abitanti** | Non adottata: la presenza vale anche nei comuni piccoli, e il rischio resta medio. È la domanda C-5 | Se l'avvocato la chiede, o alla prima segnalazione che riguarda un posto piccolo |
| **C4–C8** | Il modo di costruire la presenza: si spegne cambiando meta o date, letture da una funzione, niente copia sul telefono, una alla volta, nessun «da quando» | Con la 5.5 |
| **Il «sul posto» è una barriera, non una prova** | Lo decide l'app, e il server controlla solo chi e quando: chi chiama `segna_sul_posto` senza l'app passa. Far provare al server che la richiesta viene dall'app vera è App Attest, che chiede il programma sviluppatori | Se qualcuno lo aggira |
| **Il parere delle persone** (art. 35.9) | Cinque domande a chi usa l'ondata 1: che cosa si aspetta di vedere e di non vedere in un profilo pubblico | Prima di finire la 5.3 |
| **Nessuna copia di sicurezza del database** | Il progetto è sul piano gratuito di Supabase, che non ne fa: un errore o una migrazione sbagliata non si recupera, e con persone vere dentro è un rischio sulla disponibilità dei loro viaggi. Passando a un piano che le fa, la presenza in città resta nelle copie per sette giorni, e l'informativa lo deve dire | Prima dell'ondata 1 |

### Rimasto fuori dalla 5.3

Il profilo pubblico e la ricerca (Community nella barra, la ricerca per meta e gusti, il profilo di un altro con «…», «Così ti vedono», i viaggi sul profilo) sono costruiti il 10 ottobre 2026. Restano:

| Voce | Perché aspetta | Quando |
|---|---|---|
| ~~**Applicare la migrazione `profilo_pubblico`**~~ | Applicata dall'editor SQL il 10 ottobre 2026 e verificata in sola lettura; la versione non è in `schema_migrations`. Prima provata su un Postgres locale (PGlite): 17 prove su 17 | ✅ |
| ~~**La prova `profilo_pubblico.sql` sul server**~~ | Lanciata il 10 ottobre 2026: 10 su 10, e non ha lasciato niente. Sul server ci sono anche le persone vere: dei risultati di una ricerca la prova guarda solo le sue | ✅ |
| **«Chiedi di collegarvi»** | Il pulsante della 73 apre la 76: arriva con i collegamenti | 5.4 |
| **La segnalazione di un profilo fotografa solo il nome** | `segnala` conserva nome e stato del profilo (5.1); gusti e viaggi si possono ricostruire, ma non com'erano | Se chi modera ne ha bisogno |
| **Un indice delle mete pubbliche** | `cerca_viaggiatori` legge i viaggi di ogni profilo acceso a ogni ricerca | Con qualche migliaio di profili accesi |
| **Una meta scritta a mano** | Compare sul profilo com'è scritta (M5): la persona la vede nella 109 e la può nascondere. Il server non ha l'elenco delle destinazioni per riconoscerla | Se capita un nome di persona |
| **Rivedere sulla tela 73–75 e 108–110** | Ridisegnate e costruite il 10 ottobre 2026 (versione 45) | Prima di chiudere la 5.3 |

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
| **Le schermate delle fasi 2.2–6 sono disegnate, non ancora riviste** | Disegnate il 4 ottobre 2026 sulla tela (34–87, una fila per fase, più le notifiche) perché le correzioni arrivino prima di costruire. Ogni fila ha una nota arancione con le scelte e le domande aperte (per esempio: i rimborsi nei saldi, quali traguardi, «cosa ti piace» nel profilo pubblico). Quando si costruisce una fase si rilegge la sua fila: l'utente può averla corretta | Prima di costruire ciascuna fase |
| **Community nella barra in basso** | La tela la ha; nell'app la barra mostra solo le sezioni che esistono (Viaggi, Mappa, +, Profilo). «Mappa» c'è dalla 3.2 | Con la fase 5 |
