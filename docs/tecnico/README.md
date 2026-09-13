# Documentazione tecnica

Come è fatta l'app. È il documento che chi sviluppa — persona o agente — apre prima di scrivere codice, e che serve a evitare che ogni funzione reinventi le proprie regole.

Il comportamento atteso sta in [`../prodotto/`](../prodotto/); qui c'è come si realizza.

Lo stack è deciso: **Flutter**, un solo codice per iOS e Android. Il ragionamento e le alternative scartate sono in [ADR-001](adr/001-stack.md).

## Capitoli

| # | Capitolo | Contenuto |
|---|---|---|
| 00 | [Architettura](00-architettura.md) | Cosa gira sul telefono e cosa su un server, e perché. I confini |
| 01 | [Modello dati](01-modello-dati.md) | Entità, relazioni, stati, invarianti. La parte da cui dipende tutto il resto |
| 02 | [Sincronizzazione e offline](02-sincronizzazione-e-offline.md) | Cosa è essenziale senza rete, cosa è a scelta, come si risolvono i conflitti fra più autori |
| 03 | [Documenti sul dispositivo](03-documenti-sul-dispositivo.md) | Dove stanno, come sono protetti, cosa succede cambiando telefono |
| 04 | [Integrazioni](04-integrazioni.md) | Tasso di cambio, invio SMS, deep link differito, mappe. Per ciascuna: costo, limiti, comportamento senza rete |
| 05 | [Community e sicurezza](05-community-e-sicurezza.md) | Profili pubblici, ricerca, collegamenti, segnalazione e blocco lato dati |
| 06 | [Privacy e conformità](06-privacy-e-conformita.md) | Dati trattati, basi giuridiche, conservazione, età, cosa non esce mai dal telefono |
| 07 | [Misurazione](07-misurazione.md) | Eventi, dove finiscono, come si leggono contro le soglie delle ipotesi |

## ADR

Le decisioni architetturali che vale la pena motivare per iscritto vivono in `adr/`, una per file, con la forma: contesto, opzioni considerate, scelta, conseguenze.

- [**ADR-001** — Stack e piattaforma](adr/001-stack.md) ✅
- [**ADR-002** — Persistenza locale](adr/002-persistenza-locale.md) ✅
- [**ADR-003** — Backend](adr/003-backend.md) ✅
- [**ADR-004** — Deep link differito](adr/004-deep-link-differito.md) ✅
- [**ADR-005** — Dati geografici](adr/005-dati-geografici.md) ✅
- [**ADR-006** — Mappe, percorsi e il tetto alla spesa](adr/006-mappe-e-percorsi.md) ✅ *(fornitore da confermare alla realizzazione)*
