# Documentazione tecnica

Come è fatta l'app. È il documento che chi sviluppa — persona o agente — apre prima di scrivere codice, e che serve a evitare che ogni funzione reinventi le proprie regole.

Il comportamento atteso sta in [`../prodotto/`](../prodotto/); qui c'è come si realizza.

Lo stack è deciso: **Flutter**, un solo codice per iOS e Android. Il ragionamento e le alternative scartate sono in [ADR-001](adr/001-stack.md).

## Capitoli previsti

| # | Capitolo | Contenuto |
|---|---|---|
| 00 | Architettura | Cosa gira sul telefono e cosa su un server, e perché. I confini |
| 01 | Modello dati | Entità, relazioni, stati, invarianti. La parte da cui dipende tutto il resto |
| 02 | Sincronizzazione e offline | Cosa è essenziale senza rete, cosa è a scelta, come si risolvono i conflitti fra più autori |
| 03 | Documenti sul dispositivo | Dove stanno, come sono protetti, cosa succede cambiando telefono |
| 04 | Integrazioni | Tasso di cambio, invio SMS, deep link differito, mappe. Per ciascuna: costo, limiti, comportamento senza rete |
| 05 | Community e sicurezza | Profili pubblici, ricerca, collegamenti, segnalazione e blocco lato dati |
| 06 | Privacy e conformità | Dati trattati, basi giuridiche, conservazione, età, cosa non esce mai dal telefono |
| 07 | Misurazione | Eventi, dove finiscono, come si leggono contro le soglie delle ipotesi |

## ADR

Le decisioni architetturali che vale la pena motivare per iscritto vivono in `adr/`, una per file, con la forma: contesto, opzioni considerate, scelta, conseguenze.

Le prime due già previste dalla discovery:

- [**ADR-001** — Stack e piattaforma](adr/001-stack.md) ✅
- **ADR-002** — Persistenza locale e libreria SQLite
- **ADR-003** — Backend: autenticazione e sincronizzazione
- **ADR-004** — Deep link differito — il pezzo da cui dipende H3
- **ADR-005** — Dati geografici: elenco incorporato o servizio esterno
- **ADR-006** — Fornitore di mappe e percorsi, e come si mette un tetto al costo per utente
