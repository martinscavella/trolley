# ADR-010 — Itinerario incollato: il formato del ritorno, la nota, l'elenco dei modelli

**Stato**: accettata (fase 1.6, 3 ottobre 2026).

## Contesto

Trolley non chiama nessun modello ([04](../../prodotto/04-itinerario.md), regole 7–14; [decisioni](../../decisioni/prodotto.md), "Prompt in uscita, risultato incollato indietro"). Prepara una richiesta, la persona la porta sul suo assistente e incolla la risposta. Il ritorno è la funzione, non l'idraulica: se il testo non rientra, la persona resta a scorrere un muro di testo nell'assistente. Tre vincoli:

- la risposta deve stare **in un blocco di codice**, così che tornare sia un tocco su «Copia» (regola 8);
- la lettura deve essere **tollerante**: chiacchiere intorno, campi mancanti, formattazione approssimativa, e si importa il parziale (regola 10);
- il testo incollato **si salva sempre**, anche quando non si capisce (regola 11), e l'elenco dei modelli consigliati **non sta nel codice** (regola 12).

## Opzioni considerate

**Il formato della risposta.**
- *JSON.* I modelli lo scrivono bene, ma rotto in un punto — una virgola in più, una risposta interrotta — non si legge più niente. E un parziale di JSON non è un parziale di itinerario.
- *Testo libero, interpretato.* Nessun vincolo per l'assistente, ma l'interpretazione diventa un problema di linguaggio, e un'app che non chiama modelli non ha con cosa risolverlo.
- *Una riga per tappa, campi separati da «|», una riga per giorno.* Ogni riga si legge da sola: una sbagliata non trascina le altre, e una risposta interrotta si legge fin dove arriva. È anche come scrivono i modelli quando fanno una tabella. **Scelta.**

**Dove sta l'elenco dei modelli.**
- *Un file sul sito dei link d'invito.* Già pubblicato, ma un altro posto da tenere d'occhio e un'altra strada di rete.
- *Una tabella `configurazione` su Supabase*, letta con la copia del viaggio e tenuta sul telefono. Si cambia dal pannello senza un rilascio. **Scelta.**

## Decisione

**La richiesta** nasce sul telefono, in `dominio/itinerario.dart` (`scriviRichiesta`), da destinazione, giorni con la loro finestra, tappe già in programma, ritmo, interessi e una riga libera. Niente che dica chi è la persona. Chiede un blocco che comincia con `TROLLEY ITINERARIO`, poi `DESTINAZIONE: …`, poi per ogni giorno `GIORNO n · aaaa-mm-gg` e una riga per tappa: `ora | nome | tipo | minuti | zona`. I tipi sono quelli delle tappe (`visita`, `museo`, `pasto`, …).

**La lettura** sta nello stesso file (`leggiItinerario`), perché richiesta e lettura sono le due facce dello stesso formato. Legge i blocchi di codice che sembrano un itinerario, o tutto il testo se non ce ne sono. Riconosce tabelle Markdown, elenchi, grassetti, campi in un altro ordine, tipi in inglese, durate come `90`, `1h30`, `2 ore`, `1,5 h`, e righe senza barre come `10:30 Livraria Lello (visita, 60 min)`. Senza tipo lo ricava dal nome quando non ci sono dubbi («Pranzo al mercato»); senza durata usa quella del tipo. Le righe che sembrano tappe ma non si leggono si contano e si dicono. I giorni si abbinano per data, e se la data non è del viaggio per numero.

**L'anteprima** mostra le tappe giorno per giorno, già scelte nell'ordine finché entrano nella capienza; le altre restano fuori e dicono quanto manca. La regola della capienza non cambia: una giornata che sfora non si aggiunge. Le tappe entrano dalla coda come quelle aggiunte a mano (`aggiungiLeTappe`), quindi anche senza rete.

**La nota.** Prima di leggere, il testo si salva in `nota` (`origine = 'incollata'`), una tabella nuova con le regole di accesso delle altre entità del viaggio. Salvare richiede la rete; per questo **leggere la risposta richiede la rete**, e lo dice prima. Una nota si rilegge quando si vuole, e da lì si aggiungono le tappe.

**La configurazione** è `configurazione (chiave, valore jsonb)`: la legge chi ha un accesso, la scrive solo chi gestisce il progetto. Per ora una sola chiave, `modelli_suggeriti`, un elenco di frasi così come si mostrano. Sul telefono è una copia: senza, la schermata non consiglia nessun modello ma dice comunque che la risposta la scrive un servizio di terzi (migrazione `20261003174945_itinerario_incollato.sql`, prove in `supabase/tests/note.sql`).

## Conseguenze

- Se un assistente smette di rispettare il formato, si vede negli eventi: `incollato_non_interpretato` sopra il 10% vuol dire stringere lo schema ([04-metriche](../../discovery/04-metriche-di-successo.md)). Il testo resta comunque nella nota.
- Cambiare il formato vuol dire cambiare richiesta e lettura insieme, e le prove in `test/dominio/itinerario_test.dart` le tengono d'accordo, compresa quella che incollare la richiesta stessa non aggiunge tappe finte.
- Le note sono la prima metà delle «note» di [02](../../prodotto/02-il-viaggio.md), regola 2: scriverle a mano è un'aggiunta, non un cambio di schema (`origine = 'scritta'`).
- La tabella `configurazione` è il posto per la prossima cosa che deve cambiare senza un rilascio.
