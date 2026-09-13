# Ipotesi da validare

## Obiettivo

Elencare le ipotesi da cui dipende la sopravvivenza di Trolley, con una soglia numerica e un modo per testarle. Serve a evitare di costruire per nove mesi qualcosa che poggia su una convinzione mai verificata.

Le ipotesi sono ordinate per **quanto costa scoprirle sbagliate tardi**, non per quanto sono probabili.

Le scelte già prese — quelle che non hanno bisogno di un test — stanno in [Decisioni di prodotto](../decisioni/prodotto.md). Quello che resta da chiudere sta in [Punti aperti](../punti-aperti.md).

> **Revisione del 13 settembre 2026.** Quattro premesse sono cambiate: l'itinerario non si scrive a mano per intero (basta lo scheletro), gli invitati sono pari all'organizzatore e non spettatori, l'offline è selettivo e non totale, i badge non sono più candidati a motore di ritorno. Il dettaglio di cosa è caduto e perché è in fondo, nella sezione *Cosa è cambiato*.

> **Aggiornamento successivo.** La generazione dell'itinerario entra nell'MVP, ma senza chiamate a pagamento: Trolley costruisce un prompt, l'utente lo porta sull'LLM che già usa, e incolla indietro il risultato. Ragioni e regola di decisione in *Decisioni prese*. **H2 non cambia bersaglio**: lo scheletro resta il primo gesto e la generazione è un'aggiunta, non un sostituto.

---

## Ipotesi principali

