# 05 — Community e sicurezza

La parte pubblica esce nella **seconda ondata**. È l'unica porzione del prodotto dove un errore non produce un dato sbagliato ma un danno a una persona, e dove quindi le regole stanno **sul server** e non nell'app: un controllo fatto solo nell'interfaccia è un controllo che non esiste.

---

## Le regole di accesso per riga

Poche, e vanno scritte una volta sola con dei test. È qui che si sbaglia.

| Regola | Formulazione |
|---|---|
| **Viaggi** | Si legge un viaggio solo se si è partecipanti con stato `attivo`. Nessuna eccezione, nemmeno per chi ha creato il viaggio dopo esserne uscito |
| **Profilo pubblico** | Si legge solo se `profilo_pubblico_attivo` è vero e chi guarda non è bloccato |
| **Viaggi sul profilo** | Solo quelli con stato `chiuso`. I viaggi futuri e in corso **non compaiono in nessuna query pubblica**: non è un filtro nell'interfaccia, è una condizione della regola |
| **Messaggi** | Si scrive solo verso un collegamento con stato `accettato` |
| **Blocco** | Bidirezionale: nessuno dei due compare all'altro in ricerca, profili o messaggi |
| **Presenza in città** | Si legge solo da chi ha a sua volta la presenza attiva per un viaggio in corso nella stessa città |

L'invariante da cui non si deroga: **se una regola dell'interfaccia nasconde qualcosa, deve esistere una regola sul server che lo rende irraggiungibile.**

---

## Presenza in città

| | |
|---|---|
| Granularità | **Città.** Mai coordinate, mai distanza, mai un punto su una mappa |
| Attivazione | Esplicita, per singolo viaggio, spenta di default |
| Durata | Si **cancella** alla fine del viaggio. Non si archivia: la riga sparisce |
| Reciprocità | Si vede solo chi ha attivato a sua volta |
| Storico | Non esiste. Nessuna tabella conserva dove qualcuno è stato e quando |

La città si ricava dalla destinazione del viaggio, **non dalla posizione rilevata**. È una semplificazione che elimina il problema alla radice: non esiste un flusso in cui la posizione di una persona viene mandata al server per essere confrontata con quella di altri.

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
- **La terza azione**, togliere un contenuto, arriva con i messaggi (5.4): oggi si segnalano solo i profili.

---

## Cosa resta fuori

- Moderazione automatica dei contenuti
- Ricerca per posizione più precisa della città
- Qualunque forma di storico degli spostamenti
