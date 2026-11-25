# 08 — Mappa

## A cosa serve

Vedere dove sono le cose e arrivarci. Trolley non prova a essere una mappa migliore di quelle che esistono: prova a essere **una mappa che sa cosa hai in programma oggi**, ed è una differenza che nessuna app di mappe generica può avere.

---

## Schermate

- **Mappa del giorno** — le tappe di oggi nell'ordine previsto
- **Mappa del viaggio** — tutte le tappe, per giornata
- **Tappa sulla mappa** — dettaglio e navigazione verso quel punto

---

## Regole di comportamento

1. **La mappa mostra le tappe della giornata nell'ordine del programma**, numerate. È questo che la distingue da un elenco di posti salvati.
2. **La navigazione è dentro Trolley, non consegnata ad altri.** Percorso disegnato sulla mappa, indicazioni passo passo, posizione aggiornata in tempo reale mentre ci si muove. Con Google la fa il Navigation SDK, a piedi, in bici e in auto; i mezzi pubblici sono un percorso a passi ([04](04-itinerario.md), regola 37; [ADR-014](../tecnico/adr/014-google-maps-platform.md)). **Un tasto apre Google Maps o Mappe di Apple** per chi preferisce, ma la spinta è restare in Trolley (CR-06).
3. **La posizione della persona si vede sulla mappa** mentre il viaggio è in corso, e in navigazione si aggiorna di continuo.
4. **Da una tappa si può marcare l'arrivo**: completata o saltata, in un tocco, senza tornare all'itinerario. È il gesto da cui dipende la verifica del viaggio, e va reso disponibile dove la persona si trova già.
5. **Toccare una tappa sulla mappa apre la tappa**, con orario, durata e note: la mappa e l'itinerario sono due viste della stessa cosa, non due funzioni separate.
6. **Mappa e navigazione hanno bisogno di rete.** Senza, restano indirizzi e coordinate delle tappe — che sono nell'insieme essenziale — e la possibilità di consegnarli all'app di mappe del telefono, che può avere le proprie mappe scaricate.
7. **La posizione non lascia mai il telefono** per scopi diversi dal mostrare la mappa e guidare chi la sta guardando, **e dalle notifiche localizzate** di chi ha concesso la posizione «sempre» ([09](09-durante-il-viaggio.md), regola 16): solo verso il server e il fornitore di mappe, solo per calcolare un tragitto o cercare locali vicini, arrotondata a circa 100 m, mai salvata e mai nei registri. È una domanda per l'avvocato ([per la revisione](../legale/per-la-revisione.md), 27). Per la modalità città della parte pubblica valgono regole a sé, molto più strette, nel capitolo 11. Per la verifica del viaggio si conserva solo l'esito del confronto con la destinazione, mai la posizione.

8. **Durante il viaggio la mappa si apre su chi la guarda e sulla tappa dopo** (CR-02), con il tragitto disegnato; le altre tappe di oggi più piccole. Due tasti allargano a **tutta la giornata** e a **tutto il viaggio**. Senza la posizione, o prima e dopo il viaggio, si apre sulla giornata come prima.
9. **«Qui vicino»** (CR-03): un elenco di caffè, ristoranti e bar intorno a chi guarda — o intorno a una tappa, dalla tappa —, con la distanza a piedi, aperto o chiuso e fino a che ora. Da uno: «Aggiungilo come tappa» o «Portami lì». **Non compare sulla mappa**: le condizioni europee di Google sembrano vietare nomi e orari dei luoghi su una mappa ([ADR-014](../tecnico/adr/014-google-maps-platform.md), da verificare). Vuole la rete, e senza lo dice.
10. **Gli orari delle tappe** (CR-03): per le tappe dei prossimi sette giorni con un posto, Trolley chiede gli orari di apertura al massimo una volta al giorno; se a quell'ora il posto è chiuso, la tappa lo dice («Chiuso alle 15:00 di lunedì») con le proposte degli orari per spostarla quando è aperto. Non blocca niente.

> **Il costo di questa scelta.** La navigazione in tempo reale ha bisogno di un servizio di mappe e percorsi che si paga **a chiamata**. È il terzo costo variabile del prodotto — dopo gli SMS di verifica e il tasso di cambio — e il primo che cresce con **l'uso** invece che con le registrazioni: una persona che naviga tutto il giorno costa più di dieci che aprono l'app due volte. Per la **fase interna** — solo il team, una decina di persone — i piani gratuiti dei fornitori sono abbondanti e il problema non si pone: la valutazione è rimandata di proposito. Il tetto per utente e per viaggio diventa però un **prerequisito per aprire a persone fuori dal team**, e non qualcosa da aggiungere quando arriva la bolletta.

---

## Casi limite

| Situazione | Comportamento |
|---|---|
| Una tappa non ha una posizione riconoscibile | Resta nell'itinerario ma non sulla mappa, e lo si dice invece di farla sparire |
| Il permesso di posizione è negato | La mappa funziona lo stesso, senza il puntino della persona. Non si insiste e non si blocca niente |
| Due tappe nello stesso posto in giorni diversi | Compaiono entrambe, distinte per giornata |
| Il viaggio è allo stato idea | La mappa mostra i posti dell'elenco idee, senza ordine né giornate |

---

## Cosa resta fuori

- Mappe scaricabili per l'uso senza rete
- Ottimizzazione automatica dell'ordine delle tappe
- Dati propri su luoghi, orari di apertura o recensioni: orari e luoghi vengono dal fornitore di mappe (regole 9 e 10), mai raccolti da noi
