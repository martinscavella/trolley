# Per la revisione legale

Bozza dell'8 ottobre 2026, con la parte pubblica aggiunta il 9; da consegnare a chi farà la revisione privacy prima che l'app esca dal team (ondata 1 della beta). Accompagna due testi da rivedere:

- l'**informativa sulla privacy**: `sito/privacy.html`, che sarà pubblicata su `trolleyapp.vercel.app/privacy`;
- la pagina **cosa misuriamo**: `sito/misurazione.html`, su `trolleyapp.vercel.app/misurazione`;
- le **condizioni d'uso della parte pubblica**: `sito/condizioni.html`, su `trolleyapp.vercel.app/condizioni` (aggiunte il 9 ottobre 2026, con la fase 5.1). Servono prima della seconda ondata, non della prima: le domande 18–26 possono aspettare.

E dal 10 ottobre 2026 (fase 5.2) due **valutazioni d'impatto** in bozza, anche loro per la seconda ondata, ciascuna con le sue domande (P1–P9 e C-1–C-5):

- [la parte pubblica fra sconosciuti](valutazione-impatto-parte-pubblica.md): profilo pubblico, ricerca, collegamenti, messaggi;
- [chi c'è in città](valutazione-impatto-presenza-in-citta.md): la presenza in città.

Il ragionamento completo sta in [06 — Privacy e conformità](../tecnico/06-privacy-e-conformita.md). Qui ci sono il quadro in breve e le domande a cui serve una risposta. Le parti evidenziate nelle due pagine sono le stesse di queste domande.

---

## Che cos'è Trolley, per quello che riguarda i dati

Un'app per iPhone (Android in seguito) per organizzare un viaggio, da soli o con altri: tappe, spese divise, liste, documenti, mappa. Oggi è in prova privata, usata solo dal team. Il server è Supabase (database, accesso, funzioni), con i dati nell'Unione europea, in Irlanda.

Tre scelte di architettura tolgono dal server i dati più delicati:

- **I documenti** (passaporti, biglietti, prenotazioni) stanno solo sul telefono, cifrati con il codice di sblocco. Non esiste nessun percorso nel codice né nel server che li riceva. Finiscono nel backup del telefono della persona, se lo ha attivo.
- **La posizione** si usa solo sul telefono, mentre si usa l'app, mai in sottofondo. Per la verifica del viaggio il telefono confronta la posizione con la meta, e al server arriva solo «sì, era sul posto», con l'ora. Per la navigazione a piedi, il punto di partenza passa dal nostro server al fornitore di mappe, senza essere salvato.
- **L'itinerario generato** non passa da noi. L'app prepara un testo che la persona copia nel proprio assistente (Claude, ChatGPT…), con il proprio account; la risposta torna nell'app incollata a mano.

Non ci sono pubblicità, strumenti di analisi di terzi o identificativi pubblicitari. La misurazione è nostra: un elenco chiuso di azioni, senza contenuti.

## Che cosa si tratta oggi

| Dati | Dove | Perché |
|---|---|---|
| Email, password, nome, data di nascita, valuta | Server (Supabase Auth e database) | L'account; l'età minima di 16 anni |
| Viaggi, giorni, tappe e i posti scelti (con le coordinate del posto, non della persona), spese e quote, liste, note, inviti, partecipazioni, traguardi | Server | Il servizio, condiviso fra chi partecipa a un viaggio |
| «Sul posto» e quando, per ogni viaggio verificato | Server | La verifica, che dà i traguardi |
| Eventi di misurazione: nome dell'azione, alcune proprietà numeriche o a scelta chiusa, id dell'account, id del viaggio per alcune, ora, versione dell'app | Server | Capire quali funzioni servono (le ipotesi del prodotto) |
| Conto delle chiamate alle mappe, per persona, viaggio e giorno | Server, una settimana | Il tetto di consumo |
| IP, città approssimativa, user agent, ora di ogni richiesta | Registri di Supabase e Vercel | Funzionamento e sicurezza |

Fuori da questo elenco, per ora: profilo pubblico, ricerca di altri viaggiatori, messaggi, presenza in città. Sono funzioni future (fase 5), e le loro due valutazioni d'impatto sono scritte in bozza (sopra).

Il loro impianto di sicurezza (5.1) è già costruito, e resta spento finché la parte pubblica non apre: chi accende il profilo pubblico verifica il **numero di telefono** con un codice SMS (Twilio Verify, chiamato dal nostro server; il numero sta sul server, non lo vede nessuno, un numero per account) e accetta le **condizioni d'uso**; può **bloccare** (chi è bloccato non lo sa) e **segnalare** (la segnalazione conserva il contenuto com'era, e chi è segnalato non sa da chi). La moderazione la fa una persona, con uno strumento fuori dall'app; può **sospendere** il profilo pubblico, e la persona sospesa legge il motivo. Il processo è in [moderazione](../sicurezza/moderazione.md).

