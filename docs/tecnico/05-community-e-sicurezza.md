# 05 — Community e sicurezza

La parte pubblica esce nella **seconda ondata**. È l'unica porzione del prodotto dove un errore non produce un dato sbagliato ma un danno a una persona, e dove quindi le regole stanno **sul server** e non nell'app: un controllo fatto solo nell'interfaccia è un controllo che non esiste.

---

## Le regole di accesso per riga

Poche, e vanno scritte una volta sola con dei test. È qui che si sbaglia.

| Regola | Formulazione |
|---|---|
| **Viaggi** | Si legge un viaggio solo se si è partecipanti con stato `attivo`. Nessuna eccezione, nemmeno per chi ha creato il viaggio dopo esserne uscito |
| **Profilo pubblico** | Si legge solo se `profilo_pubblico_attivo` è vero, **anche quello di chi guarda**, e i due non si bloccano. La ricerca passa da una funzione: per meta e gusti, mai per nome, al più trenta risultati, un tetto al giorno, i criteri nel corpo della richiesta (5.2, M1 e M2) |
| **Viaggi sul profilo** | Solo quelli con stato `chiuso` **e la fine passata**, che la persona non ha nascosto. I viaggi futuri e in corso **non compaiono in nessuna query pubblica**: non è un filtro nell'interfaccia, è una condizione della regola. Del viaggio escono la meta, il mese e l'anno, i giorni e se è verificato o importato: mai i compagni, le tappe, le spese, le note (5.2, M3–M5) |
| **Collegamenti e messaggi** | Si chiede di collegarsi solo a chi si vede; si scrive solo verso un collegamento con stato `accettato`, finché vi vedete. Una conversazione finita resta a chi non l'ha tolta, senza poter scrivere (5.4, P6) |
| **Blocco** | Bidirezionale: nessuno dei due compare all'altro in ricerca, profili o messaggi |
| **Presenza in città** | Si legge solo da chi ha a sua volta la presenza attiva per un viaggio in corso nella stessa città, e senza `attiva_fino`: la fine la legge solo la persona (5.2, C2). Le righe scadute non si leggono, anche se la cancellazione tarda |

L'invariante da cui non si deroga: **se una regola dell'interfaccia nasconde qualcosa, deve esistere una regola sul server che lo rende irraggiungibile.**

---

## Presenza in città

| | |
|---|---|
| Granularità | **Città.** Mai coordinate, mai distanza, mai un punto su una mappa |
| Attivazione | Esplicita, per singolo viaggio, spenta di default. **Solo con `partecipazione.sul_posto_il`** di quel viaggio: il telefono ha già trovato la persona entro 50 km dalla meta (5.2, C1) |
| Durata | Si **cancella** alla fine del viaggio. Non si archivia: la riga sparisce |
| Reciprocità | Si vede solo chi ha attivato a sua volta |
| Storico | Non esiste. Nessuna tabella conserva dove qualcuno è stato e quando |

La città si ricava dalla destinazione del viaggio, **non dalla posizione rilevata**. È una semplificazione che elimina il problema alla radice: non esiste un flusso in cui la posizione di una persona viene mandata al server per essere confrontata con quella di altri.

La meta però è dichiarata: un viaggio finto a Porto, con le date di oggi, bastava per guardare chi c'è senza esserci. Per questo la presenza chiede anche il «sul posto» della verifica, che il telefono calcola da sé e di cui il server ha già il sì: nessuna posizione nuova arriva al server, e per guardare bisogna esserci. È una barriera, non una prova: il sì lo decide l'app (`segna_sul_posto`), e chi falsifica la posizione o chiama il server senza l'app passa. Le ragioni sono nella [valutazione d'impatto](../legale/valutazione-impatto-presenza-in-citta.md).

---

## Verifica del viaggio e posizione

La verifica ha bisogno di sapere se la persona era sul posto. Il confronto **avviene sul telefono**, e verso il server parte solo l'esito: vero o falso.

Non esiste nessun percorso in cui una coordinata raggiunge il server. Se in futuro servisse, va trattato come una funzione nuova con una valutazione sua, non come un'estensione di questa.

---

## Segnalazione, blocco, moderazione

