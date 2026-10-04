-- Prova della divisione delle spese (fase 2.3): registrare una spesa con le
-- sue quote in un colpo solo e rimandarla senza duplicare, chi può risultare
-- in una quota, cambiare spesa e quote con la versione, il rimborso.
--
-- Come regole_di_accesso.sql: gira dentro un blocco che alla fine solleva
-- un'eccezione e non lascia niente. Il messaggio finale è il resoconto.
--
-- Tre persone: A crea il viaggio, B entra con l'invito, C è un estraneo.

do $$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  c uuid := gen_random_uuid();
  v uuid := gen_random_uuid();
  g1 uuid := gen_random_uuid();
  s1 uuid := gen_random_uuid();
  s2 uuid := gen_random_uuid();
  r1 uuid := gen_random_uuid();
  codice text;
  righe jsonb;
  n int;
  fallita boolean;
  log text := '';
begin
  insert into auth.users (id, email) values
    (a, a || '@prova.local'), (b, b || '@prova.local'), (c, c || '@prova.local');

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (c, 'Carlo', '1990-01-01');
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (b, 'Marco', '1994-03-01');

  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (a, 'Giulia', '1995-04-02');
  perform public.crea_viaggio(v, 'Porto', 'PT', null, '2026-10-10', '2026-10-10', '10:00', '18:00',
    jsonb_build_array(
      jsonb_build_object('id', g1, 'data', '2026-10-10', 'inizio', '10:00:00', 'fine', '18:00:00')));
  insert into public.invito (viaggio_id) values (v) returning token into codice;
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  perform public.accetta_invito(codice);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);

  -- ── Registrare con le quote ─────────────────────────────────────────────
  righe := public.registra_spesa(
    jsonb_build_object('id', s1, 'viaggio_id', v, 'importo', '42.00', 'valuta', 'EUR',
                       'pagante_id', a, 'data', '2026-10-10', 'descrizione', 'Cena'),
    jsonb_build_array(jsonb_build_object('utente_id', a, 'quota', '21.00'),
                      jsonb_build_object('utente_id', b, 'quota', '21.00')));
  if righe -> 'spesa' ->> 'id' <> s1::text or jsonb_array_length(righe -> 'quote') <> 2 then
    raise exception 'FALLITA: registra_spesa non restituisce la spesa e le sue quote';
  end if;
  select count(*) into n from public.spesa where id = s1 and creato_da = a and not rimborso;
  if n <> 1 then raise exception 'FALLITA: la spesa non nasce a nome di chi la registra'; end if;
  log := log || E'\nok  una spesa si registra con le sue quote, e torna com''è';

  -- Rimandata dalla coda, anche con quote diverse: non cambia niente.
  righe := public.registra_spesa(
    jsonb_build_object('id', s1, 'viaggio_id', v, 'importo', '42.00', 'valuta', 'EUR',
                       'pagante_id', a, 'data', '2026-10-10'),
    jsonb_build_array(jsonb_build_object('utente_id', a, 'quota', '42.00')));
  select count(*) into n from public.spesa_quota where spesa_id = s1;
  if n <> 2 or jsonb_array_length(righe -> 'quote') <> 2 then
    raise exception 'FALLITA: rimandare la spesa duplica o cambia le quote';
  end if;
  log := log || E'\nok  rimandarla non la duplica e non tocca le quote';

  -- Una quota per un estraneo: niente, nemmeno la spesa.
  fallita := false;
  begin
    perform public.registra_spesa(
      jsonb_build_object('id', s2, 'viaggio_id', v, 'importo', '10.00', 'valuta', 'EUR',
                         'pagante_id', a, 'data', '2026-10-10'),
      jsonb_build_array(jsonb_build_object('utente_id', c, 'quota', '10.00')));
  exception when insufficient_privilege then fallita := true;
  end;
  select count(*) into n from public.spesa where id = s2;
  if not fallita or n <> 0 then
    raise exception 'FALLITA: si attribuisce una quota a un estraneo';
  end if;
  log := log || E'\nok  una quota è di qualcuno del viaggio, e se no non resta niente';

  -- L'estraneo non registra spese nel viaggio.
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform public.registra_spesa(
      jsonb_build_object('id', s2, 'viaggio_id', v, 'importo', '10.00', 'valuta', 'EUR',
                         'pagante_id', c, 'data', '2026-10-10'), '[]'::jsonb);
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un estraneo registra una spesa'; end if;
  -- Per chi non la vede, la spesa non c'è.
  fallita := false;
  begin
    perform public.cambia_spesa(s1, 1, jsonb_build_object('importo', '1.00'), null);
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un estraneo cambia una spesa'; end if;
  log := log || E'\nok  un estraneo non registra e non cambia';
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);

  -- ── Cambiare con la versione ────────────────────────────────────────────
  righe := public.cambia_spesa(s1, 1, jsonb_build_object('importo', '48.00'),
    jsonb_build_array(jsonb_build_object('utente_id', a, 'quota', '16.00'),
                      jsonb_build_object('utente_id', b, 'quota', '32.00')));
  select count(*) into n from public.spesa where id = s1 and importo = 48 and versione = 2;
  if n <> 1 then raise exception 'FALLITA: la spesa non cambia con la versione giusta'; end if;
  select count(*) into n from public.spesa_quota
   where spesa_id = s1 and eliminato_il is null
     and ((utente_id = a and quota = 16) or (utente_id = b and quota = 32));
  if n <> 2 then raise exception 'FALLITA: le quote nuove non prendono il posto delle vecchie'; end if;
  log := log || E'\nok  spesa e quote cambiano insieme';

  -- Sulla versione vecchia: rifiutata, e le quote restano quelle.
  fallita := false;
  begin
    perform public.cambia_spesa(s1, 1, jsonb_build_object('importo', '50.00'),
      jsonb_build_array(jsonb_build_object('utente_id', a, 'quota', '50.00')));
  exception when sqlstate 'TR409' then fallita := true;
  end;
  select count(*) into n from public.spesa_quota where spesa_id = s1 and eliminato_il is null;
  if not fallita or n <> 2 then
    raise exception 'FALLITA: su una versione superata cambia qualcosa';
  end if;
  log := log || E'\nok  sulla versione superata si rifiuta tutto, quote comprese (TR409)';

  -- Chi esce dalla spesa si marca; chi rientra riprende la sua riga.
  perform public.cambia_spesa(s1, 2, '{}'::jsonb,
    jsonb_build_array(jsonb_build_object('utente_id', b, 'quota', '48.00')));
  select count(*) into n from public.spesa_quota where spesa_id = s1 and utente_id = a and eliminato_il is not null;
  if n <> 1 then raise exception 'FALLITA: chi esce dalla spesa non si marca'; end if;
  perform public.cambia_spesa(s1, 3, '{}'::jsonb,
    jsonb_build_array(jsonb_build_object('utente_id', a, 'quota', '24.00'),
                      jsonb_build_object('utente_id', b, 'quota', '24.00')));
  select count(*) into n from public.spesa_quota where spesa_id = s1;
  if n <> 2 then raise exception 'FALLITA: chi rientra in una spesa crea una riga nuova'; end if;
  select count(*) into n from public.spesa_quota where spesa_id = s1 and eliminato_il is null;
  if n <> 2 then raise exception 'FALLITA: chi rientra in una spesa resta marcato'; end if;
  log := log || E'\nok  chi esce dalla spesa si marca, chi rientra riprende la sua riga';

  -- Toglierla: si marca, le quote restano com'erano.
  perform public.cambia_spesa(s1, 4, jsonb_build_object('eliminato_il', now()), null);
  select count(*) into n from public.spesa where id = s1 and eliminato_il is not null;
  if n <> 1 then raise exception 'FALLITA: togliere una spesa non la marca'; end if;
  log := log || E'\nok  togliere una spesa la marca';

  -- ── Il rimborso ─────────────────────────────────────────────────────────
  -- B dà 12 euro ad A: pagati da B, tutti per A.
  righe := public.registra_spesa(
    jsonb_build_object('id', r1, 'viaggio_id', v, 'importo', '12.00', 'valuta', 'EUR',
                       'pagante_id', b, 'data', '2026-10-10', 'rimborso', true),
    jsonb_build_array(jsonb_build_object('utente_id', a, 'quota', '12.00')));
  select count(*) into n from public.spesa where id = r1 and rimborso and pagante_id = b;
  if n <> 1 then raise exception 'FALLITA: il rimborso non si registra come tale'; end if;
  log := log || E'\nok  un rimborso è una spesa segnata come tale';

  -- ── Le funzioni non si chiamano senza accesso ─────────────────────────────
  if has_function_privilege('anon', 'public.registra_spesa(jsonb, jsonb)', 'execute')
     or has_function_privilege('anon', 'public.cambia_spesa(uuid, integer, jsonb, jsonb)', 'execute')
     or has_function_privilege('anon', 'privato.righe_della_spesa(uuid)', 'execute') then
    raise exception 'FALLITA: senza accesso si chiamano le funzioni delle spese';
  end if;
  log := log || E'\nok  senza accesso non si registra e non si cambia niente';

  raise exception 'TUTTE LE PROVE PASSATE (annullate)%', log;
end;
$$;
