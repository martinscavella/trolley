# Punti aperti

Quello che non è ancora chiuso, e per ciascuna cosa **che cosa la chiude**.

Le decisioni già prese non stanno qui: stanno in [Decisioni di prodotto](decisioni/prodotto.md). Le domande a cui era possibile rispondere subito sono state chiuse e riportate lì — questo documento tiene solo ciò che richiede lavoro o misure.

Due sezioni:

- **A fare** — non sono domande, sono cose da costruire o da stimare.
- **Da misurare** — la risposta arriva dai numeri della beta, e qui è scritto quali.

---

## A fare

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

Tre modi di assorbirle:

1. **Spostare la data** di circa un mese. Onesto, ma resta ottimista per tutti i motivi già scritti altrove.
2. **Tenere la data e tagliare altro.** Il candidato naturale sarebbe il matching, che però è stato rimesso dentro apposta: il ragionamento gira in tondo.
3. **Beta in due ondate.** ← è quella che consiglio

**Come funziona.**

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
