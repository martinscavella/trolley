-- Prova di eliminare un viaggio (02, regola 13): solo chi è rimasto da solo,
-- con tutto quello che contiene, e mai un viaggio degli altri.
--
-- Come regole_di_accesso.sql: gira dentro un blocco che alla fine solleva
-- un'eccezione e non lascia niente. Il messaggio finale è il resoconto.
--
-- A crea Porto, B entra con l'invito; A crea anche Lisbona, da solo, con un
-- invito che nessuno ha accettato. D è un estraneo.

do $$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  d uuid := gen_random_uuid();
  porto uuid := gen_random_uuid();
  lisbona uuid := gen_random_uuid();
  t text;
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
  perform public.crea_viaggio(porto, 'Porto', 'PT', null, null, null, null, null, '[]'::jsonb);
  insert into public.invito (viaggio_id) values (porto) returning token into t;
  perform public.crea_viaggio(lisbona, 'Lisbona', 'PT', null, null, null, null, null, '[]'::jsonb);
  insert into public.invito (viaggio_id) values (lisbona);
  insert into public.nota (viaggio_id, testo, creato_da) values (lisbona, 'Il tram 28', a);
  insert into public.voce_lista (viaggio_id, testo, tipo) values (lisbona, 'Crema solare', 'viaggio');

  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (b, 'Marco', '1994-07-20');
  perform public.accetta_invito(t);

  -- ── Un estraneo non elimina niente ──────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform public.elimina_viaggio(lisbona);
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un estraneo elimina un viaggio'; end if;
  log := log || E'\nok  un estraneo non elimina';

  -- ── Con altri dentro non si elimina, né da chi è responsabile né da chi partecipa ──
  foreach t in array array[a::text, b::text] loop
    perform set_config('request.jwt.claims', json_build_object('sub', t, 'role', 'authenticated')::text, true);
    fallita := false;
    begin
      perform public.elimina_viaggio(porto);
    exception when sqlstate 'TR413' then fallita := true;
    end;
    if not fallita then raise exception 'FALLITA: si elimina un viaggio con altri dentro'; end if;
  end loop;
  perform set_config('role', 'postgres', true);
  select count(*) into n from public.viaggio where id = porto;
  if n <> 1 then raise exception 'FALLITA: Porto non c''è più'; end if;
  perform set_config('role', 'authenticated', true);
  log := log || E'\nok  con altri dentro non si elimina';

  -- ── Rimasto da solo, si elimina: con tutto, anche l'invito non accettato ─
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.elimina_viaggio(lisbona);
  perform set_config('role', 'postgres', true);
  select (select count(*) from public.viaggio where id = lisbona)
       + (select count(*) from public.partecipazione where viaggio_id = lisbona)
       + (select count(*) from public.invito where viaggio_id = lisbona)
       + (select count(*) from public.nota where viaggio_id = lisbona)
       + (select count(*) from public.voce_lista where viaggio_id = lisbona)
    into n;
  if n <> 0 then raise exception 'FALLITA: di Lisbona restano % righe', n; end if;
  select count(*) into n from public.viaggio where id = porto;
  if n <> 1 then raise exception 'FALLITA: eliminando Lisbona se n''è andato Porto'; end if;
  perform set_config('role', 'authenticated', true);
  log := log || E'\nok  da solo si elimina, con tutto quello che contiene';

  -- ── Chi esce lascia l'altro da solo: allora sì ──────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  perform public.esci_dal_viaggio(porto);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.elimina_viaggio(porto);
  perform set_config('role', 'postgres', true);
  select count(*) into n from public.viaggio where id = porto;
  if n <> 0 then raise exception 'FALLITA: Porto resta dopo che Marco è uscito'; end if;
  log := log || E'\nok  uscito l''altro, si elimina';

  -- ── Senza accesso, niente ───────────────────────────────────────────────
  if has_function_privilege('anon', 'public.elimina_viaggio(uuid)', 'execute') then
    raise exception 'FALLITA: anon può chiamare elimina_viaggio';
  end if;
  log := log || E'\nok  anon non la chiama';

  raise exception 'PASSATE%', log;
end;
$$;
