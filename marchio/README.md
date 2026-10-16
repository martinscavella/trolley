# Il marchio

Le sorgenti del marchio approvato, dal kit del 16 ottobre 2026 ([decisioni](../docs/decisioni/prodotto.md#il-marchio-logo-icona-e-avvio-16-ottobre-2026)). Nell'app non servono questi file: il logo, l'avvio animato e la valigia che aspetta li disegna in vettoriale il pacchetto `app/packages/trolley_brand`, e le schermate lo usano da `app/lib/aspetto/marchio.dart`. Le icone dell'app sono già in `app/ios/Runner/Assets.xcassets/AppIcon.appiconset` e in `app/android/app/src/main/res`.

## Cosa c'è

- `brand/`: il logo completo (`trolley-logo-*`) e il simbolo da solo (`trolley-symbol-*`), blu e bianchi, in SVG e PNG trasparenti; `palette.json`.
- `icons/`: l'icona quadrata dell'app, sorgente SVG e PNG da 1024 × 1024, senza trasparenza e senza angoli arrotondati (li mette il sistema). È quella che chiede l'App Store.

## Come si usa

- **Il simbolo** per l'icona e per gli spazi piccoli; **il logo completo** dove il nome deve leggersi: intestazioni, schermata iniziale.
- **La versione bianca** sta sul blu o sullo scuro.
- Si mantengono le proporzioni, e alla scritta non si aggiungono altri caratteri.

## I colori

| Nome | Colore | Dove |
|---|---|---|
| Blu del marchio | `#3049D3` | Logo, simbolo, fondo dell'icona |
| Blu del percorso | `#7185E5` | Il tratto che si disegna nell'avvio animato |
| Bianco | `#FFFFFF` | Il logo sul blu, il fondo dell'avvio |

Il blu del marchio è appena diverso dal cobalto della tela, `#2B4ACB`: se allinearli è ancora da decidere ([punti aperti](../docs/punti-aperti.md#rimasto-fuori-dal-marchio)).
