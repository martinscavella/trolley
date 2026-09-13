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
| `idea_definita` | giorni trascorsi dalla creazione | Peso della fase decisione |
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

Il campo **"quale condizione di verifica è mancata"** è il più importante della tabella. La regola di verifica è severa per scelta, e il rischio probabile è che non la superi quasi nessuno: senza sapere *dove* si rompe, l'unica reazione possibile sarebbe ammorbidirla — che è la reazione sbagliata.

---

## Cosa non si fa

- Nessun identificativo pubblicitario, nessun tracciamento di terze parti
- Nessuna registrazione di sessione, nessuna mappa di calore
- Nessun dato che permetta di ricostruire dove una persona è stata, e quando
