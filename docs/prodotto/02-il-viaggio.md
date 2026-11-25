# 02 — Il viaggio

## A cosa serve

Creare il contenitore, farlo passare da intenzione a programma, accompagnarlo e chiuderlo. È l'oggetto attorno a cui ruota tutto il resto dell'app.

---

## Schermate

- **Elenco viaggi** — divisi in *idee*, *in programma*, *in corso*, *conclusi*. L'archivio è una voce a parte
- **Nuovo viaggio** — destinazione, e poi date **oppure** un periodo approssimativo
- **Viaggio** — la schermata principale, che cambia forma a seconda dello stato
- **Completa le date** — il passaggio da idea a definito
- **Riepilogo di chiusura** — cosa è successo, quanto si è speso, cosa si è guadagnato

---

## Regole di comportamento

1. **Per creare un viaggio bastano destinazione e periodo.** Il periodo può essere vago: "agosto", "un weekend di primavera". Quel viaggio nasce nello stato **idea**.
2. **Allo stato idea si possono aggiungere** compagni, posti e note, un budget di massima. Non si possono aggiungere elementi legati a un giorno preciso: itinerario per giornate, documenti agganciati ai giorni, spese.
3. **Il passaggio a definito richiede date di inizio e fine, i giorni, e gli orari di arrivo e partenza.** Da quel momento si sblocca tutto il resto. È un passaggio esplicito, con una schermata sua.
4. **Il viaggio diventa in corso** da solo, alla data di inizio, e **chiuso** alla data di fine. Si può chiudere prima a mano.
5. **Un'idea non scade e non si cancella.** Quando il periodo indicato passa senza che il viaggio sia diventato definito, l'idea va in **archivio**: esce dalla vista principale e resta recuperabile. Se nessun periodo è stato indicato, il termine è 12 mesi dalla creazione.
6. **Prima di archiviare si avvisa** — una volta sola, non ripetutamente.
7. **Un viaggio chiuso è *verificato*** se **tutte** queste condizioni sono vere:
   - **c'è almeno una tappa per ogni giorno** del viaggio;
   - **durante il viaggio l'app è stata aperta con la geolocalizzazione attiva, e la posizione coincideva con la destinazione** — la coincidenza si valuta a livello di città o paese, la posizione non viene conservata, si conserva solo l'esito;
   - **tutte le tappe sono state marcate** come *completata* o *saltata*, **mentre il viaggio era in corso**. Marcare dopo la chiusura non vale.

   Solo i viaggi verificati assegnano i traguardi pieni e contano nelle metriche.
8. **Esiste una deroga amministrativa**, necessaria per poter provare la funzione senza essere davvero in viaggio. Non è raggiungibile dall'app, e i viaggi verificati per deroga sono **contrassegnati e sempre esclusi dalle metriche**: altrimenti la metrica mentirebbe esattamente nel punto in cui deve dire la verità.
9. **Chi nega il permesso di posizione non potrà mai ottenere un viaggio verificato.** Va detto in una schermata, quando il permesso viene negato, non scoperto alla chiusura.
10. **I viaggi passati si possono inserire come ricordo.** Nascono chiusi, sono marcati visibilmente come **importati** e non producono mai traguardi verificati.
11. **Niente si cancella da solo.** Un viaggio chiuso resta per sempre, in qualunque piano, finché chi ci è rimasto da solo non decide di eliminarlo (regola 13).
12. **Il viaggio in corso non viene mai bloccato da un limite commerciale.** Nessuno resta fermo in aeroporto per una questione di abbonamento.
13. **Un viaggio si elimina solo se ci sei soltanto tu** (scelto dall'utente il 26 ottobre 2026). In qualunque stato, anche chiuso, e allora esce dal passaporto e dai traguardi. Si cancella tutto quello che contiene — giorni, tappe, spese, cose da portare, note, inviti, traguardi — e, su questo telefono, i tuoi documenti di quel viaggio. Non si torna indietro: la conferma dice prima, contato, che cosa si perde. Con altri dentro non si elimina, e lo dice: si esce, oppure chi è responsabile toglie prima gli altri. Chi è stato invitato e non è ancora entrato non conta: il suo invito si annulla con il viaggio. Richiede la rete. Per un'idea c'è anche l'archivio, per un viaggio passato «Togli dal passaporto»: restano, e sono da preferire quando non si vuole perdere niente.
14. **Le note del viaggio le scrive e le cambia chiunque ci sia dentro** (chiesto dall'utente il 26 ottobre 2026; tela, 139–142). Una nota è un testo libero — il codice del wifi, il treno delle 15:20 — e la sua prima riga è il titolo. In ogni stato, anche da idea (regola 2). Si leggono senza rete; scriverle, cambiarle ed eliminarle richiedono la rete, perché non sono uno dei quattro gesti che la aspettano. La risposta incollata di un assistente è una nota anche lei (04, regola 11), ma resta com'era: si rilegge, si copia, si elimina. Se due cambiano la stessa nota si mostrano le due versioni: se ne sceglie una, o si tengono tutte e due e la propria diventa una nota in più. Mai fuse.

---

## Casi limite

| Situazione | Comportamento |
|---|---|
| Le date si spostano mentre il viaggio è definito | Si possono cambiare. Le tappe che finiscono fuori dai nuovi giorni vengono mostrate come da ricollocare, non cancellate |
| Il viaggio dura più del previsto | La data di fine si può spostare anche mentre è in corso |
| Si torna indietro da definito a idea | Si può, ma va detto chiaramente cosa si perde di vista: itinerario, documenti agganciati ai giorni e spese restano salvati e tornano se si ridefiniscono le date |
| Un'idea archiviata viene ripresa | Torna nello stato idea. Nessun dato è andato perso |
| Si elimina un viaggio da cui altri sono usciti | Si può: chi è uscito non lo vedeva più. Le sue spese se ne vanno con il viaggio, e la conferma lo dice, perché un saldo aperto con lui sparisce |
| Si elimina un viaggio con cose ancora in coda, fatte senza rete | Prima si mandano; se non partono, la conferma dice che andranno perse |
| Il viaggio è di un solo giorno | È regolare, ed è anzi il caso che l'app vuole incoraggiare. Vale 1,0 punti viaggio |
| Resta una tappa non marcata | Il viaggio si chiude ma non è verificato. È una regola severa per scelta, e per questo l'app ricorda a fine giornata le tappe rimaste da marcare |
| Il permesso di posizione è negato | Il viaggio non potrà essere verificato. Si dice nel momento in cui il permesso viene negato, spiegando a cosa serve |
| La posizione non coincide con la destinazione | Nessuna verifica. Capita a chi cambia programma: è il prezzo di una regola che si fida dei fatti e non delle dichiarazioni |

---

## Cosa resta fuori

- Viaggi ricorrenti o modelli di viaggio da riusare
- Viaggi di gruppo organizzati da un ente, con un organizzatore dai poteri estesi
- Import automatico di un viaggio da una prenotazione o da una email
