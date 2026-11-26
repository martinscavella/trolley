# Piano di costruzione

In che ordine si costruisce, e perché quello.

**Il principio**: si parte da ciò che, se non funziona, costringe a rifare tutto il resto. Non da ciò che si vede meglio.

Tre cose in questo progetto hanno quella proprietà — il **deep link differito**, la **sincronizzazione fra più autori** e l'**impianto di sicurezza** — e tutte e tre sono invisibili in una dimostrazione. Sono le prime tre voci del loro blocco.

---

## Fase 0 — Il terreno

Nessuna funzione. Se questa fase va male, le ipotesi cambiano.

| | Cosa | Perché prima |
|---|---|---|
| 0.1 | **Deep link differito**, provato su un'installazione vera dallo store | H3 è l'unico canale di acquisizione e non ha piano B. Si rompe in silenzio, e in sviluppo funziona sempre |
| 0.2 | Scheletro dell'app, backend e schema, copia locale, coda di scrittura (vuota) | È il terreno su cui poggia tutto. Aggiungerlo dopo significa riscrivere le funzioni già fatte |
| 0.3 | Accesso con email, Google e Apple; età | Ogni cosa successiva ha bisogno di sapere chi è la persona |

---

## Fase 1 — Il viaggio da solo

Niente condivisione. Alla fine di questa fase l'app **è già utile a chi viaggia da solo**, e la si può usare internamente per un viaggio vero — che è il primo momento in cui si scopre davvero qualcosa.

| | Cosa |
|---|---|
| 1.1 | Viaggio: stati idea e definito, giorni, capienza della giornata |
| 1.2 | Tappe: durata stimata, ordine, stato *da fare / completata / saltata* |
| 1.3 | Documenti sul dispositivo |
| 1.4 | Spese: valuta predefinita, tasso di cambio, ultimo valore noto offline |
| 1.5 | Cose da portare |
| 1.6 | Esportazione del prompt e ritorno incollato |

---

## Fase 2 — La condivisione

Va fatta **prima** della fase live: aggiungere la scrittura concorrente a funzioni già scritte per un autore solo costa più che prevederla. Con il server autoritativo però è molto meno cara di quanto sarebbe stata — non c'è nessuna riconciliazione fra due database, solo un rifiuto onesto quando si scrive su una versione superata.

| | Cosa |
|---|---|
| 2.1 | Partecipanti, inviti, poteri del creatore |
| 2.2 | Conflitti fra modifiche concorrenti online: versione al salvataggio, rifiuto, schermata di scelta |
| 2.3 | Divisione delle spese e saldi |
| 2.4 | Liste condivise e liste personali |

---

## Fase 3 — Il durante

| | Cosa |
|---|---|
| 3.1 | Schermata "adesso" |
| 3.2 | Mappa, navigazione, marcatura della tappa dalla mappa |
| 3.3 | Sincronizzazione selettiva e preparazione prima della partenza |
| 3.4 | Verifica del viaggio — dipende da 1.2, 3.2 e dal permesso di posizione |

---

## Fase 4 — Il dopo

| | Cosa |
|---|---|
| 4.1 | Chiusura, riepilogo, traguardi |
| 4.2 | Mappamondo e passaporto |
| 4.3 | Viaggi importati, marcati come tali |

### → Ondata 1 della beta

Prima ancora c'è la fase interna: solo il team, su un viaggio vero ([punti aperti](punti-aperti.md), «La conseguenza sul calendario»). Per mettere l'app in mano a persone fuori dal team mancano tre cose da costruire, scritte il 6 ottobre 2026 a 4.3 finita:

| | Cosa | Perché prima di uscire |
|---|---|---|
| U.1 | **I tuoi dati e chiudere l'account**: esportarli in un formato leggibile da una macchina, chiudere l'account dall'app | Sono diritti della persona ([06](tecnico/06-privacy-e-conformita.md)), e lo store non accetta un'app in cui si crea un account e non lo si può chiudere. Si fa per prima perché tocca lo schema: chi sparisce lascia i suoi contributi nei viaggi degli altri |
| U.2 | **Il tetto delle mappe e la chiave del fornitore** | Senza tetto una persona sola consuma i crediti di tutti, e la chiave nell'app la trova chiunque la smonti ([ADR-006](tecnico/adr/006-mappe-e-percorsi.md)) |
| U.3 | **L'informativa e la pagina su cosa si misura**, in bozza per l'avvocato | Lo store chiede l'indirizzo dell'informativa; 06 vuole le scelte confermate da un avvocato prima di aprire fuori dal team |

E le cose che non sono codice: il programma sviluppatori di Apple (senza, niente TestFlight), il deep link differito provato da un'installazione vera (0.1), l'accesso con Google e Apple, il dominio dei link d'invito, le impostazioni di Supabase, la data. Stanno nei [prerequisiti operativi](punti-aperti.md).

---

## Fase 5 — La parte pubblica

| | Cosa |
|---|---|
| 5.1 | **Impianto di sicurezza**: segnalazione, blocco, moderazione, verifica del telefono, condizioni d'uso — 3–4 settimane |
| 5.2 | Valutazioni d'impatto e revisione legale |
| 5.3 | Profilo pubblico e ricerca |
| 5.4 | Collegamenti reciproci e messaggi |
| 5.5 | Presenza in città |

**5.1 viene prima di 5.3, non dopo.** Costruendo prima le funzioni pubbliche si crea la pressione a pubblicarle senza la rete di protezione — e quella pressione vince sempre.

### → Ondata 2, quattro-sei settimane dopo

---

## Le notifiche

