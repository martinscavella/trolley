# Ipotesi da validare

## Obiettivo

Elencare le ipotesi da cui dipende la sopravvivenza di Trolley, con una soglia numerica e un modo per testarle. Serve a evitare di costruire per nove mesi qualcosa che poggia su una convinzione mai verificata.

Le ipotesi sono ordinate per **quanto costa scoprirle sbagliate tardi**, non per quanto sono probabili.

---

## Ipotesi principali

| ID | Tipo | Ipotesi | Perché è critica | Come la testo | Soglia di successo | Stato |
|---|---|---|---|---|---|---|
| **H2** | Desiderabilità | Le persone accettano di inserire l'itinerario a mano | In MVP non c'è import automatico. Se l'attrito iniziale è troppo alto, l'utente non arriva mai al valore e nessuna delle altre ipotesi viene mai messa alla prova | Test su prototipo navigabile: chiedere a 10 persone di ricostruire un viaggio vero già fatto, cronometrando e osservando dove si fermano | 7 su 10 completano un viaggio con almeno 3 tappe in meno di 8 minuti senza aiuto | Da testare |
| **H1** | Desiderabilità | La continuità tra le fasi è percepita come valore, non come "un'app che vuole fare troppo" | È l'unica differenza strutturale rispetto a chi presidia una fase sola. Se non viene percepita, Trolley è un'app in più che fa peggio quello che altri fanno meglio | Interviste sul problema con chi ha viaggiato negli ultimi 3 mesi: ricostruire dove sono finite le informazioni del loro ultimo viaggio, fase per fase | 7 su 10 raccontano spontaneamente almeno due travasi manuali tra strumenti diversi | Da testare |
| **H4** | Fattibilità | Il funzionamento senza rete è un requisito reale, non solo dichiarato | Determina la decisione architetturale più costosa del progetto. Costruire la sincronizzazione offline quando non serviva significa buttare settimane; non costruirla quando serviva significa fallire nel momento decisivo | Domanda diretta nelle interviste ("l'ultima volta che sei stato senza rete in viaggio, cosa non riuscivi a fare?") più spike tecnico che ne misura il costo reale | 6 su 10 raccontano un episodio concreto e recente, non ipotetico | Da testare |
| **H3** | Crescita | La condivisione del viaggio è il motore di diffusione: chi viene invitato installa | È il canale di acquisizione previsto, a costo zero. Se non funziona, non esiste un piano B di crescita e la community non ha da cosa nascere | Misurabile solo in beta: quota di invitati che installano e completano l'accesso | >35% degli invitati installa entro 7 giorni | Da testare in beta |
| **H5** | Retention | I badge fanno tornare le persone tra un viaggio e l'altro | Regge l'intera fase "dopo" e la community. Senza, Trolley è un'app stagionale aperta due volte l'anno, e la gamification è costo puro | Misurabile solo in beta: aperture dell'app nei periodi senza viaggi attivi, e quota di utenti che aprono la bacheca traguardi | >25% degli utenti con almeno un viaggio chiuso apre l'app in un mese senza viaggi attivi | Da testare in beta |
| **H6** | Monetizzazione | Una parte degli utenti paga per superare i limiti del piano gratuito | Determina se Trolley può esistere oltre la beta. Va testato tardi ma non troppo: prima che i limiti del piano gratuito siano scolpiti nel prodotto | Pagina di piano visibile in beta con misurazione dell'intenzione, più conversazioni dirette con gli utenti più attivi | >10% degli utenti attivati manifesta interesse concreto | Da testare in beta |

---

## Esperimenti previsti

| # | Esperimento | Obiettivo | Ipotesi coperte | Durata | Quando |
|---|---|---|---|---|---|
| 1 | Interviste sul problema — 10 persone che hanno viaggiato di recente | Capire dove finiscono davvero le informazioni di un viaggio, fase per fase | H1, H4 | 7 giorni | Prima di scrivere codice |
| 2 | Spike tecnico offline + viaggi condivisi | Misurare quanto costa la sincronizzazione con scrittura condivisa | H4 | 2–3 giorni | Prima di chiudere l'ADR sullo stack |
| 3 | Test su prototipo navigabile — inserimento manuale itinerario | Misurare l'attrito reale del gesto più rischioso dell'MVP | H2 | 5 giorni | Dopo la mappa schermate, prima di costruire |
| 4 | Beta con utenti reali | Verificare diffusione, ritorno e disponibilità a pagare | H3, H5, H6 | continuativo | Alla prima release TestFlight |

Gli esperimenti 1 e 2 sono **bloccanti**: il primo può cambiare il prodotto, il secondo può cambiare l'architettura. Vanno fatti prima che le rispettive decisioni diventino costose da revocare.

---

## Cosa non assumere senza prove

- Che coprire più fasi aumenti automaticamente il valore percepito. Può anche leggersi come dispersione: è esattamente ciò che H1 deve verificare.
- Che chi viene invitato a un viaggio abbia una ragione per installare l'app. L'invitato ha un bisogno diverso dall'organizzatore — consulta e non inserisce — e va convinto con argomenti suoi.
- Che i badge motivino di per sé. La gamification funziona quando premia qualcosa che la persona già vuole fare; se il viaggio non è già di per sé memorabile, un distintivo non lo rende tale.
- Che chi dichiara "sì, mi servirebbe offline" abbia davvero vissuto il problema. La domanda va posta chiedendo un episodio concreto, non un'opinione.
- Che l'uso della community segua l'uso dell'app. Sono due prodotti con due motivazioni diverse: si può amare Trolley in viaggio e ignorarne completamente la parte pubblica.

---

## Domande aperte

- Serve validare H2 con utenti che non hanno mai usato app di viaggio, o il test su chi le usa già è sufficiente? I secondi sono più facili da trovare ma hanno aspettative diverse.
- H5 richiede mesi per essere misurata davvero, ma la fase "dopo" va costruita prima. Ha senso un test anticipato su un prototipo di bacheca traguardi, o è un segnale troppo debole per valerne il costo?
