-- Prova del mezzo di un tragitto (CR-07, ADR-015; migrazione
-- mezzo_della_tappa): chi partecipa lo sceglie e lo cambia, e cambiarlo fa
-- una versione nuova; un valore che non è un mezzo non entra; chi non
-- partecipa non lo tocca.
--
-- Come le altre prove: gira dentro un blocco che alla fine solleva
-- un'eccezione e non lascia niente. Il messaggio finale è il resoconto.

do $$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  c uuid := gen_random_uuid();
  v uuid := gen_random_uuid();
  g1 uuid := gen_random_uuid();
  t uuid := gen_random_uuid();
  codice text;
  n int;
  ver int;
  fallita boolean;
  log text := '';
begin
  insert into auth.users (id, email) values
    (a, a || '@prova.local'), (b, b || '@prova.local'), (c, c || '@prova.local');

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (a, 'Giulia', '1995-04-02');
  perform public.crea_viaggio(v, 'Porto', 'PT', null, '2026-10-11', '2026-10-11', '09:00', '22:00',
    jsonb_build_array(
      jsonb_build_object('id', g1, 'data', '2026-10-11', 'inizio', '09:00:00', 'fine', '22:00:00')));
  insert into public.invito (viaggio_id) values (v) returning token into codice;

  -- ── Una tappa nasce con il mezzo, o senza ───────────────────────────────
  insert into public.tappa (id, viaggio_id, giorno_id, ordine, titolo, durata_stimata_min, mezzo)
  values (t, v, g1, 1, 'Torre dos Clérigos', 60, 'a_piedi');
  select count(*) into n from public.tappa where id = t and mezzo = 'a_piedi';
  if n <> 1 then raise exception 'la tappa non tiene il mezzo'; end if;
  log := log || E'\n✓ una tappa nasce con il suo mezzo';

  insert into public.tappa (viaggio_id, giorno_id, ordine, titolo, durata_stimata_min)
  values (v, g1, 2, 'Pranzo', 90);
  select count(*) into n from public.tappa where viaggio_id = v and mezzo is null;
  if n <> 1 then raise exception 'una tappa senza mezzo non entra'; end if;
  log := log || E'\n✓ senza mezzo è «Come ci vai?»';

  -- ── Solo i sei mezzi ────────────────────────────────────────────────────
  fallita := false;
  begin
    update public.tappa set mezzo = 'elicottero', versione = versione where id = t;
  exception when check_violation then fallita := true;
  end;
  if not fallita then raise exception 'un mezzo che non esiste è entrato'; end if;
  log := log || E'\n✓ un mezzo che non esiste non entra';

  -- ── Cambiarlo fa una versione nuova ─────────────────────────────────────
  select versione into ver from public.tappa where id = t;
  update public.tappa set mezzo = 'mezzi', versione = ver where id = t;
  select count(*) into n from public.tappa where id = t and mezzo = 'mezzi' and versione = ver + 1;
  if n <> 1 then raise exception 'cambiare il mezzo non fa una versione nuova'; end if;
  log := log || E'\n✓ cambiare il mezzo fa una versione nuova';

  fallita := false;
  begin
    update public.tappa set mezzo = 'taxi', versione = ver where id = t;
  exception when sqlstate 'TR409' then fallita := true;
  end;
  if not fallita then raise exception 'un mezzo scelto su una versione vecchia è passato'; end if;
  log := log || E'\n✓ su una versione superata non passa: due versioni';

  -- ── Chi partecipa lo cambia ─────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (b, 'Marco', '1994-01-01');
  perform public.accetta_invito(codice);
  update public.tappa set mezzo = 'bici', versione = ver + 1 where id = t;
  select count(*) into n from public.tappa where id = t and mezzo = 'bici';
  if n <> 1 then raise exception 'chi partecipa non cambia il mezzo'; end if;
  log := log || E'\n✓ chi partecipa cambia il mezzo';

  -- ── Chi non partecipa no ────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (c, 'Luca', '1990-01-01');
  update public.tappa set mezzo = 'auto', versione = ver + 2 where id = t;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  select count(*) into n from public.tappa where id = t and mezzo = 'bici';
  if n <> 1 then raise exception 'chi non partecipa ha cambiato il mezzo'; end if;
  log := log || E'\n✓ chi non partecipa non lo tocca';

  raise exception 'PASSATE%', log;
end;
$$;
