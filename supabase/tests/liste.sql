-- Prova delle cose da portare (fase 1.5): la lista personale che nessun altro
-- vede, la spunta (il gesto della coda), le modifiche con la versione, quello
-- che di una voce non si cambia, a chi si assegna una voce del viaggio.
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
  mia uuid := gen_random_uuid();
  comune uuid := gen_random_uuid();
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

  -- Un'idea, senza date: le liste non le aspettano (05, regola 4).
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (a, 'Giulia', '1995-04-02');
  perform public.crea_viaggio(v, null, 'JP', 'autunno', null, null, null, null, '[]'::jsonb);
  insert into public.invito (viaggio_id) values (v) returning token into codice;

  -- ── A: la sua lista ─────────────────────────────────────────────────────
  insert into public.voce_lista (id, viaggio_id, testo, tipo, quantita, proprietario_id, creato_da)
  values (mia, v, 'Magliette', 'personale', 5, a, a);
  select count(*) into n from public.voce_lista
   where id = mia and quantita = 5 and not spuntata and versione = 1;
  if n <> 1 then raise exception 'FALLITA: una voce non si aggiunge a un''idea'; end if;
  log := log || E'\nok  si aggiunge una voce anche a un''idea, con quante';

  fallita := false;
  begin
    insert into public.voce_lista (viaggio_id, testo, tipo, quantita, proprietario_id, creato_da)
    values (v, 'Calzini', 'personale', 0, a, a);
  exception when check_violation then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si accetta una voce con zero pezzi'; end if;

  fallita := false;
  begin
    insert into public.voce_lista (viaggio_id, testo, tipo, proprietario_id, creato_da)
    values (v, '   ', 'personale', a, a);
  exception when check_violation then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si accetta una voce senza testo'; end if;

  fallita := false;
  begin
    insert into public.voce_lista (viaggio_id, testo, tipo, proprietario_id, creato_da)
    values (v, repeat('x', 201), 'personale', a, a);
  exception when check_violation then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si accetta un testo lunghissimo'; end if;

  fallita := false;
  begin
    insert into public.voce_lista (viaggio_id, testo, tipo, proprietario_id, assegnato_a, creato_da)
    values (v, 'Ombrello', 'personale', a, a, a);
  exception when check_violation then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si assegna una voce personale'; end if;
  log := log || E'\nok  testo non vuoto e breve, da 1 a 99 pezzi, una personale non si assegna';

  -- La spunta come la manda la coda: senza versione, vince l'ultima.
  update public.voce_lista set spuntata = true where id = mia;
  update public.voce_lista set spuntata = true where id = mia;
  select count(*) into n from public.voce_lista where id = mia and spuntata and versione = 3;
  if n <> 1 then raise exception 'FALLITA: spuntare due volte non lascia la voce spuntata'; end if;
  log := log || E'\nok  si spunta senza versione, e spuntato è spuntato';

  select versione into ver from public.voce_lista where id = mia;
  update public.voce_lista set testo = 'Magliette leggere', quantita = 4, versione = ver where id = mia;
  fallita := false;
  begin
    update public.voce_lista set testo = 'Magliette pesanti', versione = ver where id = mia;
  exception when sqlstate 'TR409' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si cambia il testo su una versione superata'; end if;
  log := log || E'\nok  il testo si cambia con la versione, e una versione superata si rifiuta';

  fallita := false;
  begin
    update public.voce_lista set tipo = 'viaggio' where id = mia;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: una voce cambia lista'; end if;

  fallita := false;
  begin
    update public.voce_lista set proprietario_id = b where id = mia;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: una voce cambia proprietario'; end if;
  log := log || E'\nok  una voce non cambia lista né proprietario';

  -- ── B: invitato ─────────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (b, 'Marco', '1994-07-20');
  perform public.accetta_invito(codice);

  select count(*) into n from public.voce_lista where id = mia;
  if n <> 0 then raise exception 'FALLITA: l''invitato vede la lista personale di un altro'; end if;
  update public.voce_lista set spuntata = false where id = mia;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLITA: l''invitato spunta la voce personale di un altro'; end if;
  log := log || E'\nok  la lista personale non la vede nessun altro, nemmeno chi ha creato il viaggio';

  fallita := false;
  begin
    insert into public.voce_lista (viaggio_id, testo, tipo, proprietario_id, creato_da)
    values (v, 'Spazzolino', 'personale', a, b);
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si scrive una voce a nome di un altro'; end if;
  log := log || E'\nok  una voce si aggiunge solo a proprio nome';

  -- Una voce del viaggio (2.4) si assegna a qualcuno del viaggio, non a un
  -- estraneo.
  insert into public.voce_lista (id, viaggio_id, testo, tipo, proprietario_id, assegnato_a, creato_da)
  values (comune, v, 'Adattatore', 'viaggio', b, a, b);
  fallita := false;
  begin
    update public.voce_lista set assegnato_a = c where id = comune;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si assegna una voce a un estraneo'; end if;
  log := log || E'\nok  una voce del viaggio si assegna solo a chi ne fa parte';

  -- ── C: estraneo ─────────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);

  select count(*) into n from public.voce_lista where viaggio_id = v;
  if n <> 0 then raise exception 'FALLITA: un estraneo vede le liste'; end if;
  update public.voce_lista set spuntata = true where id = comune;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLITA: un estraneo spunta una voce'; end if;
  fallita := false;
  begin
    insert into public.voce_lista (viaggio_id, testo, tipo, proprietario_id, creato_da)
    values (v, 'Intruso', 'personale', c, c);
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un estraneo aggiunge una voce'; end if;
  log := log || E'\nok  un estraneo non vede, non aggiunge, non spunta';

  raise exception 'TUTTE LE PROVE PASSATE (annullate)%', log;
end;
$$;