## Le domande

### Chi e su quale base

1. **Titolare del trattamento.** Chi è: persona fisica o società, con quale indirizzo, e quale contatto per la privacy. Nell'informativa c'è un segnaposto.
2. **Basi giuridiche.** Abbiamo scritto: il contratto per l'account, i viaggi e la verifica; l'interesse legittimo per la misurazione, per il tetto delle mappe e per i registri tecnici. Vanno bene?
3. **La misurazione è accesa di default, con la possibilità di spegnerla** dal profilo, senza perdere funzioni. Gli eventi si scrivono prima sul telefono e partono a lotti. Basta l'interesse legittimo con opposizione, o per l'art. 122 del Codice privacy (informazioni archiviate sul terminale) serve un consenso prima, cioè spenta finché la persona non la accende?
4. **La verifica del viaggio.** La posizione resta sul telefono e al server arriva solo un sì con l'ora. Quel sì è un dato di localizzazione? Basta il permesso di posizione del sistema operativo, chiesto dopo una schermata che spiega a cosa serve, o serve un consenso a parte?

### Età e minori

5. **Sedici anni per tutti**, anche se in Italia il consenso digitale è a 14: un'unica soglia evita la logica per paese. La data di nascita è dichiarata, non verificata, e la persona non la può cambiare da sola. Va bene così?

### Chiudere l'account e scaricare i dati

6. **Chi chiude l'account** perde accesso, email, nome e data di nascita, e i viaggi in cui era da solo. Nei viaggi condivisi i suoi contributi restano, attribuiti a «Account chiuso», perché gli altri non perdano il viaggio; le spese restano nei saldi. Il profilo resta come riga vuota, senza dati personali, a cui puntano quei contributi. È una cancellazione sufficiente?
7. **Gli eventi di chi chiude** restano, ma passano tutti sotto un identificativo nuovo che non porta più al profilo. Sono dati anonimi o ancora pseudonimi? Se pseudonimi, vanno cancellati anche loro?
8. **Il file dei dati** (formato JSON, dal profilo) contiene i viaggi come la persona li vede, quindi anche il nome dei compagni e quello che hanno aggiunto nei viaggi condivisi. È compatibile con i diritti degli altri (art. 20, par. 4)?

### Fornitori e trasferimenti

