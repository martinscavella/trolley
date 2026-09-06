# Visione prodotto

## Identità

- **Nome**: Trolley
- **Tagline**: l'app che ti segue dal "e se andassimo a Lisbona?" al ritorno a casa
- **Categoria**: app mobile consumer / viaggi / organizzazione personale
- **Piattaforma**: iOS in prima release, Android in fase successiva

---

## Problema

**Il problema principale.** Organizzare un viaggio produce lavoro: cerchi, decidi, prenoti, scrivi, salvi. Quel lavoro si disperde negli strumenti in cui lo fai — le idee restano in chat, l'itinerario in un documento condiviso, le conferme nella casella email, i biglietti in screenshot nel rullino, le spese da nessuna parte. Il risultato è che nel momento in cui quel lavoro dovrebbe servirti — sei in aeroporto, hai poca rete, poca batteria e zero pazienza — non ce l'hai in un posto solo. E quando torni, non resta niente: il viaggio finisce e con lui sparisce tutto quello che avevi messo insieme.

**Quanto è frequente.** Da 1 a 5 volte l'anno per la maggior parte delle persone, ma con **intensità altissima nei giorni intorno alla partenza**. Non è un problema quotidiano, è un problema concentrato: poche occasioni all'anno in cui però conta moltissimo.

**Perché oggi non è risolto bene.** Gli strumenti esistenti coprono ciascuno una fase sola e si passano male il testimone. Le app di ispirazione ti aiutano a scegliere e poi ti lasciano; i comparatori ti fanno prenotare e poi ti mandano una email; i documenti condivisi reggono la pianificazione di gruppo ma sono inutilizzabili in mobilità; le app di compagnia funzionano solo se qualcuno ha già inserito i dati altrove. Nessuno accompagna la stessa persona lungo l'intero arco, e la conseguenza è che ogni passaggio di fase costa un travaso manuale di informazioni.

**Il segnale che il problema è reale.** Il comportamento che quasi tutti adottano è già una diagnosi: si crea un gruppo in chat per il viaggio, si fissano i messaggi importanti, si fanno screenshot delle prenotazioni "per averle offline". Sono soluzioni di ripiego costruite a mano da persone che non hanno trovato di meglio. Lo stesso vale per il gesto di cercare freneticamente una email di conferma con una barra di segnale sola.

---

## Per chi

- **Utente principale**: chi organizza il viaggio, per sé o per il gruppo. È la persona che tiene insieme date, prenotazioni e informazioni, e che oggi paga il prezzo più alto della frammentazione.
- **Utente secondario**: chi viaggia insieme e non organizza. Consulta, non inserisce. Oggi riceve informazioni a spizzichi in chat e non ha mai il quadro completo.
- **Contesto d'uso**: due contesti opposti che la stessa app deve servire. A casa, con calma, mentre pianifica. In movimento, di fretta, con rete incerta, mentre viaggia.

---

## Proposta di valore

- **Promessa principale**: tutto il tuo viaggio in un posto solo, dalla prima idea al ritorno — e disponibile proprio quando serve.
- **Differenza rispetto alle alternative**: non copre una fase, copre l'arco intero. Quello che scrivi mentre pianifichi è esattamente quello che ti ritrovi in mano quando parti, senza travasi.
- **Beneficio funzionale**: niente informazioni sparse, niente ricerca affannosa di una conferma, niente dipendenza dalla rete nel momento peggiore.
- **Beneficio emotivo**: la tranquillità di chi sa di avere tutto con sé — e, al ritorno, la soddisfazione di vedere che il viaggio ha lasciato un segno.

---

## Perché adesso

- **Driver di mercato**: i viaggi sono tornati a volumi pieni e si organizzano quasi interamente da telefono, ma gli strumenti restano frammentati per fase. Nel frattempo le persone si aspettano che un'app funzioni anche senza rete, cosa che dieci anni fa era un requisito da specialisti.
- **Opportunità specifica**: nessuno presidia bene il **passaggio tra le fasi**. È lo spazio dove la frammentazione fa più male e dove un prodotto continuo ha un vantaggio strutturale, difficile da replicare per chi è nato come strumento di una fase sola.

