-- Prova dei partecipanti (fase 2.1): uscire, togliere qualcuno, passare il
-- ruolo, rientrare da un invito, e che nessuno lo faccia al posto di chi può.
--
-- Come regole_di_accesso.sql: gira dentro un blocco che alla fine solleva
-- un'eccezione e non lascia niente. Il messaggio finale è il resoconto.
--
-- Quattro persone: A crea il viaggio, B e C entrano con l'invito, D è un
-- estraneo.

do $$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  c uuid := gen_random_uuid();
  d uuid := gen_random_uuid();
  v uuid := gen_random_uuid();
  t1 text;
  t2 text;
  t3 text;
  righe jsonb;
  n int;
  testo text;
  fallita boolean;
  log text := '';
begin
  insert into auth.users (id, email) values
    (a, a || '@prova.local'), (b, b || '@prova.local'),
    (c, c || '@prova.local'), (d, d || '@prova.local');

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (d, 'Dario', '1990-01-01');

  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (a, 'Giulia', '1995-04-02');
  perform public.crea_viaggio(v, 'Porto', 'PT', null, null, null, null, null, '[]'::jsonb);
  insert into public.invito (viaggio_id) values (v) returning token into t1;

  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (b, 'Marco', '1994-07-20');
  perform public.accetta_invito(t1);

  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (c, 'Sara', '1996-11-05');
  perform public.accetta_invito(t1);
  insert into public.nota (viaggio_id, testo, creato_da) values (v, 'Prenotare il treno', c);

  -- ── Chi partecipa non toglie e non passa il ruolo ───────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform public.rimuovi_partecipante(v, c);
  exception when sqlstate 'TR403' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: chi partecipa toglie qualcuno'; end if;

  fallita := false;
  begin
    perform public.passa_il_ruolo(v, b);
  exception when sqlstate 'TR403' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: chi partecipa si prende il ruolo'; end if;

  fallita := false;
  begin
    update public.partecipazione set ruolo = 'creatore' where viaggio_id = v and utente_id = b;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: la partecipazione si scrive direttamente'; end if;

  fallita := false;
  begin
    insert into public.partecipazione (viaggio_id, utente_id, ruolo, stato) values (v, d, 'partecipante', 'attivo');
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si aggiunge qualcuno senza invito'; end if;
  log := log || E'\nok  chi partecipa non toglie, non passa il ruolo, non scrive la partecipazione';

  -- ── Il creatore non esce senza passare il ruolo, e non toglie se stesso ──
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform public.esci_dal_viaggio(v);
  exception when sqlstate 'TR412' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: il creatore esce lasciando il viaggio senza creatore'; end if;

  fallita := false;
  begin
    perform public.rimuovi_partecipante(v, a);
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: il creatore toglie se stesso'; end if;
  log := log || E'\nok  il creatore non esce senza passare il ruolo, e non toglie se stesso';

  -- ── Il creatore toglie C ────────────────────────────────────────────────
  righe := public.rimuovi_partecipante(v, c);
  select count(*) into n from jsonb_array_elements(righe->'partecipazioni') p
   where p->>'utente_id' = c::text and p->>'stato' = 'rimosso';
  if n <> 1 then raise exception 'FALLITA: togliere non restituisce la partecipazione cambiata'; end if;
  select count(*) into n from public.invito where viaggio_id = v and eliminato_il is null;
  if n <> 0 then raise exception 'FALLITA: togliere qualcuno lascia validi i link di prima'; end if;

  -- I suoi contributi restano, con il suo nome.
  select count(*) into n from public.nota where viaggio_id = v and creato_da = c;
  if n <> 1 then raise exception 'FALLITA: i contributi di chi è tolto spariscono'; end if;
  select nome into testo from public.utente where id = c;
  if testo is distinct from 'Sara' then raise exception 'FALLITA: non si vede più il nome di chi è stato tolto'; end if;
  log := log || E'\nok  il creatore toglie: i link di prima si ritirano, i contributi restano col nome';

  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  select count(*) into n from public.viaggio where id = v;
  if n <> 0 then raise exception 'FALLITA: chi è stato tolto vede ancora il viaggio'; end if;
  select count(*) into n from public.nota where viaggio_id = v;
  if n <> 0 then raise exception 'FALLITA: chi è stato tolto vede ancora le note'; end if;
  select stato into testo from public.partecipazione where viaggio_id = v and utente_id = c;
  if testo is distinct from 'rimosso' then raise exception 'FALLITA: chi è stato tolto non sa di esserlo'; end if;
  fallita := false;
  begin
    insert into public.nota (viaggio_id, testo, creato_da) values (v, 'ancora io', c);
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: chi è stato tolto scrive ancora'; end if;
  fallita := false;
  begin
    perform public.accetta_invito(t1);
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: chi è stato tolto rientra con il link di prima'; end if;
  log := log || E'\nok  chi è stato tolto non vede, non scrive, sa di esserlo, non rientra col link di prima';

  -- Un link di chi partecipa non basta; uno di chi è responsabile sì.
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  insert into public.invito (viaggio_id) values (v) returning token into t2;
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform public.accetta_invito(t2);
  exception when sqlstate 'TR403' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: chi è stato tolto rientra con il link di un altro partecipante'; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  insert into public.invito (viaggio_id) values (v) returning token into t3;
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  perform public.accetta_invito(t3);
  select count(*) into n from public.viaggio where id = v;
  if n <> 1 then raise exception 'FALLITA: chi è stato tolto non rientra con un link nuovo del creatore'; end if;
  log := log || E'\nok  rientra solo con un link nuovo di chi è responsabile';

  -- ── B esce da solo, e rientra con un link qualsiasi ─────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  perform public.esci_dal_viaggio(v);
  select count(*) into n from public.viaggio where id = v;
  if n <> 0 then raise exception 'FALLITA: chi è uscito vede ancora il viaggio'; end if;
  fallita := false;
  begin
    perform public.esci_dal_viaggio(v);
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si esce due volte'; end if;
  perform public.accetta_invito(t2);
  select count(*) into n from public.viaggio where id = v;
  if n <> 1 then raise exception 'FALLITA: chi è uscito non rientra con un invito'; end if;
  log := log || E'\nok  chiunque esce da solo, e rientra con un invito';

  -- ── A passa il ruolo a B ────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform public.passa_il_ruolo(v, d);
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: il ruolo passa a un estraneo'; end if;

  righe := public.passa_il_ruolo(v, b);
  select count(*) into n from public.partecipazione
   where viaggio_id = v and ruolo = 'creatore' and stato = 'attivo';
  if n <> 1 then raise exception 'FALLITA: dopo il passaggio i creatori sono %', n; end if;
  select count(*) into n from public.partecipazione
   where viaggio_id = v and utente_id = b and ruolo = 'creatore';
  if n <> 1 then raise exception 'FALLITA: il ruolo non è passato'; end if;
  if (righe->'viaggio'->>'creatore_id') <> b::text or (righe->'viaggio'->>'creato_da') <> a::text then
    raise exception 'FALLITA: il viaggio non segue il ruolo, o dimentica chi l''ha creato';
  end if;

  fallita := false;
  begin
    perform public.rimuovi_partecipante(v, c);
  exception when sqlstate 'TR403' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: chi ha passato il ruolo toglie ancora'; end if;

  perform public.esci_dal_viaggio(v);
  select count(*) into n from public.viaggio where id = v;
  if n <> 0 then raise exception 'FALLITA: chi ha creato il viaggio ed è uscito lo vede ancora'; end if;
  log := log || E'\nok  il ruolo passa a uno solo, il viaggio segue, e dopo si esce';

  -- ── D, estraneo ─────────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform public.rimuovi_partecipante(v, c);
  exception when sqlstate 'TR403' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un estraneo toglie qualcuno'; end if;
  fallita := false;
  begin
    perform public.passa_il_ruolo(v, d);
  exception when sqlstate 'TR403' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un estraneo si prende il ruolo'; end if;
  fallita := false;
  begin
    perform public.esci_dal_viaggio(v);
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un estraneo esce da un viaggio non suo'; end if;
  select count(*) into n from public.partecipazione where viaggio_id = v;
  if n <> 0 then raise exception 'FALLITA: un estraneo vede chi partecipa'; end if;
  log := log || E'\nok  un estraneo non toglie, non prende il ruolo, non vede chi partecipa';

  if has_function_privilege('anon', 'public.esci_dal_viaggio(uuid)', 'execute')
     or has_function_privilege('anon', 'public.rimuovi_partecipante(uuid, uuid)', 'execute')
     or has_function_privilege('anon', 'public.passa_il_ruolo(uuid, uuid)', 'execute') then
    raise exception 'FALLITA: senza accesso si chiamano le funzioni dei partecipanti';
  end if;
  log := log || E'\nok  senza accesso non si chiama niente';

  raise exception 'TUTTE LE PROVE PASSATE (annullate)%', log;
end;
$$;
