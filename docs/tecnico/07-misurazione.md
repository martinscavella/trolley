# 07 — Misurazione

Non essendoci esperimenti prima di costruire, **questa è l'unica verifica rimasta**. Un evento mancante non è un dato mancante: è una decisione che non si potrà prendere.

---

## Come funziona

1. Gli eventi si scrivono in una **tabella locale**, come tutto il resto. Funziona offline per definizione.
2. Partono a lotti quando c'è rete, con **l'orario in cui sono avvenuti**, non quello in cui sono partiti.
3. Sono **idempotenti**: ogni evento ha un identificativo generato dal client.
4. Se la persona ha rifiutato la misurazione, non si scrivono affatto. Non si scrivono e si scartano dopo: non si scrivono.

---

## Le regole

1. **Azioni, mai contenuti.** Mai il testo di una nota, il nome di un documento, il contenuto di un messaggio, una coordinata.
2. **Ogni evento risponde a una domanda già scritta.** Un evento che non alimenta una soglia non si registra: costa e non dice niente.
3. **Ogni evento nasce con la funzione.** Una funzione senza il suo evento non è finita, e non si considera tale in revisione.
4. **Tre popolazioni sempre distinguibili e sempre escluse** dalle soglie: account **interni** del team, viaggi **importati**, verifiche concesse per **deroga amministrativa**. Una decina di persone che usano l'app tutti i giorni farebbero sembrare vera qualunque ipotesi.
5. **Le idee non si sommano ai viaggi definiti**, mai, in nessun conteggio.
6. **Gli eventi si potano come il codice.** Quando una soglia sparisce, sparisce il suo evento.

---

## Gli eventi, e cosa alimentano

| Evento | Campi oltre ai comuni | Alimenta |
|---|---|---|
| `viaggio_creato` | stato iniziale, durata prevista | H2, H5, conteggio separato delle idee |
| `idea_definita` | giorni trascorsi dalla creazione, durata prevista | Peso della fase decisione; **H5** per i viaggi nati come idee |
| `primo_elemento_aggiunto` | tipo, ore dalla creazione | **H2** — >60% entro 7 giorni |
| `funzione_usata_nel_viaggio` | quale funzione | **H1** — >50% dei viaggi ne usa almeno 3 |
| `invito_creato` · `installazione_da_invito` · `viaggio_corretto_aperto` | — | **H3** e sorveglianza del deep link differito |
| `primo_contributo_invitato` | tipo | **H3** — >50% di chi installa |
| `apertura_senza_rete` | schermata, tipo di contenuto mancante | **H4** — ≥80% su ≤5 tipi |
| `prompt_esportato` · `incollato_riuscito` · `incollato_non_interpretato` | — | Regola asimmetrica sulla generazione |
| `tappa_marcata` | durante il viaggio sì/no | Leva sulla verifica |
| `viaggio_chiuso` | verificato, **quale condizione è mancata**, punti viaggio | **North Star** |
| `apertura_fuori_stagione` | giorni dall'ultimo viaggio attivo | Ritorno fuori stagione, e il taglio oltre i sei mesi |
| `passaporto_compilato` | — | Curiosità iniziale, **non** adozione |
| `profilo_pubblico_attivato` | — | **H7** — ≥15 su 100 in 6 mesi |
| `collegamento_richiesto` · `collegamento_accettato` | — | **H7** — ≥10 reciproci |
| `segnalazione_ricevuta` · `segnalazione_gestita` | ore trascorse | Sostenibilità della moderazione |
| `interesse_piano` | quale piano | **H6** — >10% degli attivati |
| `conflitto_mostrato` · `conflitto_risolto` | tipo di entità, scelta fatta | Salute della sincronizzazione |
| `consumo_mappe` | riquadri, ricerche, percorsi, fermati | Quanto costa una persona che viaggia: il tetto per persona e per viaggio di [ADR-006](adr/006-mappe-e-percorsi.md) |
| `permesso_posizione` | esito | **North Star** — la sorveglianza delle chiusure che non superano la verifica: fra chi non è risultato sul posto, quanti avevano detto no alla posizione |
| `viaggio_preparato` | giorni alla partenza | **H4** — quanti viaggi si preparano per l'uso senza rete prima di partire, e quando: la metà «il resto si scarica su scelta» |
| `dati_esportati` · `account_chiuso` | viaggi cancellati, viaggi lasciati (solo `account_chiuso`) | Salute dei diritti di [06](06-privacy-e-conformita.md): quanti scaricano i dati, quanti se ne vanno e lasciando che cosa |

