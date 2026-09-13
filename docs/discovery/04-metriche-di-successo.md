# Metriche di successo

## North Star

**Viaggi chiusi con verifica d'uso reale.**

Un viaggio conta quando è stato portato a termine *con* l'app: almeno una tappa per ogni giorno, l'app aperta sul posto con la geolocalizzazione attiva, e **tutte** le tappe marcate come completate o saltate mentre il viaggio era in corso. La regola per intero è nel [capitolo 02 della documentazione funzionale](../prodotto/02-il-viaggio.md). È la stessa condizione che assegna i badge, e non è un caso: il traguardo premia esattamente il comportamento che definisce il successo del prodotto.

**Perché questa e non un'altra.** Misura l'unica cosa che conta davvero — che Trolley sia stato attraversato per intero, non solo installato o riempito. Un viaggio creato non dice niente. Un viaggio *verificato* dice tutto.

**Cosa resta fuori.** I viaggi passati inseriti come ricordo non entrano nel conteggio. Sono utili — riempiono il mappamondo e danno senso al profilo dal primo giorno — ma un viaggio del 2019 aggiunto in trenta secondi non dice niente sull'uso dell'app, e contarlo farebbe salire la North Star proprio mentre il prodotto non viene usato. Vanno misurati a parte, come segnale di adozione del profilo.

**Come si pesano.** *(Coefficienti confermati, da rivedere più avanti sui viaggi veri.)* Un viaggio lungo conta un po' più di uno breve, ma non in proporzione ai giorni: **peso = 1 + 0,1 per ogni giorno oltre il primo, con tetto a 2**. Una gita di un giorno vale 1,0, un weekend 1,1, una settimana 1,6, due settimane o più 2,0. La conseguenza è voluta: **più uscite brevi superano un viaggio lungo** — due weekend valgono 2,2 contro l'1,6 di una settimana. È coerente con H5, dove la frequenza conta più della durata, e impedisce che un mese in Asia faccia sembrare riuscito un anno in cui l'app è stata aperta una volta sola.

**L'avvertenza che va con essa.** Nel momento in cui una metrica diventa anche la condizione per ottenere un premio, smette di essere solo una misura e diventa un bersaglio: le persone impareranno a soddisfarla. È il motivo per cui la regola di verifica va scritta con cura — se è troppo facile, i badge si svalutano *e* la metrica mente. Vanno monitorati insieme: la North Star e la percentuale di viaggi chiusi che **non** superano la verifica. Se la seconda crolla verso zero, la regola è troppo generosa.

---

## Funnel principale

| Fase | Metrica | Definizione | Obiettivo a 12 mesi dalla beta |
|---|---|---|---|
| Acquisizione | Registrazioni | Account creati | 500 |
| **Diffusione** | **Invitati che installano** | Compagni invitati a un viaggio che completano l'accesso entro 7 giorni | **>35%** |
| Diffusione | Invitati che contribuiscono | Chi arriva da invito e aggiunge almeno un elemento proprio: una spesa, una cosa da portare, un documento | >50% di chi installa |
| Idea | Viaggi allo stato di idea | Viaggi creati senza date. Contati **a parte**: non entrano nell'attivazione, che conta solo i viaggi definiti | nessun obiettivo, si osserva quante diventano definite |
| Attivazione | Primo viaggio con contenuto | Utenti che creano un viaggio con almeno 3 tappe o 1 documento | >45% delle registrazioni |
| Valore | **Viaggio attraversato** | Utenti con almeno un viaggio arrivato in stato *in corso* e toccato mentre era in corso. È una soglia **più bassa della verifica**: serve a vedere chi arriva alla fase live, non chi la percorre per intero | >30% delle registrazioni |
| **Ritorno** | **Secondo viaggio** | Utenti che creano un secondo viaggio dopo averne chiuso uno | **>40% di chi ha chiuso un viaggio** |
| **Frequenza** | **Viaggi brevi** | Quota di viaggi creati che dura due giorni o meno — le uscite del weekend e le gite fuoriporta | **>30% dei viaggi creati** |
| Fase dopo | Ritorno fuori stagione | Utenti che aprono l'app dopo almeno 30 giorni senza viaggi attivi. **Nessun limite superiore**: un ritorno dopo sei mesi conta eccome | >25% di chi ha almeno un viaggio chiuso |
| Ricavo | Interesse al pagamento | Utenti attivati che manifestano interesse concreto | >10% |

Le tre righe in grassetto sono quelle da cui dipende la sopravvivenza del modello: **la diffusione** è l'unico canale di acquisizione previsto, **il secondo viaggio** è la prova che l'app è entrata nelle abitudini, **i viaggi brevi** sono ciò che separa un'app aperta tre volte l'anno da una aperta quindici.

---

## La retention di un'app stagionale non si misura a settimane

