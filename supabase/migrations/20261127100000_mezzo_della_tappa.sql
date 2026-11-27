-- Il mezzo di un tragitto (CR-07, ADR-015).
--
-- Fra due tappe vicine dello stesso giorno c'è un tragitto, con un mezzo.
-- Il mezzo sta nella tappa a cui si arriva: è «come ci arrivi» dalla tappa
-- prima. Una tabella dei tragitti `da → a` si romperebbe a ogni tappa
-- spostata, tolta o rimandata; così, spostando una tappa, il mezzo la segue.
--
-- Vuoto è «Come ci vai?»: lo sceglie la persona. È parte della tappa come
-- l'ora: cambiarlo fa una versione nuova, e due versioni si mostrano come
-- per gli altri campi. I tempi non si tengono: li stima l'app, e Google li
-- dice quando si apre il tragitto (le sue condizioni non lasciano tenerli).

alter table public.tappa
  add column mezzo text
    check (mezzo in ('a_piedi', 'bici', 'mezzi', 'auto', 'monopattino', 'taxi'));
