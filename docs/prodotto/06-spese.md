# 06 — Spese

## A cosa serve

Sapere quanto si sta spendendo mentre lo si spende, e alla fine sapere chi deve cosa a chi. È una delle due funzioni che devono essere **alla pari o meglio** di uno strumento specializzato, ed è quella che gli invitati toccano per prima: è lì che si gioca H3.

---

## Schermate

- **Spese del viaggio** — elenco, totale, totale proprio
- **Nuova spesa** — importo, valuta, chi ha pagato, chi partecipa
- **Saldi** — chi deve cosa a chi, con il minor numero possibile di movimenti
- **Budget** — quanto si pensava di spendere, e a che punto si è

---

## Regole di comportamento

1. **Le spese esistono solo nello stato definito.** Allo stato idea c'è un budget di massima, che è un'altra cosa.
2. **Registrare una spesa deve costare due secondi**: importo, e il resto precompilato. Valuta, pagante e partecipanti hanno tutti un valore predefinito sensato.
3. **Chi viaggia da solo usa le spese lo stesso.** In un viaggio con un partecipante solo non si parla mai di dividere: si tiene il conto. Le schermate non mostrano nulla che riguardi la divisione.
4. **La valuta predefinita è quella scelta dalla persona** nelle impostazioni, con l'euro come valore iniziale — non quella della destinazione. Il motivo è pratico: il cambio lo fa spesso la banca al momento del pagamento, quindi la spesa arriva già convertita nella valuta del conto, ed è quella che la persona si ritrova davanti.
5. **Il tasso di cambio arriva da un servizio esterno** e si aggiorna quando c'è rete.
6. **Senza rete si usa l'ultimo tasso noto**, dicendolo esplicitamente: il valore mostrato può essere cambiato, perché non è in tempo reale. L'importo nella valuta originale è il dato vero e non cambia mai.
7. **Senza rete si leggono le spese e se ne registrano di nuove.** Modificare o cancellare una spesa già registrata richiede la rete: registrare è il gesto che capita al mercato, correggere è quello che capita la sera in albergo.
8. **Una spesa si divide fra i partecipanti scelti**, non necessariamente tutti. Si può dividere in parti uguali o per importi diversi.
9. **I saldi si calcolano riducendo il numero di movimenti**: se tre persone si devono qualcosa a giro, si propone il giro più corto.
10. **Chi esce dal viaggio lascia le sue spese dov'erano.** I saldi restano calcolati come prima: sparire non cancella un debito.
11. **Le spese proprie sono sempre visibili a chi le ha registrate**, in qualunque piano. Le statistiche aggregate sono invece una funzione premium individuale.

### Il budget

Chiesto dall'utente il 26 ottobre 2026, «per vedere visivamente lo stato attuale delle spese», con un budget del viaggio e uno di ciascuno ([decisioni](../decisioni/prodotto.md#il-budget-26-ottobre-2026)).

12. **Un viaggio può avere un budget**: un importo in una valuta, quanto si pensa di spendere in tutto, insieme. Allo stato idea è il **budget di massima** (regola 1); quando il viaggio prende le date resta, e diventa il metro delle spese. Lo mette e lo cambia chiunque partecipi, come le date; lasciato vuoto, non c'è.
13. **Ognuno può avere anche il suo**, che vede solo lui: quanto vuole spendere della sua parte. Sta solo sul suo telefono, e si mette anche senza rete. In un viaggio in cui si è da soli c'è solo quello del viaggio, perché sarebbe la stessa cosa.
14. **Il budget del viaggio si confronta con il totale delle spese, quello di ciascuno con la propria parte** — non con quello che ha pagato: chi anticipa la cena per tutti non ha speso di più. I rimborsi non contano: chiudono un conto, non sono una spesa.
15. **Si vede a colpo d'occhio.** Una barra di quanto è speso sul budget, con la tacca di **dove si dovrebbe essere oggi**: il budget diviso per i giorni del viaggio, per quelli già cominciati, più le spese fatte prima di partire, che contano tutte subito. Sotto, quanto resta e quanto fa al giorno per i giorni che restano, e una colonna per giorno contro la quota del giorno. Oltre la tacca lo dice; oltre il budget la barra diventa rossa e dice di quanto. Prima di partire mostra quanto fa al giorno; finito il viaggio, com'è andata.
16. **Si mostra nella valuta della persona**, con l'ultimo tasso noto come le spese (regola 6). Se il budget è in un'altra valuta lo si dice; le spese senza tasso restano fuori dal conto, e si dice quante sono.
17. **Si legge senza rete; mettere, cambiare e togliere quello del viaggio la richiedono**, come correggere una spesa (regola 7). Il proprio no: è sul telefono.

---

## Casi limite

| Situazione | Comportamento |
|---|---|
| La stessa spesa registrata da due persone | Non si può impedire, ma si segnala: stesso importo, stessa valuta, a pochi minuti di distanza |
| Il tasso di cambio non è mai stato scaricato per quella valuta | Si registra la spesa nella valuta originale e si mostra la conversione come non disponibile. Non si inventa un tasso |
| Il tasso cambia fra la registrazione e il saldo | Il saldo si calcola sull'ultimo tasso noto, e si dice quale. L'importo originale resta la verità |
| Due persone modificano la stessa spesa insieme, online | Conflitto: si mostrano le due versioni. Sui soldi non si indovina mai |
| Una spesa registrata offline arriva giorni dopo | Entra con la sua data originale, non con quella dell'invio. I saldi si ricalcolano |
| Un partecipante viene rimosso con saldi aperti | Si avvisa chi rimuove prima di procedere. La rimozione non azzera nulla |

---

## Cosa resta fuori

- Pagamenti dentro l'app o collegamento a sistemi di pagamento
- Lettura automatica degli scontrini
- Categorie di spesa con analisi: le statistiche premium restano un riepilogo, non uno strumento di contabilità. Il budget è uno solo per tutto il viaggio, non per categoria
- Avvisi quando ci si avvicina al budget: ci vogliono le notifiche da un altro telefono ([14](14-notifiche.md))