| ID | Tipo | Ipotesi | Perché è critica | Come la testo | Soglia di successo | Stato |
|---|---|---|---|---|---|---|
| **H1** | Desiderabilità | Le persone vogliono in un posto solo le funzioni che oggi svolgono con strumenti generici non nati per il viaggio: cose da portare, divisione delle spese, itinerario e attrazioni, documenti, mappa e orientamento | È la premessa del prodotto. Se il valore sta nell'aggregazione, il confronto non avviene tra app ma **funzione per funzione contro lo specialista** che la persona già usa: basta che la divisione delle spese sia peggiore di quella che ha oggi e continuerà a usare quella, e l'aggregazione si rompe nel punto più debole | In beta: quante funzioni diverse vengono usate nello stesso viaggio dalla stessa persona. È la traduzione misurabile di "le vuole insieme": chi ne usa una sola sta usando un'app specializzata scritta male | >50% dei viaggi attivati usa almeno **3 funzioni diverse** fra tappe, spese, cose da portare e documenti | Da misurare in beta |
| **H5** | Retention | Le uscite brevi — un weekend, una gita fuoriporta — finiscono su Trolley come i viaggi veri | È ciò che separa un'app aperta 3 volte l'anno da una aperta 15. Da questa frequenza dipendono il ritorno, la community (che ha bisogno di gente che passa di lì) e l'abbonamento (difficile da giustificare su un uso stagionale). Se cade, il modello di ricavo va ripensato, non ritoccato | In beta: quota di viaggi creati che dura due giorni o meno, e quanti utenti ne creano più di uno | >30% dei viaggi creati dura ≤2 giorni | Da misurare in beta |
| **H2** | Desiderabilità | Lo scheletro basta: l'utente arriva al valore inserendo solo date, giorni e orari di arrivo e partenza, senza scrivere l'itinerario | È il primo gesto dell'MVP, ma il rischio si è spostato. Non è più "quanto costa scrivere tutto", è "un viaggio quasi vuoto invoglia il gesto dopo?". Se lo scheletro non fa sentire il viaggio già esistente, la persona resta davanti a un contenitore vuoto e non arriva a nessuna delle altre funzioni | In beta: quanti viaggi vanno oltre lo scheletro da soli, e quanto tempo passa fra la creazione e il primo elemento aggiunto | >60% dei viaggi che arrivano allo stato *definito* riceve almeno un elemento oltre lo scheletro entro 7 giorni | Da misurare in beta |
| **H4** | Fattibilità | Esiste un insieme piccolo e condiviso di cose che devono esserci senza rete; tutto il resto si scarica su scelta dell'utente | Determina la decisione architetturale più costosa del progetto. Se l'essenziale è un elenco corto e uguale per tutti, la sincronizzazione selettiva è alla portata di una persona sola. Se ognuno ha il suo essenziale, "selettivo" significa sincronizzare quasi tutto — cioè il costo che si voleva evitare. Il modello paritario di H3 alza il conto: più persone scrivono lo stesso viaggio, anche mentre sono offline | In beta: quali schermate vengono aperte mentre il telefono è senza rete, e quali contenuti risultano mancanti. **Attenzione**: qui la misura arriva dopo la decisione architetturale, che va presa senza prove | ≥80% delle aperture senza rete riguarda al massimo **5 tipi di contenuto**. Se il ventaglio è più largo, "essenziale offline" non è un insieme piccolo e l'architettura va rivista | Da misurare in beta |
| **H3** | Crescita | Chi viene invitato installa — e contribuisce, non guarda soltanto | È l'unico canale di acquisizione previsto e, con il modello paritario, anche la premessa della gamification: se gli invitati non aggiungono niente, i loro traguardi non hanno su cosa maturare e il viaggio condiviso torna a essere il documento di una persona sola | Misurabile solo in beta: quota di invitati che installa, e quota di chi installa che aggiunge qualcosa di suo | >35% degli invitati installa entro 7 giorni, e >50% di chi installa aggiunge almeno un elemento proprio (una spesa, una cosa da portare, un documento) entro la fine del viaggio | Da testare in beta |
| **H7** | Crescita | La community si forma da sola: le persone rendono pubblico il proprio profilo di viaggiatore e alcune lo usano per trovare compagni di viaggio | È l'unica cosa che nessuna delle app che Trolley aggrega ha, quindi è ciò che rende l'aggregazione difendibile invece che copiabile. Ed è la parte di cui non si sa nulla: una community non si costruisce, succede o non succede. È anche l'unica funzione con un rischio **sulle persone** e non sui dati — mettere in contatto sconosciuti per viaggiare insieme richiede segnalazione, blocco, verifica dell'identità e nessuna esposizione dei viaggi futuri, e sono requisiti da progettare prima, non dopo il primo problema. Il collegamento reciproco è il primo di questi presidi: senza il sì dell'altro non esiste contatto | Misurabile in beta, matching compreso: profili resi pubblici, richieste di collegamento tra persone che non si conoscevano già, e quante vengono accettate da entrambe le parti | Su 100 utenti beta e in 6 mesi: almeno **15 profili pubblici** e almeno **10 collegamenti reciproci accettati** tra persone che non si conoscevano, senza che li abbia stimolati io | Da testare in beta |
| **H6** | Monetizzazione | Una parte degli utenti paga un abbonamento premium per funzioni in più e accesso anticipato alle novità | Determina se Trolley esiste oltre la beta. Il contenuto del premium non è ancora definito, e **non può esserlo prima di H1**: le funzioni che le persone valutano di più sono le candidate naturali all'abbonamento, ma sono anche quelle che rendono l'app utile a chiunque. La scelta va fatta con i dati di H1 in mano, non adesso | Pagina di piano visibile in beta con misurazione dell'intenzione, più conversazioni dirette con gli utenti più attivi | >10% degli utenti attivati manifesta interesse concreto | Da testare in beta |

---

## Dove si è spostato il rischio

Le correzioni hanno tolto due rischi e ne hanno aggiunti altrettanti.

Sono usciti l'attrito dell'inserimento totale — lo scheletro costa pochi secondi — e l'offline totale, che era la voce più cara dell'architettura. Sono entrati la **frequenza** e la **community**.

La frequenza pesa più di quanto sembri: con i badge ridimensionati a cartolina, H5 è rimasta l'unica ipotesi che regge il ritorno da sola. Se le gite fuoriporta non finiscono su Trolley, non c'è nient'altro che riporti una persona nell'app tra un viaggio d'agosto e il successivo.

