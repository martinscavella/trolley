-- Prova del profilo pubblico e della ricerca (5.3): i gusti dalla lista
-- chiusa e solo dalla loro funzione; sul profilo solo i viaggi chiusi e
-- finiti, non nascosti, senza date né compagni; chi guarda si fa guardare;
-- il blocco e la sospensione nascondono nei due versi; la ricerca per meta e
-- per gusti, mai senza criteri, con il tetto; la parte pubblica chiusa; i
-- dati scaricati e la lapide.
--
-- Va lanciata dopo la migrazione profilo_pubblico.sql. Come le altre: gira
-- dentro un blocco che alla fine solleva un'eccezione e non lascia niente.
-- Il messaggio finale è il resoconto.
--
-- Giulia, Marco ed Elena sono maggiorenni con il numero verificato; Sara ha
-- 17 anni; Dario è del team. Sul server vero ci sono anche le persone vere:
-- dei risultati di una ricerca si guardano solo quelle della prova.

do $$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  c uuid := gen_random_uuid();
  d uuid := gen_random_uuid();
  e uuid := gen_random_uuid();
  kyoto uuid := gen_random_uuid();
  lisbona uuid := gen_random_uuid();
  porto uuid := gen_random_uuid();
  futuro uuid := gen_random_uuid();
  barcellona uuid := gen_random_uuid();
  kyoto_marco uuid := gen_random_uuid();
  osaka uuid := gen_random_uuid();
  oggi date := current_date;
  nostri uuid[];
  p jsonb;
  r jsonb;
  g text[];
  n int;
  fallita boolean;
  log text := '';
