# ADR-011 — La verifica del numero di telefono

**Stato**: accettata il 9 ottobre 2026, con la fase 5.1. Il fornitore è **Twilio Verify**, scelto dall'utente fra questo e il telefono di Supabase Auth

## Contesto

La parte pubblica richiede un numero di telefono verificato: un numero, un account ([decisioni](../../decisioni/prodotto.md), «Verifica dell'identità: numero di telefono»; [01](../../prodotto/01-account-e-profilo.md), regola 4). Si verifica con un codice SMS, e l'SMS si paga a messaggio: è il primo posto da cui qualcuno può far uscire soldi per divertimento, mandando codici a numeri a pagamento ([04](../04-integrazioni.md)). Servono quindi tre cose insieme: il codice, il tetto, e la garanzia che il numero sia di un account solo.

## Decisione

**Una funzione nostra, `telefono`, davanti a Twilio Verify.** Come per le mappe ([ADR-006](006-mappe-e-percorsi.md)): l'app parla con il nostro server, il server con il fornitore.

- **L'app non parla con Twilio**: chiama `…/functions/v1/telefono/invia` e `…/verifica` con il proprio accesso (`dati/telefono.dart`, dietro l'interfaccia `VerificaDelTelefono`). Il numero va nel corpo, non nell'indirizzo, e non finisce nei registri delle richieste.
- **Le chiavi stanno sul server**, nei segreti delle funzioni: `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_VERIFY_SID`.
- **Prima di ogni invio e di ogni controllo la funzione chiede al database** (`telefono_invio`, `telefono_controllo`): la parte pubblica accoglie questa persona, ha 18 anni, il numero non è di un altro account, il tetto non è raggiunto. Quando Twilio dice che il codice è giusto, `telefono_conferma` scrive il numero. Sono funzioni che solo la chiave di servizio può chiamare: se le potesse chiamare l'app, ci si dichiarerebbe verificati senza aver ricevuto niente.
- **Il numero sta in `privato.telefono`**, una riga per account con il numero unico: un numero, un account, garantito dal database e non da un controllo prima. Il client non lo raggiunge; la persona lo legge con `la_mia_parte_pubblica` e lo trova nei dati che scarica.
- **Il tetto**, al giorno: 5 codici per persona, 3 per numero, 10 tentativi di scriverlo per persona, 100 codici per tutta l'app. I numeri stanno in `configurazione` (`tetto_telefono`) e si cambiano senza un rilascio. I tentativi si tolgono dopo una settimana.
- **Twilio Verify** genera il codice (sei cifre), lo manda, lo controlla e lo fa scadere. Ha già le sue difese contro il traffico SMS gonfiato (Fraud Guard) e i paesi permessi: si impostano sul suo pannello.
- **Numeri di prova**: il segreto `TELEFONO_PROVA` (`+393400000001=123456,…`) elenca numeri finti con il loro codice, che la funzione accetta senza mandare SMS. Servono a provare l'app sull'iPhone prima di avere un conto Twilio, e si tolgono prima di aprire la parte pubblica: chi conosce un numero di prova si verifica senza telefono.

## Alternative considerate

**Il telefono di Supabase Auth** (`updateUser(phone:)` e il codice di `phone_change`). Meno codice nostro, e l'unicità del numero viene da `auth.users`. Scartato perché accendere il telefono come fornitore d'accesso accende anche **l'accesso con il numero**: chiunque potrebbe creare account e far partire SMS chiamando l'API, senza passare dall'app né dai 18 anni. Si chiude solo con un hook sull'invio, che finisce per essere la stessa funzione nostra, scritta peggio.

**Un altro fornitore** (Vonage, Sinch, Bird). Equivalenti per quello che serve. Twilio Verify ha il controllo del codice e le difese contro le frodi già fatte; cambiarlo vuol dire riscrivere la funzione, non l'app.

**Il codice generato da noi**, mandato con un SMS semplice. Più economico a messaggio, ma il codice, la scadenza, i tentativi e le frodi diventano lavoro nostro: per una persona sola non conviene.

## Conseguenze

- Senza rete, o senza Twilio, la parte pubblica non si accende. Il resto dell'app funziona per intero ([04](../04-integrazioni.md)).
- Il numero è un dato personale nuovo, sul server: va nell'informativa ([06](../06-privacy-e-conformita.md)), e Twilio è un fornitore che tratta dati per noi, negli Stati Uniti. Chiudendo l'account il numero si cancella e torna libero.
- Per la parte pubblica serve un conto Twilio, con un servizio Verify: è un prerequisito operativo ([punti aperti](../../punti-aperti.md)).
