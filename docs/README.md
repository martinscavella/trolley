# Documentazione — Trolley

> **Trolley è un nome in codice.** Serve a identificare il progetto finché non c'è quello vero.

Un'app mobile che segue un viaggio dall'idea al ritorno, raccogliendo in un posto solo le cose che oggi si fanno su due o tre app diverse: cosa portare, come dividere le spese, l'itinerario, i documenti, dove sono le cose. E, sopra, una parte pubblica dove i viaggiatori si conoscono.

Questa cartella contiene il ragionamento dietro il prodotto, non il prodotto.

---

## In che ordine si legge

| # | Documento | Cosa ci trovi |
|---|---|---|
| 1 | [Visione prodotto](discovery/01-visione-prodotto.md) | Il problema, per chi, la proposta di valore, i vincoli. **Si parte da qui** |
| 2 | [Personas e Jobs To Be Done](discovery/02-personas-e-jtbd.md) | Chi sono le persone, cosa vogliono ottenere, cosa obiettano |
| 3 | [Ipotesi da validare](discovery/03-ipotesi-da-validare.md) | Le sette convinzioni da cui dipende tutto, con le soglie che le confermano o le smentiscono |
| 4 | [Metriche di successo](discovery/04-metriche-di-successo.md) | Come si misura se funziona, e cosa si fa quando non funziona |
| 5 | [Modello di business](discovery/05-modello-di-business.md) | Come genera ricavi, quanto costa, cosa può andare storto |

E accanto, due registri che si aggiornano di continuo:

- [**Decisioni di prodotto**](decisioni/prodotto.md) — le scelte già prese, con il motivo. Non sono ipotesi: non serve un test per autorizzarle
- [**Punti aperti**](punti-aperti.md) — cosa resta da fare o da misurare, e cosa lo chiude
- [**Piano di costruzione**](piano-di-costruzione.md) — in che ordine si costruisce, e perché quello
- [**Glossario**](glossario.md) — i termini che in questi documenti hanno un significato preciso

E la documentazione di costruzione, in corso di scrittura:

- [**Funzionale**](prodotto/README.md) — cosa fa l'app, schermata per schermata e regola per regola
- [**Tecnica**](tecnico/README.md) — come è fatta, più gli ADR

---

## Dove va cosa

La regola che tiene ordinata questa cartella è una sola: **una domanda, una decisione e una misura sono tre cose diverse e stanno in tre posti diversi.**

| | Va in |
|---|---|
| Una convinzione da verificare, con una soglia numerica | `discovery/03-ipotesi-da-validare.md` |
| Una scelta presa, che non ha bisogno di un test | `decisioni/prodotto.md` |
| Qualcosa da costruire, stimare o misurare | `punti-aperti.md` |
| Un termine che va definito una volta sola | `glossario.md` |

Le cartelle `prodotto/` e `tecnico/` sono vuote per ora e aspettano la fase dopo: `prodotto/` le specifiche funzionali e la mappa delle schermate, `tecnico/` l'architettura e gli ADR — quello sullo stack e quello sui dati geografici sono già citati nei documenti di discovery.

---

## A che punto siamo

Discovery **conclusa**: visione, personas, ipotesi, metriche e modello di business sono scritti e coerenti tra loro.

**Non ci sono esperimenti prima di costruire.** Le ipotesi si verificano sui numeri della beta: è un vincolo accettato, e la conseguenza è che **l'app deve misurare dal primo giorno**. La strumentazione è parte della prima release esattamente come le funzioni, perché è l'unico strumento di verifica rimasto.

**Documentazione funzionale e tecnica completa.** `prodotto/` descrive cosa fa l'app, capitolo per capitolo e regola per regola; `tecnico/` come è fatta, con sei decisioni architetturali motivate. Servono a due cose insieme: dare a chi sviluppa una base su cui costruire senza reinventare le regole, e dare a chi guarda il progetto dall'alto la visibilità su cosa fa l'app e come si comporta.

**Da qui si può cominciare a costruire.** Tre cose vanno fatte prima di tutto il resto, e sono scritte in [Punti aperti](punti-aperti.md): il **deep link differito**, perché è l'unico punto da cui dipende la crescita e si rompe in silenzio; la **stima dell'impianto di sicurezza** del matching; e le due **valutazioni d'impatto** prima della seconda ondata.

La prima fase d'uso è interna — solo il team — e i suoi numeri restano fuori da ogni soglia: una decina di persone che usano l'app tutti i giorni farebbero sembrare vera qualunque ipotesi.
