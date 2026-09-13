# 04 — Integrazioni

Quattro servizi esterni. Per ciascuno le stesse quattro domande: **quanto costa, cosa succede senza rete, cosa succede se smette di funzionare, e cosa vede del nostro utente.**

La regola che li governa tutti: **ogni integrazione sta dietro un'interfaccia interna.** Nessuna schermata parla direttamente con un fornitore, così cambiarlo è un file e non una settimana.

---

## Mappe, percorsi e ricerca luoghi

| | |
|---|---|
| **A cosa serve** | Mappa del giorno, navigazione passo passo con posizione in tempo reale, ricerca del luogo di una tappa |
| **Costo** | A chiamata. È **il costo variabile che cresce con l'uso** e non con le registrazioni: chi naviga tutto il giorno costa più di dieci persone che aprono l'app due volte |
| **Senza rete** | Non funziona. Restano indirizzi e coordinate delle tappe, che sono nell'insieme essenziale, e la possibilità di consegnarli all'app di mappe del telefono |
| **Se smette** | Degrada a elenco: le tappe restano, la mappa no. Non si blocca niente |
| **Cosa vede** | Posizione durante la navigazione. Dev'essere l'unico servizio a vederla, e solo mentre si naviga |

Nella fase interna i piani gratuiti bastano. Il **tetto per utente e per viaggio è prerequisito per aprire fuori dal team**: vedi [ADR-006](adr/006-mappe-e-percorsi.md).

---

## Tasso di cambio

| | |
|---|---|
| **A cosa serve** | Convertire le spese nella valuta scelta dalla persona |
| **Costo** | A chiamata, ma le chiamate sono poche: **un aggiornamento al giorno per le valute in uso**, non una per spesa |
| **Senza rete** | Si usa l'ultimo tasso noto, dicendo esplicitamente che può essere cambiato. L'importo nella valuta originale resta il dato vero |
| **Se smette** | Le spese si registrano lo stesso nella valuta originale; la conversione si dichiara non disponibile. **Non si inventa mai un tasso** |
| **Cosa vede** | Quali valute ci interessano. Nient'altro: non sa a quale persona né per quale viaggio |

Il tasso usato e la sua data si conservano **dentro la spesa**: una conversione senza la sua data è una bugia raccontata bene.

---

## Verifica del numero di telefono

| | |
|---|---|
| **A cosa serve** | Attivare profilo pubblico e matching |
| **Costo** | A messaggio. Variabile ma **limitato dalle registrazioni**, non dall'uso: è il più prevedibile dei tre |
| **Senza rete** | Non si può verificare. Non blocca nulla del viaggio: serve solo per la parte pubblica |
| **Se smette** | La parte pubblica non si può attivare. Il resto dell'app funziona per intero |
| **Cosa vede** | Un numero di telefono |

Serve un limite di tentativi per numero e per account, altrimenti è il primo posto da cui qualcuno fa uscire dei soldi per divertimento.

---

## Deep link differito

| | |
|---|---|
| **A cosa serve** | Far sì che, dopo aver installato l'app da un link d'invito, si apra **quel** viaggio |
| **Costo** | Dipende dalla soluzione: vedi [ADR-004](adr/004-deep-link-differito.md) |
| **Senza rete** | Non applicabile: chi installa ha rete |
| **Se smette** | **È il guasto più grave dell'app e non produce nessun errore.** La persona installa, apre, e trova un'app vuota. Va sorvegliato con una misura apposta: quota di installazioni da invito che arrivano sul viaggio corretto |
| **Cosa vede** | Dipende dalla soluzione, ed è uno dei criteri di scelta |

È il pezzo da cui dipende H3, che è l'unico canale di acquisizione e non ha un piano B: **si costruisce e si prova per primo**, prima di qualunque funzione.
