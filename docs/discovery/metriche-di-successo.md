# Metriche di successo

## North Star

**Viaggi chiusi con verifica d'uso reale.**

Un viaggio conta quando è stato portato a termine *con* l'app: c'erano tappe, i documenti sono stati aperti, le spese registrate mentre il viaggio era in corso. È la stessa condizione che assegna i badge, e non è un caso: il traguardo premia esattamente il comportamento che definisce il successo del prodotto.

**Perché questa e non un'altra.** Misura l'unica cosa che conta davvero — che Trolley sia stato attraversato per intero, non solo installato o riempito. Un viaggio creato non dice niente. Un viaggio *vissuto* con l'app dice tutto.

**L'avvertenza che va con essa.** Nel momento in cui una metrica diventa anche la condizione per ottenere un premio, smette di essere solo una misura e diventa un bersaglio: le persone impareranno a soddisfarla. È il motivo per cui la regola di verifica va scritta con cura — se è troppo facile, i badge si svalutano *e* la metrica mente. Vanno monitorati insieme: la North Star e la percentuale di viaggi chiusi che **non** superano la verifica. Se la seconda crolla verso zero, la regola è troppo generosa.

---

## Funnel principale

| Fase | Metrica | Definizione | Obiettivo a 12 mesi dalla beta |
|---|---|---|---|
| Acquisizione | Registrazioni | Account creati | 500 |
| **Diffusione** | **Invitati che installano** | Compagni invitati a un viaggio che completano l'accesso entro 7 giorni | **>35%** |
| Attivazione | Primo viaggio con contenuto | Utenti che creano un viaggio con almeno 3 tappe o 1 documento | >45% delle registrazioni |
| Valore | **Viaggio vissuto** | Utenti con almeno un viaggio arrivato in stato *in corso* con uso reale | >30% delle registrazioni |
| **Ritorno** | **Secondo viaggio** | Utenti che creano un secondo viaggio dopo averne chiuso uno | **>40% di chi ha chiuso un viaggio** |
| Fase dopo | Ritorno fuori stagione | Utenti che aprono l'app in un mese senza viaggi attivi | >25% di chi ha almeno un viaggio chiuso |
| Ricavo | Interesse al pagamento | Utenti attivati che manifestano interesse concreto | >10% |

Le due righe in grassetto sono quelle da cui dipende la sopravvivenza del modello: **la diffusione** è l'unico canale di acquisizione previsto, **il secondo viaggio** è l'unica prova che l'app è entrata nelle abitudini.

---

## La retention di un'app stagionale non si misura a settimane

Un'app da viaggio si usa 2-5 volte l'anno. Gli utenti attivi settimanali, che sono la metrica standard per un'app consumer, qui **mentono in entrambe le direzioni**: fanno sembrare un successo la settimana della partenza e un fallimento i due mesi seguenti.

Le metriche giuste sono altre:

- **Ritorno per viaggio**: quanti utenti che hanno chiuso un viaggio ne creano un altro. È la vera retention di Trolley.
- **Tempo tra il primo e il secondo viaggio**: dice se l'app è stata ricordata al momento giusto, cioè quando è nata l'idea del viaggio dopo.
- **Ritorno fuori stagione**: aperture nei periodi senza viaggi attivi. È l'unico modo per sapere se la fase "dopo" sta facendo il suo lavoro, ed è la misura diretta dell'ipotesi H5.
- **Profondità del viaggio**: tappe, documenti, spese per viaggio. Distingue chi usa Trolley davvero da chi ci ha messo dentro solo il volo.

---

## Da guardare ogni settimana

- Nuove registrazioni, separando **arrivi diretti** e **arrivi da invito** (sono due canali con qualità diverse e vanno letti separati)
- Viaggi creati, e quanti superano le 3 tappe
- Documenti caricati per viaggio attivo
- Viaggi entrati in stato *in corso* e viaggi chiusi
- **Percentuale di chiusure che non superano la verifica** — il termometro della regola dei badge
- Segnalazioni ricevute e tempo di gestione (dal momento in cui la parte pubblica è attiva)
- Errori di sincronizzazione e conflitti risolti automaticamente

---

## Soglie decisionali

| Se osservo | Significa | Cosa faccio |
|---|---|---|
| Attivazione <25% | Il primo gesto costa troppo. È **H2 che cade**: l'inserimento manuale non regge | Anticipo l'import automatico, prima di ogni altra cosa in programma |
| Attivazione buona, viaggi vissuti <15% | Le persone pianificano con Trolley e poi lo chiudono. **La fase live non convince** | Riprogetto la fase live: è il cuore del prodotto, non un ramo secondario |
| Invitati che installano <15% | **H3 cade**: la diffusione non funziona e non esiste un piano B | Ripenso l'esperienza dell'invitato prima di investire un'ora in altro |
| Secondo viaggio <20% | L'app non è entrata nelle abitudini | Verifico se è un problema di memoria (nessuno se la ricorda) o di valore |
| Ritorno fuori stagione <10% | **H5 cade**: i badge non producono ritorno | Rivedo l'economia dei traguardi, o accetto che Trolley sia un'app stagionale e riadatto il modello di ricavo |
| Quasi tutte le chiusure superano la verifica | La regola è troppo generosa, i badge non valgono niente | Stringo la soglia di verifica prima che la community si popoli di traguardi finti |

---

## Obiettivi della beta

- **100 utenti attivi** entro 12 mesi dall'apertura della beta
- **50 viaggi chiusi con verifica** — la prova che l'arco completo funziona per persone che non sono io
- **Cinque abbonati annuali**, quanto basta a coprire i 99$ dell'Apple Developer Program. Traguardo volutamente minuscolo, ma è il primo segnale vero che qualcuno è disposto a pagare

---

## Domande aperte

- Quanti giorni devono passare senza viaggi attivi perché un'apertura conti come "ritorno fuori stagione"? La soglia cambia completamente il valore del numero.
- La profondità del viaggio è una metrica di successo o un rischio? Un viaggio con trenta tappe può indicare un utente coinvolto — oppure uno che sta lavorando troppo per un'app che dovrebbe fargli risparmiare fatica.
- Serve misurare la community separatamente fin dall'inizio, o basta il ritorno fuori stagione come indicatore aggregato?
