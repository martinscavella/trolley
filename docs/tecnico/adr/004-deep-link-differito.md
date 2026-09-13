# ADR-004 — Deep link differito

**Stato**: accettata

## Contesto

L'invito è un link. Se chi lo riceve ha l'app, si apre il viaggio. Se non ce l'ha, va sullo store — e **dopo l'installazione deve aprirsi quel viaggio**, non una schermata vuota.

Su iOS non esiste un modo di sistema per far arrivare quell'informazione dentro un'app appena installata: è un problema noto, che si risolve con servizi dedicati o con espedienti.

Il peso del problema: **H3 è l'unico canale di acquisizione previsto e non ha un piano B.** E il guasto è silenzioso — nessun errore, solo una persona che installa e non trova niente.

## Opzioni considerate

**Servizio dedicato di terze parti.** Risolve il problema bene. Ma introduce un componente esterno che vede ogni installazione, costa oltre una soglia — quindi un costo variabile — e il panorama dei fornitori gratuiti si è ristretto negli ultimi anni: alcune soluzioni storiche non esistono più. Prima di sceglierne uno va verificato cosa è ancora attivo e a quali condizioni.

**Espediente con gli appunti.** Dopo l'installazione l'app legge gli appunti per trovare il codice d'invito. Su iOS una lettura non richiesta fa comparire un avviso di sistema proprio nel momento più delicato, e leggere gli appunti altrui all'avvio è un comportamento che non ci piace anche quando è permesso.

**Riaprire il link.** Dopo aver installato, la persona tocca di nuovo il link che ha già in chat — che a quel punto apre l'app sul viaggio giusto. Costa un passaggio in più e una riga di istruzioni nel messaggio d'invito. Costo zero, nessun componente esterno, nessun dato in mano a nessuno.

## Decisione

**Si parte dal riaprire il link**, con due appoggi:

1. il messaggio d'invito generato dall'app contiene l'istruzione — *"installa Trolley e poi riapri questo link"* — perché la riuscita non può dipendere da quanto è sveglia la persona;
2. esiste comunque un **codice d'invito da incollare o digitare**, raggiungibile dalla prima schermata dopo l'installazione, per chi il link non ce l'ha più sottomano.

E si **misura**: quota di installazioni da invito che arrivano sul viaggio corretto. Se il calo su quel passaggio è significativo, la misura giustifica la spesa per un servizio dedicato — che a quel punto si compra con un dato in mano invece che per prudenza.

## Conseguenze

- **Si accetta un passaggio in più** in cambio di zero costi variabili, zero dipendenze e zero dati in mano a terzi. È coerente con la regola che governa tutto il resto delle spese in questa fase.
- **La misura diventa parte della funzione**, non un'aggiunta: senza, non si saprebbe mai che il pezzo più importante della crescita sta perdendo persone.
- **Va provato per primo**, prima di qualunque funzione, su dispositivi veri e su una installazione vera dallo store. È il genere di cosa che funziona in sviluppo e non in produzione.
- **La decisione è reversibile in un punto solo**: l'ingresso da invito sta dietro un'interfaccia interna, e sostituirlo con un servizio dedicato non deve toccare nient'altro.