1. **Il blocco ha effetto immediato e locale**, prima ancora della sincronizzazione: chi blocca non deve aspettare la rete per smettere di vedere qualcuno.
2. **La segnalazione conserva il contenuto segnalato** al momento della segnalazione, altrimenti chi modera guarda un messaggio già cancellato.
3. **La coda di moderazione è uno strumento interno**, non una schermata dell'app. Deve funzionare per una persona sola: elenco, priorità, tre azioni possibili, e uno stato che chi ha segnalato può vedere.
4. **Una sospensione toglie la superficie pubblica**, non i dati: i viaggi della persona restano suoi.
5. **Gli strumenti di moderazione sono fuori dall'app** e richiedono un'autenticazione separata. È la stessa superficie della deroga amministrativa sulla verifica, e va protetta con la stessa serietà.

### Come è fatto (5.1)

- **La parte pubblica ha un interruttore sul server**, `parte_pubblica` in `configurazione`: chiusa, aperta, chiusa ai nuovi. Chiusa, nel profilo non c'è niente e non parte nessun SMS; chiusa ai nuovi, chi c'era resta e chi l'aveva spenta la riaccende. Gli account interni la vedono sempre: il team la prova mentre per gli altri è chiusa.
- **Il profilo pubblico si accende solo con `attiva_profilo_pubblico`**: dai 18 anni, con il telefono verificato, le condizioni d'uso accettate (la loro versione resta sul profilo), senza sospensione. Il client non può scrivere la colonna.
- **Il blocco** sta in `blocco`; `privato.si_bloccano(a, b)` lo dice nei due versi alle regole della 5.3 e della 5.4. Chi è bloccato non può saperlo: la tabella si legge solo dal lato di chi blocca.
- **La segnalazione** passa da `segnala`, che fotografa il contenuto sul server — chi segnala non può scriverlo da sé — e, con «Blocca anche», blocca nella stessa operazione. Al massimo venti al giorno per persona. Chi segnala vede lo stato con `le_mie_segnalazioni`.
- **Lo strumento di moderazione** è lo schema `moderazione`: la vista `coda` e le funzioni `archivia`, `sospendi`, `riattiva`, `parte_pubblica`. L'API e le funzioni del server non ci arrivano: si usa dall'editor SQL di Supabase, con l'accesso al progetto e la sua verifica in due passaggi. Scelto dall'utente il 9 ottobre 2026 al posto di una pagina web interna, che sarebbe stata una superficie in più da difendere. Il processo è in [moderazione](../sicurezza/moderazione.md).
- **La terza azione**, togliere un contenuto, è arrivata con i messaggi: `moderazione.togli` (5.4).

### Come è fatto (5.3)

- **Chi vede chi lo dice una funzione sola**, `privato.vede_il_profilo(chi, di)`: tutti e due con il profilo pubblico acceso e senza sospensione, tutti e due dove la parte pubblica c'è (chiusa, il team vede solo il team), nessun blocco nei due versi. La usano `profilo_pubblico` e `cerca_viaggiatori`; quando un profilo non si vede la risposta è sempre «non c'è», che sia spento, sospeso o bloccato.
- **I viaggi sul profilo li sceglie `privato.viaggi_del_profilo`**: partecipazione attiva, viaggio `chiuso` e con la fine passata (gli importati lo sono per costruzione), e non in `privato.fuori_dal_profilo`. Escono la meta, il primo giorno del mese, i giorni, se è verificato per quella persona o importato: le date non lasciano il server.
- **La ricerca è `cerca_viaggiatori(paese, città, gusti)`**: almeno uno dei due criteri, una città solo con il suo paese, al più trenta, prima chi ha più gusti fra quelli cercati e poi chi è stato nella meta più di recente. Il tetto (`tetto_ricerca`) conta solo le ricerche valide. Ogni ricerca legge i viaggi di ogni profilo acceso: con la beta va bene, con molte più persone servirà un indice delle mete pubbliche.
- **Le funzioni passano dal corpo della richiesta** (RPC), come tutte quelle dell'app: la meta e i gusti cercati non finiscono nell'indirizzo, che è quello che i registri del server tengono.
- **Che cosa avete in comune lo calcola il telefono di chi guarda**, con i propri viaggi chiusi (dalla copia) e i propri gusti: il server non conserva un'affinità fra due persone.
- **La barra mostra Community** se l'ultima volta che il server l'ha detto la parte pubblica c'era per quella persona ed era maggiorenne: il telefono lo ricorda, e lo richiede a ogni apertura dell'app. Mostrarla per errore non apre niente: dentro, ogni cosa la chiede al server.

