# ADR-003 — Backend

**Stato**: accettata

## Contesto

Il server è **l'autorità**: è lì che stanno i dati, e l'app è un client. Serve quindi qualcosa che faccia tre cose: **autenticare** (email, Google, Apple), **custodire** i dati dei viaggi, e **garantire che nessuno legga o scriva ciò che non gli spetta**.

Non serve archiviare file: i documenti restano sul telefono. Non serve logica di dominio sul server: le regole vivono nell'app, in un posto solo, così iOS e Android non divergono. Non serve tempo reale.

Il vincolo che decide: **una persona sola non mantiene un server.** Qualunque cosa richieda aggiornamenti di sistema, certificati o sorveglianza è esclusa a prescindere dai suoi meriti.

## Opzioni considerate

**Backend proprio.** Massima libertà, costo di manutenzione che non rientra nei sei mesi né negli anni dopo. Escluso dal vincolo, non dai meriti.

**Servizio gestito a documenti.** Ottimo supporto per il funzionamento senza rete, già pronto. Ma il modello è relazionale e i documenti annidati lo combattono: le quote di una spesa e i vincoli fra tappe e giorni diventano codice che riscrive a mano quello che un database relazionale fa da sé. Inoltre la sincronizzazione automatica risolve i conflitti per conto suo — esattamente quello che qui **non** si vuole.

**Servizio gestito su Postgres.** Autenticazione con i tre fornitori inclusa, regole di accesso per riga, e lo stesso modello relazionale che c'è sul telefono.

## Decisione

**Un servizio gestito su Postgres** (Supabase come candidato).

Due ragioni. La prima: il modello è **relazionale** — quote di una spesa, tappe dentro giorni, partecipazioni — e un archivio a documenti costringerebbe a riscrivere a mano i vincoli che Postgres applica da sé.

La seconda, meno ovvia: la **sincronizzazione automatica** che i servizi a documenti offrono come pregio qui sarebbe un difetto. Risolve i conflitti per conto suo, mentre Trolley deve **mostrarli**. Con un server autoritativo la cosa giusta è il contrario di una sincronizzazione furba: un rifiuto onesto quando si scrive su una versione superata, e la decisione lasciata alla persona.

A seguire: i tre metodi di accesso già pronti, e un piano gratuito ampio per una fase in cui gli utenti sono il team.

## Conseguenze

- **Le regole di accesso per riga sono la vera superficie di sicurezza.** Un viaggio si legge solo se si è partecipanti attivi; un profilo non pubblico non si legge; un viaggio non chiuso non compare mai in nessuna query pubblica. Sono poche regole e vanno scritte una volta, bene, con dei test: è lì che si sbaglia.
- **Il server non conosce le regole di dominio**, pur essendo l'autorità sui dati. Non sa cos'è la capienza di una giornata né quando un viaggio è verificato: quelle regole vivono nell'app, in un posto solo, così iOS e Android non divergono. Il server fa rispettare **chi può leggere e scrivere cosa**, che è una cosa diversa e non si può delegare al client. L'unica eccezione è la **deroga amministrativa sulla verifica**.
- **Serve una colonna di versione per entità**, perché il rifiuto di una scrittura su versione superata è il meccanismo che produce i conflitti da mostrare.
- **Nessun object storage attivo**, e questa non è solo un'economia: è ciò che rende vera l'affermazione "i documenti non lasciano il telefono".
- **Migrare è possibile.** Postgres è Postgres: se il fornitore diventa un problema, ciò che si porta via è uno schema e dei dati, non un modello di programmazione.
