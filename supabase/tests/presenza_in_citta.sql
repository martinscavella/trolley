-- Prova di chi c'è in città (5.5): la tabella solo dalle sue funzioni; si
-- accende solo con il profilo pubblico, per un viaggio in corso, dopo il «sul
-- posto» (C1); si vede solo chi l'ha accesa nella stessa città, in ordine di
-- nome (C8), senza fino a quando (C2), e i compagni di viaggio solo se
-- l'hanno accesa anche loro; il blocco nasconde; una presenza alla volta
-- (C7); cambiare le date, uscire dal viaggio, spegnere il profilo la
-- spengono, e una scaduta non si vede (C4); i dati scaricati; i privilegi.
--
-- Va lanciata dopo la migrazione presenza_in_citta.sql. Come le altre: gira
-- dentro un blocco che alla fine solleva un'eccezione e non lascia niente.
-- Il messaggio finale è il resoconto.
--
-- Giulia e Luca sono insieme a Porto; Marco è a Porto per conto suo; Elena è
-- a Lisbona. Hanno tutti il profilo pubblico acceso, tranne Carla.

do $$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  c uuid := gen_random_uuid();
  e uuid := gen_random_uuid();
  l uuid := gen_random_uuid();
  porto uuid := gen_random_uuid();
  braga uuid := gen_random_uuid();
  futuro uuid := gen_random_uuid();
  porto_marco uuid := gen_random_uuid();
  lisbona uuid := gen_random_uuid();
  carla_porto uuid := gen_random_uuid();
  oggi date := (now() at time zone 'utc')::date;
  codice text;
  r jsonb;
  n int;
  fallita boolean;
  log text := '';
