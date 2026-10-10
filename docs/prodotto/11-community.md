# 11 — Community

## A cosa serve

È l'unica cosa che nessuna delle app che Trolley sostituisce ha, ed è anche la meno dimostrata del prodotto: l'ipotesi H7. Esce nella **seconda ondata** della beta, quattro-sei settimane dopo la prima, insieme al suo impianto di sicurezza.

---

## Schermate

- **Profilo pubblico** — passaporto, mappamondo, traguardi di una persona
- **Cerca viaggiatori** — per interessi, mete, affinità di viaggio
- **Collegamenti** — richieste inviate, ricevute, accettate
- **Chi c'è in città** — chi altro sta viaggiando qui adesso
- **Messaggi** — solo fra persone collegate

---

## Regole di comportamento

1. **La parte pubblica richiede 18 anni compiuti e un numero di telefono verificato.** È spenta di default.
2. **Sul profilo pubblico compaiono solo i viaggi chiusi e finiti.** Mai quelli futuri o in corso, in nessuna forma, in nessuna schermata, nemmeno nella ricerca: un viaggio chiuso a mano prima della fine compare dopo la fine. Di ciascuno si vedono la meta, il mese e l'anno, i giorni, e nient'altro — né chi c'era, né tappe, spese, note — e ciascuno si può nascondere dal profilo.
3. **Il collegamento è reciproco**: uno chiede, l'altro accetta, e solo allora esiste. Non esiste il seguito unilaterale: non si accumula un pubblico.
4. **Si può scrivere solo a chi è collegato.** La richiesta di collegamento può portare un messaggio breve, e nient'altro passa prima del sì.
5. **Rifiutare una richiesta non dice niente a chi l'ha mandata**, oltre al fatto che non è stata accettata.
6. **Chi guarda si fa guardare.** La ricerca e i profili degli altri si vedono solo con il proprio profilo pubblico acceso.
7. **Non si cerca una persona per nome**: si cerca per meta e per gusti, e i risultati sono al più trenta.

### Chi c'è in città

8. **La granularità è la città. Mai coordinate, mai distanza, mai un puntino sulla mappa.**
9. **Si attiva esplicitamente per un singolo viaggio**, ed è spenta di default. **Si può accendere solo sul posto**: quando il telefono ha già trovato la persona entro 50 km dalla meta, per quel viaggio (la verifica, 02, regola 7).
10. **Si spegne da sola alla fine del viaggio.** Non resta accesa per dimenticanza.
11. **Si vede solo chi l'ha attivata a sua volta.** Chi guarda è anche visto.
12. **Gli altri vedono che sei in città adesso, non fino a quando.** La data di fine la vede solo chi è in viaggio.
13. **Non esiste nessuno storico.** Non si può sapere dove qualcuno era ieri, né da noi né da chiunque altro.

Le regole 2, 6, 7, 9 e 12 vengono dalle valutazioni d'impatto della fase 5.2 ([decisioni](../decisioni/prodotto.md), «Dopo le valutazioni d'impatto»).

---

## Casi limite

| Situazione | Comportamento |
|---|---|
| Una persona spegne il profilo pubblico | Sparisce dalla ricerca, i collegamenti restano ma diventano inattivi. Riaccendendolo tornano |
| Qualcuno manda molte richieste senza risposta | Non scatta nessun controllo automatico: è lo stesso comportamento di chi segue cento profili privati su un social. Il tasso di accettazione resta un indicatore aggregato di salute |
| Due persone collegate finiscono nello stesso viaggio | Normale, ed è il risultato migliore possibile per questa funzione |
| Si è a Porto, ma il telefono non ha ancora trovato la persona sul posto | La presenza non si accende ancora: «Quando sarai a Porto». Senza il permesso di posizione non si accende mai, e la schermata lo dice |
| In città non c'è nessun altro | È il caso normale con cento utenti in beta. La schermata deve reggerlo senza sembrare rotta |
| Qualcuno chiede di vedere i viaggi futuri di un altro | Non c'è modo di farlo. Non è un'impostazione, è un'assenza |

---

## Cosa resta fuori

- Contenuti pubblici diversi dal profilo: niente bacheca, niente commenti, niente post
- Ricerca per posizione più precisa della città
- Ricerca di una persona per nome
- Gruppi, eventi, viaggi pubblici a cui candidarsi
