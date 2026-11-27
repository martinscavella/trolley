# ADR-015 — I tragitti: il mezzo nella tappa, i tempi stimati da noi, Google quando si apre

**Stato**: accettata il 27 novembre 2026, con la CR-07 ([decisioni](../../decisioni/prodotto.md#le-richieste-dopo-copenaghen-25-novembre-2026); [04](../../prodotto/04-itinerario.md), regole 34–39; tela, 164, 166–169)

## Contesto

La CR-07 chiede che fra due tappe si veda il tragitto, con il mezzo e quanto dura, e che la giornata avvisi quando lo spazio libero non basta. ADR-014 dice che i tragitti li calcola Google, con le Routes API.

Le pagine di Google sulle Routes API, lette il 27 novembre 2026 ([condizioni](https://developers.google.com/maps/documentation/routes/policies), [Europa](https://developers.google.com/maps/comms/eea/routes), [listino](https://developers.google.com/maps/billing-and-pricing/sku-details/routes)), dicono:

- **Non si conserva niente** oltre al `place_id` (per sempre) e alle coordinate (30 giorni). Durata, distanza, linea e passi di un tragitto non hanno un permesso di conservazione: si usano mentre si mostrano.
- **In Europa** la descrizione e i passi di un percorso non si usano con nessuna mappa; durata, distanza e linea non sono nominate.
- **Il prezzo**: Compute Routes Essentials (a piedi, in bici, in auto senza traffico, i mezzi pubblici) 10 000 gratis al mese per tutta l'app, poi 5 $ ogni 1000; con il traffico è Pro (5000 gratis). I mezzi pubblici danno i passi: la linea, la direzione, la fermata dove salire e dove scendere, l'ora, quante fermate.

La regola 39 del capitolo 04 voleva che l'ultimo tragitto calcolato restasse leggibile senza rete: vuol dire conservarlo, e le condizioni non lo permettono. E mostrare la durata di ogni tragitto della giornata con Google vorrebbe dire chiederli tutti a ogni apertura: una giornata di sei tappe sono cinque chiamate ogni volta, e le 10 000 gratuite sono di tutta l'app.

## Opzioni considerate

1. **Una stima nostra sulla linea del tempo, Google quando si apre il tragitto.** Scelta dall'utente il 27 novembre 2026.
2. **Sempre Google, senza conservare**: tempi esatti ovunque, ma servono la rete e molte chiamate; senza rete la giornata non ha durate.
3. **Google, tenuto sul telefono** come diceva la regola 39: comodo, ma contro le condizioni.

## Decisione

**Il mezzo è un campo della tappa; i tempi della giornata li stima Trolley; il tragitto vero si chiede a Google solo quando lo si apre, e si tiene finché lo si guarda.**

- **Il mezzo sta nella tappa a cui si arriva** (`tappa.mezzo`): è «come ci arrivi», dalla tappa prima dello stesso giorno. Un campo e non una tabella dei tragitti perché il programma è uno solo (04, regola 34) e una tappa ha una sola tappa prima: una tabella `da → a` si romperebbe a ogni tappa spostata, tolta o rimandata. Spostando una tappa il suo mezzo la segue: dice come ci si arriva, e la tappa prima può essere cambiata. Sulla prima tappa del giorno non si vede. Valori: `a_piedi`, `bici`, `mezzi`, `auto`, `monopattino`, `taxi`; `null` è «Come ci vai?». È parte della tappa come l'ora: si sincronizza, fa una versione nuova e due versioni si mostrano come per gli altri campi (02).
- **Il tragitto è fra due tappe vicine nel tempo** della stessa giornata, tolte le saltate: da quella che finisce prima a quella che comincia dopo (`dominio/tragitti.dart`). Due tappe che si sovrappongono non hanno un tragitto fra loro: la giornata le mostra già rosse.
- **La stima** è `distanza in linea d'aria × 1,3` (le strade non sono dritte) diviso la velocità del mezzo, arrotondata ai 5 minuti in su, con un minimo di 5: a piedi 4,5 km/h, bici e monopattino 13, mezzi 15 più 8 minuti di attesa e di strada a piedi, auto e taxi 22 più 3 minuti per partire e parcheggiare. Si calcola sul telefono, dalle coordinate delle due tappe, anche senza rete, e non costa niente. Si scrive sempre «circa». Senza le coordinate di una delle due non c'è stima: si vede il mezzo da solo.
- **Dove si sceglie** (28 novembre 2026, dopo la prova dell'utente): nel foglio della tappa, «Come ci arrivi?» (tela, 170), con i sei mezzi e la loro stima dalla tappa prima del giorno com'è nel foglio — l'ora, il giorno e il posto appena scelti; e durante la guida, dalla scheda in basso (tela, 171–172): a piedi, bici e auto guidano, il monopattino come la bici, il taxi come l'auto; con i mezzi la guida lascia il posto al percorso a passi. Cambiato nella guida, la strada si ricalcola (una destinazione nuova, contata sul tetto) e il mezzo si scrive nella tappa. La pillola sulla giornata si vede soltanto.
- **L'avviso**: se lo spazio libero fra le due tappe è più corto della stima, il tragitto si colora e il foglio della tappa lo dice accanto ai mezzi, ognuno con il suo tempo. Non blocca niente: le regole degli orari (04, 19–30) e la capienza restano quelle.
- **Google quando si apre** (passo 2; da ripensare: la pillola non si tocca più, e il tempo vero lo dice già la guida): toccato un tragitto con la rete, la funzione `mappe` chiede le Routes API (`/mappe/tragitto`, Essentials, senza traffico) per il solo mezzo scelto. Durata e distanza si mostrano nel foglio, con «Google Maps» sotto e senza mappa, finché è aperto; poi si buttano. Si contano sul tetto per persona, viaggio e giorno, come i percorsi. I mezzi pubblici aprono il percorso a passi (tela, 164; passo 3), senza mappa.
- **I mezzi a passi** (passo 3, costruito il 28 novembre 2026; tela, 164): «Portami» su una tappa con i mezzi, o i mezzi scelti nella guida, aprono il percorso coi mezzi pubblici da dove si è. La funzione `mappe` (`/mappe/mezzi`) chiede a Google Compute Routes `TRANSIT` (Essentials) con i soli campi che servono: durata, linea del percorso, e per ogni passo inizio, fine, durata, distanza e i dettagli della linea. Dove si è va a Google arrotondato a circa 100 metri (tre decimali, sul telefono e di nuovo sul server), come deciso per la CR-05, e non si tiene. Il telefono unisce i tratti a piedi, mostra la linea con la fermata, la direzione, le fermate e fra quanto parte, e «Scendi a…»; il passo di adesso è quello la cui strada (da inizio a fine, in linea retta) è più vicina alla posizione, e non torna indietro. «Vedi sulla mappa» mostra solo la linea, senza i passi; sotto i passi, «Google Maps». Si conta sul tetto come una guida (`percorsi`) e in `consumo_mappe.mezzi`. Il percorso si chiede una volta, all'apertura: per ricalcolarlo si riapre.
- **Scegliere il mezzo cambia il programma**: vuole la rete come cambiare una tappa, e senza i mezzi sono spenti con il motivo. Non è uno dei quattro gesti senza rete.

## Conseguenze

- **La regola 39 cambia**: senza rete restano il mezzo e la stima, non l'ultimo tragitto calcolato.
- **La stima può sbagliare**, soprattutto con i mezzi (un cambio, una corsa ogni venti minuti) e in città con un fiume o una collina. Per questo è «circa», e il tragitto vero è a un tocco. Se si vede che sbaglia troppo, si corregge la tabella delle velocità: è un posto solo.
- **Una migrazione** (`tappa.mezzo`, con il suo controllo dei valori), Drift alla versione 14, il prompt dell'assistente che chiede il mezzo (ADR-010) e l'anteprima che lo legge.
- **Costo**: la giornata non chiama nessuno; ogni tragitto aperto con la rete è una chiamata Essentials.
