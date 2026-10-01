# ADR-007 — Interfaccia: componenti di sistema e Liquid Glass

**Stato**: accettata

## Contesto

La prima versione dell'interfaccia usava i widget Material di Flutter con i valori predefiniti: funzionava, ma su iPhone sembrava un'app di un'altra piattaforma, e non si muoveva. La richiesta è un'app moderna e viva, con il **Liquid Glass di iOS 26 e 27**.

Flutter disegna da sé ogni pixel: non eredita l'aspetto del sistema come fanno le app native. È il limite che [ADR-001](001-stack.md) aveva messo in conto — "meno naturale sulle integrazioni specifiche di sistema" — e il vetro di iOS ne è l'esempio più visibile.

## Opzioni considerate

**Imitare il vetro con uno shader** (per esempio `liquid_glass_widgets`). Uguale su tutte le piattaforme e sotto pieno controllo. Ma non è il vetro di sistema: non segue le impostazioni di accessibilità di iOS (Riduci trasparenza, il livello di trasparenza di iOS 27), invecchia a ogni versione di iOS e porta su Android un aspetto che lì non appartiene.

**Componenti nativi di UIKit dentro Flutter** (`adaptive_platform_ui`). Barra in alto, pulsanti, dialoghi, interruttori e barra delle schede sono componenti di sistema veri su iOS 26 e successivi, con il vetro disegnato da iOS; Cupertino sulle versioni precedenti; Material su Android.

**Nessun vetro**: Cupertino disegnato da Flutter. Semplice, ma è proprio ciò che è stato chiesto di superare.

## Decisione

**Componenti di sistema per lo strato di navigazione, contenuti disegnati da Flutter.**

- **Il vetro sta solo nella navigazione**: barre, pulsanti flottanti, dialoghi, interruttori. È anche quello che chiedono le linee guida di Apple: il Liquid Glass galleggia sopra i contenuti, non li sostituisce.
- **I contenuti sono nostri e uguali ovunque**: copertine dei viaggi, schede, avatar, pannelli con gli angoli continui di iOS. Vivono in `app/lib/aspetto/`.
- **Il movimento è parte del disegno**: entrate scaglionate, pressione con una molla, copertina che vola dalla scheda al dettaglio, sfondo che respira nelle schermate d'ingresso, vibrazioni leggere sui gesti. **Ogni animazione rispetta "Riduci movimento"**, in un punto solo (`aspetto/movimento.dart`).

## Conseguenze

- **Una dipendenza di terzi per la parte nativa.** Il pacchetto è mantenuto e compila con Xcode 27, ma è di una persona sola. Se si fermasse, i suoi widget si sostituiscono uno per uno con quelli Cupertino: i contenuti non ne dipendono.
- **Le viste native costano.** Si usano per la struttura, mai dentro gli elenchi.
- **Su iOS precedenti al 26 non c'è vetro**, per costruzione: lì si vedono i componenti Cupertino classici. È il comportamento voluto, non un difetto.
- **Su Android l'app è Material**, con gli stessi contenuti e lo stesso accento.
- **I test girano sul percorso Material**, con "Riduci movimento" attivo: il vetro si controlla sul telefono, a vista.
- **L'identità visiva resta provvisoria**: un solo colore d'accento, nessun investimento su marchio e nome finché "Trolley" è un nome in codice ([punti aperti](../../punti-aperti.md)).