9. **Responsabili del trattamento**: Supabase (database, accesso, funzioni), Vercel (sito con la pagina degli inviti e l'informativa), Geoapify (mappe, ricerche, percorsi; riceve dal nostro server zone di mappa, testo cercato e capi del percorso, senza sapere chi è la persona). Servono gli accordi dell'art. 28 con tutti e tre? Quelli standard dei fornitori bastano?
10. **Geoapify**: dalle fonti pubbliche risulta Geoapify GmbH in Germania, ma anche una KEPTAGO LTD a Cipro. Quale entità va indicata?
11. **Trasferimenti fuori dall'UE**: Supabase e Vercel sono società statunitensi. I dati dell'app stanno in Irlanda, ma il sito di Vercel è servito dalla rete globale, e l'assistenza di entrambi può accedere dagli Stati Uniti. Quali garanzie citare: Data Privacy Framework, clausole contrattuali standard?
12. **Apple** (App Store, TestFlight, backup del telefono) e l'**assistente** scelto dalla persona per l'itinerario: li consideriamo titolari autonomi, non nostri fornitori. È corretto?

### Conservazione e adempimenti

13. **Conservazione**: i viaggi restano finché la persona non li cancella o chiude l'account; il conto delle mappe una settimana; gli eventi nel dettaglio «per poco», poi solo aggregati. Quale periodo fissare per gli eventi? Per i registri tecnici valgono i periodi dei fornitori: vanno citati?
14. **Registro dei trattamenti** (art. 30) e **valutazioni d'impatto**: per quello che c'è oggi servono? Per la presenza in città e per il matching fra sconosciuti (fase 5) le bozze sono scritte, per la seconda ondata.

### L'informativa

15. **Dove e quando si mostra**: un rimando sotto «Crea un account», nella schermata d'accesso, prima di dare email e data di nascita; e nel profilo, sotto Privacy, accanto alla misurazione e a «I tuoi dati». La persona non deve accettare niente: l'informativa informa. È sufficiente?
16. **Il testo**: le due pagine sono scritte in linguaggio semplice, in italiano. Che cosa manca, o va detto diversamente?
17. **App Store**: Apple chiede di dichiarare quali dati l'app raccoglie e se sono legati alla persona. La nostra lettura è: dati di contatto (email, nome) e contenuti dell'utente, legati alla persona, per il funzionamento; identificativi (id dell'account) e dati d'uso (interazioni con il prodotto), legati alla persona, per l'analisi; nessun tracciamento; nessuna posizione raccolta. Il sì della verifica va dichiarato come posizione approssimativa?

### La parte pubblica (prima della seconda ondata)

18. **Il numero di telefono** si tratta solo per chi accende la parte pubblica, sulla base del contratto. Twilio (Stati Uniti) lo riceve per mandare e controllare il codice: è un altro responsabile, con un trasferimento. Va bene? I tentativi di verifica si tengono una settimana, con il numero, per il tetto contro l'abuso degli SMS.
19. **Le condizioni d'uso** si accettano accendendo il profilo pubblico, e il server ricorda quale versione e quando. Sono scritte come regole numerate, perché una sospensione le cita. Che cosa manca? In particolare: la responsabilità per gli incontri di persona (sezione 7), la chiusura definitiva della parte pubblica per i casi gravi, e se servono condizioni generali anche per il resto dell'app.
20. **Digital Services Act.** Trolley ospiterà contenuti delle persone (profili, messaggi fra persone collegate). Quali obblighi valgono per noi, piccoli: il meccanismo di segnalazione (art. 16) e la motivazione delle decisioni (art. 17) li abbiamo previsti — chi segnala riceve conferma e l'esito, chi è sospeso legge il motivo e a chi scrivere. Serve un sistema interno di reclamo (art. 20), o basta il contatto? I punti di contatto per le autorità e per le persone (artt. 11 e 12)?
21. **La conservazione delle segnalazioni** e dei contenuti segnalati: «il tempo di gestirle più il periodo utile a difendersi da una contestazione». Quanto? Chiudendo l'account, le segnalazioni fatte restano, e quelle ricevute anche: va bene?
22. **Un possibile reato** segnalato: il processo dice di non cancellare niente, sospendere, e rispondere alle autorità solo su richiesta formale. È corretto? C'è un obbligo di denuncia?
23. **Un possibile minore** nella parte pubblica: la data di nascita è dichiarata. Si sospende alla segnalazione; basta?
24. **Il blocco** non avvisa chi è bloccato, e la segnalazione non dice a chi è segnalato chi l'ha fatta. Se la persona segnalata chiede l'accesso ai suoi dati (art. 15), che cosa le si deve dare delle segnalazioni che la riguardano?
25. **App Store, linea guida 1.2** (contenuti delle persone): chiede di poter segnalare, bloccare, un contatto pubblicato, e «un modo per filtrare i contenuti inappropriati». La moderazione automatica è fuori di proposito ([12](../prodotto/12-sicurezza-e-moderazione.md)): i messaggi solo fra persone collegate, dopo un sì, bastano?
26. **Le valutazioni d'impatto** per il matching e la presenza in città: le abbiamo scritte noi, in bozza, con l'impianto già costruito e i disegni delle schermate ancora da costruire. Bastano come forma e come contenuto, e chi le firma? Le loro domande sono dentro, P1–P9 e C-1–C-5.

---

## Dopo la revisione

Le risposte si riportano in [06](../tecnico/06-privacy-e-conformita.md), nelle decisioni e nelle pagine del sito. Poi si tolgono gli avvisi di bozza e si pubblica.
