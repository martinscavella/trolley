# Piano di costruzione

In che ordine si costruisce, e perché quello.

**Il principio**: si parte da ciò che, se non funziona, costringe a rifare tutto il resto. Non da ciò che si vede meglio.

Tre cose in questo progetto hanno quella proprietà — il **deep link differito**, la **sincronizzazione fra più autori** e l'**impianto di sicurezza** — e tutte e tre sono invisibili in una dimostrazione. Sono le prime tre voci del loro blocco.

---

## Fase 0 — Il terreno

Nessuna funzione. Se questa fase va male, le ipotesi cambiano.

| | Cosa | Perché prima |
|---|---|---|
| 0.1 | **Deep link differito**, provato su un'installazione vera dallo store | H3 è l'unico canale di acquisizione e non ha piano B. Si rompe in silenzio, e in sviluppo funziona sempre |
| 0.2 | Scheletro dell'app, backend e schema, copia locale, coda di scrittura (vuota) | È il terreno su cui poggia tutto. Aggiungerlo dopo significa riscrivere le funzioni già fatte |
| 0.3 | Accesso con email, Google e Apple; età | Ogni cosa successiva ha bisogno di sapere chi è la persona |

---

## Fase 1 — Il viaggio da solo

Niente condivisione. Alla fine di questa fase l'app **è già utile a chi viaggia da solo**, e la si può usare internamente per un viaggio vero — che è il primo momento in cui si scopre davvero qualcosa.

| | Cosa |
|---|---|
| 1.1 | Viaggio: stati idea e definito, giorni, capienza della giornata |
| 1.2 | Tappe: durata stimata, ordine, stato *da fare / completata / saltata* |
| 1.3 | Documenti sul dispositivo |
| 1.4 | Spese: valuta predefinita, tasso di cambio, ultimo valore noto offline |
| 1.5 | Cose da portare |
| 1.6 | Esportazione del prompt e ritorno incollato |

---

## Fase 2 — La condivisione

Va fatta **prima** della fase live: aggiungere la scrittura concorrente a funzioni già scritte per un autore solo costa più che prevederla. Con il server autoritativo però è molto meno cara di quanto sarebbe stata — non c'è nessuna riconciliazione fra due database, solo un rifiuto onesto quando si scrive su una versione superata.

| | Cosa |
|---|---|
| 2.1 | Partecipanti, inviti, poteri del creatore |
| 2.2 | Conflitti fra modifiche concorrenti online: versione al salvataggio, rifiuto, schermata di scelta |
| 2.3 | Divisione delle spese e saldi |
| 2.4 | Liste condivise e liste personali |

---

## Fase 3 — Il durante

| | Cosa |
|---|---|
| 3.1 | Schermata "adesso" |
| 3.2 | Mappa, navigazione, marcatura della tappa dalla mappa |
| 3.3 | Sincronizzazione selettiva e preparazione prima della partenza |
| 3.4 | Verifica del viaggio — dipende da 1.2, 3.2 e dal permesso di posizione |

---

## Fase 4 — Il dopo

| | Cosa |
|---|---|
| 4.1 | Chiusura, riepilogo, traguardi |
| 4.2 | Mappamondo e passaporto |
| 4.3 | Viaggi importati, marcati come tali |

### → Ondata 1 della beta

---

## Fase 5 — La parte pubblica

| | Cosa |
|---|---|
| 5.1 | **Impianto di sicurezza**: segnalazione, blocco, moderazione, verifica del telefono, condizioni d'uso — 3–4 settimane |
| 5.2 | Valutazioni d'impatto e revisione legale |
| 5.3 | Profilo pubblico e ricerca |
| 5.4 | Collegamenti reciproci e messaggi |
| 5.5 | Presenza in città |

**5.1 viene prima di 5.3, non dopo.** Costruendo prima le funzioni pubbliche si crea la pressione a pubblicarle senza la rete di protezione — e quella pressione vince sempre.

### → Ondata 2, quattro-sei settimane dopo

---

## Fase 6 — Monetizzazione

Non nell'MVP. Si accende quando i numeri di H1 dicono quali funzioni le persone valutano davvero, perché è quello che decide cosa sta dietro il pagamento.

---

## Due regole che attraversano tutte le fasi

**La misurazione non è una fase.** Ogni funzione nasce con il suo evento: una funzione senza evento non è finita, e non passa la revisione. Rincorrere gli eventi alla fine significa scoprire a beta avviata che la soglia non si può calcolare.

**Il funzionamento senza rete non è una fase.** Ogni funzione nasce sapendo da che parte sta: leggibile offline, o uno dei quattro gesti scrivibili, o dipendente dalla rete — e in quest'ultimo caso lo dice prima invece di fallire dopo. Aggiungerlo alla fine vuol dire riscriverla.
