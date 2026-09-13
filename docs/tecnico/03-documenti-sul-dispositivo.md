# 03 — Documenti sul dispositivo

I documenti sono il dato più delicato che Trolley tocca — carte d'identità, passaporti, biglietti con nome e codice — e sono l'unica entità che **non lascia mai il telefono**. Questo capitolo esiste per rendere quella frase verificabile invece che dichiarata.

---

## Dove stanno

Nella cartella documenti del contenitore dell'app, in una sottocartella per viaggio. Solo il percorso e i metadati finiscono nel database locale; il file sta sul disco.

Due proprietà vengono gratis dal sistema, e vanno **verificate invece che date per scontate**:

- il contenuto del contenitore dell'app è cifrato a riposo dal sistema operativo, legato al codice di sblocco del telefono;
- rientra nel backup di sistema, quindi cambiare telefono li porta con sé.

Se la verifica dicesse il contrario su una delle due piattaforme, la cifratura va aggiunta esplicitamente: è un requisito, non un vantaggio ereditato.

---

## Le regole che vanno fatte rispettare dal codice

1. **Nessun percorso di codice invia un documento.** Non c'è un endpoint che li accetti: la protezione più forte è che il posto dove metterli non esista.
2. **L'entità `documento` non entra nella coda di sincronizzazione.** Va escluso esplicitamente, con un test che fallisce se qualcuno la aggiunge.
3. **Niente miniature o anteprime fuori dal contenitore**, nemmeno nella cache condivisa del sistema.
4. **Niente nella libreria foto.** Un documento acquisito con la fotocamera va nel contenitore, non nel rullino.
5. **Eliminare un documento elimina il file**, non solo la riga. E rimuovere un viaggio rimuove la sua cartella.
6. **Disinstallare l'app porta via i documenti.** È una conseguenza di dove stanno, e va detta alla persona quando carica il primo documento e nella schermata di chiusura account — non scoperta dopo.

---

## Casi da gestire

| Situazione | Comportamento |
|---|---|
| Spazio sul telefono esaurito | L'errore di sistema va tradotto in una frase comprensibile. Il documento non si salva a metà |
| File enorme | Si comprime se è un'immagine, si accetta com'è se è un PDF. Il limite è lo spazio del telefono, non una nostra quota |
| Il file originale viene spostato o cancellato fuori dall'app | Si copia sempre dentro il contenitore al momento dell'acquisizione. Non si conservano riferimenti a file altrui |
| Ripristino da backup su un telefono nuovo | I documenti tornano con il database, e i percorsi devono reggere un contenitore con un identificativo diverso: **mai salvare percorsi assoluti**, sempre relativi alla cartella dell'app |

L'ultima riga è l'errore classico di questa architettura, e si manifesta solo settimane dopo, sul telefono nuovo di qualcun altro.

---

## Cosa resta fuori

- Sincronizzazione fra i dispositivi della stessa persona
- Condivisione con i compagni di viaggio
- Copia di sicurezza gestita da noi