`installazione_da_invito` e `viaggio_corretto_aperto` portano `via` (`link` o `codice`: quanto lavora il link e quanto il codice digitato); `viaggio_corretto_aperto` porta anche `gia_dentro`, vero quando il link è stato riaperto da chi era già nel viaggio — per la quota del deep link differito contano solo gli arrivi nuovi. Uscire, rimuovere qualcuno e passare il ruolo non hanno un evento: nessuna soglia li chiede (regola 2).

Valori in uso: `primo_elemento_aggiunto.tipo` e `primo_contributo_invitato.tipo` sono `tappa`, `documento`, `spesa` o `voce`; `funzione_usata_nel_viaggio.funzione` è `itinerario`, `documenti`, `spese`, `liste` (le cose da portare: conta aggiungere una voce, spuntarla o prendere una voce del viaggio) o `mappa` (conta vedere la mappa del viaggio con almeno una tappa sopra); `apertura_senza_rete.schermata` è `viaggi`, `viaggio`, `adesso`, `giornata`, `mappa`, `documenti`, `documento`, `spese`, `liste`, `partecipanti`, `prima_di_partire`, `passaporto` o `mappamondo`; `prompt_esportato`, `incollato_riuscito` e `incollato_non_interpretato` portano solo `viaggio_id`: la richiesta conta come esportata quando è negli appunti o è uscita dal foglio di condivisione, e una risposta è riuscita se se ne legge almeno una tappa (i 24 ore della soglia si contano fra i due eventi dello stesso viaggio). Rileggere una nota già salvata non è un nuovo incollato e non si conta; e `mancante` è `viaggio` quando il viaggio non è sul telefono, `contenuto` quando è un viaggio finito di cui il telefono ha solo il biglietto (non lo si è mai aperto lì), `documento` quando il suo file non c'è più, altrimenti vuoto. `conflitto_mostrato.tipo` e `conflitto_risolto.tipo` sono `viaggio` (le date), `tappa`, `spesa` o `voce`; `conflitto_risolto.scelta` è `tua`, `loro` o `entrambe` (solo per le voci). Si contano solo le due versioni mostrate davvero: quando l'altro ha toccato altro, o ha scritto la stessa cosa, si salva senza chiedere e non c'è evento. Un `conflitto_mostrato` senza il suo `conflitto_risolto` è una persona tornata al foglio senza scegliere. Dividere una spesa non ha un evento suo: è dentro registrarla, che già conta per `funzione_usata_nel_viaggio` e `primo_contributo_invitato`. Il rimborso («Li ho ricevuti») non ha eventi e non conta come contributo: chiude un conto, non aggiunge niente al viaggio, e nessuna soglia lo chiede (regola 2). Prendere una voce della lista del viaggio («Chi la porta?», scegliendo sé) conta come primo contributo di chi è stato invitato, con `tipo` `voce`: è il «qualcosa di suo da fare» della lista comune (03, regola 9). Dare una voce a un altro no: il contributo è suo solo se l'ha scelta lui. Spostare una voce da una lista all'altra non ha eventi: la voce c'era già, e aggiungerla l'aveva contata. La schermata «Adesso» non ha un evento suo: i suoi gesti sono quelli di sempre — `tappa_marcata` per «Fatta» e «Salta», gli eventi della spesa e della tappa aggiunta — e si conta quando si apre senza rete. La mappa non ha un evento per i suoi gesti: segnare una tappa da lì o dall'arrivo è `tappa_marcata`, come altrove. `consumo_mappe` porta `viaggio_id` e quante chiamate al fornitore si sono fatte — `riquadri` scaricati davvero (quelli già in memoria non contano), `ricerche`, `percorsi` — e `fermati`, quante il tetto per persona, viaggio e giorno ha fermato prima che arrivassero al fornitore (U.2): è il numero che dice se il tetto è giusto. Si registra quando si chiude la mappa, la navigazione o la ricerca di un posto, se si è chiesto qualcosa. Mai dove, mai cosa si è cercato. Svuotare un giorno o tutto il viaggio non ha un evento, come togliere una tappa: nessuna soglia lo chiede (regola 2). `permesso_posizione` porta `viaggio_id` ed `esito` — `concesso`, `negato` o `non_ora` — e si registra quando la persona risponde alla schermata che dice a cosa serve la posizione (fase 3.4): non quando il telefono lo sa già. Essere sul posto non ha un evento: l'esito sta in `partecipazione.sul_posto_il`, e la chiusura dirà quale condizione è mancata (`viaggio_chiuso`). `viaggio_chiuso` porta `viaggio_id`, `verificato` (per chi ha il telefono: la verifica è di ciascuno), `mancate` — l'elenco delle condizioni mancate fra `una_tappa_per_giorno`, `sul_posto` e `tappe_segnate` —, `punti_viaggio`, `per_deroga`, `a_mano` (chiuso prima della fine da chi è responsabile), `tappe` e `segnate_durante` (la leva della North Star: quante tappe sono state segnate mentre il viaggio era in corso, sul totale). Si registra una volta per persona e per viaggio, quando la chiusura è riuscita. Il passaporto e il mappamondo non hanno un evento loro: sono la cartolina, da costruire e non da misurare come leva di ritorno (decisioni, «Badge e mappamondo digitale»; regola 2), e un evento con i paesi direbbe dove una persona è stata. Si contano solo quando si aprono senza rete; nemmeno grattare un paese nuovo ha un evento, per le stesse ragioni. `passaporto_compilato` si registra a ogni viaggio passato aggiunto (fase 4.3), senza campi oltre ai comuni: mai dove, mai quando. Cambiarlo o toglierlo non ha un evento. Un viaggio passato non è un `viaggio_creato`. `viaggio_preparato` porta `viaggio_id` e `giorni_alla_partenza` (2, 1 o 0, il giorno stesso) e si registra quando la preparazione è riuscita; guardare il giro di controllo, o sistemare da lì una tappa senza posto, non ha un evento suo. `dati_esportati` non ha campi oltre ai comuni e si registra quando il file dei dati è uscito dal foglio di condivisione: chiuderlo senza scegliere non conta (U.1). `account_chiuso` lo scrive il server dentro `chiudi_account`, perché dopo il telefono non ha più nessuno a nome di cui mandarlo: porta `viaggi_cancellati` (quelli in cui si era da soli) e `viaggi_lasciati`, e si scrive solo se sul telefono la misurazione era accesa. Subito dopo tutti gli eventi della persona, questo compreso, passano sotto un id nuovo che non porta al profilo: le soglie restano calcolabili, la persona no ([06](06-privacy-e-conformita.md), «Conservazione»). Quelli di un account interno si cancellano.

Il campo **"quale condizione di verifica è mancata"** è il più importante della tabella. La regola di verifica è severa per scelta, e il rischio probabile è che non la superi quasi nessuno: senza sapere *dove* si rompe, l'unica reazione possibile sarebbe ammorbidirla — che è la reazione sbagliata.

---

## Cosa non si fa

- Nessun identificativo pubblicitario, nessun tracciamento di terze parti
- Nessuna registrazione di sessione, nessuna mappa di calore
- Nessun dato che permetta di ricostruire dove una persona è stata, e quando
