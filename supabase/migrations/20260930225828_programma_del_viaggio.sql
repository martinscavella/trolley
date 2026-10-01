-- Le date di un viaggio e i suoi giorni si scrivono insieme (02-il-viaggio.md,
-- regola 3: il passaggio a definito richiede date, giorni e orari).
--
-- I giorni li calcola l'app, dove vivono le regole di dominio (00-architettura.md):
-- queste funzioni li applicano in una transazione sola, così un viaggio definito
-- non resta mai senza giorni né un'idea con i giorni. Girano con i permessi di
-- chi le chiama (security invoker): valgono le stesse regole di accesso delle
-- scritture dirette.
--
-- Un giorno non si cancella: quando esce dalle date si marca, e se le date
-- tornano a comprenderlo ritorna com'era, con quello che vi è agganciato
-- (02-il-viaggio.md, casi limite: si torna a idea, si spostano le date).

-- p_giorni: [{"id": uuid, "data": "2026-10-10", "inizio": "10:00:00", "fine": "24:00:00"}]
-- L'id conta solo per le date nuove: una data che il viaggio ha già avuto riprende
-- la sua riga.
create function privato.applica_giorni(p_viaggio uuid, p_giorni jsonb)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  update public.giorno g
     set eliminato_il = now()
   where g.viaggio_id = p_viaggio
     and g.eliminato_il is null
     and not exists (
       select 1 from jsonb_array_elements(p_giorni) n
       where (n->>'data')::date = g.data
     );

  update public.giorno g
     set finestra_inizio = (n->>'inizio')::time,
         finestra_fine = (n->>'fine')::time,
         eliminato_il = null
    from jsonb_array_elements(p_giorni) n
   where g.viaggio_id = p_viaggio
     and g.data = (n->>'data')::date
     and (g.eliminato_il is not null
          or g.finestra_inizio <> (n->>'inizio')::time
          or g.finestra_fine <> (n->>'fine')::time);

  insert into public.giorno (id, viaggio_id, data, finestra_inizio, finestra_fine)
  select (n->>'id')::uuid, p_viaggio, (n->>'data')::date,
         (n->>'inizio')::time, (n->>'fine')::time
    from jsonb_array_elements(p_giorni) n
   where not exists (
     select 1 from public.giorno g
      where g.viaggio_id = p_viaggio and g.data = (n->>'data')::date
   );
end;
$$;

-- Un viaggio nuovo: idea se mancano le date, definito con i suoi giorni se ci sono.
create function public.crea_viaggio(
  p_id uuid,
  p_destinazione_citta text,
  p_destinazione_paese text,
  p_periodo text,
  p_data_inizio date,
  p_data_fine date,
  p_ora_arrivo time,
  p_ora_partenza time,
  p_giorni jsonb
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  insert into public.viaggio (id, stato, destinazione_citta, destinazione_paese,
                              periodo_approssimativo, data_inizio, data_fine,
                              ora_arrivo, ora_partenza, creatore_id)
  values (p_id,
          case when p_data_inizio is null then 'idea' else 'definito' end,
          p_destinazione_citta,
          p_destinazione_paese,
          -- Il periodo vale solo per le idee (01-modello-dati.md).
          case when p_data_inizio is null then p_periodo end,
          p_data_inizio, p_data_fine, p_ora_arrivo, p_ora_partenza,
          (select auth.uid()));
  if p_data_inizio is not null then
    perform privato.applica_giorni(p_id, p_giorni);
  end if;
end;
$$;

-- Fissa o sposta le date. Da idea (o dall'archivio) il viaggio diventa definito.
-- La versione è quella su cui la persona ha deciso: se nel frattempo qualcuno ha
-- cambiato il viaggio, si rifiuta (TR409) invece di scrivere sopra.
create function public.programma_viaggio(
  p_viaggio uuid,
  p_versione integer,
  p_data_inizio date,
  p_data_fine date,
  p_ora_arrivo time,
  p_ora_partenza time,
  p_giorni jsonb
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  update public.viaggio
     set stato = case when stato in ('idea', 'archiviato') then 'definito' else stato end,
         periodo_approssimativo = null,
         data_inizio = p_data_inizio,
         data_fine = p_data_fine,
         ora_arrivo = p_ora_arrivo,
         ora_partenza = p_ora_partenza,
         versione = p_versione
   where id = p_viaggio
     and eliminato_il is null;
  if not found then
    raise exception 'viaggio non trovato' using errcode = 'TR404';
  end if;
  perform privato.applica_giorni(p_viaggio, p_giorni);
end;
$$;

-- Da definito a idea: le date spariscono, i giorni si marcano e tornano se le
-- stesse date si fissano di nuovo.
create function public.torna_idea(p_viaggio uuid, p_versione integer, p_periodo text)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  update public.viaggio
     set stato = 'idea',
         periodo_approssimativo = p_periodo,
         data_inizio = null,
         data_fine = null,
         ora_arrivo = null,
         ora_partenza = null,
         versione = p_versione
   where id = p_viaggio
     and eliminato_il is null
     and stato = 'definito';
  if not found then
    raise exception 'viaggio non trovato' using errcode = 'TR404';
  end if;
  perform privato.applica_giorni(p_viaggio, '[]'::jsonb);
end;
$$;

revoke execute on function privato.applica_giorni(uuid, jsonb) from public, anon;
revoke execute on function public.crea_viaggio(uuid, text, text, text, date, date, time, time, jsonb) from public, anon;
revoke execute on function public.programma_viaggio(uuid, integer, date, date, time, time, jsonb) from public, anon;
revoke execute on function public.torna_idea(uuid, integer, text) from public, anon;
grant execute on function privato.applica_giorni(uuid, jsonb) to authenticated;
grant execute on function public.crea_viaggio(uuid, text, text, text, date, date, time, time, jsonb) to authenticated;
grant execute on function public.programma_viaggio(uuid, integer, date, date, time, time, jsonb) to authenticated;
grant execute on function public.torna_idea(uuid, integer, text) to authenticated;
