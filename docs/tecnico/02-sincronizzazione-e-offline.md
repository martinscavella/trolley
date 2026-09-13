# 02 — Copia locale, coda e conflitti

Tre meccanismi separati, ognuno con un problema suo. Tenerli distinti è metà del lavoro: confonderli è come si finisce a costruire un sistema di sincronizzazione bidirezionale senza essersene accorti.

---

## 1. La copia locale

Serve a **leggere senza rete**. È una copia: si può cancellare e riscaricare senza che nessuno perda niente.

| Cosa | Quando si aggiorna |
|---|---|
| Viaggi attivi, partecipanti, giorni e tappe | All'apertura dell'app e all'apertura del viaggio |
| Spese e liste del viaggio attivo | Idem |
| Ultimo tasso di cambio per le valute in uso | Una volta al giorno |
| **Tutto il viaggio corrente, per intero** | Su richiesta esplicita: "prepara per l'uso senza rete", nella schermata di preparazione alla partenza |

**Cosa non entra nella copia**: viaggi passati, parte pubblica, ricerca. Si aprono con la rete.

**La preparazione si chiede prima della partenza, non quando la rete manca già.** È il momento in cui la persona sta già controllando di non dimenticare niente, e una riga in più in quella lista costa zero attenzione.

Ogni riga della copia porta **quando è stata scaricata**. Serve per dire "aggiornato due giorni fa" invece di far credere che sia fresca.

---

## 2. La coda di scrittura

Quattro operazioni, e nessun'altra: **registrare una spesa**, **marcare una tappa**, **spuntare una voce**, **aggiungere una tappa**.

| Proprietà | Perché |
|---|---|
| **Persistente** | Sopravvive alla chiusura dell'app e al riavvio. È l'unico dato che esiste solo in locale: se si perde, si perde davvero |
| **Idempotente** | Ogni operazione ha un identificativo generato dal client. Rimandarla non la applica due volte, e serve perché *"non ho ricevuto risposta"* non significa *"non è arrivato"* |
| **Ordinata per viaggio** | Aggiungere una tappa e poi marcarla non può arrivare al contrario |
| **Non bloccante** | Un'operazione che fallisce ripetutamente si mette da parte e si segnala, senza fermare quelle dietro |

**Il gesto riesce subito.** Si scrive in locale, si mette in coda, e l'interfaccia si comporta come se fosse fatto — perché è fatto. Nessuna rotellina, nessuna conferma dal server.

### Perché questi quattro non confliggono

- **Registrare una spesa** e **aggiungere una tappa** sono aggiunte: due persone che le fanno insieme producono due spese e due tappe, non un conflitto.
- **Spuntare una voce** è ripetibile: spuntato è spuntato, chiunque l'abbia fatto.
- **Marcare una tappa** ha un solo caso di scontro — uno mette `completata`, l'altro `saltata`. Vince l'ultima che arriva e non si chiede niente a nessuno: entrambe contano come *marcata*, quindi la **verifica del viaggio non cambia** e la differenza è cosmetica.

L'unico caso da gestire davvero: **una tappa aggiunta offline che sfora la capienza del giorno**, perché nel frattempo qualcun altro ne ha aggiunte. Il controllo si rifà al momento dell'invio; se sfora, la tappa entra comunque ma **segnalata come eccedente**, e si chiede cosa togliere. Rifiutarla dopo che la persona l'ha vista nella sua app per due giorni sarebbe peggio.

---

## 3. I conflitti — e adesso sono un problema piccolo

Un conflitto nasce quando **due persone modificano la stessa cosa mentre sono entrambe online**. È l'unico caso rimasto, perché offline si può solo aggiungere.

Si risolve con un **controllo di versione al salvataggio**: si invia la modifica insieme alla versione su cui è stata fatta. Se il server è andato avanti, rifiuta e restituisce la versione corrente.

A quel punto:

1. **Si mostrano le due versioni affiancate**, con chi ha scritto e quando — il diff.
2. **Si sceglie una, o si tengono entrambe** dove ha senso.
3. **Non si blocca niente**: finché non si sceglie resta visibile quello che si stava scrivendo.
4. **Non si fondono mai due testi.** Unire due frasi produce una terza frase che nessuno ha scritto.

Quali entità possono generarlo: campi di testo, importi, date, durate. Tutte cose che ora **richiedono rete comunque**, il che riduce parecchio la finestra in cui due persone si pestano i piedi.

---

## Casi che si scoprono tardi

| Situazione | Comportamento |
|---|---|
| Offline per giorni, poi rete | La coda si svuota in ordine. Sono aggiunte: nessuna richiesta di scelta |
| App chiusa a metà invio | La coda è persistente e riprende. Le operazioni sono idempotenti: ripartire non duplica |
| Rete che c'è ma non funziona (portale wi-fi di hotel) | Si tratta come assenza di rete: timeout breve, si torna offline senza insistere |
| L'utente viene rimosso dal viaggio mentre è offline | Le operazioni in coda non sono più applicabili. Si conservano e si spiega, non si cancellano in silenzio |
| Copia locale vecchia di giorni | Si mostra l'età del dato. Non si finge che sia fresco |
| La stessa persona su due telefoni | Nessun problema nuovo: entrambi sono client dello stesso server |
| Il server rifiuta un'operazione della coda | Si mette da parte, si spiega cosa è successo, e la persona può riprovare o scartarla |

---

## Cosa non si fa

- **Nessuna sincronizzazione bidirezionale generale.** Non esiste un meccanismo che riconcilia due database: esiste una copia che si riscarica e una coda che si svuota.
- **Nessuna fusione automatica di testo.**
- **Nessun tempo reale.**
- **Nessuna risoluzione lato server dei conflitti.** Il server rifiuta una scrittura su versione superata; a decidere è la persona.