La community è insieme la differenza più forte rispetto agli strumenti che Trolley sostituisce e la parte meno dimostrata del prodotto. Finché resta non verificata, la difendibilità di Trolley è dichiarata e non provata: l'aggregazione da sola è copiabile da chiunque abbia già una delle cinque funzioni.

**La community resta dentro la beta, e ha un prezzo da mettere a calendario adesso.** Il matching era stato spostato dopo e poi rimesso, per una ragione buona: senza, la beta attraverserebbe dodici mesi senza sapere niente sulla cosa che rende Trolley diverso. Ma tenerlo dentro significa che segnalazione, blocco, verifica dell'identità, nessuna esposizione dei viaggi futuri e un processo di moderazione scritto diventano **lavoro bloccante della prima release**, non lavoro successivo. Non sono rifiniture: senza, l'app non passa la revisione di App Store, e la prima volta che qualcuno si comporta male non c'è niente da usare. Su sei mesi già stretti è la voce più pesante: la stima è in [Punti aperti](../punti-aperti.md) e vale tre settimane e mezzo, che è anche il motivo per cui la beta esce in due ondate.

Il modello paritario, infine, non ha cambiato il rischio di crescita ma ha alzato il prezzo dell'architettura: più persone che scrivono lo stesso viaggio, anche senza rete, significa conflitti veri da risolvere invece che un autore solo da sincronizzare.

**E infine sparisce la validazione a monte.** Niente interviste, niente prototipo, niente spike: tutto si misura in beta. Il rischio non cambia natura, cambia momento — si scopre più tardi e correggerlo costa di più. Per H4 significa scegliere l'architettura senza prove e convivere con la possibilità di riscriverla; per tutte le altre significa che la strumentazione va costruita insieme alle funzioni, perché è l'unico strumento di verifica rimasto.

---

## Come si valida, senza esperimenti preliminari

Non ci sono interviste, prototipi o spike prima di costruire: **le ipotesi si verificano sui numeri della beta**. È un vincolo, non un metodo, e porta due conseguenze da accettare consapevolmente.

**La prima**: ogni ipotesi si scopre sbagliata *dopo* averla costruita. Manca la rete di protezione che un test da cinque giorni avrebbe dato, e questo pesa soprattutto su **H4**, dove la decisione architetturale più costosa del progetto va presa senza nessuna prova a monte — con la possibilità concreta di doverla rifare.

**La seconda**, che è anche l'unica risposta possibile alla prima: **l'app deve misurare dal primo giorno**. Se la validazione vive solo in beta, la strumentazione non è una cosa da aggiungere dopo: è parte della prima release esattamente come le funzioni, e ogni soglia della tabella qui sopra deve avere un numero che la alimenta il giorno del rilascio. Le soglie e le azioni conseguenti stanno in [Metriche di successo](04-metriche-di-successo.md).

La beta esce in **due ondate** — la prima senza la parte pubblica, la seconda con matching e sicurezza quattro-sei settimane dopo. Il motivo è in [Punti aperti](../punti-aperti.md).

---

## Cosa non assumere senza prove

