-- Il rinnovo delle coordinate di Google (CR-06, ultimo passo; ADR-014).
--
-- Le condizioni di Google lasciano tenere latitudine e longitudine al massimo
-- 30 giorni. Finora il lavoro di notte le toglieva e basta
-- (`privato.scadi_coordinate_google`, migrazione posto_da_google); da qui le
-- si rinnova prima. Lo chiede il telefono quando aggiorna la copia, con la
-- rete: la funzione `mappe` (`/mappe/rinnova`) chiede qui quali tappe del
-- viaggio vanno rinnovate, chiede a Google dove stanno, e le riscrive qui.
-- Il lavoro di notte resta: toglie quelle che nessuno ha rinnovato, perché
-- nessuno ha aperto il viaggio.
--
-- Rinnovare o togliere le coordinate di Google **non è una modifica**: il
-- posto è lo stesso (il `place_id`), cambia solo la copia di dove sta. Per
-- questo non porta la tappa a una versione nuova, non cambia quando è stata
-- modificata né chi l'ha fatto: chi la sta cambiando sul telefono non si
-- trova davanti «due versioni» che dicono lo stesso posto, firmate da chi ha
-- solo aperto il viaggio. Lo dice `trolley.solo_coordinate`, acceso solo
-- dentro le due funzioni qui sotto, e vale solo se la riga cambia nelle
-- coordinate e nel `place_id` (che Google a volte rinnova) e in nient'altro.

-- ─── Una tappa che cambia solo le coordinate di Google ──────────────────

-- Quando vale: acceso, e la riga cambia solo nelle coordinate e nel
-- `place_id`. Scritto dentro i due trigger, e non in una funzione a parte:
-- un trigger chiama le altre funzioni con i permessi di chi scrive.

-- Come aggiorna_riga, tranne quando cambiano solo le coordinate di Google.
create function privato.aggiorna_tappa()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_setting('trolley.solo_coordinate', true) = 'on'
     and to_jsonb(old) - array['lat', 'lon', 'coordinate_il', 'place_id']
       = to_jsonb(new) - array['lat', 'lon', 'coordinate_il', 'place_id'] then
    return new;
  end if;
  if new.versione is distinct from old.versione then
    raise exception 'versione superata: attesa %, ricevuta %', old.versione, new.versione
      using errcode = 'TR409';
  end if;
  new.versione := old.versione + 1;
  new.modificato_il := now();
  new.id := old.id;
  new.creato_da := old.creato_da;
  new.creato_il := old.creato_il;
  return new;
end;
$$;

revoke execute on function privato.aggiorna_tappa() from public, anon, authenticated;

drop trigger tappa_aggiorna on public.tappa;
create trigger tappa_aggiorna before update on public.tappa
  for each row execute function privato.aggiorna_tappa();

-- Chi ha scritto l'ultima versione resta quello che era.
create or replace function privato.segna_autore()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE'
     and current_setting('trolley.solo_coordinate', true) = 'on'
     and to_jsonb(old) - array['lat', 'lon', 'coordinate_il', 'place_id']
       = to_jsonb(new) - array['lat', 'lon', 'coordinate_il', 'place_id'] then
    new.modificato_da := old.modificato_da;
    return new;
  end if;
  new.modificato_da := auth.uid();
  return new;
end;
$$;

-- ─── Trenta giorni, poi via: senza fare una versione nuova ──────────────

create or replace function privato.scadi_coordinate_google()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  perform set_config('trolley.solo_coordinate', 'on', true);
  update public.tappa
     set lat = null, lon = null, coordinate_il = null
   where place_id is not null
     and coordinate_il is not null
     and coordinate_il < now() - interval '30 days';
  get diagnostics n = row_count;
  perform set_config('trolley.solo_coordinate', 'off', true);
  return n;
end;
$$;

revoke execute on function privato.scadi_coordinate_google() from public, anon, authenticated;

-- ─── Quali rinnovare ────────────────────────────────────────────────────

-- Le tappe del viaggio con un posto di Google e le coordinate più vecchie di
-- [p_giorni] giorni (da 1 a 29), o già tolte: al massimo 50, le più vecchie
-- prima. Con l'accesso di chi chiama: le vede solo chi partecipa. Un viaggio
-- chiuso o un'idea in archivio non ne hanno bisogno (ADR-014: il passaporto
-- e il mappamondo usano paese e città, che sono nostri).
create function public.coordinate_da_rinnovare(p_viaggio uuid, p_giorni integer)
returns table (id uuid, place_id text)
language sql
stable
security invoker
set search_path = ''
as $$
  select t.id, t.place_id
    from public.tappa t
    join public.viaggio v on v.id = t.viaggio_id
   where t.viaggio_id = p_viaggio
     and t.place_id is not null
     and t.eliminato_il is null
     and v.eliminato_il is null
     and v.stato not in ('chiuso', 'archiviato')
     and (t.coordinate_il is null
          or t.coordinate_il < now() - make_interval(days => least(greatest(coalesce(p_giorni, 20), 1), 29)))
   order by t.coordinate_il nulls first, t.id
   limit 50;
$$;

revoke execute on function public.coordinate_da_rinnovare(uuid, integer) from public, anon;
grant execute on function public.coordinate_da_rinnovare(uuid, integer) to authenticated;

-- ─── Rinnovarle ─────────────────────────────────────────────────────────

-- Scrive le coordinate rinnovate: `[{id, place_id, nuovo, lat, lon}]`, dove
-- `place_id` è quello chiesto a Google e `nuovo` quello che Google ha
-- risposto (di solito lo stesso). Con l'accesso di chi chiama, quindi con le
-- regole di sempre: solo chi partecipa. Una tappa si rinnova solo se ha
-- ancora quel posto (chi l'ha cambiato nel frattempo vince), se non è tolta
-- e se le sue coordinate hanno più di un giorno: chi chiama non riscrive
-- dove sta un posto quando vuole. Restituisce le tappe rinnovate, come sono
-- ora: il telefono le mette nella sua copia.
create function public.rinnova_coordinate(p_viaggio uuid, p_rinnovi jsonb)
returns table (id uuid, place_id text, lat double precision, lon double precision,
               coordinate_il timestamptz)
language plpgsql
security invoker
set search_path = ''
as $$
#variable_conflict use_column
begin
  if jsonb_typeof(p_rinnovi) is distinct from 'array' or jsonb_array_length(p_rinnovi) > 50 then
    raise exception 'rinnovi non validi' using errcode = '22023';
  end if;
  perform set_config('trolley.solo_coordinate', 'on', true);
  return query
    update public.tappa t
       set place_id = r.nuovo, lat = r.lat, lon = r.lon, coordinate_il = now()
      from jsonb_to_recordset(p_rinnovi)
           as r(id uuid, place_id text, nuovo text, lat double precision, lon double precision)
     where t.id = r.id
       and t.viaggio_id = p_viaggio
       and t.place_id = r.place_id
       and t.eliminato_il is null
       and (t.coordinate_il is null or t.coordinate_il < now() - interval '1 day')
       and r.nuovo is not null
       and r.lat between -90 and 90
       and r.lon between -180 and 180
    returning t.id, t.place_id, t.lat, t.lon, t.coordinate_il;
  perform set_config('trolley.solo_coordinate', 'off', true);
end;
$$;

revoke execute on function public.rinnova_coordinate(uuid, jsonb) from public, anon;
grant execute on function public.rinnova_coordinate(uuid, jsonb) to authenticated;
