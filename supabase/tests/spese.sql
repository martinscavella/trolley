-- Prova delle spese (fase 1.4): registrare (il gesto della coda), chi può
-- risultare pagante, le modifiche con la versione, i tassi di cambio.
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

  -- ── Registrare: il gesto della coda ─────────────────────────────────────
  insert into public.spesa (id, viaggio_id, importo, valuta, tasso_usato, tasso_al, pagante_id, data, descrizione)
  values (s1, v, 12.40, 'EUR', 1, now(), a, '2026-10-10', 'Pranzo');
  select count(*) into n from public.spesa where id = s1 and creato_da = a and versione = 1;
  if n <> 1 then raise exception 'FALLITA: la spesa non nasce a nome di chi la registra'; end if;
  log := log || E'\nok  si registra una spesa con l''id nato sul telefono';

  insert into public.spesa (id, viaggio_id, importo, valuta, pagante_id, data)
  values (s1, v, 12.40, 'EUR', a, '2026-10-10')
  on conflict (id) do nothing;
  select count(*) into n from public.spesa where viaggio_id = v;
  if n <> 1 then raise exception 'FALLITA: rimandare la stessa spesa la duplica'; end if;
  log := log || E'\nok  rimandare la stessa spesa non la duplica';

  fallita := false;
  begin
    insert into public.spesa (viaggio_id, importo, valuta, pagante_id, data)
    values (v, 5, 'EUR', c, '2026-10-10');
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si attribuisce una spesa a un estraneo'; end if;
  log := log || E'\nok  il pagante è qualcuno del viaggio, non un estraneo';

  fallita := false;
  begin
    insert into public.spesa (viaggio_id, importo, valuta, pagante_id, data)
    values (v, 5, 'eur', a, '2026-10-10');
  exception when check_violation then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si accetta una valuta scritta male'; end if;

  fallita := false;
  begin
    insert into public.spesa (viaggio_id, importo, valuta, pagante_id, data)
    values (v, 0, 'EUR', a, '2026-10-10');
  exception when check_violation then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si accetta una spesa di zero'; end if;

  fallita := false;
  begin
    insert into public.spesa (viaggio_id, importo, valuta, tasso_usato, pagante_id, data)
    values (v, 5, 'MAD', 11.18, a, '2026-10-10');
  exception when check_violation then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si accetta un tasso senza la sua data'; end if;
  log := log || E'\nok  valuta in tre lettere maiuscole, importo positivo, tasso sempre con la data';

  -- ── B: invitato ─────────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (b, 'Marco', '1994-07-20');
  perform public.accetta_invito(codice);

  select count(*) into n from public.spesa where viaggio_id = v;
  if n <> 1 then raise exception 'FALLITA: l''invitato non vede le spese del viaggio'; end if;

  insert into public.spesa (id, viaggio_id, importo, valuta, pagante_id, data)
  values (s2, v, 300, 'MAD', a, '2026-10-10');
  log := log || E'\nok  l''invitato vede le spese e ne registra, anche pagate da altri';

  select versione into ver from public.spesa where id = s1;
  update public.spesa set importo = 14.00, versione = ver where id = s1;
  select count(*) into n from public.spesa where id = s1 and importo = 14.00 and versione = ver + 1;
  if n <> 1 then raise exception 'FALLITA: un partecipante non modifica una spesa'; end if;

  fallita := false;
  begin
    update public.spesa set importo = 15.00, versione = ver where id = s1;
  exception when sqlstate 'TR409' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si modifica una spesa su una versione superata'; end if;
  log := log || E'\nok  si modifica con la versione, e una versione superata si rifiuta';

  fallita := false;
  begin
    update public.spesa set pagante_id = c, versione = ver + 1 where id = s1;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: una modifica passa la spesa a un estraneo'; end if;
  log := log || E'\nok  modificando non si passa la spesa a un estraneo';

  -- ── C: estraneo ─────────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);

  select count(*) into n from public.spesa where viaggio_id = v;
  if n <> 0 then raise exception 'FALLITA: un estraneo vede le spese'; end if;
  update public.spesa set importo = 1 where id = s1;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLITA: un estraneo modifica una spesa'; end if;
  fallita := false;
  begin
    insert into public.spesa (viaggio_id, importo, valuta, pagante_id, data)
    values (v, 5, 'EUR', c, '2026-10-10');
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un estraneo registra una spesa'; end if;
  log := log || E'\nok  un estraneo non vede, non registra, non modifica';

  -- ── Tassi di cambio ─────────────────────────────────────────────────────
  if not has_table_privilege('authenticated', 'public.tasso_cambio', 'select') then
    raise exception 'FALLITA: chi ha un accesso non legge i tassi';
  end if;
  if has_table_privilege('authenticated', 'public.tasso_cambio', 'insert')
     or has_table_privilege('authenticated', 'public.tasso_cambio', 'update') then
    raise exception 'FALLITA: chi ha un accesso scrive i tassi';
  end if;
  if has_table_privilege('anon', 'public.tasso_cambio', 'select') then
    raise exception 'FALLITA: senza accesso si leggono i tassi';
  end if;
  if has_function_privilege('authenticated', 'privato.aggiorna_tassi()', 'execute')
     or has_function_privilege('anon', 'privato.aggiorna_tassi()', 'execute') then
    raise exception 'FALLITA: dall''app si può far scaricare i tassi';
  end if;
  log := log || E'\nok  i tassi si leggono con un accesso, li scrive solo il server';

  raise exception 'TUTTE LE PROVE PASSATE (annullate)%', log;
end;
$$;