---

## Alternative attuali

| Alternativa | Cosa fanno oggi le persone | Limite principale |
|---|---|---|
| Chat di gruppo | Coordinano il viaggio a messaggi, fissano quelli importanti | L'informazione scorre via, non ha struttura, ritrovarla è impossibile |
| Documenti e fogli condivisi | Scrivono l'itinerario a più mani | Ottimi da desktop, inutilizzabili in mobilità e senza rete |
| Casella email | Lasciano lì le conferme di prenotazione | Servono ricerca e connessione proprio quando non ce n'è |
| Screenshot nel rullino | Salvano biglietti e codici "per sicurezza" | Si mescolano a migliaia di foto, senza ordine né scadenze |
| App di pianificazione | Costruiscono itinerari elaborati | Abbandonano l'utente alla partenza, quando servirebbero di più |
| Social e foto | Raccontano il viaggio dopo | Nessun legame con quello che era stato organizzato prima |

Il punto non è che queste alternative funzionino male: è che sono **sei strumenti diversi per un'esperienza sola**, e ogni confine tra loro è un punto in cui si perde qualcosa.

---

## Ambizione del prodotto

- **MVP**: un'app che copre l'arco completo in modo essenziale — crei il viaggio quando è ancora un'idea, costruisci l'itinerario, ci attacchi i documenti, ti accompagna dal vivo, e alla chiusura ti restituisce i traguardi che hai guadagnato. Viaggi condivisi con i compagni fin da subito.
- **Versione validata**: sparisce l'attrito di inserimento (le prenotazioni si importano invece di essere scritte a mano), la community diventa un motivo di ritorno autonomo, arriva Android.
- **Versione scalabile**: Trolley è il posto dove le persone tengono la propria storia di viaggio, e quella storia — traguardi, mete, abitudini — è ciò che rende l'app difficile da abbandonare.

---

## Vincoli iniziali

- **Budget**: tendente a zero sull'infrastruttura. Due costi però esistono e vanno accettati: **99$/anno** di Apple Developer Program, necessari già per distribuire su TestFlight, e la **commissione Apple del 15–30%** su qualsiasi acquisto in-app.
- **Tempo**: obiettivo dichiarato di sei mesi alla prima beta, a fronte di uno scope che ne richiede realisticamente nove. La roadmap tiene la tensione esplicita invece di nasconderla.
- **Team**: solo founder.
- **Vincoli normativi**: GDPR. Trolley tratta documenti d'identità e dati di viaggio, che rivelano spostamenti di persone fisiche; con la parte pubblica tratta anche dati resi visibili ad altri, inclusi quelli dei compagni di viaggio. Non è un'app dove la privacy si sistema alla fine.
- **Vincolo di piattaforma**: dal momento che esistono contenuti pubblici, l'App Store richiede segnalazione, blocco, filtro dei contenuti e un contatto raggiungibile. Senza, l'app non viene approvata.

---

## Criterio di esistenza del prodotto

**Trolley ha senso se** le persone che lo usano per pianificare lo tengono aperto anche durante il viaggio, e tornano a crearne un secondo. È l'unica prova che la continuità — l'unica cosa che rende Trolley diverso — viene percepita davvero.

**Trolley va ripensato se** viene usato solo in una fase e abbandonato nelle altre. Se le persone pianificano altrove e lo aprono solo in viaggio, o lo riempiono prima di partire e non lo toccano più una volta partite, allora l'arco completo non è un valore ma un'ambizione nostra: meglio scegliere la fase che regge da sola e costruire quella.

---

## Domande aperte

- Il nome "Trolley" comunica l'arco completo o suggerisce solo il momento della partenza? Da verificare con utenti reali prima di investire sull'identità visiva.
- Quanto pesa davvero la fase "decisione" nell'MVP? È la fase con meno funzioni e più valore narrativo: se in test nessuno crea viaggi allo stato di idea, va ridimensionata a favore delle altre.