### Come è fatto (5.4)

- **Collegamenti e messaggi si toccano solo dalle loro funzioni** (M7): `collegamento` e `messaggio` hanno la sicurezza per riga accesa e nessun privilegio per l'app. `chiedi_collegamento`, `rispondi`, `ritira_richiesta`, `togli_collegamento`, `togli_conversazione`, `scrivi` scrivono; `i_miei_collegamenti`, `i_miei_messaggi`, `conversazione` e il campo `collegamento` di `profilo_pubblico` leggono.
- **Un collegamento per coppia**, in qualunque verso (un indice unico su `least`/`greatest`): chi ha chiesto per ultimo è `da_utente`. Se l'altro aveva già chiesto, chiedere è un sì. Dopo un no si chiede di nuovo, e la riga torna `richiesto` (M9 non adottata). Il messaggio della richiesta vive nella riga finché si risponde: accettata, diventa il primo messaggio con la sua ora; rifiutata, si cancella.
- **Tutto segue `privato.vede_il_profilo`**: un profilo spento, sospeso o bloccato sparisce anche da collegamenti e conversazioni, e torna quando si riaccende o si sblocca. Bloccare non cancella niente.
- **La conversazione sopravvive al collegamento** (P6, scelto dall'utente il 10 ottobre 2026). `privato.conversazione_per(io, altro)` dice `collegati` (vi vedete: si scrive), `finita` (non più collegati, ma restano messaggi per chi guarda, che è nella parte pubblica, e nessun blocco) o niente. Chi toglie il collegamento o la conversazione finisce in `privato.conversazione_tolta` con un `fino_al`: i messaggi di prima non li vede più. Quelli che nessuno dei due vede più si cancellano. Gli orari vengono da `clock_timestamp()`, perché dentro una transazione `now()` è fermo e «prima» e «dopo» si confonderebbero.
- **Chi chiude l'account** perde i collegamenti; le conversazioni restano agli altri con «Account chiuso» (il profilo resta come lapide, senza nome). Dove c'era un blocco, in un verso o nell'altro, la conversazione si toglie anche all'altra persona, e quindi si cancella: chi aveva bloccato non deve ritrovarsela.
- **Un messaggio ha l'id nato sul telefono**: rimandato dopo una risposta persa, `scrivi` lo riconosce e non lo scrive due volte. Fra 1 e 1000 caratteri; al più `tetto_messaggi` (500) al giorno per persona. Le richieste non hanno tetto (M8 non adottata).
- **Niente conferme di lettura**: `letto_il` serve solo a dire a chi riceve che cosa è da leggere, e chi scrive non lo vede.
- **Niente notifiche, e niente Realtime**: la conversazione aperta chiede i messaggi nuovi ogni 5 secondi, da un minuto prima dell'ultimo arrivato (uno scritto un attimo prima può essere salvato dopo; quelli già arrivati si riconoscono dall'id). Collegamenti e Messaggi si ricaricano ogni 15 secondi mentre li si guarda. Con molte più persone, o con le notifiche (14), si passa a Realtime.
- **I messaggi non restano sul telefono**: si leggono con la rete, come tutta la parte pubblica. Scrivere non è uno dei quattro gesti offline; un messaggio che non parte resta con «Non inviato · Riprova», con lo stesso id.
- **Segnalare un messaggio** passa da `segnala` con il tipo `messaggio`: solo uno ricevuto, non tolto, in una conversazione che si vede. La fotografia tiene il testo, il nome di chi l'ha scritto e quando; chi è segnalato è chi l'ha scritto. Segnalando un profilo che ha chiesto di collegarsi, la fotografia tiene anche il messaggio della richiesta in attesa: rifiutando si cancellerebbe.
- **Togliere un messaggio** è `moderazione.togli(segnalazione)`: il testo si cancella (resta nella fotografia), le due persone vedono «Messaggio tolto da chi modera», e si chiudono tutte le segnalazioni aperte su quel messaggio con l'esito `contenuto_rimosso`.
- **I tuoi dati** (versione 4) hanno `corrispondenza`: i propri collegamenti e i messaggi che si vedono ancora, anche con chi oggi non si vede, da `la_mia_corrispondenza`.

---

## Cosa resta fuori

- Moderazione automatica dei contenuti
- Ricerca per posizione più precisa della città
- Qualunque forma di storico degli spostamenti
