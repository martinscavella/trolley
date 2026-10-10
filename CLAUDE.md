# Trolley

App mobile (Flutter, iOS prima) che segue un viaggio dall'idea al ritorno. "Trolley" è un nome in codice.

La documentazione in `docs/` è la fonte di verità: si parte da [docs/README.md](docs/README.md). Prima di costruire una funzione si leggono il suo capitolo in `docs/prodotto/` e i capitoli rilevanti in `docs/tecnico/`. L'ordine di costruzione è in [docs/piano-di-costruzione.md](docs/piano-di-costruzione.md).

## Stack

- App: Flutter, un solo codice per iOS e Android ([ADR-001](docs/tecnico/adr/001-stack.md))
- Locale: SQLite con Drift — è una **copia**, non la fonte di verità ([ADR-002](docs/tecnico/adr/002-persistenza-locale.md))
- Backend: Supabase (Postgres, Auth, regole di accesso per riga) — è **l'autorità** ([ADR-003](docs/tecnico/adr/003-backend.md))

## Struttura e comandi

| Cartella | Cosa | Comandi |
|---|---|---|
| `app/` | L'app Flutter. `lib/dominio/` regole pure, `lib/dati/` database locale, coda dei gesti senza rete (`coda.dart`), documenti sul telefono (`documenti.dart`, mai in rete), server, rete e destinazioni, il fornitore di mappe (`mappe.dart`, Geoapify attraverso la funzione `mappe` del server, ADR-006), la verifica del telefono (`telefono.dart`, Twilio Verify attraverso la funzione `telefono`, ADR-011), la parte pubblica sul server (`parte_pubblica.dart`) e la posizione del telefono (`posizione.dart`, mai fuori), `lib/aspetto/` colori, testi, movimento e componenti, `lib/schermate/`. `tool/genera_destinazioni.dart` rigenera l'elenco incorporato delle destinazioni, `tool/genera_confini.dart` i confini del mappamondo (ADR-005) | `flutter test`, `flutter analyze`, `dart run build_runner build` dopo aver toccato `database.dart`. Sul telefono: `flutter build ios --release` e `xcrun devicectl device install app`. La chiave di Geoapify non sta nell'app: è il segreto `GEOAPIFY_CHIAVE` delle funzioni di Supabase (U.2). Il canale nativo dei documenti (`ios/Runner/DocumentiDelTelefono.swift`) si prova sull'iPhone con `xcodebuild test` (ADR-008) |
| `supabase/migrations/` | Lo schema del server, una migrazione per file | Applicate a `trolley-db` (ref `nhdgxlynnudwkmxrrokp`). Il nome del file porta la versione registrata sul server |
| `supabase/functions/` | Le funzioni del server: `mappe` tiene la chiave di Geoapify e il tetto (ADR-006); `telefono` tiene le chiavi di Twilio e chiede al database se si può mandare un codice (ADR-011) | Si pubblicano con `supabase functions deploy <nome> --project-ref nhdgxlynnudwkmxrrokp --no-verify-jwt`; i segreti con `supabase secrets set GEOAPIFY_CHIAVE=…` (e `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_VERIFY_SID`, `TELEFONO_PROVA` per i numeri finti) |
| `supabase/migrations/…_sicurezza.sql`, schema `moderazione` | Lo strumento di moderazione: si usa solo dall'editor SQL, mai dall'app ([docs/sicurezza/moderazione.md](docs/sicurezza/moderazione.md)) | `select * from moderazione.coda;` |
| `supabase/tests/` | Le prove delle regole di accesso | Girano dentro un blocco che si annulla da solo: si possono lanciare anche sul progetto remoto |
| `sito/` | La pagina dei link d'invito, l'informativa (`privacy.html`), cosa si misura (`misurazione.html`) e le condizioni d'uso della parte pubblica (`condizioni.html`, la cui data è `versioneCondizioni` nell'app), su `trolleyapp.vercel.app` | `vercel deploy --prod` dalla cartella |

Nomi di tabelle, colonne ed eventi sono in italiano, uguali a quelli di `docs/tecnico/01-modello-dati.md`: sul server e nella copia locale sono gli stessi, così scaricare è tradurre righe.

## Regole che valgono per ogni modifica

1. **Ogni funzione nasce con il suo evento** ([07 — Misurazione](docs/tecnico/07-misurazione.md)). Una funzione senza evento non è finita. Eventi: azioni, mai contenuti; niente coordinate, testi, nomi di documenti. Un evento nuovo o cambiato si scrive anche in `sito/misurazione.html`, la pagina che le persone leggono.
2. **Ogni funzione sa da che parte sta rispetto alla rete**: leggibile offline, uno dei quattro gesti scrivibili offline (registrare una spesa, marcare una tappa, spuntare una voce, aggiungere una tappa), oppure dipendente dalla rete — e in quel caso lo dice prima, disabilitando il controllo con il motivo ([02](docs/tecnico/02-sincronizzazione-e-offline.md)): `schermate/con_la_rete.dart` e il `motivo` di `PulsanteGrande`. Le chiamate al server passano da `alServer` con la `Rete`, e da `supabase.rest`, non da `supabase.from` (che ignora le opzioni del client).
3. **I documenti non lasciano mai il telefono.** Nessun percorso di codice li carica o li sincronizza; il backend non ha object storage ([03](docs/tecnico/03-documenti-sul-dispositivo.md)).
4. **Le regole di dominio vivono nell'app, in un posto solo** (capienza della giornata, stati del viaggio, verifica). Il server fa rispettare solo chi può leggere e scrivere cosa.
5. **Ogni servizio esterno sta dietro un'interfaccia interna** — mappe, SMS, tassi di cambio, ingresso da invito. Nessuna schermata parla direttamente con un fornitore ([04](docs/tecnico/04-integrazioni.md)).
6. **Le regole di accesso per riga si scrivono con i loro test.** Sono la vera superficie di sicurezza.
7. **La coda di scrittura è preziosa**: ogni migrazione del database locale deve preservarla, e va provato.
8. **Mai fondere due testi** in un conflitto: si mostrano le due versioni e sceglie la persona.
9. **La grafica viene dalla tela di Claude Design**, "Trolley — design dell'app" (https://claude.ai/artifact/7bMn83Z9KWisT6VC6xxLZz): prima di costruire o cambiare una schermata o un componente la si rilegge e la si segue — colori, font, forme. Lo stile è «Biglietti» (le file con quel nome sulla tela): il biglietto solo per viaggi e idee, il resto schede bianche. Una schermata che la tela non ha ancora si disegna prima lì, nello stesso linguaggio, e poi si costruisce. Nell'app la tela diventa `lib/aspetto/` ([ADR-007](docs/tecnico/adr/007-interfaccia-e-liquid-glass.md)); dialoghi, selettori e interruttori restano componenti di sistema. Ogni animazione passa da `aspetto/movimento.dart`, che rispetta "Riduci movimento".

## Dove si scrive cosa

- Una scelta presa → `docs/decisioni/prodotto.md` (prodotto) o un nuovo ADR in `docs/tecnico/adr/` (tecnica)
- Qualcosa da fare o da misurare → `docs/punti-aperti.md`
- Un'ipotesi con soglia → `docs/discovery/03-ipotesi-da-validare.md`

I documenti sono in italiano, e anche i nomi degli eventi di misurazione.
