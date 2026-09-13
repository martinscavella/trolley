# 06 — Privacy e conformità

Trolley tratta **documenti d'identità** e **dati che rivelano gli spostamenti di persone fisiche**, e mette in contatto **sconosciuti**. Sono le tre cose che alzano di più il profilo di rischio, e messe insieme non si compensano: questo capitolo non è una formalità di fine progetto.

> Le scelte qui descritte sono ragionate, non certificate. Prima di aprire fuori dal team vanno **confermate da un avvocato**: è il punto del progetto in cui quella spesa si ripaga da sola.

---

## Cosa si tratta, e dove sta

| Dato | Dove | Nota |
|---|---|---|
| Email, data di nascita | Server | Necessari per l'account e per l'età |
| Numero di telefono | Server | Solo per chi attiva la parte pubblica |
| Viaggi, tappe, spese, liste | Server | Rivelano dove una persona è stata e con chi |
| **Documenti d'identità e biglietti** | **Solo telefono** | Non esiste un endpoint che li accetti |
| **Posizione durante la navigazione** | **Solo telefono** | Va al fornitore di mappe mentre si naviga, mai a noi |
| **Posizione per la verifica** | **Solo telefono** | Al server arriva solo l'esito vero/falso |
| Presenza in città | Server | Ricavata dalla destinazione del viaggio, non dalla posizione rilevata. Cancellata a fine viaggio |
| Eventi di misurazione | Server | Azioni, mai contenuti |

**La riga che vale più di tutte le altre**: l'architettura è fatta in modo che i dati più delicati non ci arrivino proprio. Non è una promessa di buona condotta, è un'assenza di strada.

---

## Età

- **16 anni** per l'account. Il GDPR fissa il consenso autonomo per i servizi online a 16, lasciando agli Stati la facoltà di scendere fino a 13 — l'Italia è a 14. Tenere 16 evita la logica per paese e non costa niente su un pubblico di adulti.
- **18 anni** per profilo pubblico, matching e messaggi.
- Data di nascita raccolta alla registrazione, **non modificabile dalla persona**.
- Dichiarazione, non verifica documentale: è la misura proporzionata.
- **Nessuna pubblicità profilata**, a nessuna età.

---

## Conservazione

| Dato | Per quanto |
|---|---|
| Viaggi, anche chiusi | **Finché la persona non li cancella.** Nessuna cancellazione automatica |
| Presenza in città | Fino alla fine del viaggio, poi cancellata |
| Segnalazioni e contenuti segnalati | Il tempo necessario a gestirle, più il periodo utile a difendersi da una contestazione |
| Eventi di misurazione | Aggregati oltre un orizzonte breve: non servono a lungo nel dettaglio |
| Account chiuso | Dati personali cancellati; i contributi nei viaggi altrui restano, attribuiti a un partecipante non più presente |

L'ultima riga va spiegata alla persona **prima** che chiuda l'account: le spese che ha pagato non si cancellano dai saldi altrui, perché sparire non estingue un debito.

---

## Diritti delle persone

- **Esportazione sempre gratuita**, in un formato leggibile da una macchina. È un diritto, non una funzione a pagamento: la reimportazione invece è un servizio e può essere premium.
- **Cancellazione dell'account** raggiungibile dall'app, non solo scrivendo a un indirizzo.
- **Pagina leggibile su cosa si misura**, con la possibilità di rifiutare senza perdere funzioni.

---

## Le due valutazioni d'impatto probabili

Due funzioni, per conto loro, fanno scattare l'obbligo di valutare formalmente l'impatto sulla protezione dei dati:

1. **La presenza in città**, perché mette in relazione persone in base a dove si trovano. È mitigata parecchio dal fatto che la città arriva dalla destinazione del viaggio e non dalla posizione rilevata, e che non esiste storico — ma va scritta, non dedotta.
2. **Il matching fra sconosciuti**, per la combinazione di dati sociali e rischio sulle persone.

Vanno fatte **prima** della seconda ondata, non dopo.

---

## Fornitori

Ogni servizio esterno è un responsabile del trattamento e va nell'informativa: mappe e percorsi, invio SMS, tassi di cambio, e — se scelto — il servizio per il deep link differito.

Il fornitore dei modelli per la generazione dell'itinerario **non è nostro fornitore**: è la persona che porta il prompt sul proprio assistente, con il proprio account. È una delle ragioni per cui l'MVP funziona così.
