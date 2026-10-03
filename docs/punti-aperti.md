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
| **Schermata dei conflitti** | Una modifica su versione superata oggi si rifiuta, la copia si riscarica e la persona riprova. Mostrare le due versioni affiancate è la 2.2 | Fase 2.2 |
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
| **Rimuovere un viaggio dal telefono** | `eliminaViaggio` cancella cartella e righe, ma nessun gesto oggi toglie un viaggio: si chiamerà uscendo da un viaggio (2.1). Un viaggio che sparisse dal server lascerebbe i documenti sul disco, non visibili: si è scelto di non cancellarli da soli, perché sono l'unica copia | Fase 2.1 |
| **Il documento di adesso** | La schermata "adesso" mostrerà il documento agganciato a questo momento ([09](prodotto/09-durante-il-viaggio.md)) | Fase 3.1 |
| **Luminosità al massimo** mostrando un codice a barre | Comodo al gate; non chiesto dai documenti | Se la beta lo chiede |
| **Rivedere sulla tela le schermate 10–14** | Disegnate e costruite insieme il 3 ottobre 2026; l'utente non le ha ancora viste | Prima di chiudere la 1.3 |

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
| Quali modelli suggerire, nome per nome | Vive in una configurazione remota, non nel codice: si aggiorna quando cambiano i modelli | Continuo |
| Il nome definitivo del prodotto | "Trolley" è un nome in codice. Nessun investimento sull'identità visiva prima | Prima del lancio pubblico |

### Dalla tela di Claude Design

La grafica viene dalla tela "Trolley — design dell'app", stile «Biglietti» ([ADR-007](tecnico/adr/007-interfaccia-e-liquid-glass.md), revisione del 2026-10-02). Quello che l'app non fa ancora come la tela, e perché:

| Voce | Perché aspetta | Quando |
|---|---|---|
| **Foto della destinazione sul biglietto** | La tela attacca una piccola foto, storta, sulla carta d'imbarco del viaggio in corso. Serve un fornitore di immagini (licenza, attribuzione, costo), dietro un'interfaccia come gli altri servizi esterni ([04](tecnico/04-integrazioni.md)). Intanto il biglietto vive senza: il codice di tre lettere basta a riconoscerlo | Da scegliere il fornitore |
| **Tema scuro** | La tela è solo chiara, e l'app pure: col telefono in scuro resta chiara | Quando la tela disegna lo scuro |
| **Mappa e Community nella barra in basso** | La tela le ha; nell'app la barra mostra solo le sezioni che esistono (Viaggi, +, Profilo) | Con le fasi 3.2 e 5 |
