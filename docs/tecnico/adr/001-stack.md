# ADR-001 — Stack e piattaforma

**Stato**: accettata

---

## Contesto

Una persona sola, con sei mesi dichiarati su uno scope che ne vale nove. iOS in prima release e Android dichiarato nella visione. Budget vicino a zero.

Quattro vincoli tecnici vengono dal prodotto e non si negoziano:

- **Funziona senza rete** su un sottoinsieme essenziale, con il resto scaricabile a scelta
- **Più persone scrivono lo stesso viaggio**, anche mentre sono offline, e i conflitti vanno mostrati e non fusi in silenzio
- **I documenti stanno sul telefono**, mai su un server
- Le regole di comportamento sono **molte e sottili** — la capienza della giornata, l'insieme essenziale offline, gli stati del viaggio, i poteri del creatore

E un vincolo che viene dal metodo: non c'è validazione prima di costruire, quindi **il prodotto può cambiare parecchio** dopo i primi numeri della beta. Quello che si costruisce va tenuto riscrivibile.

## Opzioni considerate

**Swift / SwiftUI nativo.** Il migliore proprio dove questo prodotto è delicato: file locali, permessi, comportamento senza rete e in background, integrazione di sistema. Ma Android diventa una seconda costruzione, e su una persona sola quella seconda costruzione in pratica non arriva.

**React Native / Expo.** Un solo codice, ecosistema enorme, e la possibilità di aggiornare da remoto senza passare dallo store. Meno solido su file e background, che qui non sono un dettaglio.

**Flutter.** Un solo codice, buon supporto per la persistenza locale, resa uniforme sulle due piattaforme. Meno naturale sulle integrazioni specifiche di sistema.

## Decisione

**Flutter.**

La ragione che pesa più di tutte non è Android: sono le **regole di comportamento**. Sono molte, sono precise, e scritte due volte divergerebbero — non "se", ma "quando". Un solo posto in cui vive la capienza della giornata, la definizione di viaggio verificato e l'insieme essenziale offline vale più della resa nativa sulle schermate.

Android smette di essere una seconda costruzione e diventa rifinitura, il che cambia il significato della riga "Android in fase successiva" nella visione.

## Conseguenze

**Da affrontare per primi, non per ultimi.** I punti in cui Flutter è meno naturale coincidono esattamente con le parti delicate di questo prodotto: archiviazione dei file sul dispositivo, permessi, comportamento in background, notifiche. Vanno risolti all'inizio, quando cambiare idea costa poco.

**Persistenza locale relazionale.** Il modello dati è relazionale — viaggio, partecipanti, tappe, spese, documenti — quindi SQLite, con un livello tipizzato sopra. La scelta della libreria va in un ADR suo, ma la forma è questa.

**Niente archiviazione di file lato server.** Siccome i documenti restano sul telefono, il backend non ha bisogno di object storage: sincronizza testo. È una semplificazione grossa, e restringe la scelta del backend a "autenticazione più database", con Postgres come candidato naturale per somigliare al modello locale.

**Il pezzo rischioso non è lo stack, è il deep link differito.** Far sì che dopo l'installazione si apra il viaggio giusto non è una funzione di Flutter né di iOS: richiede un servizio o una soluzione costruita apposta, e il panorama delle opzioni gratuite si è ristretto negli ultimi anni — va verificato cosa è ancora attivo prima di darlo per scontato. Siccome H3 dipende interamente da quel pezzo, va costruito e provato prima di qualunque funzione.

**Riscrivibile.** Se i numeri della beta dicono che il prodotto è un altro, un solo codice è anche un solo codice da buttare.
