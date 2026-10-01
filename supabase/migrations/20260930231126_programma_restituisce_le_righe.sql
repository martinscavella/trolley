-- crea_viaggio, programma_viaggio e torna_idea restituiscono le righe che hanno
-- scritto: il viaggio, i suoi giorni attivi, chi partecipa. L'app le mette
-- nella copia locale così come sono, senza una seconda chiamata: se la rete cade
-- subito dopo, la copia non resta indietro rispetto al server.
--
-- Il tipo restituito cambia, quindi le funzioni si ricreano. Il corpo è quello
-- di 20260930225828_programma_del_viaggio.sql, più il ritorno.

create function privato.righe_del_viaggio(p_viaggio uuid)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'viaggio', (select to_jsonb(v) from public.viaggio v where v.id = p_viaggio),
    'giorni', coalesce(
      (select jsonb_agg(to_jsonb(g) order by g.data)
         from public.giorno g
        where g.viaggio_id = p_viaggio and g.eliminato_il is null),
      '[]'::jsonb),
    'partecipazioni', coalesce(
      (select jsonb_agg(to_jsonb(p))
         from public.partecipazione p
        where p.viaggio_id = p_viaggio),
      '[]'::jsonb)
  );
$$;

drop function public.crea_viaggio(uuid, text, text, text, date, date, time, time, jsonb);
drop function public.programma_viaggio(uuid, integer, date, date, time, time, jsonb);
drop function public.torna_idea(uuid, integer, text);

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
returns jsonb
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
  return privato.righe_del_viaggio(p_id);
end;
$$;

create function public.programma_viaggio(
  p_viaggio uuid,
  p_versione integer,
  p_data_inizio date,
  p_data_fine date,
  p_ora_arrivo time,
  p_ora_partenza time,
  p_giorni jsonb
)
returns jsonb
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
  return privato.righe_del_viaggio(p_viaggio);
end;
$$;

create function public.torna_idea(p_viaggio uuid, p_versione integer, p_periodo text)
returns jsonb
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
  return privato.righe_del_viaggio(p_viaggio);
end;
$$;

revoke execute on function privato.righe_del_viaggio(uuid) from public, anon;
revoke execute on function public.crea_viaggio(uuid, text, text, text, date, date, time, time, jsonb) from public, anon;
revoke execute on function public.programma_viaggio(uuid, integer, date, date, time, time, jsonb) from public, anon;
revoke execute on function public.torna_idea(uuid, integer, text) from public, anon;
grant execute on function privato.righe_del_viaggio(uuid) to authenticated;
grant execute on function public.crea_viaggio(uuid, text, text, text, date, date, time, time, jsonb) to authenticated;
grant execute on function public.programma_viaggio(uuid, integer, date, date, time, time, jsonb) to authenticated;
grant execute on function public.torna_idea(uuid, integer, text) to authenticated;