begin
  insert into auth.users (id, email) values
    (a, a || '@prova.local'), (b, b || '@prova.local'), (c, c || '@prova.local'),
    (e, e || '@prova.local'), (l, l || '@prova.local');

  perform set_config('role', 'authenticated', true);

  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (a, 'Giulia', '1995-04-02');
  perform public.crea_viaggio(porto, 'Porto', 'PT', null, oggi - 1, oggi + 1,
    '10:00', '18:00', jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi - 1, 'inizio', '10:00', 'fine', '24:00'),
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi, 'inizio', '00:00', 'fine', '24:00'),
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi + 1, 'inizio', '00:00', 'fine', '18:00')));
  perform public.crea_viaggio(braga, 'Braga', 'PT', null, oggi, oggi,
    '10:00', '18:00', jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi, 'inizio', '10:00', 'fine', '18:00')));
  perform public.crea_viaggio(futuro, 'Madrid', 'ES', null, oggi + 10, oggi + 10,
    '10:00', '18:00', jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi + 10, 'inizio', '10:00', 'fine', '18:00')));
  insert into public.invito (viaggio_id) values (porto) returning token into codice;

  perform set_config('request.jwt.claims', json_build_object('sub', l, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (l, 'Luca', '1992-05-05');
  perform public.accetta_invito(codice);

  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (b, 'Marco', '1994-03-01');
  perform public.crea_viaggio(porto_marco, 'porto', 'PT', null, oggi, oggi + 3,
    '10:00', '18:00', jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi, 'inizio', '10:00', 'fine', '24:00'),
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi + 1, 'inizio', '00:00', 'fine', '24:00'),
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi + 2, 'inizio', '00:00', 'fine', '24:00'),
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi + 3, 'inizio', '00:00', 'fine', '18:00')));

  perform set_config('request.jwt.claims', json_build_object('sub', e, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (e, 'Elena', '1991-02-02');
  perform public.crea_viaggio(lisbona, 'Lisbona', 'PT', null, oggi, oggi,
    '10:00', '18:00', jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi, 'inizio', '10:00', 'fine', '18:00')));

  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (c, 'Carla', '1990-01-01');
  perform public.crea_viaggio(carla_porto, 'Porto', 'PT', null, oggi, oggi,
    '10:00', '18:00', jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi, 'inizio', '10:00', 'fine', '18:00')));
  perform public.segna_sul_posto(carla_porto);

  -- Il numero lo verificherebbe la funzione `telefono`: qui lo si dà per fatto.
  perform set_config('role', 'postgres', true);
  update public.utente set telefono_verificato = true where id in (a, b, e, l);
  perform moderazione.parte_pubblica('aperta');
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.attiva_profilo_pubblico('2026-10-09');
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  perform public.attiva_profilo_pubblico('2026-10-09');
  perform set_config('request.jwt.claims', json_build_object('sub', e, 'role', 'authenticated')::text, true);
  perform public.attiva_profilo_pubblico('2026-10-09');
  perform set_config('request.jwt.claims', json_build_object('sub', l, 'role', 'authenticated')::text, true);
  perform public.attiva_profilo_pubblico('2026-10-09');

  -- ── La tabella non si tocca ──────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform 1 from public.presenza_citta;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: le presenze si leggono dalla tabella'; end if;
  fallita := false;
  begin
    insert into public.presenza_citta (utente_id, viaggio_id, citta, paese, attiva_fino)
    values (a, porto, 'Porto', 'PT', oggi);
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: una presenza si scrive nella tabella'; end if;
  log := log || E'\nok  la presenza solo dalle sue funzioni (C5)';

  -- ── Si accende solo sul posto, con il profilo, per un viaggio in corso ───
  fallita := false;
  begin
    perform public.accendi_presenza(porto);
  exception when sqlstate 'TR425' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si accende prima del «sul posto»'; end if;
  fallita := false;
  begin
    perform public.accendi_presenza(futuro);
  exception when sqlstate 'TR422' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si accende per un viaggio non in corso'; end if;
  fallita := false;
  begin
    perform public.accendi_presenza(lisbona);
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si accende per il viaggio di un altro'; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform public.accendi_presenza(carla_porto);
  exception when sqlstate 'TR403' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si accende senza il profilo pubblico'; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.segna_sul_posto(porto);
  r := public.accendi_presenza(porto);
  if r ->> 'citta' <> 'Porto' or (r ->> 'fino')::date <> oggi + 1 then
    raise exception 'FALLITA: accesa, la presenza è %', r;
  end if;
  r := public.chi_ce_in_citta();
  if r -> 'mia' ->> 'citta' <> 'Porto' or jsonb_array_length(r -> 'altri') <> 0 then
    raise exception 'FALLITA: da sola, Giulia vede %', r;
  end if;
  log := log || E'\nok  si accende solo dopo il «sul posto», con il profilo, per un viaggio in corso (C1)';

  -- ── Si vede solo chi l'ha accesa, nella stessa città ─────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  r := public.chi_ce_in_citta();
  if r -> 'mia' <> 'null'::jsonb or jsonb_array_length(r -> 'altri') <> 0 then
    raise exception 'FALLITA: senza accenderla Marco vede %', r;
  end if;
  perform public.segna_sul_posto(porto_marco);
  perform public.accendi_presenza(porto_marco);
  perform set_config('request.jwt.claims', json_build_object('sub', e, 'role', 'authenticated')::text, true);
  perform public.segna_sul_posto(lisbona);
  perform public.accendi_presenza(lisbona);

  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  r := public.chi_ce_in_citta();
  if (r -> 'mia' ->> 'fino')::date <> oggi + 3 or jsonb_array_length(r -> 'altri') <> 1
     or r -> 'altri' -> 0 ->> 'nome' <> 'Giulia' then
    raise exception 'FALLITA: a Porto Marco vede %', r;
  end if;
  if r -> 'altri' -> 0 ? 'fino' or r -> 'altri' -> 0 ? 'attiva_fino'
     or r -> 'altri' -> 0 ? 'viaggio_id' then
    raise exception 'FALLITA: di Giulia si legge fino a quando: %', r -> 'altri' -> 0;
  end if;
  perform set_config('request.jwt.claims', json_build_object('sub', e, 'role', 'authenticated')::text, true);
  if jsonb_array_length(public.chi_ce_in_citta() -> 'altri') <> 0 then
    raise exception 'FALLITA: da Lisbona si vede Porto';
  end if;
  log := log || E'\nok  si vede solo chi l''ha accesa nella stessa città, senza fino a quando (C2)';

  -- ── I compagni solo se l'accendono; in ordine di nome ────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  r := public.chi_ce_in_citta();
  if jsonb_array_length(r -> 'altri') <> 1 or r -> 'altri' -> 0 ->> 'nome' <> 'Marco' then
    raise exception 'FALLITA: Giulia vede %, e Luca non l''ha accesa', r -> 'altri';
  end if;
  perform set_config('request.jwt.claims', json_build_object('sub', l, 'role', 'authenticated')::text, true);
  perform public.segna_sul_posto(porto);
  perform public.accendi_presenza(porto);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  r := public.chi_ce_in_citta();
  if jsonb_array_length(r -> 'altri') <> 2 or r -> 'altri' -> 0 ->> 'nome' <> 'Luca'
     or r -> 'altri' -> 1 ->> 'nome' <> 'Marco' then
    raise exception 'FALLITA: l''ordine di nome è %', r -> 'altri';
  end if;
  log := log || E'\nok  i compagni di viaggio solo se l''accendono; in ordine di nome (C8)';

  -- ── A che punto si è; il blocco nasconde ─────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  perform public.chiedi_collegamento(a, 'Anche tu a Porto!');
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  r := public.chi_ce_in_citta() -> 'altri' -> 1;
  if r -> 'collegamento' ->> 'stato' <> 'ricevuta' or r -> 'collegamento' ? 'messaggio' then
    raise exception 'FALLITA: la riga di Marco dice %', r -> 'collegamento';
  end if;
  perform public.blocca(b);
  if jsonb_array_length(public.chi_ce_in_citta() -> 'altri') <> 1 then
    raise exception 'FALLITA: chi blocca vede ancora Marco';
  end if;
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  r := public.chi_ce_in_citta() -> 'altri';
  if jsonb_array_length(r) <> 1 or r -> 0 ->> 'nome' <> 'Luca' then
    raise exception 'FALLITA: il bloccato vede ancora Giulia: %', r;
  end if;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.sblocca(b);
  log := log || E'\nok  ogni riga dice a che punto si è; il blocco nasconde nei due versi';

  -- ── Una presenza alla volta ──────────────────────────────────────────────
  perform public.segna_sul_posto(braga);
  r := public.accendi_presenza(braga);
  perform set_config('role', 'postgres', true);
  select count(*) into n from public.presenza_citta where utente_id = a;
  if n <> 1 or (select citta from public.presenza_citta where utente_id = a) <> 'Braga' then
    raise exception 'FALLITA: Giulia ha % presenze', n;
  end if;
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  if exists (select 1 from jsonb_array_elements(public.chi_ce_in_citta() -> 'altri') x
              where x ->> 'nome' = 'Giulia') then
    raise exception 'FALLITA: accesa a Braga, Giulia si vede ancora a Porto';
  end if;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.accendi_presenza(porto);
  log := log || E'\nok  una presenza alla volta: accenderne un''altra la sostituisce (C7)';

  -- ── Si spegne da sola ────────────────────────────────────────────────────
  perform set_config('role', 'postgres', true);
  update public.viaggio set data_fine = data_fine + 1 where id = porto_marco;
  if exists (select 1 from public.presenza_citta where utente_id = b) then
    raise exception 'FALLITA: cambiate le date, la presenza di Marco resta';
  end if;
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', l, 'role', 'authenticated')::text, true);
  perform public.esci_dal_viaggio(porto);
  perform set_config('request.jwt.claims', json_build_object('sub', e, 'role', 'authenticated')::text, true);
  perform public.spegni_profilo_pubblico();
  perform set_config('role', 'postgres', true);
  select count(*) into n from public.presenza_citta where utente_id in (l, e);
  if n <> 0 then raise exception 'FALLITA: restano % presenze di chi è uscito o ha spento', n; end if;
  -- Una scaduta, prima che la cancellazione passi, non si vede.
  insert into public.presenza_citta (utente_id, viaggio_id, citta, paese, attiva_fino)
  values (b, porto_marco, 'porto', 'PT', oggi - 1);
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  if jsonb_array_length(public.chi_ce_in_citta() -> 'altri') <> 0 then
    raise exception 'FALLITA: si vede una presenza scaduta o di chi è uscito: %', public.chi_ce_in_citta();
  end if;
  log := log || E'\nok  cambiare le date, uscire, spegnere il profilo la spengono; scaduta non si vede (C4)';

  -- ── I dati scaricati; spegnere ───────────────────────────────────────────
  r := public.i_miei_dati();
  if (r ->> 'versione')::int < 5 or r -> 'presenza_in_citta' ->> 'citta' <> 'Porto' then
    raise exception 'FALLITA: i dati di Giulia non hanno la presenza: %', r -> 'presenza_in_citta';
  end if;
  perform public.spegni_presenza();
  if public.chi_ce_in_citta() -> 'mia' <> 'null'::jsonb
     or public.i_miei_dati() -> 'presenza_in_citta' <> 'null'::jsonb then
    raise exception 'FALLITA: spenta, la presenza resta';
  end if;
  log := log || E'\nok  i dati scaricati hanno la presenza; spenta, sparisce';

  -- ── I privilegi ──────────────────────────────────────────────────────────
  perform set_config('role', 'postgres', true);
  if has_function_privilege('anon', 'public.accendi_presenza(uuid)', 'execute')
     or has_function_privilege('anon', 'public.chi_ce_in_citta()', 'execute')
     or has_function_privilege('anon', 'public.spegni_presenza()', 'execute')
     or has_function_privilege('authenticated', 'privato.presenza_vale(public.presenza_citta)', 'execute')
     or has_table_privilege('authenticated', 'public.presenza_citta', 'select')
     or has_table_privilege('anon', 'public.presenza_citta', 'select') then
    raise exception 'FALLITA: un privilegio di troppo';
  end if;
  log := log || E'\nok  niente per anon, e la tabella resta chiusa';

  raise exception 'PASSATE%', log;
end;
$$;
