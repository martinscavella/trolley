-- Prova del rinnovo delle coordinate di Google (CR-06, ADR-014; migrazione
-- rinnovo_coordinate): quali tappe si rinnovano, chi può rinnovarle, e che
-- rinnovarle o toglierle non è una modifica — niente versione nuova, niente
-- autore nuovo — mentre ogni altra modifica lo resta.
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
  t_vecchia uuid := gen_random_uuid();
  t_fresca uuid := gen_random_uuid();
  t_tolta uuid := gen_random_uuid();
  t_osm uuid := gen_random_uuid();
  t_eliminata uuid := gen_random_uuid();
  codice text;
  n int;
  ver int;
  il timestamptz;
  autore uuid;
  ids uuid[];
  fallita boolean;
  log text := '';
begin
  insert into auth.users (id, email) values
    (a, a || '@prova.local'), (b, b || '@prova.local'), (c, c || '@prova.local');

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (a, 'Giulia', '1995-04-02');
  perform public.crea_viaggio(v, 'Copenaghen', 'DK', null, '2026-12-20', '2026-12-22', '09:00', '22:00',
    jsonb_build_array(
      jsonb_build_object('id', g1, 'data', '2026-12-20', 'inizio', '09:00:00', 'fine', '22:00:00')));
  insert into public.invito (viaggio_id) values (v) returning token into codice;

  insert into public.tappa (id, viaggio_id, giorno_id, ordine, titolo, durata_stimata_min,
                            place_id, lat, lon, coordinate_il) values
    (t_vecchia, v, g1, 1, 'Rosenborg', 90, 'ChIJ-rosenborg', 55.6858, 12.5770, now()),
    (t_fresca, v, g1, 2, 'Nyhavn', 60, 'ChIJ-nyhavn', 55.6798, 12.5911, now()),
    (t_tolta, v, g1, 3, 'Tivoli', 120, 'ChIJ-tivoli', null, null, null),
    (t_eliminata, v, g1, 5, 'Tolta', 30, 'ChIJ-tolta', 55.68, 12.57, now());
  insert into public.tappa (id, viaggio_id, giorno_id, ordine, titolo, durata_stimata_min,
                            luogo_nome, lat, lon)
  values (t_osm, v, g1, 4, 'Torvehallerne', 60, 'Frederiksborggade 21', 55.6838, 12.5697);
  update public.tappa set eliminato_il = now(), versione = versione where id = t_eliminata;

  -- Rosenborg arrivata 25 giorni fa; Nyhavn e la tolta di oggi.
  perform set_config('role', 'postgres', true);
  update public.tappa set coordinate_il = now() - interval '25 days' where id = t_vecchia;
  update public.tappa set coordinate_il = now() - interval '25 days' where id = t_eliminata;
  perform set_config('role', 'authenticated', true);

  -- ── Quali rinnovare ─────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (b, 'Marco', '1994-07-20');
  perform public.accetta_invito(codice);

  select array_agg(r.id) into ids from public.coordinate_da_rinnovare(v, 20) r;
  if ids is distinct from array[t_tolta, t_vecchia] then
    raise exception 'FALLITA: da rinnovare % invece della tolta e di quella di 25 giorni', ids;
  end if;
  log := log || E'\nok  si rinnovano le coordinate tolte, poi le più vecchie dei giorni chiesti';
  log := log || E'\nok  non quelle di oggi, non i posti di prima, non le tappe tolte';

  select count(*) into n from public.coordinate_da_rinnovare(v, 26);
  if n <> 1 then raise exception 'FALLITA: con 26 giorni se ne rinnovano %', n; end if;
  select count(*) into n from public.coordinate_da_rinnovare(v, 0);
  if n <> 2 then raise exception 'FALLITA: con 0 giorni (vale 1) se ne rinnovano %', n; end if;
  log := log || E'\nok  i giorni vanno da 1 a 29';

  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (c, 'Teresa', '1990-01-01');
  select count(*) into n from public.coordinate_da_rinnovare(v, 20);
  if n <> 0 then raise exception 'FALLITA: un estraneo vede le tappe da rinnovare'; end if;
  select count(*) into n from public.rinnova_coordinate(v, jsonb_build_array(
    jsonb_build_object('id', t_tolta, 'place_id', 'ChIJ-tivoli', 'nuovo', 'ChIJ-tivoli',
                       'lat', 1, 'lon', 1)));
  if n <> 0 then raise exception 'FALLITA: un estraneo rinnova le coordinate'; end if;
  log := log || E'\nok  un estraneo non vede e non rinnova';

  if has_function_privilege('anon', 'public.rinnova_coordinate(uuid, jsonb)', 'execute')
     or has_function_privilege('anon', 'public.coordinate_da_rinnovare(uuid, integer)', 'execute') then
    raise exception 'FALLITA: chi non è entrato può chiedere il rinnovo';
  end if;
  log := log || E'\nok  chi non è entrato non le chiama';

  -- ── Rinnovarle non è una modifica ───────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  select t.versione, t.modificato_il, t.modificato_da into ver, il, autore
    from public.tappa t where t.id = t_vecchia;

  select array_agg(r.id) into ids from public.rinnova_coordinate(v, jsonb_build_array(
    -- Google ha rinnovato anche il place_id.
    jsonb_build_object('id', t_vecchia, 'place_id', 'ChIJ-rosenborg', 'nuovo', 'ChIJ-rosenborg-2',
                       'lat', 55.6859, 'lon', 12.5771),
    -- Di oggi: non si riscrive.
    jsonb_build_object('id', t_fresca, 'place_id', 'ChIJ-nyhavn', 'nuovo', 'ChIJ-nyhavn',
                       'lat', 1, 'lon', 1),
    -- Il posto intanto è cambiato: vince chi l'ha cambiato.
    jsonb_build_object('id', t_tolta, 'place_id', 'ChIJ-altro', 'nuovo', 'ChIJ-altro',
                       'lat', 1, 'lon', 1),
    -- Tolta: non si rinnova.
    jsonb_build_object('id', t_eliminata, 'place_id', 'ChIJ-tolta', 'nuovo', 'ChIJ-tolta',
                       'lat', 1, 'lon', 1),
    -- Fuori dal mondo.
    jsonb_build_object('id', t_osm, 'place_id', null, 'nuovo', 'x', 'lat', 200, 'lon', 1))) r;
  if ids is distinct from array[t_vecchia] then
    raise exception 'FALLITA: rinnovate % invece della sola di 25 giorni', ids;
  end if;
  log := log || E'\nok  si rinnova solo la tappa che ha ancora quel posto, non tolta, di più di un giorno';

  select count(*) into n from public.tappa t
   where t.id = t_vecchia and t.place_id = 'ChIJ-rosenborg-2' and t.lat = 55.6859
     and t.lon = 12.5771 and t.coordinate_il > now() - interval '1 minute';
  if n <> 1 then raise exception 'FALLITA: le coordinate rinnovate non ci sono'; end if;
  log := log || E'\nok  le coordinate nuove hanno la data di adesso, e il place_id di Google';

  select count(*) into n from public.tappa t
   where t.id = t_vecchia and t.versione = ver and t.modificato_il = il
     and t.modificato_da is not distinct from autore;
  if n <> 1 then raise exception 'FALLITA: rinnovare fa una versione nuova, o cambia chi l''ha scritta'; end if;
  log := log || E'\nok  rinnovare non fa una versione nuova e non cambia chi l''ha scritta';

  select count(*) into n from public.tappa t where t.id = t_fresca and t.lat = 55.6798;
  if n <> 1 then raise exception 'FALLITA: riscritte le coordinate di oggi'; end if;

  -- ── Le altre modifiche restano modifiche ────────────────────────────────
  perform set_config('trolley.solo_coordinate', 'on', true);
  update public.tappa set titolo = 'Rosenborg Slot', lat = 1 where id = t_vecchia;
  perform set_config('trolley.solo_coordinate', 'off', true);
  select count(*) into n from public.tappa t
   where t.id = t_vecchia and t.versione = ver + 1 and t.modificato_da = b;
  if n <> 1 then raise exception 'FALLITA: con il segnale acceso un titolo cambia senza versione'; end if;
  log := log || E'\nok  anche col segnale acceso, cambiare altro fa una versione nuova e la firma';

  update public.tappa set lat = 2 where id = t_vecchia;
  select count(*) into n from public.tappa t where t.id = t_vecchia and t.versione = ver + 2;
  if n <> 1 then raise exception 'FALLITA: senza segnale le coordinate cambiano senza versione'; end if;
  log := log || E'\nok  senza segnale anche le coordinate fanno una versione nuova';

  fallita := false;
  begin
    update public.tappa set titolo = 'Vecchia', versione = ver where id = t_vecchia;
  exception when sqlstate 'TR409' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: passa una modifica su una versione superata'; end if;
  log := log || E'\nok  una modifica su una versione superata resta rifiutata';

  fallita := false;
  begin
    perform public.rinnova_coordinate(v, (select jsonb_agg(jsonb_build_object('id', gen_random_uuid()))
                                            from generate_series(1, 51)));
  exception when invalid_parameter_value then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: più di 50 rinnovi in una volta'; end if;
  fallita := false;
  begin
    perform public.rinnova_coordinate(v, '{}'::jsonb);
  exception when invalid_parameter_value then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: rinnovi che non sono un elenco'; end if;
  log := log || E'\nok  al massimo 50 alla volta, in un elenco';

  -- ── Trenta giorni, poi via: neanche togliere è una modifica ─────────────
  perform set_config('role', 'postgres', true);
  update public.tappa set coordinate_il = now() - interval '31 days' where id = t_vecchia;
  select t.versione, t.modificato_il, t.modificato_da into ver, il, autore
    from public.tappa t where t.id = t_vecchia;
  n := privato.scadi_coordinate_google();
  if n <> 1 then raise exception 'FALLITA: scadute % tappe invece di una', n; end if;
  select count(*) into n from public.tappa t
   where t.id = t_vecchia and t.lat is null and t.coordinate_il is null
     and t.versione = ver and t.modificato_il = il and t.modificato_da is not distinct from autore;
  if n <> 1 then raise exception 'FALLITA: togliere le coordinate fa una versione nuova'; end if;
  if current_setting('trolley.solo_coordinate', true) = 'on' then
    raise exception 'FALLITA: il segnale resta acceso dopo il lavoro di notte';
  end if;
  log := log || E'\nok  il lavoro di notte le toglie senza fare una versione nuova';

  -- ── Un viaggio chiuso non ne ha bisogno ─────────────────────────────────
  perform set_config('trolley.chiusura', 'si', true);
  update public.viaggio set stato = 'chiuso' where id = v;
  perform set_config('trolley.chiusura', '', true);
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  select count(*) into n from public.coordinate_da_rinnovare(v, 1);
  if n <> 0 then raise exception 'FALLITA: si rinnovano le coordinate di un viaggio chiuso'; end if;
  log := log || E'\nok  le tappe di un viaggio chiuso non si rinnovano';

  raise exception 'TUTTE LE PROVE PASSATE (annullate)%', log;
end;
$$;
