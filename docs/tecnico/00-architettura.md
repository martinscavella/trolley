# 00 — Architettura

## Il principio

**Il server è l'autorità.** È lì che stanno i dati, ed è lui a decidere cosa è vero quando due persone scrivono la stessa cosa. L'app è un client che parla con il server, e tiene in locale quello che serve per non fermarsi quando la rete manca.

Questo è l'opposto di un'architettura *local-first*, ed è una scelta deliberata. Il funzionamento senza rete è un'ipotesi — **H4** — che nessuno ha ancora verificato: non c'è stato nessuno spike, nessuna intervista. Costruire il database locale come fonte di verità significherebbe pagare subito, e per intero, la scommessa più cara del progetto per sostenere una convinzione che si potrà controllare solo in beta.

Server autoritativo con copia locale è **la scommessa piccola**: se in beta H4 si dimostra forte, si approfondisce; se si dimostra debole, non è stato speso niente.

---

## I tre pezzi

```
┌──────────────────────────────────────────────┐
│  App Flutter (iOS, poi Android)              │
│                                              │
│  ├── Copia locale ← per leggere senza rete   │
│  ├── Coda di scrittura ← quattro gesti soli  │
│  └── Cartella documenti ← non è una copia:   │
│      stanno solo qui                         │
└──────────────┬───────────────────────────────┘
               │  solo testo
┌──────────────▼───────────────────────────────┐
│  Backend gestito — l'autorità                │
│  ├── Autenticazione (email, Google, Apple)   │
│  ├── Postgres — viaggi, tappe, spese…        │
│  └── Regole di accesso per riga              │
└──────────────┬───────────────────────────────┘
               │
┌──────────────▼───────────────────────────────┐
│  Servizi esterni, a chiamata                 │
│  mappe e percorsi · SMS · tassi di cambio    │
└──────────────────────────────────────────────┘
```

---

## Cosa c'è in locale, e perché

| | Cosa | Natura |
|---|---|---|
| **Copia di lettura** | Viaggi attivi, giorni e tappe, spese registrate, liste, partecipanti, ultimo tasso di cambio noto | Una copia. Si può buttare e riscaricare senza perdere niente |
| **Coda di scrittura** | I quattro gesti essenziali fatti senza rete | L'unico dato che esiste solo in locale finché non parte. **Va trattato come prezioso** |
| **Documenti** | I file | Non sono una copia: **esistono solo qui** |

---

## I quattro gesti che si possono fare senza rete

1. **Registrare una spesa**
2. **Marcare una tappa** come completata o saltata
3. **Spuntare una voce di lista**
4. **Aggiungere una tappa**

Non è un elenco arbitrario: sono i gesti che capitano **mentre si è in giro** — al mercato, sul taxi, davanti al museo — e sono anche, non per caso, gli unici quattro che **non possono generare un conflitto**. Sono aggiunte o cambi di stato ripetibili: due persone che registrano due spese producono due spese, due che spuntano la stessa voce producono una voce spuntata.

Tutto il resto — modificare un importo, riscrivere una nota, spostare le date, cambiare una durata — **richiede rete**. E va bene: sono gesti da tavolino, non da marciapiede.

> È questa distinzione a eliminare il pezzo più caro del progetto. Una coda generale con scrittura libera offline avrebbe richiesto versioni, fusioni e una macchina dei conflitti; una coda di quattro operazioni che non confliggono richiede un elenco e dei tentativi ripetuti.

---

## Le regole che vincolano ogni scelta tecnica

1. **Leggere non richiede mai la rete** per ciò che è nella copia locale.
2. **I quattro gesti non richiedono mai la rete.** Riescono subito, localmente, e partono dopo.
3. **Tutto il resto richiede la rete, e lo dice prima.** Un campo che non si può modificare offline si mostra disabilitato con il motivo, non fallisce dopo che qualcuno ha scritto.
4. **I documenti non attraversano mai il confine.** Nessun percorso di codice li carica o li sincronizza.
5. **Le regole di dominio vivono nell'app** — capienza della giornata, stati del viaggio, verifica — in un posto solo, uguale su iOS e Android. Il server custodisce, distribuisce e fa rispettare **chi può leggere cosa**. L'unica eccezione è la deroga amministrativa sulla verifica, che non può stare in mano all'app.

---

## Cosa si accetta di non avere

- **Nessun tempo reale.** Le modifiche degli altri arrivano al prossimo aggiornamento.
- **Nessuna scrittura libera offline.** È la rinuncia che compra la semplicità di tutto il resto, e si può rivedere se i numeri di H4 lo giustificano.
- **Nessun backend proprio.** Una persona sola non mantiene un server.

---

## Da qui in poi

- Entità e regole: [01 — Modello dati](01-modello-dati.md)
- Copia locale, coda e conflitti: [02 — Copia locale, coda e conflitti](02-sincronizzazione-e-offline.md)
- Le scelte motivate: [ADR](adr/)
