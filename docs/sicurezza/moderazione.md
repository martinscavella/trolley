# Il processo di moderazione

Chi guarda le segnalazioni, entro quanto, che cosa fa, e che cosa si fa quando arriva più di quanto si riesce a gestire ([12](../prodotto/12-sicurezza-e-moderazione.md), regola 8). È scritto per **una persona sola**: è un vincolo di progetto, non una mancanza.

Le regole che si fanno rispettare sono le [condizioni d'uso](../../sito/condizioni.html), numerate: una sospensione cita la regola.

---

## Chi, e con che cosa

- **Chi modera** è una persona del team con l'accesso al progetto Supabase `trolley-db`, protetto dalla verifica in due passaggi. È l'unico accesso agli strumenti: non stanno nell'app né nelle funzioni del server ([05](../tecnico/05-community-e-sicurezza.md), regola 5).
- **Lo strumento** è lo schema `moderazione` (migrazione `sicurezza`), che l'API non raggiunge. Si usa dall'editor SQL di Supabase; conviene salvare le cinque righe qui sotto come snippet.

```sql
-- La coda: prima i minori e le molestie, poi chi è segnalato da più persone, poi la più vecchia.
select * from moderazione.coda;

-- Archiviare: non c'è una violazione. Chi ha segnalato lo vede gestito.
select moderazione.archivia('<id della segnalazione>', 'nota per chi modera, facoltativa');

-- Sospendere il profilo pubblico. Il motivo lo legge la persona sospesa: la regola, mai chi l'ha segnalata.
-- Chiude tutte le segnalazioni aperte su di lei.
select moderazione.sospendi('<id>', 'Condizioni d''uso, regola 2: messaggi molesti.', 'nota interna');

-- Togliere la sospensione (un errore, un ricorso accolto).
select moderazione.riattiva('<id della persona>');

-- Chiudere la parte pubblica ai nuovi, riaprirla, chiuderla del tutto.
select moderazione.parte_pubblica('chiusa_ai_nuovi');  -- 'aperta', 'chiusa'
```

La coda mostra, per ogni segnalazione: la priorità, il motivo, da quanto aspetta, chi è segnalato e se è già sospeso, **da quante persone** è segnalato adesso, quante sospensioni ha avuto, quante segnalazioni di chi segnala sono state archiviate, la nota e il **contenuto com'era** quando è stato segnalato.

---

## Entro quanto

| Priorità | Motivo | Si guarda entro |
|---|---|---|
| 1 | Potrebbe avere meno di 18 anni · Messaggi molesti o minacce | **24 ore** |
| 2 | Profilo falso · Contenuti inappropriati | 72 ore |
| 3 | Altro | 72 ore |

La coda si apre **ogni giorno**, anche quando è vuota: con la parte pubblica aperta non esiste un giorno senza moderazione. Se chi modera non c'è per più di un giorno, prima di andare **chiude la parte pubblica ai nuovi**, e la riapre al ritorno.

I tempi sono una prima stima: li corregge l'evento `segnalazione_gestita`, che porta le ore passate ([07](../tecnico/07-misurazione.md), «Sostenibilità della moderazione»).

---

## Che cosa si fa

Per ogni segnalazione, dall'alto della coda:

1. **Si legge il contenuto conservato**, non quello di adesso: può essere stato cambiato o cancellato.
2. **Si confronta con le condizioni d'uso.** Se non viola una regola scritta, si **archivia**, anche se è antipatico: una regola non scritta non si applica (12, regola 7).
3. **Se viola una regola**, si **sospende** il profilo pubblico, citando la regola nel motivo. Il motivo è breve, e non dice chi ha segnalato né che cosa ha scritto.
4. Un messaggio che viola le regole si toglierà con la terza azione, che arriva con i messaggi (5.4).

Segnalazioni dalla stessa persona contro la stessa persona contano una volta: «da quante persone» conta le persone, non le segnalazioni.

### Casi che non si decidono sul momento

| Caso | Che cosa si fa |
|---|---|
| **Un possibile reato** (minacce gravi, violenza, sfruttamento, un minore in pericolo) | Si sospende subito. **Non si cancella niente**: il contenuto conservato è la prova. Non si contatta chi è segnalato. Si risponde alle autorità solo su richiesta formale *[da confermare con l'avvocato: [per la revisione](../legale/per-la-revisione.md)]*. Chi ha segnalato, se è in pericolo, deve chiamare il 112: lo dice l'app |
| **Un possibile minore** | Si sospende: la parte pubblica è dai 18 anni (regola 6). La data di nascita è dichiarata, non verificata: se la persona scrive che è un errore, si decide con quello che scrive *[da confermare]* |
| **Chi segnala a vuoto**, con molte segnalazioni archiviate | È a sua volta una violazione (regola 8). Dalla terza archiviata si guardano le sue segnalazioni insieme, e se sono pretesti si sospende chi segnala |
| **Una persona già sospesa, segnalata di nuovo** | Le segnalazioni restano in coda: se riattivata, contano |
| **Una persona segnalata è in un viaggio con chi l'ha segnalata** | Il blocco e la sospensione valgono per la parte pubblica; dentro il viaggio la toglie chi ne è responsabile (12, casi limite) |

---

## Quando arriva più di quanto si riesce a gestire

Meglio una funzione sospesa che una non sorvegliata (12, casi limite).

- **Una segnalazione di priorità 1 aspetta più di 24 ore**, o le segnalazioni aperte sono più di quelle che si guardano in un giorno: `moderazione.parte_pubblica('chiusa_ai_nuovi')`. Chi c'è resta, e chi aveva spento il profilo lo riaccende; i nuovi aspettano, e l'app lo dice.
- **Anche così non basta**: `moderazione.parte_pubblica('chiusa')`. Nel profilo la parte pubblica sparisce per tutti, tranne il team.
- Si riapre quando la coda è tornata dentro i tempi.

---

## Se qualcuno pensa che sia un errore

Scrive al contatto della moderazione, che sta nelle condizioni d'uso e nell'app (`contatto_moderazione` in `configurazione`). Si risponde entro una settimana. Se la sospensione era sbagliata: `moderazione.riattiva`.

*[Il contatto non c'è ancora: punti aperti, «Rimasto fuori dalla 5.1».]*
