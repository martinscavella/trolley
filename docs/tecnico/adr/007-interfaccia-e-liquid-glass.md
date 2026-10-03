# ADR-007 — Interfaccia: componenti di sistema e Liquid Glass

**Stato**: accettata, rivista il 2026-10-01 (la grafica viene dalla tela di Claude Design) e il 2026-10-02 (stile «Biglietti», niente vetro sui contenuti): sotto, le due revisioni

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

## Revisione del 2026-10-01: la tela di Claude Design

La prima realizzazione di questo ADR aveva inventato un aspetto suo — un altro verde, copertine a sfumature, il carattere di sistema — mentre esisteva già il design dell'app, fatto con Claude Design: la tela **"Trolley — design dell'app"** (https://claude.ai/artifact/7bMn83Z9KWisT6VC6xxLZz). Da qui in avanti:

- **La grafica viene dalla tela.** Prima di costruire o cambiare una schermata la si rilegge e la si segue (CLAUDE.md, regola 9). Una schermata che la tela non ha si disegna prima lì, nello stesso linguaggio, e la si rivede.
- **Il vetro è anche sui contenuti**, come nella tela: pannelli, campi, schede, pulsanti tondi e barra in basso sono vetro chiaro che sfoca e satura le macchie di colore dello sfondo. È vetro disegnato da Flutter (`aspetto/vetro.dart`), uguale su iOS e Android, non quello di sistema.
- **Restano componenti di sistema** i dialoghi, i fogli di azioni, i selettori di data e ora, gli interruttori e i controlli segmentati: su iOS 26 e successivi hanno il Liquid Glass vero.
- **Caratteri della tela dentro l'app**: Bricolage Grotesque per i titoli (variabile, con la dimensione ottica che segue la grandezza) e DM Sans per il testo, con la loro licenza OFL in `app/assets/fonts/`.
- **Solo chiaro**, perché la tela è solo chiara: l'app non segue il tema scuro del telefono finché la tela non lo disegna.
- **Le copertine dei viaggi** sono fatte dei colori della tela finché non arriva la foto della destinazione, che richiede un fornitore di immagini ([punti aperti](../../punti-aperti.md)).

Il resto vale com'era: il movimento passa da `aspetto/movimento.dart` e rispetta "Riduci movimento"; i test girano sul percorso Material con le animazioni spente, e il vetro si guarda sul telefono.

## Revisione del 2026-10-02: lo stile «Biglietti»

Rivedendo la tela, l'utente l'ha trovata "troppo da app standard di iPhone": liste raggruppate, frecce a destra e vetro chiaro su macchie sfocate leggono come un'app di sistema. Ha chiesto un'app moderna e con un carattere, sul modello dello spirito di Duolingo e non della sua lettera. Fra tre direzioni disegnate sulla tela (Sentiero, Biglietti, Audace) ha scelto **Biglietti**, "non tutto letteralmente a biglietto", con l'itinerario "a punti collegati, stile mappa". Le schermate sono sulla tela, nelle file "Biglietti"; la nota verde ne riassume le regole. Da qui in avanti, al posto della revisione precedente:

- **Niente vetro sui contenuti.** Il fondo è un grigio freddo pieno (`#EDEFF3`), i contenuti stanno su schede bianche. Spariscono le macchie sfocate e le copertine a colori: `vetro.dart`, `sfondo.dart` e `copertina.dart` non ci sono più.
- **Colori con un compito ciascuno**: inchiostro (`#15192B`) per il testo e i pulsanti principali; cobalto (`#2B4ACB`) per i viaggi definiti e quello che è attivo; giallo (`#FFCF4A`) solo per le idee; verde (`#1F5F4A`) solo per le tappe fatte; rosso (`#B42318`) per quello che non entra. Sono in `aspetto/tavolozza.dart`.
- **Caratteri**: Unbounded per titoli, codici e numeri (variabile, il peso con `fontVariations`), DM Sans per il testo, con il grassetto aggiunto. Bricolage Grotesque esce dall'app.
- **Il biglietto è per i viaggi e le idee, e basta** (`aspetto/biglietto.dart`): la carta d'imbarco con il codice di tre lettere della destinazione («?» se non c'è) e la matrice con date e persone; l'idea come biglietto giallo. Il resto sono schede pulite, senza dentelli.
- **La barra in basso** è una pillola d'inchiostro che galleggia, con la voce attiva bianca e il "+" giallo (`aspetto/barra.dart`).
- **Il motivo ricorrente è il percorso a punti collegati**: nell'accesso, nel profilo, e con la 1.2 nella giornata, che diventa un percorso di tappe numerate. È uno schema dell'ordine della giornata, non una mappa: la mappa vera arriva con la 3.2.
- **Restano componenti di sistema** i dialoghi, i fogli di azioni, i selettori di data e ora e gli interruttori: su iOS 26 e successivi hanno il Liquid Glass vero, ed è l'unico vetro dell'app.

Il resto vale com'era: il movimento passa da `aspetto/movimento.dart` e rispetta "Riduci movimento"; i test girano sul percorso Material con le animazioni spente; l'aspetto si controlla sul telefono.
