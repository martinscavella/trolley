-- Prova della chiusura (fase 4.1): chi chiude e quando, la verifica di
-- ciascuno, i traguardi; e che niente di questo si scriva direttamente.
--
-- Va lanciata dopo sul_posto.sql e chiusura.sql. Come regole_di_accesso.sql:
-- gira dentro un blocco che alla fine solleva un'eccezione e non lascia niente.
-- Il messaggio finale è il resoconto.
--
-- Tre persone: A crea i viaggi, B entra con l'invito, D è un estraneo.

do $$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  d uuid := gen_random_uuid();
  in_corso uuid := gen_random_uuid();
  finito uuid := gen_random_uuid();
  oggi date := (now() at time zone 'utc')::date;
  codice text;
  riga jsonb;
  n int;
  fallita boolean;
  log text := '';
begin
  insert into auth.users (id, email) values
    (a, a || '@prova.local'), (b, b || '@prova.local'), (d, d || '@prova.local');

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (d, 'Dario', '1990-01-01');

  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (a, 'Giulia', '1995-04-02');
  perform public.crea_viaggio(in_corso, 'Porto', 'PT', null, oggi - 1, oggi + 1,
    '10:00', '18:00', jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi - 1, 'inizio', '10:00', 'fine', '24:00'),
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi, 'inizio', '00:00', 'fine', '24:00'),
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi + 1, 'inizio', '00:00', 'fine', '18:00')));
  -- Finito ieri: sul posto lo si segna ancora, con il giorno di margine.
  perform public.crea_viaggio(finito, 'Madrid', 'ES', null, oggi - 3, oggi - 1,
    '10:00', '18:00', jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi - 3, 'inizio', '10:00', 'fine', '24:00'),
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi - 2, 'inizio', '00:00', 'fine', '24:00'),
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi - 1, 'inizio', '00:00', 'fine', '18:00')));
  insert into public.invito (viaggio_id) values (in_corso) returning token into codice;
  perform public.segna_sul_posto(finito);

  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (b, 'Marco', '1994-07-20');
  perform public.accetta_invito(codice);

  -- ── Lo stato chiuso non si scrive direttamente ───────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    update public.viaggio set stato = 'chiuso' where id = in_corso;
  exception when sqlstate 'TR403' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un viaggio si chiude scrivendo lo stato'; end if;
  fallita := false;
  begin
    update public.viaggio set verificato = true where id = in_corso;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: verificato si dichiara'; end if;
  log := log || E'\nok  chiuso e verificato non si scrivono direttamente';

  -- ── Prima della fine chiude solo chi è responsabile ──────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform public.chiudi_viaggio(in_corso);
  exception when sqlstate 'TR403' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: chi partecipa chiude prima della fine'; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  riga := public.chiudi_viaggio(in_corso);
  if riga ->> 'stato' <> 'chiuso' then raise exception 'FALLITA: chi è responsabile non chiude'; end if;
  riga := public.chiudi_viaggio(in_corso);
  if riga ->> 'stato' <> 'chiuso' then raise exception 'FALLITA: richiudere non è innocuo'; end if;
  fallita := false;
  begin
    update public.viaggio set stato = 'definito' where id = in_corso;
  exception when sqlstate 'TR403' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un viaggio chiuso si riapre'; end if;
  log := log || E'\nok  prima della fine chiude solo chi è responsabile, e non si riapre';

  -- ── Dopo la fine chiunque, e un estraneo mai ─────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform public.chiudi_viaggio(finito);
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un estraneo chiude un viaggio'; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.chiudi_viaggio(finito);
  log := log || E'\nok  finito, si chiude; un estraneo no';

  -- ── La verifica, di ciascuno e una volta ─────────────────────────────────
  -- A era sul posto a Madrid; B non c'era (non è nemmeno nel viaggio).
  riga := public.segna_verifica(finito, true);
  if (riga ->> 'verificato')::boolean is not true then
    raise exception 'FALLITA: chi era sul posto non si segna verificato';
  end if;
  riga := public.segna_verifica(finito, false);
  if (riga ->> 'verificato')::boolean is not true then
    raise exception 'FALLITA: la verifica si riscrive';
  end if;
  select count(*) into n from public.viaggio where id = finito and verificato;
  if n <> 1 then raise exception 'FALLITA: il viaggio non risulta verificato per almeno uno'; end if;

  fallita := false;
  begin
    perform public.segna_verifica(in_corso, true);
  exception when sqlstate 'TR403' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: verificato senza essere stati sul posto'; end if;
  riga := public.segna_verifica(in_corso, false);
  if (riga ->> 'verificato')::boolean is not false then
    raise exception 'FALLITA: un viaggio non verificato non si segna';
  end if;
  log := log || E'\nok  verificato solo chi era sul posto, una volta';

  -- ── I traguardi, solo da un viaggio verificato per sé ────────────────────
  fallita := false;
  begin
    perform public.prendi_traguardi(in_corso, array['primo_viaggio_verificato']);
  exception when sqlstate 'TR403' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: traguardi da un viaggio non verificato'; end if;

  perform public.prendi_traguardi(finito, array['primo_viaggio_verificato', 'una_settimana']);
  perform public.prendi_traguardi(finito, array['primo_viaggio_verificato']);
  select count(*) into n from public.traguardo where utente_id = a;
  if n <> 2 then raise exception 'FALLITA: i traguardi non sono uno per tipo (%)', n; end if;
  fallita := false;
  begin
    insert into public.traguardo (utente_id, tipo, viaggio_id) values (a, 'organizzare', finito);
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un traguardo si scrive direttamente'; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  select count(*) into n from public.traguardo;
  if n <> 0 then raise exception 'FALLITA: si leggono i traguardi degli altri'; end if;
  log := log || E'\nok  traguardi solo da un viaggio verificato, uno per tipo, solo i propri';

  if has_function_privilege('anon', 'public.chiudi_viaggio(uuid)', 'execute')
     or has_function_privilege('anon', 'public.segna_verifica(uuid, boolean)', 'execute')
     or has_function_privilege('anon', 'public.prendi_traguardi(uuid, text[])', 'execute') then
    raise exception 'FALLITA: senza accesso si chiama la chiusura';
  end if;
  log := log || E'\nok  senza accesso non si chiama niente';

  raise exception 'TUTTE LE PROVE PASSATE (annullate)%', log;
end;
$$;
