# ADR-002 — Persistenza locale

**Stato**: accettata

> **Rivista** dopo la scelta di un'architettura con server autoritativo. La decisione tecnica non cambia; cambia il ruolo di ciò che sta sul telefono.

## Contesto

Il database locale **è una copia**, non la fonte di verità. Deve però reggere lo stesso modello **relazionale** del server — viaggi, giorni, tappe, spese, quote, partecipazioni — perché è su quello che si fanno le query per giornata e per viaggio mentre la rete non c'è.

Serve inoltre una **coda di operazioni persistente** per i quattro gesti scrivibili offline, descritta in [02](../02-sincronizzazione-e-offline.md). Quella coda è l'unico dato che esiste solo sul telefono: perderla significa perdere le spese che qualcuno ha registrato in viaggio.

## Opzioni considerate

**SQLite con accesso diretto.** Massimo controllo, nessuna dipendenza in più. Ma ogni query è una stringa, le migrazioni si scrivono a mano e gli errori si scoprono a runtime — su un modello con una dozzina di entità correlate è una scelta che si paga ogni settimana.

**Un archivio a oggetti non relazionale.** Veloce da partire e comodo finché le entità sono indipendenti. Qui non lo sono: le quote di una spesa, le tappe di un giorno e la capienza sono relazioni con vincoli, e ricostruirli a mano significa riscrivere un database peggiore.

**SQLite con un livello tipizzato sopra.** Query controllate alla compilazione, migrazioni versionate, e sotto resta SQLite — cioè il formato più solido e più diffuso per i dati locali su telefono.

## Decisione

**SQLite, con un livello tipizzato sopra** (in Flutter, Drift).

Due ragioni. La prima: il modello è relazionale davvero, e fingere il contrario costa di più. La seconda, meno ovvia ma più importante — **il backend sarà Postgres** ([ADR-003](003-backend.md)), e avere lo stesso modello relazionale da entrambe le parti rende la sincronizzazione una traduzione di righe e non di concetti.

## Conseguenze

- **Le migrazioni pesano meno di quanto peserebbero in un'architettura local-first**: la copia si può buttare e riscaricare. L'eccezione è la coda, che non si può buttare: una migrazione deve sempre preservarla, e questo va provato.
- **La capienza del giorno si controlla in due momenti**: quando si aggiunge una tappa, e di nuovo quando l'operazione arriva al server, perché nel frattempo altri possono aver riempito la giornata.
- **Il file del database è dentro il contenitore dell'app**, quindi rientra nel backup di sistema insieme ai documenti — che è ciò che conta davvero, visto che i documenti sul server non ci sono.
