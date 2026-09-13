# 04 — Itinerario

## A cosa serve

Costruire il programma dei giorni. È la funzione con più attrito potenziale dell'app, ed è quella su cui poggia l'ipotesi H2: se lo scheletro non invoglia il gesto successivo, il viaggio resta un contenitore vuoto.

---

## Schermate

- **Giorni** — l'elenco delle giornate con la loro capienza
- **Giornata** — le tappe in ordine, con i tempi
- **Nuova tappa** — luogo, durata stimata, orario
- **Genera itinerario** — prepara il prompt, lo consegna, riceve indietro il risultato

---

## Regole di comportamento

1. **L'itinerario esiste solo nello stato definito**, perché ha bisogno dei giorni.
2. **Ogni tappa ha una durata stimata.** Il campo è **precompilato** con un valore sensato secondo il tipo di tappa: non si chiede mai a vuoto.
3. **Ogni giornata ha una capienza**, che è la finestra reale del giorno — dagli orari di arrivo e partenza per il primo e l'ultimo giorno, dall'intera giornata per quelli in mezzo.
4. **Quando la somma delle durate supera la capienza, la tappa non si aggiunge.** Si dice quanto manca e si propone di accorciare, spostare a un altro giorno o togliere qualcosa.
5. **Nessun limite al numero di tappe** oltre quello che la capienza impone da sé. Non c'è nessun avviso su chi "ne mette troppe": il limite è nel modello, non nella sorveglianza.
6. **Le tappe si possono spostare fra giornate**, e la capienza si ricalcola su entrambe.

### Generazione dell'itinerario

7. **Trolley non chiama nessun modello.** Costruisce un prompt a partire da destinazione, giorni, orari e preferenze, e lo consegna perché la persona lo porti sull'assistente che già usa.
8. **Il prompt chiede una risposta in un formato preciso**, dentro un blocco di codice, così che il ritorno sia un solo tocco e non una selezione di testo fatta a dito.
9. **Il ritorno si incolla in un campo**, con il gesto della persona. L'app non legge gli appunti da sola.
10. **L'interpretazione è tollerante**: chiacchiere prima e dopo, campi mancanti, formattazione approssimativa. Si importa il parziale invece di rifiutare tutto.
11. **Il testo incollato si salva sempre**, anche quando l'interpretazione fallisce: diventa una nota del viaggio. Nessuno deve rifare il giro da capo.
12. **Si suggeriscono modelli di fascia medio-alta**, da un elenco aggiornabile da remoto e non scritto nel codice.
13. **Si avvisa che il risultato lo produce un servizio di terzi** e che Trolley non risponde della sua qualità. La tutela vera però è che tutto ciò che arriva resta modificabile.
14. **Le tappe generate entrano come tutte le altre**, capienza della giornata compresa: se l'assistente propone dodici ore di visite in una giornata da otto, l'eccedenza si vede e si sistema.

### Stato delle tappe

15. **Ogni tappa ha uno stato**: *da fare*, *completata*, *saltata*.
16. **Si marca durante il viaggio**, dalla schermata di oggi o dalla mappa, in un tocco solo.
17. **Marcare dopo la chiusura si può, ma non conta per la verifica.** La verifica misura cosa è successo durante, non cosa è stato ricostruito dopo.
18. **A fine giornata, se restano tappe non marcate, l'app lo ricorda una volta.** È il gesto da cui dipende la verifica del viaggio: vale un promemoria, non vale un assillo.

---

## Casi limite

| Situazione | Comportamento |
|---|---|
| L'interpretazione del testo incollato fallisce | Il testo si salva come nota, si spiega cosa non si è capito, si propone di riprovare. Mai una schermata di errore che non lascia niente |
| L'itinerario generato riguarda una destinazione diversa | Si segnala prima di importare. Capita quando qualcuno riusa un prompt vecchio |
| La durata stimata è palesemente sbagliata | È modificabile sempre, e la stima proposta non è mai vincolante |
| Due persone modificano la stessa giornata | Si applicano le regole sui conflitti: si mostrano le due versioni e si sceglie |

---

## Cosa resta fuori

- Chiamata diretta a un modello dall'app
- Suggerimenti automatici di attrazioni o percorsi ottimizzati
- Tempi di spostamento calcolati fra una tappa e l'altra: la capienza somma le durate, non i trasferimenti
