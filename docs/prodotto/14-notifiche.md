# 14 — Notifiche

## A cosa serve

Ricordarsi di Trolley nei momenti giusti — che su un'app usata poche volte l'anno è metà del problema — senza diventare l'ennesima app che interrompe.

---

## Le notifiche che esistono

| Quando | Cosa dice | Si può spegnere |
|---|---|---|
| Il periodo di un'idea si avvicina | "Questo viaggio è ancora un'idea? Completa le date per sbloccare il resto". **Una volta sola** | Sì |
| Poco prima della partenza | Cosa manca: documenti, cose da portare non spuntate | Sì |
| Qualcuno aggiunge qualcosa al viaggio | Raggruppata, mai una per modifica | Sì |
| C'è un conflitto da risolvere | Solo quando serve una scelta della persona | Sì |
| Un anno dalla chiusura di un viaggio | "Un anno fa eri a Lisbona" | Sì |
| Richiesta di collegamento ricevuta o accettata | — | Sì |
| Messaggio ricevuto da una persona collegata | — | Sì |
| La parte pubblica è disponibile | Una volta, all'uscita della seconda ondata | — |

---

## Regole di comportamento

1. **Nessuna notifica è indispensabile.** L'app funziona per intero anche con tutte spente.
2. **Ogni categoria si spegne separatamente.** Non esiste solo l'interruttore generale.
3. **Le modifiche al viaggio si raggruppano.** Cinque persone che aggiungono cinque spese producono una notifica, non cinque.
4. **Niente notifiche promozionali.** Nessun messaggio esiste per riportare qualcuno nell'app senza avere qualcosa da dirgli.
5. **Il permesso di notifica non si chiede al primo avvio**, ma la prima volta che serve davvero — tipicamente quando si invita qualcuno o si crea il primo viaggio con date.
6. **Si rispettano le ore di silenzio del sistema**, e nessuna notifica non urgente parte di notte.
7. **Una notifica porta sempre a un posto preciso**, mai all'elenco generale.

---

## Casi limite

| Situazione | Comportamento |
|---|---|
| Il permesso è stato negato | Nessuna insistenza. Le stesse informazioni restano visibili dentro l'app |
| Una persona ha quindici idee in archivio | Il sollecito è per idea, ma non più di uno al giorno in tutto |
| Il viaggio è in corso | Solo le notifiche che riguardano quel viaggio. Il resto aspetta |

---

## Cosa resta fuori

- Notifiche in base alla posizione
- Email: nell'MVP si comunica solo dentro l'app e con le notifiche di sistema

---

## Che cosa c'è (16 ottobre 2026)

La prima parte: i promemoria che il telefono si programma da solo, dalla copia, senza server e anche senza rete ([ADR-012](../tecnico/adr/012-notifiche-locali.md); [decisioni](../decisioni/prodotto.md), «Le notifiche, prima parte»).

| Notifica | Quando parte | Dove porta |
|---|---|---|
| Prima di partire | Due giorni prima alle 18, o il giorno prima; solo se manca qualcosa | Prima di partire |
| Tappe da segnare | Alle 21 dei giorni di viaggio con tappe ancora da fare | La giornata |
| Idee che scadono | Alle 10 del giorno in cui compare il sollecito; al massimo una al giorno | L'idea |
| Un anno fa | Alle 10, un anno dopo l'ultimo giorno | Il riepilogo |

Il permesso si chiede la prima volta che un viaggio prende le date, e ogni tipo si spegne dal profilo. Le notifiche che vengono da un altro telefono — novità nei viaggi, conflitti, collegamenti, messaggi, «la parte pubblica è disponibile» — aspettano le push, cioè il programma sviluppatori di Apple ([punti aperti](../punti-aperti.md)).