begin
  nostri := array[a, b, c, d, e];
  insert into auth.users (id, email) values
    (a, a || '@prova.local'), (b, b || '@prova.local'), (c, c || '@prova.local'),
    (d, d || '@prova.local'), (e, e || '@prova.local');

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (a, 'Giulia', '1995-04-02');
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (b, 'Marco', '1994-03-01');
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita)
  values (c, 'Sara', current_date - interval '17 years');
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (d, 'Dario', '1990-01-01');
  perform set_config('request.jwt.claims', json_build_object('sub', e, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (e, 'Elena', '1991-02-02');

  -- Il numero lo verificherebbe la funzione `telefono`: qui lo si dà per fatto.
  perform set_config('role', 'postgres', true);
  update public.utente set telefono_verificato = true where id in (a, b, d, e);
  update public.utente set interno = true where id = d;
  perform moderazione.parte_pubblica('aperta');
  perform set_config('role', 'authenticated', true);

  -- ── I viaggi di Giulia ───────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  -- Kyoto: finito ieri, sul posto, chiuso, verificato, con un traguardo.
  perform public.crea_viaggio(kyoto, 'Kyoto', 'JP', null, oggi - 2, oggi - 1,
    '10:00', '18:00', jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi - 2, 'inizio', '10:00', 'fine', '24:00'),
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi - 1, 'inizio', '00:00', 'fine', '18:00')));
  perform public.segna_sul_posto(kyoto);
  perform public.chiudi_viaggio(kyoto);
  perform public.segna_verifica(kyoto, true);
  perform public.prendi_traguardi(kyoto, array['primo_viaggio_verificato']);
  -- Lisbona: finita, chiusa, e poi nascosta dal profilo.
  perform public.crea_viaggio(lisbona, 'Lisbona', 'PT', null, oggi - 10, oggi - 9,
    '10:00', '18:00', jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi - 10, 'inizio', '10:00', 'fine', '24:00'),
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi - 9, 'inizio', '00:00', 'fine', '18:00')));
  perform public.chiudi_viaggio(lisbona);
  -- Porto: in corso, chiuso a mano prima della fine da chi ne è responsabile.
  perform public.crea_viaggio(porto, 'Porto', 'PT', null, oggi - 1, oggi + 1,
    '10:00', '18:00', jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi - 1, 'inizio', '10:00', 'fine', '24:00'),
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi, 'inizio', '00:00', 'fine', '24:00'),
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi + 1, 'inizio', '00:00', 'fine', '18:00')));
  perform public.chiudi_viaggio(porto);
  -- Un viaggio in programma, e uno passato aggiunto a mano.
  perform public.crea_viaggio(futuro, 'Oslo', 'NO', null, oggi + 10, oggi + 11,
    '10:00', '18:00', jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi + 10, 'inizio', '10:00', 'fine', '24:00'),
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi + 11, 'inizio', '00:00', 'fine', '18:00')));
  perform public.aggiungi_viaggio_passato(barcellona, 'Barcellona', 'ES', 'agosto 2019', 5::smallint);

  -- ── I gusti: dalla lista, una volta, solo dalla loro funzione ────────────
  g := public.scegli_gusti(array['panorami', 'cibo', 'cibo']);
  if g <> array['cibo', 'panorami'] then
    raise exception 'FALLITA: i gusti non sono quelli della lista, in ordine (%)', g;
  end if;
  fallita := false;
  begin
    perform public.scegli_gusti(array['cibo', 'religione']);
  exception when sqlstate '22023' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un gusto fuori dalla lista passa'; end if;
  fallita := false;
  begin
    update public.utente set gusti = array['arte'] where id = a;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: i gusti si scrivono a mano'; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform gusti from public.utente where id = a;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: i gusti degli altri si leggono dalla tabella'; end if;
  log := log || E'\nok  gusti dalla lista chiusa, solo da scegli_gusti, illeggibili agli altri';

  -- ── I viaggi sul profilo ─────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.mostra_sul_profilo(lisbona, false);
  perform public.mostra_sul_profilo(lisbona, false);
  p := public.il_mio_profilo_pubblico();
  if (p ->> 'attivo')::boolean then
    raise exception 'FALLITA: il profilo risulta acceso prima di accenderlo';
  end if;
  select count(*) into n from jsonb_array_elements(p -> 'tutti_i_viaggi');
  if n <> 3 then
    raise exception 'FALLITA: i viaggi che possono stare sul profilo sono % e non 3: %', n, p -> 'tutti_i_viaggi';
  end if;
  if exists (select 1 from jsonb_array_elements(p -> 'tutti_i_viaggi') v
              where (v ->> 'viaggio_id')::uuid in (porto, futuro)) then
    raise exception 'FALLITA: un viaggio in corso o in programma può stare sul profilo';
  end if;
  if not exists (select 1 from jsonb_array_elements(p -> 'tutti_i_viaggi') v
                  where (v ->> 'viaggio_id')::uuid = lisbona
                    and not (v ->> 'sul_profilo')::boolean) then
    raise exception 'FALLITA: Lisbona nascosta non risulta nascosta';
  end if;
  select count(*) into n from jsonb_array_elements(p -> 'viaggi');
  if n <> 2 then raise exception 'FALLITA: sul profilo % viaggi e non 2', n; end if;
  fallita := false;
  begin
    perform public.mostra_sul_profilo(osaka, false);
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si sceglie su un viaggio non proprio'; end if;
  log := log || E'\nok  sul profilo solo chiusi e finiti, non i chiusi prima della fine; si nascondono uno per uno';

  -- ── Chi guarda si fa guardare ────────────────────────────────────────────
  perform public.attiva_profilo_pubblico('2026-10-09');
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  perform public.scegli_gusti(array['cibo', 'natura']);
  perform public.crea_viaggio(kyoto_marco, 'Kyoto', 'JP', null, oggi - 5, oggi - 4,
    '10:00', '18:00', jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi - 5, 'inizio', '10:00', 'fine', '24:00'),
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi - 4, 'inizio', '00:00', 'fine', '18:00')));
  perform public.chiudi_viaggio(kyoto_marco);
  fallita := false;
  begin
    perform public.profilo_pubblico(a);
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: con il profilo spento si vedono gli altri'; end if;
  fallita := false;
  begin
    perform public.cerca_viaggiatori('JP', null, '{}');
  exception when sqlstate 'TR403' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: con il profilo spento si cerca'; end if;

  perform public.attiva_profilo_pubblico('2026-10-09');
  p := public.profilo_pubblico(a);
  if p ->> 'nome' <> 'Giulia' or p -> 'gusti' <> '["cibo", "panorami"]'::jsonb
     or (p ->> 'traguardi')::int <> 1
     or (p ->> 'dal')::date <> date_trunc('month', current_date)::date then
    raise exception 'FALLITA: il profilo di Giulia è %', p;
  end if;
  select count(*) into n from jsonb_array_elements(p -> 'viaggi');
  if n <> 2 then raise exception 'FALLITA: Marco vede % viaggi di Giulia: %', n, p -> 'viaggi'; end if;
  r := (select v from jsonb_array_elements(p -> 'viaggi') v where v ->> 'citta' = 'Kyoto');
  if r is null or (r ->> 'mese')::date <> date_trunc('month', oggi - 2)::date
     or (r ->> 'giorni')::int <> 2 or not (r ->> 'verificato')::boolean
     or (r ->> 'importato')::boolean then
    raise exception 'FALLITA: Kyoto sul profilo è %', r;
  end if;
  if exists (select 1 from jsonb_array_elements(p -> 'viaggi') v, jsonb_object_keys(v) k
              where k not in ('citta', 'paese', 'mese', 'periodo', 'giorni', 'verificato', 'importato')) then
    raise exception 'FALLITA: del viaggio esce più di meta, mese e giorni: %', p -> 'viaggi';
  end if;
  r := (select v from jsonb_array_elements(p -> 'viaggi') v where v ->> 'citta' = 'Barcellona');
  if r is null or r ->> 'periodo' <> 'agosto 2019' or (r ->> 'giorni')::int <> 5
     or not (r ->> 'importato')::boolean or (r ->> 'verificato')::boolean then
    raise exception 'FALLITA: Barcellona importata sul profilo è %', r;
  end if;
  if p ? 'tutti_i_viaggi' or p ? 'attivo' then
    raise exception 'FALLITA: il profilo altrui dice anche le scelte di Giulia';
  end if;
  log := log || E'\nok  chi guarda si fa guardare; del viaggio solo meta, mese, giorni, verificato, importato';

  -- ── La ricerca ───────────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', e, 'role', 'authenticated')::text, true);
  perform public.scegli_gusti(array['arte', 'cibo']);
  perform public.crea_viaggio(osaka, 'Osaka', 'JP', null, oggi - 6, oggi - 5,
    '10:00', '18:00', jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi - 6, 'inizio', '10:00', 'fine', '24:00'),
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi - 5, 'inizio', '00:00', 'fine', '18:00')));
  perform public.chiudi_viaggio(osaka);
  perform public.attiva_profilo_pubblico('2026-10-09');

  fallita := false;
  begin
    perform public.cerca_viaggiatori(null, null, '{}');
  exception when sqlstate '22023' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: senza criteri si vedono tutti'; end if;
  fallita := false;
  begin
    perform public.cerca_viaggiatori(null, 'Kyoto', '{}');
  exception when sqlstate '22023' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: una città si cerca senza il paese'; end if;
  fallita := false;
  begin
    perform public.cerca_viaggiatori('JP', null, array['religione']);
  exception when sqlstate '22023' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si cerca per un gusto fuori dalla lista'; end if;

  r := (select coalesce(jsonb_agg(x order by i), '[]'::jsonb) from jsonb_array_elements(public.cerca_viaggiatori('jp', null, '{}')) with ordinality s(x, i) where (x ->> 'id')::uuid = any (nostri));
  if jsonb_array_length(r) <> 2
     or exists (select 1 from jsonb_array_elements(r) x where (x ->> 'id')::uuid = e) then
    raise exception 'FALLITA: in Giappone Elena trova %', r;
  end if;
  r := (select coalesce(jsonb_agg(x order by i), '[]'::jsonb) from jsonb_array_elements(public.cerca_viaggiatori('JP', 'kyoto', array['cibo'])) with ordinality s(x, i) where (x ->> 'id')::uuid = any (nostri));
  if jsonb_array_length(r) <> 2 then
    raise exception 'FALLITA: a Kyoto con il cibo Elena trova %', r;
  end if;
  -- A parità di gusti in comune, prima chi è stato lì più di recente: Giulia.
  if (r -> 0 ->> 'id')::uuid <> a then
    raise exception 'FALLITA: l''ordine dei risultati è %', r;
  end if;
  r := (select coalesce(jsonb_agg(x order by i), '[]'::jsonb) from jsonb_array_elements(public.cerca_viaggiatori(null, null, array['natura'])) with ordinality s(x, i) where (x ->> 'id')::uuid = any (nostri));
  if jsonb_array_length(r) <> 1 or (r -> 0 ->> 'id')::uuid <> b then
    raise exception 'FALLITA: per la natura Elena trova %', r;
  end if;
  r := (select coalesce(jsonb_agg(x order by i), '[]'::jsonb) from jsonb_array_elements(public.cerca_viaggiatori('PT', null, '{}')) with ordinality s(x, i) where (x ->> 'id')::uuid = any (nostri));
  if jsonb_array_length(r) <> 0 then
    raise exception 'FALLITA: un viaggio nascosto o chiuso prima della fine si trova: %', r;
  end if;
  if exists (select 1 from jsonb_array_elements(public.cerca_viaggiatori('JP', null, '{}')) x
              where x ? 'tutti_i_viaggi' or x ? 'attivo') then
    raise exception 'FALLITA: la ricerca dice le scelte degli altri';
  end if;
  log := log || E'\nok  si cerca per meta e gusti, mai senza criteri; nascosti e in corso non si trovano';

  -- ── Il tetto delle ricerche ──────────────────────────────────────────────
  -- Le ricerche rifiutate per un criterio sbagliato non contano: il tetto
  -- diventa quante ne ha fatte Elena finora, e la prossima si ferma.
  perform set_config('role', 'postgres', true);
  select quante into n from privato.ricerca_viaggiatori
   where utente_id = e and giorno = current_date;
  if n <> 5 then raise exception 'FALLITA: contate % ricerche e non 5', n; end if;
  update public.configurazione set valore = to_jsonb(n) where chiave = 'tetto_ricerca';
  perform set_config('role', 'authenticated', true);
  fallita := false;
  begin
    perform public.cerca_viaggiatori('JP', null, '{}');
  exception when sqlstate 'TR429' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: oltre il tetto del giorno si cerca'; end if;
  perform set_config('role', 'postgres', true);
  update public.configurazione set valore = '60' where chiave = 'tetto_ricerca';
  perform set_config('role', 'authenticated', true);
  log := log || E'\nok  il tetto ferma le ricerche oltre il numero del giorno';

  -- ── Il blocco nasconde nei due versi ─────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.blocca(e);
  fallita := false;
  begin
    perform public.profilo_pubblico(e);
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: chi blocca vede ancora il bloccato'; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', e, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform public.profilo_pubblico(a);
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: il bloccato vede chi l''ha bloccato'; end if;
  r := (select coalesce(jsonb_agg(x order by i), '[]'::jsonb) from jsonb_array_elements(public.cerca_viaggiatori('JP', null, '{}')) with ordinality s(x, i) where (x ->> 'id')::uuid = any (nostri));
  if exists (select 1 from jsonb_array_elements(r) x where (x ->> 'id')::uuid = a) then
    raise exception 'FALLITA: il bloccato trova chi l''ha bloccato';
  end if;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.sblocca(e);
  log := log || E'\nok  il blocco nasconde profili e ricerca nei due versi';

  -- ── Spento, sospeso, o con la parte pubblica chiusa: non c'è ─────────────
  perform public.spegni_profilo_pubblico();
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform public.profilo_pubblico(a);
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un profilo spento si vede'; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.attiva_profilo_pubblico('2026-10-09');

  perform set_config('role', 'postgres', true);
  update public.utente
     set profilo_pubblico_attivo = false, sospeso_il = now(), sospensione_motivo = 'Regola 3'
   where id = a;
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  if jsonb_array_length((select coalesce(jsonb_agg(x order by i), '[]'::jsonb) from jsonb_array_elements(public.cerca_viaggiatori(null, null, array['panorami', 'cibo'])) with ordinality s(x, i) where (x ->> 'id')::uuid = any (nostri))) <> 1 then
    raise exception 'FALLITA: un profilo sospeso si trova';
  end if;
  perform set_config('role', 'postgres', true);
  update public.utente set sospeso_il = null, sospensione_motivo = null where id = a;
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.attiva_profilo_pubblico('2026-10-09');

  -- Chiusa: Marco non cerca più; Dario, del team, vede solo il team.
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  perform public.scegli_gusti(array['cibo']);
  perform public.attiva_profilo_pubblico('2026-10-09');
  perform set_config('role', 'postgres', true);
  perform moderazione.parte_pubblica('chiusa');
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform public.cerca_viaggiatori(null, null, array['cibo']);
  exception when sqlstate 'TR403' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: con la parte pubblica chiusa si cerca'; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  if jsonb_array_length((select coalesce(jsonb_agg(x order by i), '[]'::jsonb) from jsonb_array_elements(public.cerca_viaggiatori(null, null, array['cibo'])) with ordinality s(x, i) where (x ->> 'id')::uuid = any (nostri))) <> 0 then
    raise exception 'FALLITA: con la parte chiusa il team trova chi non è del team';
  end if;
  perform set_config('role', 'postgres', true);
  perform moderazione.parte_pubblica('aperta');
  perform set_config('role', 'authenticated', true);
  log := log || E'\nok  spento, sospeso o con la parte pubblica chiusa non si vede né si trova';

  -- ── Sotto i 18 anni niente ───────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform public.cerca_viaggiatori(null, null, array['cibo']);
  exception when sqlstate 'TR403' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: chi ha 17 anni cerca'; end if;
  log := log || E'\nok  sotto i 18 anni non si cerca';

  -- ── I dati scaricati e la lapide ─────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', e, 'role', 'authenticated')::text, true);
  perform public.mostra_sul_profilo(osaka, false);
  r := public.i_miei_dati();
  if (r ->> 'versione')::int <> 3 or r -> 'profilo' -> 'gusti' <> '["arte", "cibo"]'::jsonb
     or jsonb_array_length(r -> 'profilo_pubblico' -> 'tutti_i_viaggi') <> 1 then
    raise exception 'FALLITA: i dati di Elena non hanno gusti e scelte: % / %',
      r -> 'profilo', r -> 'profilo_pubblico';
  end if;
  perform public.chiudi_account(true);
  perform set_config('role', 'postgres', true);
  select gusti into g from public.utente where id = e;
  select count(*) into n from privato.fuori_dal_profilo where utente_id = e;
  if g <> '{}' or n <> 0 then
    raise exception 'FALLITA: la lapide tiene gusti (%) o scelte (%)', g, n;
  end if;
  perform set_config('role', 'authenticated', true);
  log := log || E'\nok  i dati scaricati hanno gusti e scelte; la lapide no';

  -- ── I privilegi ──────────────────────────────────────────────────────────
  if has_function_privilege('anon', 'public.cerca_viaggiatori(text, text, text[])', 'execute')
     or has_function_privilege('anon', 'public.profilo_pubblico(uuid)', 'execute')
     or has_function_privilege('anon', 'public.scegli_gusti(text[])', 'execute')
     or has_function_privilege('authenticated', 'privato.vede_il_profilo(uuid, uuid)', 'execute')
     or has_function_privilege('authenticated', 'privato.viaggi_del_profilo(uuid)', 'execute')
     or has_table_privilege('authenticated', 'privato.fuori_dal_profilo', 'select') then
    raise exception 'FALLITA: un privilegio di troppo';
  end if;
  log := log || E'\nok  niente per anon, e il privato resta privato';

  raise exception 'PASSATE%', log;
end;
$$;
