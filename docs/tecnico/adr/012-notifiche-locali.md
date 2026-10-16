# ADR-012 — Le notifiche, prima parte: i promemoria programmati dal telefono

**Stato**: accettata il 16 ottobre 2026, dopo la fase 5.5. L'utente ha scelto di cominciare dalle notifiche locali, che funzionano con l'account Apple gratuito

## Contesto

Il capitolo [14](../../prodotto/14-notifiche.md) elenca otto notifiche. Quattro dipendono da qualcosa che succede sul telefono di un altro (chi entra in un viaggio, una scelta da fare fra due versioni, una richiesta di collegamento, un messaggio) e hanno bisogno di un server che le mandi: notifiche push, APNs, e quindi il programma sviluppatori di Apple, che è rimandato di proposito ([punti aperti](../../punti-aperti.md), prerequisiti). Le altre quattro dipendono solo da quello che il telefono sa già: le date dei viaggi, le tappe ancora da segnare, la valigia, i documenti, il periodo delle idee, i viaggi chiusi.

## Decisione

**Le quattro che il telefono sa calcolare se le programma da solo, dalla copia locale, senza server.**

- **Le regole stanno nel dominio** (`dominio/notifiche.dart`): quali notifiche, a che ora, che cosa dicono, dove portano. Una funzione pura riceve i viaggi e l'ora del telefono e restituisce l'elenco da programmare. Anche le parole stanno lì: una notifica non ha una schermata dove metterle.
- **Il telefono sta dietro un'interfaccia** (`dati/notifiche.dart`, `Notifiche`), come ogni servizio esterno ([04](../04-integrazioni.md)). L'implementazione usa `flutter_local_notifications`; le prove la sostituiscono. Il giorno delle push si aggiunge qui.
- **`dati/promemoria.dart` tiene i promemoria al passo con la copia.** Ascolta le tabelle che contano (viaggi, partecipazioni, giorni, tappe, voci, documenti, traguardi) e, un secondo dopo l'ultimo cambiamento, ricalcola tutto: toglie le notifiche in attesa e programma quelle nuove. Lo rifà quando l'app torna davanti. Una copia che si riscarica, una tappa segnata, una voce spuntata cambiano i promemoria senza che nessuna schermata se ne occupi.
- **Una volta sola** si ottiene ricordando che cosa si era programmato: alla programmazione dopo, quello che è passato è arrivato, e la sua chiave (`prima_di_partire:<viaggio>:<data>`, `idea_che_scade:<viaggio>:<scadenza>`, …) non riparte. Un periodo o una partenza che cambiano fanno una chiave nuova, cioè un promemoria nuovo, com'è giusto. Programmate e arrivate stanno in `impostazione`: nessuna migrazione della copia.
- **L'istante, non l'ora sul quadrante**: si programma in UTC l'istante che corrisponde alle 18 del telefono in quel momento. Se il telefono cambia fuso, la prossima programmazione lo rimette all'ora giusta.
- **Al massimo 60 in attesa**, le più vicine: iOS ne tiene 64. Le altre arrivano con le programmazioni dopo.
- **Il permesso** lo chiede il telefono solo dopo il foglio che dice cosa arriverà (tela, 82). iOS non distingue «mai chiesto» da «negato»: lo ricorda l'app (`notifiche_chieste`).

## Alternative considerate

**Aspettare il programma sviluppatori e fare tutto con le push**, calcolando i promemoria sul server. Un posto solo per tutte le notifiche, ma le regole sarebbero finite sul server, contro la regola che le vuole nell'app in un posto solo; i promemoria non sarebbero partiti senza rete, proprio in viaggio; e intanto nessuna notifica.

**Programmarle una per una nelle schermate** (la spunta di una voce aggiorna il promemoria di Prima di partire, e così via). Meno calcolo, ma ogni gesto che cambia la valigia o le tappe — anche quelli che arrivano con la copia da un altro telefono — avrebbe dovuto ricordarsene. Ricalcolare tutto dalla copia costa pochi millisecondi e non dimentica niente.

## Conseguenze

- I promemoria partono anche senza rete, e niente di quello che dicono esce dal telefono: negli eventi va solo il tipo ([07](../07-misurazione.md)).
- Una notifica dice com'era la copia quando è stata programmata. Se un compagno spunta la crema sul suo telefono e il nostro non apre l'app prima delle 18, «Mancano 3 cose» può essere vecchio di una cosa. Aprendo l'app si corregge.
- Le notifiche che vengono da un altro telefono restano da fare, con il programma sviluppatori ([punti aperti](../../punti-aperti.md), «Rimasto fuori dalle notifiche»).
- Su Android servono il desugaring e i ricevitori del plugin, già nel progetto; non è provato su un telefono Android.
