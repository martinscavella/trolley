# 06 — Spese

## A cosa serve

Sapere quanto si sta spendendo mentre lo si spende, e alla fine sapere chi deve cosa a chi. È una delle due funzioni che devono essere **alla pari o meglio** di uno strumento specializzato, ed è quella che gli invitati toccano per prima: è lì che si gioca H3.

---

## Schermate

- **Spese del viaggio** — elenco, totale, totale proprio
- **Nuova spesa** — importo, valuta, chi ha pagato, chi partecipa
- **Saldi** — chi deve cosa a chi, con il minor numero possibile di movimenti

---

## Regole di comportamento

1. **Le spese esistono solo nello stato definito.** Allo stato idea c'è un budget di massima, che è un'altra cosa.
2. **Registrare una spesa deve costare due secondi**: importo, e il resto precompilato. Valuta, pagante e partecipanti hanno tutti un valore predefinito sensato.
3. **Chi viaggia da solo usa le spese lo stesso.** In un viaggio con un partecipante solo non si parla mai di dividere: si tiene il conto. Le schermate non mostrano nulla che riguardi la divisione.
4. **La valuta predefinita è quella scelta dalla persona** nelle impostazioni, con l'euro come valore iniziale — non quella della destinazione. Il motivo è pratico: il cambio lo fa spesso la banca al momento del pagamento, quindi la spesa arriva già convertita nella valuta del conto, ed è quella che la persona si ritrova davanti.
5. **Il tasso di cambio arriva da un servizio esterno** e si aggiorna quando c'è rete.
6. **Senza rete si usa l'ultimo tasso noto**, dicendolo esplicitamente: il valore mostrato può essere cambiato, perché non è in tempo reale. L'importo nella valuta originale è il dato vero e non cambia mai.
7. **Le spese funzionano senza rete**, in lettura e in scrittura. Sono nell'insieme essenziale offline.
8. **Una spesa si divide fra i partecipanti scelti**, non necessariamente tutti. Si può dividere in parti uguali o per importi diversi.
9. **I saldi si calcolano riducendo il numero di movimenti**: se tre persone si devono qualcosa a giro, si propone il giro più corto.
10. **Chi esce dal viaggio lascia le sue spese dov'erano.** I saldi restano calcolati come prima: sparire non cancella un debito.
11. **Le spese proprie sono sempre visibili a chi le ha registrate**, in qualunque piano. Le statistiche aggregate sono invece una funzione premium individuale.

---

## Casi limite

| Situazione | Comportamento |
|---|---|
| La stessa spesa registrata da due persone | Non si può impedire, ma si segnala: stesso importo, stessa valuta, a pochi minuti di distanza |
| Il tasso di cambio non è mai stato scaricato per quella valuta | Si registra la spesa nella valuta originale e si mostra la conversione come non disponibile. Non si inventa un tasso |
| Il tasso cambia fra la registrazione e il saldo | Il saldo si calcola sull'ultimo tasso noto, e si dice quale. L'importo originale resta la verità |
| Una spesa viene modificata offline da due persone | Conflitto, si mostrano le due versioni |
| Un partecipante viene rimosso con saldi aperti | Si avvisa chi rimuove prima di procedere. La rimozione non azzera nulla |

---

## Cosa resta fuori

- Pagamenti dentro l'app o collegamento a sistemi di pagamento
- Lettura automatica degli scontrini
- Categorie di spesa con analisi: le statistiche premium restano un riepilogo, non uno strumento di contabilità
