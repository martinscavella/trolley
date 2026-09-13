# 00 — Panoramica

## A cosa serve

Il modello mentale dell'app: quali oggetti esistono, in che stati si trovano, chi può fare cosa. Ogni altro capitolo dà per acquisito quello che c'è scritto qui.

---

## Gli oggetti

| Oggetto | Cos'è |
|---|---|
| **Viaggio** | Il contenitore di tutto. Ha uno stato, una destinazione, dei partecipanti |
| **Partecipante** | Una persona dentro un viaggio. Uno di loro è il creatore |
| **Tappa** | Un luogo o un'attività dentro una giornata, con una durata stimata |
| **Spesa** | Un importo, una valuta, chi ha pagato, chi partecipa alla divisione |
| **Cosa da portare** | Una voce di lista, personale o del viaggio |
| **Documento** | Un file sul telefono, agganciato al viaggio e possibilmente a un giorno |
| **Profilo** | La persona fuori dal viaggio: i suoi viaggi, il passaporto, il mappamondo |
| **Collegamento** | Il legame reciproco fra due profili pubblici |

---

## Gli stati del viaggio

```
   idea ──────► definito ──────► in corso ──────► chiuso
     │                                               │
     │                                               ├─► con verifica
     ▼                                               └─► senza verifica
 archiviato
```

| Stato | Quando | Cosa cambia |
|---|---|---|
| **Idea** | Alla creazione, se non ci sono date | Esistono destinazione, periodo approssimativo, partecipanti, posti, budget di massima, note |
| **Archiviato** | Quando il periodo indicato passa senza che il viaggio diventi definito (12 mesi se nessun periodo è indicato) | Esce dalla vista principale. Non viene cancellato e si può recuperare |
| **Definito** | Quando ci sono date, giorni e orari di arrivo e partenza | Si sbloccano itinerario per giornate, documenti agganciati ai giorni, spese, fase live |
| **In corso** | Fra la data di inizio e quella di fine | L'app mostra oggi e dopo, e privilegia ciò che serve adesso |
| **Chiuso** | Dopo la data di fine | Arrivano traguardi, mappamondo e riepilogo |

Il viaggio chiuso è **con verifica** se è stato attraversato davvero con l'app: almeno una tappa per ogni giorno, l'app aperta sul posto con la geolocalizzazione attiva, e **tutte** le tappe marcate come completate o saltate mentre il viaggio era in corso. Solo quello conta nelle metriche e assegna i traguardi pieni. La regola per intero è nel [capitolo 02](02-il-viaggio.md).

I **viaggi importati** — quelli passati, inseriti come ricordo — non attraversano questi stati: nascono chiusi, sono marcati visibilmente come importati e non producono mai traguardi verificati.

---

## Le cinque fasi, e cosa fa l'app in ciascuna

| Fase | Stato del viaggio | Cosa fa l'app |
|---|---|---|
| Decisione | idea | Tiene ferma un'intenzione prima che si perda in chat |
| Pianificazione | definito | Costruisce il programma, aggancia le prenotazioni, invita i compagni |
| Preparazione | definito | Verifica che non manchi niente: biglietti, documenti, cose da portare |
| Durante | in corso | Mostra cosa succede adesso e cosa viene dopo, anche senza rete |
| Dopo | chiuso | Restituisce traguardi, spese totali, mappamondo |

---

## Chi può fare cosa

**Sui contenuti il modello è paritario.** Chiunque partecipi a un viaggio può aggiungere e modificare tappe, spese, cose da portare e propri documenti, e matura gli stessi traguardi degli altri.

**Sull'amministrazione no.** Chi ha creato il viaggio è l'unico che può rimuovere un partecipante. È l'unica asimmetria dell'MVP, e serve perché in un gruppo perfettamente paritario non esisterebbe nessuno legittimato a chiudere una situazione che va male.

---

## Le regole che valgono ovunque

Dieci invarianti. Se una funzione ne viola una, è la funzione a essere sbagliata.

1. **Un viaggio può esistere prima delle date.** Destinazione e un periodo qualsiasi bastano a farlo nascere.
2. **Le funzioni del durante richiedono lo stato definito.** Senza date, giorni e orari non ci sono itinerario per giornate, documenti agganciati ai giorni, spese né fase live.
3. **Ogni tappa ha una durata stimata, e la giornata ha una capienza.** Quando la somma supera la finestra reale del giorno — che è data dagli orari di arrivo e partenza — la tappa non si aggiunge. La durata è precompilata con un valore sensato, mai chiesta a vuoto.
4. **Tutti modificano i contenuti, solo il creatore rimuove le persone.**
5. **I documenti non lasciano il telefono.** Non sono su un nostro server, non si sincronizzano, non si condividono fra partecipanti.
6. **I viaggi futuri non sono mai pubblici.** Né sul profilo, né nella ricerca, né da nessuna altra parte.
7. **Niente si cancella da solo.** Le idee abbandonate si archiviano, i viaggi chiusi restano.
8. **Senza rete l'essenziale c'è.** Documenti, programma di oggi e domani, dati base del viaggio e ultimo tasso di cambio noto. Il resto si scarica a scelta.
9. **I conflitti si mostrano, non si fondono in silenzio.** Quando due persone toccano lo stesso punto si vedono le due versioni e si sceglie.
10. **Quello che una soglia deve misurare, l'app lo registra.** Senza esperimenti preliminari la strumentazione è l'unico strumento di verifica rimasto, e nasce insieme alla funzione, non dopo.

---

## Cosa resta fuori dall'MVP

- Generazione dell'itinerario chiamata direttamente dall'app: nell'MVP si esporta un prompt e si incolla indietro il risultato
- Import automatico delle prenotazioni da email o biglietti
- Prenotazione di voli, treni, bus e alloggi
- Viaggi di gruppo organizzati da un ente, con un organizzatore dai poteri estesi
- Bundle di gruppo a listino
