-- Prova di «sul posto» (fase 3.4): ciascuno lo segna per sé, una volta, solo
-- mentre il viaggio è in corso; nessuno lo scrive direttamente, né per un
-- altro, né per un viaggio importato.
--
-- Come regole_di_accesso.sql: gira dentro un blocco che alla fine solleva
-- un'eccezione e non lascia niente. Il messaggio finale è il resoconto.
--
-- Tre persone: A crea i viaggi, B entra con l'invito, D è un estraneo.

do $$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  d uuid := gen_random_uuid();
  in_corso uuid := gen_random_uuid();
  futuro uuid := gen_random_uuid();
  finito uuid := gen_random_uuid();
  importato uuid := gen_random_uuid();
  oggi date := (now() at time zone 'utc')::date;
  codice text;
  riga jsonb;
  primo timestamptz;
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
  perform public.crea_viaggio(futuro, 'Lisbona', 'PT', null, oggi + 10, oggi + 10,
    '10:00', '18:00', jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi + 10, 'inizio', '10:00', 'fine', '18:00')));
  perform public.crea_viaggio(finito, 'Madrid', 'ES', null, oggi - 10, oggi - 9,
    '10:00', '18:00', jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi - 10, 'inizio', '10:00', 'fine', '24:00'),
      jsonb_build_object('id', gen_random_uuid(), 'data', oggi - 9, 'inizio', '00:00', 'fine', '18:00')));
  insert into public.invito (viaggio_id) values (in_corso) returning token into codice;

  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (b, 'Marco', '1994-07-20');
  perform public.accetta_invito(codice);

  -- Un viaggio importato lo scrive solo il server: qui, come chi lo gestisce.
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform set_config('role', 'postgres', true);
  insert into public.viaggio (id, stato, destinazione_citta, destinazione_paese,
    data_inizio, data_fine, ora_arrivo, ora_partenza, creatore_id, creato_da, importato)
  values (importato, 'chiuso', 'Roma', 'IT', oggi - 1, oggi + 1, '10:00', '18:00', a, a, true);
  perform set_config('role', 'authenticated', true);

  -- ── Ciascuno per sé, una volta ───────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  riga := public.segna_sul_posto(in_corso);
  if riga ->> 'sul_posto_il' is null or (riga ->> 'utente_id')::uuid <> a then
    raise exception 'FALLITA: segnare sul posto non restituisce la propria partecipazione';
  end if;
  primo := (riga ->> 'sul_posto_il')::timestamptz;
  riga := public.segna_sul_posto(in_corso);
  if (riga ->> 'sul_posto_il')::timestamptz <> primo then
    raise exception 'FALLITA: la seconda volta cambia la prima';
  end if;
  select count(*) into n from public.partecipazione
   where viaggio_id = in_corso and sul_posto_il is not null;
  if n <> 1 then raise exception 'FALLITA: sul posto vale anche per Marco'; end if;
  log := log || E'\nok  si segna per sé, una volta, e i compagni no';

  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  perform public.segna_sul_posto(in_corso);
  select count(*) into n from public.partecipazione
   where viaggio_id = in_corso and sul_posto_il is not null;
  if n <> 2 then raise exception 'FALLITA: chi è entrato da un invito non si segna'; end if;
  log := log || E'\nok  chi è entrato da un invito si segna per sé';

  -- ── Solo mentre il viaggio è in corso ────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform public.segna_sul_posto(futuro);
  exception when sqlstate 'TR422' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: sul posto prima di partire'; end if;
  fallita := false;
  begin
    perform public.segna_sul_posto(finito);
  exception when sqlstate 'TR422' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: sul posto a viaggio finito'; end if;
  fallita := false;
  begin
    perform public.segna_sul_posto(importato);
  exception when sqlstate 'TR422' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: sul posto in un viaggio importato'; end if;
  log := log || E'\nok  non prima, non dopo, non in un viaggio importato';

  -- ── Nessuno lo scrive direttamente, né un estraneo ───────────────────────
  fallita := false;
  begin
    update public.partecipazione set sul_posto_il = now()
     where viaggio_id = futuro and utente_id = a;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: sul posto si scrive direttamente'; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform public.segna_sul_posto(in_corso);
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un estraneo si segna sul posto'; end if;
  log := log || E'\nok  non si scrive direttamente, e un estraneo non si segna';

  if has_function_privilege('anon', 'public.segna_sul_posto(uuid)', 'execute') then
    raise exception 'FALLITA: senza accesso si segna sul posto';
  end if;
  log := log || E'\nok  senza accesso non si chiama';

  raise exception 'TUTTE LE PROVE PASSATE (annullate)%', log;
end;
$$;
