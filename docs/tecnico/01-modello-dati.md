# 01 — Modello dati

Le entità, le loro regole, e cosa si sincronizza. È il capitolo da cui dipende ogni altro: una regola scritta qui vale ovunque, una regola scritta solo in una schermata è già persa.

Convenzione: ogni entità sincronizzata ha `id` (UUID generato dal client), `creato_da`, `creato_il`, `modificato_il`, `eliminato_il`. Si cancella marcando, mai togliendo la riga — altrimenti una cancellazione fatta offline non sa come propagarsi.

---

## Persone

### `utente`

| Campo | Note |
|---|---|
| `email` | Unica. Le tre strade d'accesso — email, Google, Apple — portano allo stesso utente |
| `data_nascita` | Obbligatoria. Non modificabile dall'utente |
| `telefono_verificato` | Necessario per la parte pubblica. Un numero, un account |
| `valuta_predefinita` | Iniziale: EUR |
| `profilo_pubblico_attivo` | Falso di default |
| `interno` | Account del team. **Escluso da ogni metrica** |

**Invarianti**
- Sotto i 16 anni non esiste un utente.
- Sotto i 18 anni `profilo_pubblico_attivo` non può essere vero, e i collegamenti non esistono.
- `profilo_pubblico_attivo` vero richiede `telefono_verificato` vero.

---

## Il viaggio

### `viaggio`

| Campo | Note |
|---|---|
| `stato` | `idea` · `definito` · `in_corso` · `chiuso` · `archiviato` |
| `destinazione_citta`, `destinazione_paese` | Servono al mappamondo e alla verifica |
| `periodo_approssimativo` | Testo libero. Solo allo stato idea |
| `data_inizio`, `data_fine` | Obbligatorie dallo stato definito in poi |
| `ora_arrivo`, `ora_partenza` | Definiscono la finestra del primo e dell'ultimo giorno |
| `creatore_id` | Uno solo, sempre presente |
| `importato` | Viaggio passato inserito come ricordo |
| `verificato`, `verifica_per_deroga` | Calcolati alla chiusura, mai dichiarati |

**Invarianti**
1. `idea` ⇒ nessun giorno, nessuna tappa, nessuna spesa, nessun documento.
2. `definito` e oltre ⇒ `data_inizio`, `data_fine`, `ora_arrivo`, `ora_partenza` tutte presenti.
3. Esiste sempre esattamente **un** creatore attivo. Se il creatore esce, deve prima passare il ruolo.
4. `importato` ⇒ `stato = chiuso` e `verificato = falso`, sempre.
5. `verifica_per_deroga` vero ⇒ escluso da ogni metrica.

### `giorno`

Generato quando il viaggio diventa definito, uno per data.

| Campo | Note |
|---|---|
| `data` | |
| `finestra_inizio`, `finestra_fine` | Primo giorno: da `ora_arrivo`. Ultimo: fino a `ora_partenza`. In mezzo: giornata intera |

La capienza di un giorno è `finestra_fine − finestra_inizio`. **Non tiene conto degli spostamenti fra una tappa e l'altra**: è una semplificazione dichiarata, non una svista.

### `tappa`

| Campo | Note |
|---|---|
| `giorno_id`, `ordine` | |
| `titolo`, `luogo_nome`, `lat`, `lon` | Senza coordinate la tappa esiste ma non compare sulla mappa |
| `durata_stimata_min` | Precompilata, sempre modificabile |
| `ora_inizio` | Opzionale |
| `stato` | `da_fare` · `completata` · `saltata` |
| `marcata_il`, `marcata_durante_il_viaggio` | Il secondo è ciò che conta per la verifica |

**Invariante**: la somma delle `durata_stimata_min` delle tappe di un giorno non supera la capienza di quel giorno. È l'unica regola dell'app che **rifiuta** un inserimento.

### `partecipazione`

| Campo | Note |
|---|---|
| `viaggio_id`, `utente_id` | |
| `ruolo` | `creatore` · `partecipante` |
| `stato` | `invitato` · `attivo` · `uscito` · `rimosso` |

**Invarianti**
- Solo il creatore può portare un `attivo` a `rimosso`.
- Chi passa a `uscito` o `rimosso` **non perde i propri contributi**: spese, tappe e voci restano attribuite a lui.

### `invito`

