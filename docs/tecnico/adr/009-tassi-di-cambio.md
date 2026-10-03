# ADR-009 — Tassi di cambio: chi li scarica, da dove, come si usano

**Stato**: accettata (fase 1.4, 3 ottobre 2026).

## Contesto

Le spese si registrano nella valuta in cui si pagano e si vedono sommate nella valuta della persona ([06](../../prodotto/06-spese.md), regole 4–6). Serve un tasso di cambio, e il capitolo [04](../04-integrazioni.md) ne fissa i vincoli: un aggiornamento al giorno per le valute in uso, non una chiamata per spesa; senza rete l'ultimo tasso noto, dicendolo; se il servizio smette, la conversione si dichiara non disponibile e **non si inventa mai un tasso**; il fornitore vede quali valute interessano e nient'altro, «non sa a quale persona né per quale viaggio».

## Opzioni considerate

**Chi chiama il fornitore.**
- *Il telefono*, al bisogno. È la via più corta, ma il fornitore vede l'indirizzo di ogni telefono, quando apre l'app e in che valute spende: proprio quello che 04 esclude. In più le chiamate crescono con le persone.
- *Il server*, una volta al giorno per tutte le valute, in una tabella che i telefoni leggono. Il fornitore vede solo il server di Supabase. Le chiamate restano due al giorno con dieci persone o con diecimila. **Scelta.**

**Da dove.**
- *Frankfurter*, i tassi di riferimento della Banca centrale europea: ufficiali, gratuiti, senza chiave. Ma sono circa trenta valute: niente dirham marocchino, dong vietnamita, sterlina egiziana, baht thailandese sì ma non il peso colombiano. Per un'app di viaggi, troppo poche.
- *Open Exchange Rates* e simili: complete, ma con chiave, limiti e un piano a pagamento appena si cresce. È il costo variabile che 04 vuole evitare.
- *fawazahmed0/currency-api*: circa duecento valute, aggiornate ogni giorno, licenza CC0, senza chiave e senza limiti, pubblicata su due indirizzi (jsDelivr e Cloudflare Pages). **Scelta.** Il prezzo è la qualità del dato: è un aggregatore, non una banca centrale. Per dire quanto fa una spesa in euro basta; per una contabilità non basterebbe, e Trolley non lo è (06, "Cosa resta fuori").

## Decisione

**Sul server.** La tabella `tasso_cambio` tiene, per ogni valuta, quanto vale un euro (`per_euro`), il giorno del tasso secondo il fornitore (`del`) e quando è arrivato (`scaricato_il`). La riempie `privato.aggiorna_tassi()`, che prova il primo indirizzo e poi il secondo; se nessuno risponde **non tocca niente**, e restano i tassi di prima con la loro data. Gira con `pg_cron` alle 4 e alle 16 UTC: il fornitore pubblica una volta al giorno, il secondo giro copre un primo andato a vuoto. La chiamata la fa l'estensione `http`. I telefoni leggono la tabella con un accesso; nessuno la scrive dall'app, e la funzione non è chiamabile dall'API (migrazione `20261003090000_spese_e_tassi.sql`, prove in `supabase/tests/spese.sql`).

**Sul telefono.** La tabella è una copia come le altre (`tasso_cambio` nel database locale, [ADR-002](002-persistenza-locale.md)). Si riscarica con la copia del viaggio, ma non più spesso di ogni sei ore (`Archivio.aggiornaTassi`). Da A a B si passa per l'euro: `per_euro(B) / per_euro(A)`, in `dominio/valute.dart`, l'unico posto che converte.

**Nella spesa.** `tasso_usato` è `per_euro` della valuta della spesa al momento in cui la si registra, e `tasso_al` è quando quel tasso è arrivato sul telefono. Riferito all'euro e non alla valuta di chi registra, così vale per tutti i partecipanti, anche con valute diverse. Senza tasso, entrambi vuoti. Sono la memoria di cosa si vedeva quel giorno. **Le somme invece usano sempre l'ultimo tasso noto**, e dicono di quando è (06, casi limite: "il saldo si calcola sull'ultimo tasso noto, e si dice quale").

**Il dato vero** resta l'importo nella valuta originale. Gli importi si tengono in centesimi interi, mai in `double`; la conversione si arrotonda al centesimo solo quando si mostra.

## Conseguenze

- Il fornitore è un responsabile del trattamento solo di nome: non riceve dati personali. Va comunque nell'informativa ([06](../06-privacy-e-conformita.md), "Fornitori").
- Se `fawazahmed0/currency-api` sparisce, si cambiano due indirizzi e il nome del campo nella funzione: l'app non se ne accorge, perché legge solo la tabella. Frankfurter è il ripiego, con meno valute.
- Valute che il fornitore non ha, o un telefono che non ha mai scaricato i tassi: la spesa si registra lo stesso e la conversione si dichiara non disponibile, nel foglio e nel totale.
- Due estensioni in più sul database (`http`, `pg_cron`). Si vedono in Database → Extensions; il lavoro in Integrations → Cron.