Un'app da viaggio si usa 2-5 volte l'anno. Gli utenti attivi settimanali, che sono la metrica standard per un'app consumer, qui **mentono in entrambe le direzioni**: fanno sembrare un successo la settimana della partenza e un fallimento i due mesi seguenti.

Le metriche giuste sono altre:

- **Ritorno per viaggio**: quanti utenti che hanno chiuso un viaggio ne creano un altro. È la vera retention di Trolley.
- **Tempo tra il primo e il secondo viaggio**: dice se l'app è stata ricordata al momento giusto, cioè quando è nata l'idea del viaggio dopo.
- **Frequenza dei viaggi brevi**: quota di viaggi creati che dura due giorni o meno. È la misura diretta di **H5** e la risposta più solida alla stagionalità: un'app usata anche per le uscite del weekend non ha una bassa stagione da attraversare.
- **Ritorno fuori stagione**: aperture dopo almeno 30 giorni senza viaggi attivi, senza limite superiore. Chi torna dopo sei mesi conta, ed è anzi il caso che dimostra meglio di ogni altro che l'app è stata ricordata da sola: vale la pena guardare a parte i **ritorni oltre i sei mesi**, che saranno pochi ma sono quelli veri. Dice se la fase "dopo" — mappamondo, traguardi, profilo — sta facendo qualcosa. Non è una prova di ipotesi: i badge sono una scelta già presa e non devono giustificarsi con un numero. Resta il termometro di **H7**, perché una community che non si forma non produce aperture.

**Quello che non è una metrica: la profondità del viaggio.** Tappe, documenti e spese per viaggio non misurano il successo e non vanno usati per dichiararlo. Un viaggio con trenta tappe può indicare una persona coinvolta oppure una che sta lavorando troppo dentro un'app che dovrebbe farle risparmiare fatica — e un numero che si legge nei due sensi opposti non serve a decidere niente. Resta solo il controllo di **attivazione** (almeno 3 tappe o 1 documento), che è una soglia da superare una volta, non una misura di quanto in profondità si va.

---

## Da guardare ogni settimana

- Nuove registrazioni, separando **arrivi diretti** e **arrivi da invito** (sono due canali con qualità diverse e vanno letti separati)
- Viaggi creati, e quanti superano la soglia di attivazione (3 tappe o 1 documento), tenendo separati i viaggi in programma dai viaggi passati inseriti come ricordo
- **Quota di viaggi che dura due giorni o meno** — la misura di H5, ed è la prima da guardare
- **Prompt esportati**, e quanti si chiudono con un incollato riuscito entro 24 ore — numeratore e denominatore della domanda di itinerario generato
- **Incollati che il parser non riesce a interpretare** — non è un difetto tecnico da mettere in coda: è una promessa rotta dopo che la persona ha già fatto il giro fuori dall'app
- **Passaporto compilato**: quanti inseriscono almeno un viaggio passato entro 7 giorni dalla registrazione. È **curiosità, non adozione** — chi lo riempie sta guardando indietro, che è una cosa diversa dall'usare il prodotto. Resta un numero a sé: non entra nella North Star, non si somma ai viaggi, non produce traguardi verificati, e i viaggi importati restano marcati come tali anche nell'interfaccia
- **Viaggi che passano da idea a definito**, e quanto tempo ci mettono. È la misura diretta del peso della fase "decisione": se le idee non diventano mai viaggi, quella fase è un contenitore vuoto. Un'idea si considera **abbandonata** quando il periodo che indica è passato senza essere diventata definita — 12 mesi se non indica nessun periodo — e a quel punto va in archivio: le abbandonate escono dal conteggio delle idee vive invece di gonfiarlo per sempre
- Documenti caricati per viaggio attivo
- Viaggi entrati in stato *in corso* e viaggi chiusi
- **Percentuale di chiusure che non superano la verifica** — il termometro della regola dei badge
- Segnalazioni ricevute e tempo di gestione (dal momento in cui la parte pubblica è attiva)
- Errori di sincronizzazione e conflitti risolti automaticamente

---

## La community si misura a parte, e ogni mese

Con H7 diventata un'ipotesi a sé, il ritorno fuori stagione non basta più come indicatore aggregato: dice che qualcuno apre l'app, non che esista una community. Questi numeri si guardano **una volta al mese** — a cadenza settimanale sarebbero troppo radi per dire qualcosa. L'unica eccezione sono le segnalazioni, che restano settimanali perché riguardano la sicurezza delle persone e non la crescita.