- Che "un'app invece di cinque" basti come argomento. Il confronto non è app contro app: è la divisione delle spese di Trolley contro quella che la persona usa già, la lista contro le sue note, la mappa contro quella del telefono. Si vince o si perde su ogni singola funzione, e la più debole decide.
- Che la generazione dell'itinerario con l'IA elimini l'attrito. Lo sposta: dall'inserimento alla fiducia nel risultato. Un itinerario che non ti somiglia va corretto, e correggere può costare quanto scrivere — con in più la delusione di aver ricevuto qualcosa di generico. Con il giro manuale se ne aggiunge una seconda: un incollato che Trolley non riesce a interpretare non è un errore tecnico, è una **promessa rotta dopo che la persona ha già fatto tutto il lavoro fuori dall'app**. Il testo grezzo va salvato comunque, sempre, anche quando il parsing fallisce.
- Che le gite fuoriporta usino l'app come i viaggi lunghi. Il rapporto tra fatica e beneficio è diverso: per due giorni a cento chilometri da casa non servono documenti offline né un itinerario, e resta in piedi forse solo la divisione delle spese e il ricordo. Se le uscite brevi meritano un'app più leggera, va saputo prima.
- Che l'essenziale offline sia un insieme piccolo e uguale per tutti. È esattamente ciò che H4 deve verificare, e se le risposte divergono la decisione architetturale cambia.
- Che con più persone che scrivono lo stesso viaggio i conflitti siano rari. Il modello paritario moltiplica le scritture concorrenti proprio nei momenti di bassa connettività, che sono anche quelli in cui tutti stanno guardando la stessa cosa.
- Che la community si formi perché il prodotto la prevede. Lo spazio pubblico e il bisogno di popolarlo sono due cose diverse, e la seconda non si progetta.
- Che il contenuto del piano premium possa essere deciso adesso. Deciderlo prima di H1 significa mettere dietro l'abbonamento una funzione a caso, e scoprire dopo che era quella che teneva in piedi l'app.

## Cosa è cambiato in questa revisione

| Ipotesi | Prima | Ora | Perché |
|---|---|---|---|
| **H1** | La continuità tra le fasi è percepita come valore | L'aggregazione di funzioni oggi sparse su strumenti generici è percepita come valore | La continuità resta vera ma non è l'argomento principale: il problema raccontato è dover scaricare due o tre app per un viaggio solo |
| **H2** | Le persone accettano di inserire l'itinerario a mano | Lo scheletro (date, giorni, orari) basta ad arrivare al valore | In MVP non si chiede l'itinerario completo; l'IA o la scrittura manuale vengono dopo |
| **H3** | L'invitato consulta e va convinto con argomenti suoi | L'invitato è un pari: installa **e** contribuisce | Nei viaggi tra amici ognuno aggiunge le proprie spese, le proprie liste e matura i propri traguardi |
| **H4** | Il funzionamento senza rete è un requisito reale | Esiste un insieme piccolo e condiviso da tenere sempre offline, il resto è a scelta | L'offline totale non serve: serve sapere cosa è essenziale |
| **H5** | I badge fanno tornare le persone tra un viaggio e l'altro | Le uscite brevi finiscono su Trolley come i viaggi veri | I badge sono una cartolina, non la funzione che riporta l'utente. La frequenza la fanno le gite fuoriporta |
| **H6** | Una parte degli utenti paga per superare i limiti del piano gratuito | Una parte degli utenti paga per funzioni in più e anteprime beta | Il premium è a funzioni, non solo a limiti; il contenuto preciso è da definire |
| **H7** | — | La community si forma da sola | Era nascosta dentro H5 come conseguenza dei badge. È un'ipotesi a sé, ed è il differenziatore dichiarato |
| *(ritirata)* | Test anticipato sulla bacheca traguardi | Nessun test: la funzione si fa comunque | Decisione presa |
| *(chiusa)* | Domanda aperta: l'IA è nell'MVP o dopo? | Nell'MVP, ma con il prompt esportato e il risultato incollato indietro — nessuna chiamata a pagamento | Budget zero in beta e nessun costo variabile senza tetto |
| *(chiusa)* | Domanda aperta: il matching entra in beta? | Sì. Fuori resta solo la modalità in tempo reale "chi c'è adesso in città" | Senza matching la beta non direbbe niente sul differenziatore. Il prezzo è che i presidi di sicurezza diventano lavoro bloccante della prima release |
| *(chiusa)* | Domanda aperta: la fase "decisione" sta in piedi con lo scheletro? | Sì, con due stati: **idea** (date facoltative, poche funzioni) e **definito** (date obbligatorie, sblocca il resto) | Un viaggio deve poter esistere prima delle date, ma le funzioni del durante hanno bisogno delle date per funzionare |
| *(chiusa)* | Domanda aperta: quali funzioni alla pari con lo specialista? | Cose da portare e spese alla pari o meglio, itinerario buono, mappa fuori concorso | Vedi *Dove va speso il tempo* |