`viaggio_id`, `token`, `creato_da`. Il token è un link, non una credenziale: chi lo riceve entra, e chi invita lo sa.

---

## Spese

### `spesa`

| Campo | Note |
|---|---|
| `importo`, `valuta` | L'importo nella valuta originale è **il dato vero**, e non cambia mai |
| `tasso_usato`, `tasso_al` | Il tasso applicato e quando è stato recuperato. Si conserva perché una conversione senza la sua data è una bugia |
| `pagante_id` | |
| `data`, `descrizione` | |

### `spesa_quota`

`spesa_id`, `utente_id`, `quota`. In un viaggio con un solo partecipante non esistono quote: la spesa si registra e basta, e nessuna schermata parla di dividere.

---

## Liste, documenti, ricordo

### `voce_lista`

`viaggio_id`, `testo`, `tipo` (`viaggio` · `personale`), `proprietario_id`, `assegnato_a`, `spuntata`.

**Invariante**: una voce `personale` è visibile **solo** al suo proprietario. Non sincronizza verso gli altri partecipanti, nemmeno verso il creatore.

### `documento` — locale, mai sincronizzato

`viaggio_id`, `giorno_id`, `nome`, `percorso_locale`, `proprietario_id`.

**Invariante**: nessun percorso di codice invia questa entità o il file a cui punta. Non ha `id` condiviso perché non esiste per nessun altro.

### `traguardo` e `luogo_visitato`

`traguardo`: `utente_id`, `tipo`, `viaggio_id`. Assegnato solo da viaggi verificati.
`luogo_visitato`: `utente_id`, `paese`, `citta`, `prima_volta_il`. Alimentato da **qualunque** viaggio chiuso, importati compresi — è il ricordo, non il merito.

---

## Parte pubblica

| Entità | Campi |
|---|---|
| `collegamento` | `da_utente`, `a_utente`, `stato` (`richiesto` · `accettato` · `rifiutato`) |
| `messaggio` | `collegamento_id`, `da_utente`, `testo`. Esiste solo se il collegamento è `accettato` |
| `blocco` | `da_utente`, `a_utente`. Effetto **bidirezionale** |
| `segnalazione` | `da_utente`, `tipo_oggetto`, `oggetto_id`, `motivo`, `stato` |
| `presenza_citta` | `utente_id`, `viaggio_id`, `citta`, `attiva_fino`. Mai coordinate, mai storico |

**Invarianti**
- Un viaggio con stato diverso da `chiuso` non è raggiungibile da nessuna query della parte pubblica.
- `presenza_citta` si cancella alla fine del viaggio. Non si archivia: si cancella.
- Un `blocco` rende invisibili entrambi all'altro, in ricerca, profili e messaggi.

---

## Dove vive ogni entità

Il server è l'autorità. In locale c'è una **copia di lettura**, una **coda** per quattro gesti, e i documenti che non sono una copia di niente.

| Entità | Copia locale | Scrivibile offline |
|---|---|---|
| `utente`, `partecipazione` | ✅ | ❌ |
| `viaggio`, `giorno` | ✅ viaggi attivi | ❌ |
| `tappa` | ✅ oggi e domani; tutto su richiesta | ✅ **aggiungere** e **marcare**. Modificare no |
| `spesa` | ✅ | ✅ **registrare**. Modificare no |
| `spesa_quota` | ✅ | ❌ |
| `voce_lista` tipo `viaggio` | ✅ | ✅ **spuntare**. Modificare il testo no |
| `voce_lista` tipo `personale` | ✅ | ✅ **spuntare** |
| `documento` | **non è una copia: esiste solo qui** | ✅ sempre, per definizione |
| `tasso_cambio` (ultimo noto) | ✅ | — sola lettura |
| `traguardo`, `luogo_visitato` | ✅ | ❌ |
| parte pubblica | ❌ richiede rete | ❌ |
| `evento` di misurazione | coda locale | ✅ accodato |

**La colonna che conta è la seconda.** Quattro gesti, tutti aggiunte o cambi di stato ripetibili: è la ragione per cui non serve nessuna macchina dei conflitti offline. Se in beta **H4** dicesse che le persone provano a fare offline cose che qui non si possono fare, questa colonna si allarga — e solo allora si paga il prezzo che oggi si è evitato.
