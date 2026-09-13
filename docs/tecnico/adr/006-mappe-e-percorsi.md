# ADR-006 — Mappe, percorsi e il tetto alla spesa

**Stato**: accettata nella struttura, fornitore da confermare

## Contesto

La navigazione è **dentro** Trolley: mappa, percorso disegnato, indicazioni passo passo, posizione in tempo reale. Servono tre cose dallo stesso ambito — riquadri di mappa, calcolo dei percorsi, ricerca dei luoghi — e tutte e tre si pagano a chiamata.

È il primo costo del prodotto che **cresce con l'uso** e non con le registrazioni: una persona che naviga tutto il giorno costa più di dieci che aprono l'app due volte. Va contro la regola che ci si è dati — *nessun costo variabile senza tetto* — e quindi il tetto fa parte della funzione, non è una precauzione successiva.

## Decisione

**Un fornitore solo per tutte e tre le cose, dietro un'interfaccia interna, con un tetto applicato dal client.**

**Un fornitore solo**: riquadri, percorsi e ricerca luoghi dallo stesso ambito. Due fornitori significano due integrazioni, due contratti e due comportamenti diversi sugli stessi dati.

**Dietro un'interfaccia interna**: nessuna schermata parla con il fornitore. Sostituirlo dev'essere un file.

**Il fornitore preciso si conferma alla realizzazione**, verificando condizioni e piani gratuiti nel momento in cui si integra — le tariffe di questo settore cambiano più in fretta di quanto invecchi un documento, e scriverne una qui significherebbe scrivere una cosa falsa fra sei mesi. I criteri di scelta, quelli sì, valgono: copertura delle tre funzioni, piano gratuito che regga la fase interna, plugin Flutter mantenuto, e possibilità di leggere il consumo in corso d'opera — senza quest'ultima il tetto non si può applicare.

## Il tetto

1. **Un limite di chiamate per viaggio e per persona**, non un limite globale: un tetto complessivo lo esaurirebbe il primo utente attivo e romperebbe l'app a tutti gli altri.
2. **Al raggiungimento la navigazione degrada**, non si spegne: restano mappa e tappe, si consegna all'app di mappe del telefono per la guida. Chi sta viaggiando non resta mai senza indicazioni per una questione di budget — è la stessa regola per cui nessun limite commerciale tocca un viaggio in corso.
3. **Il consumo si misura**, per persona e per viaggio, e va guardato dal primo giorno: serve a sapere quanto costa davvero una persona che viaggia, che oggi è un numero che nessuno conosce.
4. **I riquadri di mappa già scaricati si tengono in cache** per la sessione: è la riduzione più facile e non cambia niente per chi usa l'app.

Nella fase interna — il team, una decina di persone — i piani gratuiti bastano e la valutazione è rimandata di proposito. **Il tetto è prerequisito per aprire fuori dal team**, non per la prima riga di codice.

## Conseguenze

- **La navigazione è l'unica funzione dell'app con un limite tecnico**, e quel limite va progettato bene: degradare con grazia è parte della funzione.
- **Il consumo per persona diventa un'unità economica**, accanto al ricavo per persona: è il primo costo di Trolley che si può attribuire a un singolo utente.
- **Se il fornitore cambia condizioni**, l'interfaccia interna limita il danno a una sostituzione — purché nessuno la aggiri per comodità, il che succede sempre se non c'è una revisione che lo impedisce.
