-- Le tappe (fase 1.2, 04-itinerario.md). La tabella c'è dallo schema iniziale;
-- qui arrivano il tipo e l'ordine di una giornata in una scrittura sola.

-- Il tipo serve a proporre la durata — precompilata, mai chiesta a vuoto
-- (decisioni/prodotto.md, "Tetto strutturale alle tappe") — e a riconoscere la
-- tappa a colpo d'occhio. Facoltativo: quelle che arriveranno da un itinerario
-- incollato (1.6) possono non averlo. I permessi sulla tabella valgono anche
-- per la colonna nuova.
alter table public.tappa
  add column tipo text check (tipo in ('visita', 'museo', 'pasto', 'passeggiata',
                                       'spettacolo', 'escursione', 'pausa', 'altro'));

-- L'ordine delle tappe di un giorno: [p_tappe] nell'ordine voluto. Gira con i
-- permessi di chi chiama (security invoker), quindi valgono le stesse regole
-- delle scritture dirette: chi non partecipa non riordina niente.
--
-- Non porta la versione: due persone che riordinano la stessa giornata non sono
-- un conflitto da mostrare, vince l'ultima. Restituisce le righe scritte, che
-- l'app mette nella copia così come sono.
create function public.ordina_tappe(p_giorno uuid, p_tappe uuid[])
returns setof public.tappa
language sql
security invoker
set search_path = ''
as $$
  update public.tappa t
     set ordine = o.posizione::integer
    from unnest(p_tappe) with ordinality as o(id, posizione)
   where t.id = o.id
     and t.giorno_id = p_giorno
     and t.eliminato_il is null
  returning t.*;
$$;

revoke execute on function public.ordina_tappe(uuid, uuid[]) from public, anon;
grant execute on function public.ordina_tappe(uuid, uuid[]) to authenticated;