| Numero | Definizione | Cosa dice |
|---|---|---|
| Profili resi pubblici | Utenti attivi che rendono visibile il proprio profilo di viaggiatore | Se la gente vuole essere vista. È il presupposto di tutto il resto: senza profili pubblici non c'è niente da guardare |
| Richieste di collegamento inviate | Richieste tra persone che non condividevano già un viaggio | Se lo spazio pubblico fa venire voglia di conoscersi, o è solo una bacheca |
| **Collegamenti reciproci accettati** | Richieste accettate: entrambe le persone hanno detto di sì | **È questo il "contatto che arriva a qualcosa".** Un collegamento accettato è consenso da due parti, non un numero che si accumula da soli |
| Tasso di accettazione | Collegamenti accettati diviso richieste inviate | Dice se la community esiste davvero **e** fa da spia di sicurezza: tante richieste con poche accettazioni è il profilo di chi sta infastidendo, non di chi sta conoscendo gente |

Il riferimento di H7: su 100 utenti beta e in 6 mesi, almeno **15 profili pubblici** e almeno **10 collegamenti reciproci accettati** tra persone che non si conoscevano, senza che li abbia stimolati io. Con il matching dentro la prima release quella soglia è raggiungibile: è tarata su un prodotto in cui esiste un modo per cercarsi, non sul caso fortuito.

**Nessun controllo automatico per singolo utente.** Molte richieste inviate e poche accettate non fanno scattare niente: è lo stesso comportamento di chi segue cento profili privati su un social senza risposta. Il tasso resta un indicatore aggregato di salute, e la verifica manuale parte dalle **segnalazioni**.

---

## Soglie decisionali

| Se osservo | Significa | Cosa faccio |
|---|---|---|
| Attivazione <25% | Il primo gesto costa troppo. È **H2 che cade**: lo scheletro non basta a far percepire il viaggio come esistente | Anticipo la generazione dell'itinerario e l'import automatico, prima di ogni altra cosa in programma |
| Attivazione buona, viaggi vissuti <15% | Le persone pianificano con Trolley e poi lo chiudono. **La fase live non convince** | Riprogetto la fase live: è il cuore del prodotto, non un ramo secondario |
| Invitati che installano <15% | **H3 cade**: la diffusione non funziona e non esiste un piano B | Ripenso l'esperienza dell'invitato prima di investire un'ora in altro |
| Invitati che installano ma contribuiscono <20% | **H3 cade a metà**: il modello paritario non è arrivato, gli invitati restano spettatori e i loro traguardi non hanno su cosa maturare | Rivedo il primo minuto dell'invitato: deve trovare subito qualcosa di suo da fare, non solo qualcosa da leggere |
| Secondo viaggio <20% | L'app non è entrata nelle abitudini | Verifico se è un problema di memoria (nessuno se la ricorda) o di valore |
| Viaggi brevi <15% dei viaggi creati | **H5 cade**: le uscite del weekend non arrivano su Trolley e l'app resta stagionale | Capisco se è attrito (creare un viaggio costa troppo per due giorni) o valore (per due giorni non serve niente di quello che offro), e riadatto il modello di ricavo |
| Ritorno fuori stagione <10% | La fase "dopo" non produce aperture | Non tocco i badge, che restano una scelta presa: guardo se è **H7** a non essere partita — manca la community, non la cartolina |
| Quasi tutte le chiusure superano la verifica | La regola è troppo generosa, i badge non valgono niente | Stringo la soglia di verifica prima che la community si popoli di traguardi finti |
| **Quasi nessuna chiusura supera la verifica** | Con la regola attuale è il rischio più probabile: basta una tappa non marcata. Se i traguardi non li prende nessuno, l'economia dei premi muore prima di nascere | Guardo **quale** delle tre condizioni manca più spesso e agisco lì: rendere più facile marcare le tappe prima di ammorbidire la regola |
| Prompt esportati alti **e** ritorni completati alti | La generazione è dimostrata: chi cambia app, incolla e torna indietro la vuole molto più di chi premerebbe un pulsante | Costruisco la chiamata nativa all'API appena c'è budget, senza altri test |
| Prompt esportati bassi | **Non concludo niente.** Non distinguo "non voglio un itinerario generato" da "non faccio il copia-incolla su un telefono" | Non cancello la funzione: provo a cambiarne la forma (meno passaggi, ritorno più semplice) e rimisuro. La regola è asimmetrica per scelta — un risultato alto vale, uno basso no |
| Incollati non interpretati >10% | Il formato richiesto dal prompt non regge, o i modelli suggeriti non lo rispettano | Stringo lo schema, e in ogni caso salvo il testo grezzo come nota del viaggio: nessuno deve rifare il giro da capo |

---

## Obiettivi della beta

- **100 utenti attivi** entro 12 mesi dall'apertura della beta
- **50 punti viaggio** — viaggi chiusi con verifica, pesati come sopra ed esclusi i viaggi passati inseriti come ricordo. Con un mix realistico di uscite brevi e viaggi lunghi significa fra i 40 e i 45 viaggi. È la prova che l'arco completo funziona per persone che non sono io
- **Cinque abbonati annuali**, quanto basta a coprire i 99$ dell'Apple Developer Program. Traguardo volutamente minuscolo, ma è il primo segnale vero che qualcuno è disposto a pagare
