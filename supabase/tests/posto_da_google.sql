-- Prova del posto di una tappa cercato con Google (CR-06, ADR-014;
-- migrazione posto_da_google): il `place_id` si tiene, le coordinate di
-- Google hanno la data e dopo 30 giorni si tolgono; i posti di prima, senza
-- `place_id`, non si toccano.
--
-- Come le altre prove: gira dentro un blocco che alla fine solleva
-- un'eccezione e non lascia niente. Il messaggio finale è il resoconto.

do $$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  c uuid := gen_random_uuid();
  v uuid := gen_random_uuid();
  g1 uuid := gen_random_uuid();
  t_google uuid := gen_random_uuid();
  t_recente uuid := gen_random_uuid();
  t_osm uuid := gen_random_uuid();
  codice text;
  n int;
  fallita boolean;
  log text := '';
begin
  insert into auth.users (id, email) values
    (a, a || '@prova.local'), (b, b || '@prova.local'), (c, c || '@prova.local');

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (a, 'Giulia', '1995-04-02');
  perform public.crea_viaggio(v, 'Copenaghen', 'DK', null, '2026-11-20', '2026-11-20', '09:00', '22:00',
    jsonb_build_array(
      jsonb_build_object('id', g1, 'data', '2026-11-20', 'inizio', '09:00:00', 'fine', '22:00:00')));
  insert into public.invito (viaggio_id) values (v) returning token into codice;

  -- ── Il posto di Google: il place_id e le coordinate con la data ─────────
  insert into public.tappa (id, viaggio_id, giorno_id, ordine, titolo, durata_stimata_min,
                            place_id, lat, lon, coordinate_il)
  values (t_google, v, g1, 1, 'Rosenborg', 90,
          'ChIJ-rosenborg', 55.6858, 12.5770, now());
  select count(*) into n from public.tappa
   where id = t_google and place_id = 'ChIJ-rosenborg' and coordinate_il is not null;
  if n <> 1 then raise exception 'FALLITA: la tappa non tiene il posto di Google'; end if;
  log := log || E'\nok  una tappa tiene il place_id e le coordinate con la loro data';

  fallita := false;
  begin
    insert into public.tappa (viaggio_id, giorno_id, ordine, titolo, durata_stimata_min,
                              place_id, lat, lon)
    values (v, g1, 2, 'Senza data', 60, 'ChIJ-senza-data', 55.68, 12.57);
  exception when check_violation then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: coordinate di Google senza la data'; end if;
  log := log || E'\nok  coordinate di Google senza la data non entrano';

  fallita := false;
  begin
    insert into public.tappa (viaggio_id, giorno_id, ordine, titolo, durata_stimata_min, place_id)
    values (v, g1, 2, 'Id vuoto', 60, '');
  exception when check_violation then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un place_id vuoto'; end if;
  log := log || E'\nok  il place_id non è vuoto';

  -- Un place_id senza coordinate va bene: scadute, o non ancora chieste.
  insert into public.tappa (id, viaggio_id, giorno_id, ordine, titolo, durata_stimata_min,
                            place_id, lat, lon, coordinate_il)
  values (t_recente, v, g1, 2, 'Nyhavn', 60, 'ChIJ-nyhavn', 55.6798, 12.5911, now());
  -- Il posto di prima, da OpenStreetMap: nessun place_id, nessuna data.
  insert into public.tappa (id, viaggio_id, giorno_id, ordine, titolo, durata_stimata_min,
                            luogo_nome, lat, lon)
  values (t_osm, v, g1, 3, 'Torvehallerne', 60, 'Frederiksborggade 21', 55.6838, 12.5697);
  log := log || E'\nok  le tappe con il posto di prima restano come sono';

  -- ── Chi partecipa lo cambia, un estraneo no ──────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (b, 'Marco', '1994-07-20');
  perform public.accetta_invito(codice);
  update public.tappa set place_id = 'ChIJ-nyhavn-2', coordinate_il = now() where id = t_recente;
  select count(*) into n from public.tappa where id = t_recente and place_id = 'ChIJ-nyhavn-2';
  if n <> 1 then raise exception 'FALLITA: chi partecipa non cambia il posto di Google'; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (c, 'Teresa', '1990-01-01');
  update public.tappa set place_id = 'ChIJ-intruso' where id = t_google;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLITA: un estraneo cambia il posto di una tappa'; end if;
  log := log || E'\nok  il posto lo cambia chi partecipa, un estraneo no';

  -- ── Trenta giorni, poi via ──────────────────────────────────────────────
  if has_function_privilege('authenticated', 'privato.scadi_coordinate_google()', 'execute') then
    raise exception 'FALLITA: chi è entrato può togliere le coordinate di tutti';
  end if;
  log := log || E'\nok  le coordinate le toglie solo il lavoro di notte';

  perform set_config('role', 'postgres', true);
  -- Rosenborg arrivata 31 giorni fa; Nyhavn 29, appena sotto; Torvehallerne
  -- è di prima.
  update public.tappa set coordinate_il = now() - interval '31 days' where id = t_google;
  update public.tappa set coordinate_il = now() - interval '29 days' where id = t_recente;
  n := privato.scadi_coordinate_google();
  if n <> 1 then raise exception 'FALLITA: scadute % tappe invece di una', n; end if;
  select count(*) into n from public.tappa
   where id = t_google and lat is null and lon is null and coordinate_il is null
     and place_id = 'ChIJ-rosenborg';
  if n <> 1 then raise exception 'FALLITA: le coordinate di 31 giorni restano, o va via il place_id'; end if;
  select count(*) into n from public.tappa where id = t_recente and lat is not null;
  if n <> 1 then raise exception 'FALLITA: vanno via anche le coordinate di 29 giorni'; end if;
  select count(*) into n from public.tappa where id = t_osm and lat is not null and luogo_nome is not null;
  if n <> 1 then raise exception 'FALLITA: vanno via le coordinate di un posto di prima'; end if;
  log := log || E'\nok  dopo 30 giorni le coordinate di Google vanno via, il place_id resta';
  log := log || E'\nok  quelle di 29 giorni e i posti di prima restano';

  select count(*) into n from cron.job where jobname = 'scadi_coordinate_google';
  if n <> 1 then raise exception 'FALLITA: il lavoro di notte non è programmato'; end if;
  log := log || E'\nok  il lavoro è programmato ogni notte';

  raise exception 'TUTTE LE PROVE PASSATE (annullate)%', log;
end;
$$;
