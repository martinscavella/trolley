# 15 — Misurazione

## A cosa serve

Non è un capitolo accessorio. Non essendoci esperimenti prima di costruire, **la strumentazione è l'unico strumento di verifica rimasto**: ogni soglia delle sette ipotesi deve avere, il giorno del rilascio, un numero che la alimenta. Una funzione che non è misurata è una funzione su cui non si potrà decidere niente.

---

## Regole di comportamento

1. **Ogni evento nasce con la funzione**, non dopo. Una funzione senza il suo evento non è finita.
2. **Si registrano azioni, non contenuti.** Mai il testo di una nota, mai il nome di un documento, mai il contenuto di un messaggio, mai una posizione precisa.
3. **Si misura per rispondere a una domanda già scritta.** Un evento che non serve a una soglia non si registra: costa e non dice niente.
4. **I viaggi importati sono sempre distinguibili** in ogni numero, e non si sommano mai ai viaggi veri.
5. **Le idee si contano a parte** dai viaggi definiti, sempre.
6. **La persona deve poter sapere cosa si misura**, in una pagina leggibile, e poterlo rifiutare senza perdere funzioni.

---

## Cosa si misura, e per quale ipotesi

| Evento | Alimenta |
|---|---|
| Viaggio creato, con stato iniziale (idea o definito) | H2, e il conteggio separato delle idee |
| Passaggio da idea a definito, con il tempo trascorso | Peso della fase decisione |
| Primo elemento aggiunto oltre lo scheletro, con il tempo dalla creazione | **H2** — soglia: >60% entro 7 giorni |
| Quante funzioni diverse sono usate nello stesso viaggio | **H1** — soglia: >50% dei viaggi ne usa almeno 3 |
| Durata del viaggio alla creazione | **H5** — soglia: >30% dei viaggi dura ≤2 giorni |
| Invito generato, installazione da invito, arrivo sul viaggio corretto | **H3** — e la sorveglianza del deep link differito |
| Primo contributo di un invitato | **H3** — soglia: >50% di chi installa |
| Apertura di una schermata senza rete, e quale contenuto risultava mancante | **H4** — soglia: ≥80% delle aperture offline su ≤5 tipi di contenuto |
| Prompt esportato, e ritorno incollato riuscito entro 24 ore | Domanda di itinerario generato — **regola asimmetrica** |
| Incollato non interpretato | Salute del formato — soglia: <10% |
| Viaggio chiuso, e se ha superato la verifica | **North Star**, in punti viaggio |
| Quale delle tre condizioni di verifica è mancata | Serve a capire se la regola è troppo severa e, soprattutto, *dove* si rompe |
| Tappe marcate durante il viaggio, sul totale | La leva su cui agire se quasi nessuno supera la verifica |
| Verifiche concesse per deroga amministrativa | Sempre escluse da ogni altro numero. Si contano solo per sapere quante sono |
| Percentuale di chiusure che **non** superano la verifica | Termometro della regola dei traguardi |
| Apertura dell'app senza viaggi attivi da ≥30 giorni, e da ≥6 mesi | Ritorno fuori stagione |
| Passaporto compilato entro 7 giorni dalla registrazione | Curiosità iniziale — **non** adozione |
| Profilo pubblico attivato | **H7** — soglia: ≥15 su 100 in 6 mesi |
| Richiesta di collegamento inviata, accettata | **H7** — soglia: ≥10 collegamenti reciproci |
| Segnalazioni ricevute e tempo di gestione | Sostenibilità della moderazione |
| Interesse verso un piano a pagamento | **H6** — soglia: >10% degli attivati |
| Conflitti mostrati e come sono stati risolti | Salute della sincronizzazione |

---

## Casi limite

| Situazione | Comportamento |
|---|---|
| La persona rifiuta la misurazione | Si rispetta, e non si perde nessuna funzione. Il numero di chi rifiuta è a sua volta un dato utile |
| Eventi generati offline | Si accodano e partono con la sincronizzazione, con il loro orario originale |
| Un evento non corrisponde più a nessuna soglia | Si toglie. Gli eventi si potano come il codice |

---

## Cosa resta fuori

- Tracciamento pubblicitario o identificatori per la pubblicità
- Registrazione di sessione o mappe di calore
- Qualunque dato che permetta di ricostruire dove una persona è stata, quando
