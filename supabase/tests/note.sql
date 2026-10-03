-- Prova delle note e della configurazione (fase 1.6): la nota del testo
-- incollato, chi la legge e chi la cambia, cosa di una nota non cambia, e la
-- configurazione che l'app legge e non scrive.
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
  n1 uuid := gen_random_uuid();
  codice text;
  n int;
  ver int;
  fallita boolean;
  log text := '';
begin
  insert into auth.users (id, email) values
    (a, a || '@prova.local'), (b, b || '@prova.local'), (c, c || '@prova.local');

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (c, 'Carlo', '1990-01-01');

  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (a, 'Giulia', '1995-04-02');
  perform public.crea_viaggio(v, 'Porto', 'PT', null, '2026-10-10', '2026-10-10', '10:00', '18:00',
    jsonb_build_array(
      jsonb_build_object('id', g1, 'data', '2026-10-10', 'inizio', '10:00:00', 'fine', '18:00:00')));
  insert into public.invito (viaggio_id) values (v) returning token into codice;

  -- ── A: la risposta incollata ────────────────────────────────────────────
  insert into public.nota (id, viaggio_id, testo, origine, creato_da)
  values (n1, v, 'GIORNO 1 · 2026-10-10' || E'\n' || '10:30 | Livraria Lello | visita | 60', 'incollata', a);
  select count(*) into n from public.nota where id = n1 and origine = 'incollata' and versione = 1;
  if n <> 1 then raise exception 'FALLITA: la risposta incollata non si salva come nota'; end if;
  log := log || E'\nok  la risposta incollata si salva come nota del viaggio';

  fallita := false;
  begin
    insert into public.nota (viaggio_id, testo, creato_da) values (v, '   ', a);
  exception when check_violation then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si salva una nota vuota'; end if;

  fallita := false;
  begin
    insert into public.nota (viaggio_id, testo, creato_da) values (v, repeat('x', 20001), a);
  exception when check_violation then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si salva una nota sterminata'; end if;

  fallita := false;
  begin
    insert into public.nota (viaggio_id, testo, origine, creato_da) values (v, 'x', 'generata', a);
  exception when check_violation then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si accetta un''origine sconosciuta'; end if;
  log := log || E'\nok  una nota non è vuota né sterminata, e viene da un''origine nota';

  -- ── B: invitato ─────────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (b, 'Marco', '1994-07-20');
  perform public.accetta_invito(codice);

  select count(*) into n from public.nota where viaggio_id = v;
  if n <> 1 then raise exception 'FALLITA: l''invitato non vede le note del viaggio'; end if;

  select versione into ver from public.nota where id = n1;
  update public.nota set testo = 'Rivista', versione = ver where id = n1;
  fallita := false;
  begin
    update public.nota set testo = 'Rivista due volte', versione = ver where id = n1;
  exception when sqlstate 'TR409' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si cambia una nota su una versione superata'; end if;
  log := log || E'\nok  l''invitato la legge e la cambia, con la versione';

  fallita := false;
  begin
    update public.nota set viaggio_id = gen_random_uuid() where id = n1;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: una nota cambia viaggio'; end if;

  fallita := false;
  begin
    update public.nota set origine = 'scritta' where id = n1;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: una nota cambia origine'; end if;

  fallita := false;
  begin
    insert into public.nota (viaggio_id, testo, creato_da) values (v, 'a nome di A', a);
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si scrive una nota a nome di un altro'; end if;
  log := log || E'\nok  una nota non cambia viaggio né origine, e si scrive solo a proprio nome';

  -- ── C: estraneo ─────────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);

  select count(*) into n from public.nota where viaggio_id = v;
  if n <> 0 then raise exception 'FALLITA: un estraneo vede le note'; end if;
  update public.nota set testo = 'intruso' where id = n1;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLITA: un estraneo cambia una nota'; end if;
  fallita := false;
  begin
    insert into public.nota (viaggio_id, testo, creato_da) values (v, 'intruso', c);
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un estraneo scrive una nota'; end if;
  log := log || E'\nok  un estraneo non vede, non scrive, non cambia';

  -- ── La configurazione ───────────────────────────────────────────────────
  select count(*) into n from public.configurazione where chiave = 'modelli_suggeriti'
     and jsonb_typeof(valore) = 'array' and jsonb_array_length(valore) > 0;
  if n <> 1 then raise exception 'FALLITA: chi ha un accesso non legge i modelli suggeriti'; end if;
  if has_table_privilege('authenticated', 'public.configurazione', 'insert')
     or has_table_privilege('authenticated', 'public.configurazione', 'update')
     or has_table_privilege('authenticated', 'public.configurazione', 'delete') then
    raise exception 'FALLITA: dall''app si scrive la configurazione';
  end if;
  if has_table_privilege('anon', 'public.configurazione', 'select') then
    raise exception 'FALLITA: senza accesso si legge la configurazione';
  end if;
  log := log || E'\nok  la configurazione si legge con un accesso, e dall''app non si scrive';

  raise exception 'TUTTE LE PROVE PASSATE (annullate)%', log;
end;
$$;
