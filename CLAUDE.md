# Trolley

App mobile (Flutter, iOS prima) che segue un viaggio dall'idea al ritorno. "Trolley" è un nome in codice.

La documentazione in `docs/` è la fonte di verità: si parte da [docs/README.md](docs/README.md). Prima di costruire una funzione si leggono il suo capitolo in `docs/prodotto/` e i capitoli rilevanti in `docs/tecnico/`. L'ordine di costruzione è in [docs/piano-di-costruzione.md](docs/piano-di-costruzione.md).

## Stack

- App: Flutter, un solo codice per iOS e Android ([ADR-001](docs/tecnico/adr/001-stack.md))
- Locale: SQLite con Drift — è una **copia**, non la fonte di verità ([ADR-002](docs/tecnico/adr/002-persistenza-locale.md))
- Backend: Supabase (Postgres, Auth, regole di accesso per riga) — è **l'autorità** ([ADR-003](docs/tecnico/adr/003-backend.md))

## Regole che valgono per ogni modifica

1. **Ogni funzione nasce con il suo evento** ([07 — Misurazione](docs/tecnico/07-misurazione.md)). Una funzione senza evento non è finita. Eventi: azioni, mai contenuti; niente coordinate, testi, nomi di documenti.
2. **Ogni funzione sa da che parte sta rispetto alla rete**: leggibile offline, uno dei quattro gesti scrivibili offline (registrare una spesa, marcare una tappa, spuntare una voce, aggiungere una tappa), oppure dipendente dalla rete — e in quel caso lo dice prima, disabilitando il controllo con il motivo ([02](docs/tecnico/02-sincronizzazione-e-offline.md)).
3. **I documenti non lasciano mai il telefono.** Nessun percorso di codice li carica o li sincronizza; il backend non ha object storage ([03](docs/tecnico/03-documenti-sul-dispositivo.md)).
4. **Le regole di dominio vivono nell'app, in un posto solo** (capienza della giornata, stati del viaggio, verifica). Il server fa rispettare solo chi può leggere e scrivere cosa.
5. **Ogni servizio esterno sta dietro un'interfaccia interna** — mappe, SMS, tassi di cambio, ingresso da invito. Nessuna schermata parla direttamente con un fornitore ([04](docs/tecnico/04-integrazioni.md)).
6. **Le regole di accesso per riga si scrivono con i loro test.** Sono la vera superficie di sicurezza.
7. **La coda di scrittura è preziosa**: ogni migrazione del database locale deve preservarla, e va provato.
8. **Mai fondere due testi** in un conflitto: si mostrano le due versioni e sceglie la persona.

## Dove si scrive cosa

- Una scelta presa → `docs/decisioni/prodotto.md` (prodotto) o un nuovo ADR in `docs/tecnico/adr/` (tecnica)
- Qualcosa da fare o da misurare → `docs/punti-aperti.md`
- Un'ipotesi con soglia → `docs/discovery/03-ipotesi-da-validare.md`

I documenti sono in italiano, e anche i nomi degli eventi di misurazione.
