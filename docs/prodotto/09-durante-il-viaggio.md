# 09 — Durante il viaggio

## A cosa serve

È il momento per cui esiste tutto il resto. Di fretta, con poca rete, poca batteria e zero pazienza: l'app deve rispondere a due domande in un colpo d'occhio — **cosa succede adesso** e **cosa viene dopo**.

---

## Schermate

- **Adesso** — la schermata principale mentre il viaggio è in corso
- **Oggi** — la giornata per intero
- **Domani** — la giornata successiva, per chi la sera guarda avanti

---

## Regole di comportamento

1. **Quando un viaggio è in corso, l'app si apre su quello.** Non sull'elenco dei viaggi.
2. **La schermata "adesso" mostra tre cose**: cosa sta succedendo, cosa viene dopo con quanto manca, e il documento che serve adesso se ce n'è uno agganciato a questo momento.
3. **Senza rete si legge tutto quello che serve adesso**: documenti, programma di oggi e domani, dati base del viaggio, spese già registrate, liste, ultimo tasso di cambio noto.
4. **Senza rete si possono fare quattro gesti**: registrare una spesa, marcare una tappa, spuntare una voce, aggiungere una tappa. Sono quelli che capitano mentre si è in giro.
5. **Tutto il resto richiede rete, e lo dice prima.** Un campo che non si può modificare offline si mostra disabilitato con il motivo: non fallisce dopo che qualcuno ha già scritto.
6. **Il viaggio per intero si può preparare** per l'uso senza rete, e la scelta si chiede prima della partenza — non quando la rete manca già.
7. **Quando manca la rete l'app lo dice una volta e continua a funzionare.** Nessun errore ripetuto.
8. **Quello che si scrive offline parte da solo** al ritorno della rete, senza che nessuno debba premere niente.
9. **Registrare una spesa dalla schermata "adesso" deve costare un tocco più l'importo.**
10. **Marcare una tappa come completata o saltata deve costare un tocco**, dalla schermata "adesso" o dalla mappa. È il gesto da cui dipende la verifica del viaggio: se è nascosto, i traguardi non li prende nessuno.
11. **A fine giornata, se restano tappe non marcate, l'app lo ricorda una volta sola.**
12. **Nessun limite commerciale tocca il viaggio in corso**, mai.

### Dopo Copenaghen

Chieste dall'utente il 25 novembre 2026 ([decisioni](../decisioni/prodotto.md#le-richieste-dopo-copenaghen-25-novembre-2026)), da costruire.

13. **La tappa dopo è imminente quando è ora di partire per arrivarci** (CR-05): il suo inizio, meno il tragitto ([04](04-itinerario.md), regola 34), meno un margine di un quarto d'ora. Allora «Adesso» la mette in grande: «Parti fra 10 min · 25 min a piedi». Prima sta in piccolo, con quanto manca — «Alle 15:00 · fra 3 h 20» — e in cima c'è il tempo libero, non una tappa da fare come se fosse adesso.
14. **Il tragitto si calcola da dove si è**, se il telefono ha la posizione: ricalcolato al massimo ogni dieci minuti, o dopo 300 m. Senza posizione o senza rete vale quello fra le tappe, già calcolato.
15. **«Parti fra 10 minuti» è anche una notifica**, programmata dal telefono dal tragitto previsto: si spegne dal profilo come gli altri promemoria ([14](14-notifiche.md)).
16. **Con la posizione «sempre» partono le notifiche localizzate**: l'ora di partire calcolata da dove si è; l'arrivo a una tappa, entro circa 50 m, con «Segna fatta»; «Sei vicino al Rosenborg · Raccontamelo» vicino a una tappa o a un'attrazione (regola 18); i locali aperti vicino, all'ora dei pasti, se la giornata non ne ha uno. Ognuna si spegne a parte. Senza quel permesso restano quelle programmate (regola 15), e non si insiste. La posizione esce dal telefono solo come dice il capitolo 08, regola 7.
17. **Se con il mezzo scelto non si arriva in tempo**, «Adesso» propone il mezzo più veloce che ci arriva (CR-07). Non cambia niente da sola: il programma non si riorganizza mai da solo.
18. **La guida** (CR-01): entro circa 150 m da una tappa o da un'attrazione nota, «Adesso» mostra «Sei vicino al Rosenborg · Raccontamelo». La scheda — la storia, tre curiosità, cosa guardare, con le fonti — la scrive un modello solo se la si tocca; si legge, o si ascolta con la voce del telefono. Ce n'è una per luogo, per tutti, con «Segnala un errore». Vuole la rete la prima volta; una scheda già aperta si rilegge senza.
19. **«Qui vicino»** sta in «Adesso», nel tempo libero fra una tappa e l'altra ([08](08-mappa.md), regola 9).

---

## Casi limite

| Situazione | Comportamento |
|---|---|
| Non c'è nessuna tappa oggi | La schermata mostra la giornata libera e cosa viene dopo, senza sembrare rotta |
| Il programma è in ritardo rispetto all'orologio | L'app non riorganizza niente da sola e non rimprovera nessuno. Mostra cosa resta |
| Due viaggi in corso contemporaneamente | Si sceglie quale aprire, e la scelta resta fino a fine giornata |
| Il telefono è offline da giorni | Si legge tutto l'essenziale e i quattro gesti continuano a funzionare. I dati dichiarano la propria età: "aggiornato due giorni fa" |
| Al ritorno della rete la coda si svuota | Sono aggiunte e cambi di stato: nessuna richiesta di scelta, nessun conflitto |

---

## Cosa resta fuori

- Riorganizzazione automatica del programma in base ai ritardi
- Notifiche basate sulla posizione **senza** il permesso «sempre»: con quello, sono le quattro della regola 16
- Widget o complicazioni fuori dall'app
