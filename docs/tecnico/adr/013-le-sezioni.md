# ADR-013 — Le sezioni: una barra sola, una pila per sezione

**Stato**: accettata il 17 ottobre 2026, con le prime migliorie grafiche ([decisioni](../../decisioni/prodotto.md#le-sezioni-la-barra-e-il-profilo-17-ottobre-2026); tela, 122–126)

## Contesto

Fino alle notifiche la barra in basso la disegnava ogni schermata che la portava (`Pagina.inBasso`): l'elenco dei viaggi, la mappa, Community, il viaggio, «Adesso». Toccare una voce apriva una pagina nuova, che entrava da destra con la sua barra; il profilo entrava senza. Così la barra non poteva animarsi da una voce all'altra, perché erano barre diverse, e cambiare sezione sembrava andare avanti di una pagina, con «Indietro» per tornare.

## Decisione

**Le sezioni stanno in una schermata sola, `SchermataSezioni` (`schermate/sezioni.dart`), che tiene la barra e una pila di pagine per ogni sezione.**

- **Una pila per sezione**: ogni sezione è un `Navigator` suo, con la pagina della sezione in fondo. Una sezione si costruisce la prima volta che la si apre: finché non la si guarda la mappa non chiede riquadri e Community non chiama il server. Poi resta viva, ferma e senza animazioni quando non si vede, e tornandoci la si ritrova com'era.
- **Il passaggio** fra due sezioni è una dissolvenza: quella che arriva sale di pochi punti mentre compare. La barra sta fuori dalle pile, e la pillola bianca scivola dalla voce di prima alla nuova allungandosi sul nome (`aspetto/barra.dart`). Tutto passa da `movimento.dart`: con «Riduci movimento» il cambio è immediato.
- **Chi tiene la barra lo dice la pagina**: le pagine con il mixin `ConLaBarra` (il viaggio, «Adesso», due viaggi in corso, il mappamondo, i traguardi) si aprono nella pila della sezione, sotto la barra. Le altre (le schermate di lavoro, il profilo) si aprono nel navigatore principale, sopra le sezioni: entrano coprendo la barra con il passaggio di sempre, e trascinandole indietro la barra riappare insieme alla pagina di sotto. Lo decide `apri` (`aspetto/piattaforma.dart`). Fogli, menu e pagine a tutto schermo vanno sempre nel navigatore principale, perché un foglio aperto dentro una sezione starebbe sotto la barra.
- **Il viaggio in vista**: una pagina `ConLaBarra` dice quale viaggio mostra (`viaggioInVista`). Toccando «Mappa», la sezione si apre su quello della pagina in cima alla sezione da cui si viene.
- **Da fuori delle sezioni** (un invito, una notifica, un viaggio appena creato, «Guarda il passaporto», uscire da un viaggio) si passa da `SchermataSezioni.aperta`: chiude quello che sta sopra le sezioni e apre la pagina nella sezione giusta. Le pagine del navigatore principale non stanno dentro `SchermataSezioni` e non la trovano risalendo l'albero: ce n'è una sola, e si ricorda. Nelle prove di una schermata sola non c'è, e la pagina si apre come prima.
- **Indietro su Android** chiude la pagina in cima alla sezione; dalla pagina della sezione torna a Viaggi; da Viaggi esce.

## Alternative considerate

**Tutte le pagine nella pila della sezione, con la barra che si nasconde** quando la pagina in cima non la vuole, come `hidesBottomBarWhenPushed` di UIKit. Un posto solo per le pagine, ma la barra avrebbe dovuto seguire a mano il passaggio della pagina, anche mentre la si trascina indietro col dito; e ogni foglio aperto da una sezione sarebbe finito sotto la barra.

**La barra sempre visibile, in ogni pagina**, come nelle app di Apple. Le schermate di lavoro non sono disegnate per averla: i pulsanti in fondo, la tastiera e i fogli si sarebbero scontrati con la pillola.

**Una pagina per sezione nel navigatore principale, con un passaggio senza scorrimento.** Avrebbe tolto la pagina che entra da destra, non la barra che cambia: ogni pagina avrebbe ancora disegnato la sua.

## Conseguenze

- Il codice che apre pagine non cambia: `apri` sceglie la pila. Chi usa `Navigator.of(context)` a mano deve sapere in quale pila si trova.
- Le pagine con la barra lasciano in fondo il suo spazio (`BarraPrincipale.ingombro`); le altre no.
- La mappa vive in due modi: come sezione, sul viaggio scelto, e sopra la barra quando la si apre dalla giornata.
- L'avvio su «Adesso», gli inviti e le notifiche aprono le loro pagine nella sezione Viaggi.
