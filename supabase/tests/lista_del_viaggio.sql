-- Prova della lista del viaggio (fase 2.4): chi porta una voce, le voci che
-- tornano libere quando chi le portava lascia il viaggio, lo spostamento da
-- una lista all'altra.
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
  adattatore uuid := gen_random_uuid();
  powerbank uuid := gen_random_uuid();
  crema uuid := gen_random_uuid();
  ombrello uuid := gen_random_uuid();
  mappa uuid := gen_random_uuid();
  spazzolino uuid := gen_random_uuid();
  diario uuid := gen_random_uuid();
  nuova1 uuid := gen_random_uuid();
  nuova2 uuid := gen_random_uuid();
  nuova3 uuid := gen_random_uuid();
  codice text;
  righe jsonb;
  ver int;
  n int;
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
  insert into public.invito (viaggio_id) values (v) returning token into codice;
  insert into public.voce_lista (id, viaggio_id, testo, tipo, proprietario_id, creato_da)
  values (ombrello, v, 'Ombrello', 'viaggio', a, a),
         (mappa, v, 'Mappa', 'viaggio', a, a),
         (diario, v, 'Diario', 'personale', a, a);

  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (b, 'Marco', '1994-07-20');
  perform public.accetta_invito(codice);

  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (c, 'Sara', '1996-11-05');
  perform public.accetta_invito(codice);

  -- ── Chi porta cosa ──────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  insert into public.voce_lista (id, viaggio_id, testo, tipo, quantita, proprietario_id, assegnato_a, creato_da)
  values (adattatore, v, 'Adattatore', 'viaggio', 2, b, c, b),
         (powerbank, v, 'Powerbank', 'viaggio', 1, b, b, b),
         (crema, v, 'Crema solare', 'viaggio', 1, b, b, b);
  update public.voce_lista set assegnato_a = c where id = ombrello;
  insert into public.voce_lista (id, viaggio_id, testo, tipo, proprietario_id, spuntata, creato_da)
  values (spazzolino, v, 'Spazzolino', 'personale', b, true, b);

  fallita := false;
  begin
    insert into public.voce_lista (viaggio_id, testo, tipo, proprietario_id, assegnato_a, creato_da)
    values (v, 'Carte', 'viaggio', b, d, b);
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si assegna una voce nuova a un estraneo'; end if;
  log := log || E'\nok  una voce del viaggio si assegna a chi c''è, non a un estraneo';

  fallita := false;
  begin
    update public.voce_lista set lasciata_da = c where id = powerbank;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: l''app scrive chi portava una voce'; end if;

  fallita := false;
  begin
    insert into public.voce_lista (viaggio_id, testo, tipo, proprietario_id, lasciata_da, creato_da)
    values (v, 'Carte', 'viaggio', b, c, b);
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: una voce nasce già lasciata da qualcuno'; end if;
  log := log || E'\nok  chi la portava lo scrive solo il server';

  -- ── C esce: le sue voci tornano libere ──────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  perform public.esci_dal_viaggio(v);

  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  select count(*) into n from public.voce_lista
   where id in (adattatore, ombrello) and assegnato_a is null and lasciata_da = c;
  if n <> 2 then raise exception 'FALLITA: le voci di chi esce non tornano libere'; end if;
  select count(*) into n from public.voce_lista
   where id = powerbank and assegnato_a = b and lasciata_da is null;
  if n <> 1 then raise exception 'FALLITA: uscire libera anche le voci degli altri'; end if;
  log := log || E'\nok  chi esce lascia libere le voci che portava, e solo quelle';

  fallita := false;
  begin
    update public.voce_lista set assegnato_a = c where id = adattatore;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si assegna una voce a chi è uscito'; end if;
  log := log || E'\nok  una voce non si assegna a chi è uscito';

  update public.voce_lista set assegnato_a = b where id = adattatore;
  select count(*) into n from public.voce_lista
   where id = adattatore and assegnato_a = b and lasciata_da is null;
  if n <> 1 then raise exception 'FALLITA: una voce presa resta «tornata libera»'; end if;
  update public.voce_lista set spuntata = true where id = ombrello;
  select count(*) into n from public.voce_lista where id = ombrello and lasciata_da = c;
  if n <> 1 then raise exception 'FALLITA: spuntare una voce libera dimentica chi la portava'; end if;
  log := log || E'\nok  presa da qualcuno non è più tornata libera; spuntata sì';

  -- ── Spostare una voce ───────────────────────────────────────────────────
  -- Dalla propria lista a quella del viaggio: la porta chi la sposta.
  select versione into ver from public.voce_lista where id = spazzolino;
  righe := public.sposta_voce(spazzolino, ver, nuova1);
  if righe -> 'nuova' ->> 'id' <> nuova1::text then
    raise exception 'FALLITA: lo spostamento non restituisce la voce nuova';
  end if;
  select count(*) into n from public.voce_lista
   where id = spazzolino and eliminato_il is not null;
  if n <> 1 then raise exception 'FALLITA: la voce spostata resta nella lista di prima'; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  select count(*) into n from public.voce_lista
   where id = nuova1 and tipo = 'viaggio' and assegnato_a = b and proprietario_id = b
     and testo = 'Spazzolino' and spuntata and eliminato_il is null;
  if n <> 1 then raise exception 'FALLITA: la voce spostata nel viaggio non la vedono gli altri, o non è di chi la porta'; end if;
  log := log || E'\nok  dalla propria lista a quella del viaggio: la vedono tutti, la porta chi l''ha spostata, con la sua spunta';

  -- Da quella del viaggio alla propria: sparisce agli altri.
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  select versione into ver from public.voce_lista where id = ombrello;
  perform public.sposta_voce(ombrello, ver, nuova2);
  select count(*) into n from public.voce_lista
   where id = nuova2 and tipo = 'personale' and proprietario_id = b and assegnato_a is null
     and testo = 'Ombrello' and spuntata;
  if n <> 1 then raise exception 'FALLITA: la voce non arriva nella propria lista'; end if;

  -- La risposta persa: rimandato, non ne nasce un'altra.
  righe := public.sposta_voce(ombrello, ver, nuova2);
  select count(*) into n from public.voce_lista
   where proprietario_id = b and testo = 'Ombrello';
  if n <> 1 or righe -> 'nuova' ->> 'id' <> nuova2::text then
    raise exception 'FALLITA: spostare due volte la stessa voce ne fa due';
  end if;

  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  select count(*) into n from public.voce_lista where id = nuova2;
  if n <> 0 then raise exception 'FALLITA: gli altri vedono la voce diventata personale'; end if;
  select count(*) into n from public.voce_lista where id = ombrello and eliminato_il is not null;
  if n <> 1 then raise exception 'FALLITA: gli altri non sanno che la voce è uscita dalla lista del viaggio'; end if;
  log := log || E'\nok  da quella del viaggio alla propria: per gli altri è tolta, e rimandarlo non la raddoppia';

  -- Su una versione superata si rifiuta, come ogni modifica.
  select versione into ver from public.voce_lista where id = mappa;
  update public.voce_lista set testo = 'Mappa di Porto', versione = ver where id = mappa;
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform public.sposta_voce(mappa, ver, nuova3);
  exception when sqlstate 'TR409' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si sposta una voce su una versione superata'; end if;
  select count(*) into n from public.voce_lista where id = nuova3;
  if n <> 0 then raise exception 'FALLITA: uno spostamento rifiutato lascia la voce nuova'; end if;
  log := log || E'\nok  una voce cambiata intanto non si sposta: insieme o niente';

  -- La personale di un altro non si sposta, e un estraneo non sposta niente.
  fallita := false;
  begin
    perform public.sposta_voce(diario, 1, nuova3);
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si sposta la voce personale di un altro'; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  select versione into ver from public.voce_lista where id = powerbank;
  fallita := false;
  begin
    perform public.sposta_voce(powerbank, coalesce(ver, 1), nuova3);
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un estraneo sposta una voce'; end if;
  log := log || E'\nok  non si sposta la personale di un altro, e un estraneo niente';

  -- ── A toglie B: le sue voci tornano libere, e arrivano con le righe ─────
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  righe := public.rimuovi_partecipante(v, b);
  select count(*) into n
    from jsonb_array_elements(righe -> 'voci') r
   where (r ->> 'id')::uuid in (powerbank, crema, adattatore, nuova1)
     and r ->> 'assegnato_a' is null and (r ->> 'lasciata_da')::uuid = b;
  if n <> 4 then raise exception 'FALLITA: togliere qualcuno non libera le sue voci, o non le restituisce (%)', n; end if;
  select count(*) into n from public.voce_lista
   where viaggio_id = v and assegnato_a = b;
  if n <> 0 then raise exception 'FALLITA: chi è stato tolto porta ancora qualcosa'; end if;
  log := log || E'\nok  chi è tolto lascia libere le voci che portava, e chi toglie le riceve subito';

  raise exception 'TUTTE LE PROVE PASSATE (annullate)%', log;
end;
$$;