Non erano una fase del piano: il capitolo [14](prodotto/14-notifiche.md) si costruisce finita la 5.5, in due parti, perché metà delle notifiche vuole un server che le mandi.

| | Cosa |
|---|---|
| N.1 | **I promemoria programmati dal telefono**: prima di partire, tappe da segnare, idee che scadono, un anno fa. Costruiti il 16 ottobre 2026 ([ADR-012](tecnico/adr/012-notifiche-locali.md)) |
| N.2 | **Le notifiche dal server**: novità nei viaggi, scelte da fare, collegamenti e messaggi. Vogliono il programma sviluppatori di Apple |

---

## Le migliorie grafiche

Non erano una fase del piano: finite le notifiche, l'utente rivede l'app sul telefono e dice dove migliorarla. Ogni miglioria si disegna prima sulla tela, si scrive fra le decisioni e poi si costruisce.

| | Cosa |
|---|---|
| G.1 | **Le sezioni**: una barra sola che resta ferma, con la voce bianca che scivola; il Passaporto come sezione; profilo e impostazioni dall'avatar in alto a destra ([decisioni](decisioni/prodotto.md#le-sezioni-la-barra-e-il-profilo-17-ottobre-2026), [ADR-013](tecnico/adr/013-le-sezioni.md); tela, 122–126). 17 ottobre 2026 |
| G.2 | **Gli orari, eliminare, il budget, la barra col dito**: la giornata come linea del tempo dalle 0 alle 24, con le regole degli orari e delle sovrapposizioni ([04](prodotto/04-itinerario.md), regole 19–30); eliminare un viaggio in cui si è da soli ([02](prodotto/02-il-viaggio.md), regola 13); il budget del viaggio e di ciascuno ([06](prodotto/06-spese.md), regole 12–17); la pillola della barra che segue il dito e la grattata più viva ([decisioni](decisioni/prodotto.md#gli-orari-delle-tappe-e-la-linea-del-tempo-26-ottobre-2026); tela, 127–138). 26 ottobre 2026 |
| G.3 | **Le note scritte a mano, la barra più morbida, il mappamondo nuovo**: una nota del viaggio scritta da sé, che si cambia, con le due versioni ([02](prodotto/02-il-viaggio.md), regola 14); la lente della barra che insegue il dito mentre la barra sta ferma; la Terra sempre a puntini, con il giorno e la notte, con i paesi visti nei colori della loro bandiera che sventola, che si apre sotto le dita a tutto schermo, si avvicina, vola e mostra i viaggi del paese toccato ([decisioni](decisioni/prodotto.md#le-note-scritte-a-mano-la-barra-più-morbida-il-mappamondo-nuovo-1-novembre-2026); tela, 139–151). 1° novembre 2026, il mappamondo rifatto l'8 novembre |

---

## Le richieste dopo Copenaghen

Non erano nel piano: dopo il viaggio a Copenaghen, il 25 novembre 2026, l'utente ha portato otto richieste, decise una per una ([decisioni](decisioni/prodotto.md#le-richieste-dopo-copenaghen-25-novembre-2026)). Si costruiscono in quest'ordine, che segue le dipendenze: Google prima di tutto quello che usa mappe e luoghi, i tragitti prima di «Adesso». Ognuna si disegna prima sulla tela.

| | Cosa |
|---|---|
| CR-04 | **Rimandare una tappa saltata**: «Salta» chiede «Rimandala» o «Saltala e basta» ([04](prodotto/04-itinerario.md), 31–33; tela, 152–155). 25 novembre 2026 |
| CR-06 | **Google al posto di Geoapify**: mappa nativa, ricerca con il `place_id`, guida con il Navigation SDK, tetto unico alle quote gratuite, il rinnovo delle coordinate ([ADR-014](tecnico/adr/014-google-maps-platform.md)). Costruita fra il 26 e il 27 novembre 2026 |
| CR-07 | **I tragitti e i mezzi**: un mezzo per tragitto, scelto dall'assistente o chiesto; il tragitto sulla linea del tempo; i mezzi pubblici a passi ([04](prodotto/04-itinerario.md), 34–39) |
| CR-05 | **Adesso sa quando partire**, la notifica per partire e le notifiche localizzate ([09](prodotto/09-durante-il-viaggio.md), 13–17) |
| CR-02 | **La mappa di dove sei** ([08](prodotto/08-mappa.md), 8) |
| CR-03 | **Qui vicino e gli orari delle tappe** ([08](prodotto/08-mappa.md), 9–10) |
| CR-01 | **La guida**: «Raccontamelo», una scheda scritta da un modello per luogo ([09](prodotto/09-durante-il-viaggio.md), 18) |
| CR-08 | **Il viaggio raccontato**, in stile Wrapped, con le foto del telefono e i traguardi animati ([10](prodotto/10-chiusura-e-ricordo.md), 10–14) |

---

## Fase 6 — Monetizzazione

Non nell'MVP. Si accende quando i numeri di H1 dicono quali funzioni le persone valutano davvero, perché è quello che decide cosa sta dietro il pagamento.

---

## Due regole che attraversano tutte le fasi

**La misurazione non è una fase.** Ogni funzione nasce con il suo evento: una funzione senza evento non è finita, e non passa la revisione. Rincorrere gli eventi alla fine significa scoprire a beta avviata che la soglia non si può calcolare.

**Il funzionamento senza rete non è una fase.** Ogni funzione nasce sapendo da che parte sta: leggibile offline, o uno dei quattro gesti scrivibili, o dipendente dalla rete — e in quest'ultimo caso lo dice prima invece di fallire dopo. Aggiungerlo alla fine vuol dire riscriverla.
