-- Il posto di una tappa cercato con Google (CR-06, ADR-014).
--
-- Le condizioni di Google Maps Platform lasciano tenere per sempre solo il
-- `place_id`; latitudine e longitudine al massimo 30 giorni, poi vanno
-- rinnovate o tolte. Il nome e l'indirizzo di Google non si tengono: si
-- chiedono quando servono, con la rete. Le tappe di prima, con il posto di
-- OpenStreetMap, non hanno `place_id` e tengono quello che hanno.
--
-- - `place_id`: il posto di Google. Senza, il posto (se c'è) è nostro.
-- - `coordinate_il`: quando sono arrivate da Google le coordinate. Le
--   rinnova la funzione `mappe` prima dei 30 giorni (CR-06, passo 1); se
--   nessuno le ha rinnovate, di notte si tolgono, e la tappa resta senza
--   posto sulla mappa finché non si rinnovano.

alter table public.tappa
  add column place_id text check (char_length(place_id) between 1 and 300),
  add column coordinate_il timestamptz,
  -- Coordinate di Google senza la data non si saprebbe quando toglierle.
  add constraint coordinate_google_con_la_data
    check (place_id is null or lat is null or coordinate_il is not null);

-- ─── Trenta giorni, poi via ───────────────────────────────────────────────

-- Toglie le coordinate di Google più vecchie di 30 giorni. Restituisce
-- quante tappe ha toccato. Il `place_id` resta: le coordinate si possono
-- richiedere.
create or replace function privato.scadi_coordinate_google()
returns integer
language sql
security definer
set search_path = ''
as $$
  with scadute as (
    update public.tappa
       set lat = null, lon = null, coordinate_il = null
     where place_id is not null
       and coordinate_il is not null
       and coordinate_il < now() - interval '30 days'
    returning 1
  )
  select count(*)::integer from scadute;
$$;

revoke execute on function privato.scadi_coordinate_google() from public, anon, authenticated;

select cron.schedule(
  'scadi_coordinate_google',
  '15 3 * * *',
  $$select privato.scadi_coordinate_google()$$
);
