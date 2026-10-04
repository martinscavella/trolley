-- Prova di chi ha scritto l'ultima versione (fase 2.2): il server lo scrive da
-- sé, nessuno lo dichiara a nome di un altro, e una modifica su una versione
-- superata si rifiuta senza cambiare niente.
--
-- Come regole_di_accesso.sql: gira dentro un blocco che alla fine solleva
-- un'eccezione e non lascia niente. Il messaggio finale è il resoconto.
--
-- Due persone: A crea il viaggio, B entra con l'invito.

do $$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  v uuid := gen_random_uuid();
  g1 uuid := gen_random_uuid();
  t1 uuid := gen_random_uuid();
  s1 uuid := gen_random_uuid();
  vb uuid := gen_random_uuid();
  n1 uuid := gen_random_uuid();
  codice text;
  n int;
  chi uuid;
  quando timestamptz;
  fallita boolean;
  log text := '';
begin
  insert into auth.users (id, email) values
    (a, a || '@prova.local'), (b, b || '@prova.local');

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (b, 'Marco', '1994-03-01');

  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (a, 'Giulia', '1995-04-02');
  perform public.crea_viaggio(v, 'Porto', 'PT', null, '2026-10-10', '2026-10-10', '10:00', '18:00',
    jsonb_build_array(
      jsonb_build_object('id', g1, 'data', '2026-10-10', 'inizio', '10:00:00', 'fine', '18:00:00')));
  insert into public.invito (viaggio_id) values (v) returning token into codice;

  select modificato_da into chi from public.viaggio where id = v;
  if chi is distinct from a then raise exception 'FALLITA: il viaggio nuovo non dice chi l''ha scritto'; end if;
  log := log || E'\nok  una cosa nuova è di chi l''ha scritta';

  -- ── B entra, e aggiunge una tappa provando a firmarla a nome di A ─────────
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  perform public.accetta_invito(codice);
  insert into public.tappa (id, viaggio_id, giorno_id, ordine, titolo, tipo, durata_stimata_min, modificato_da)
  values (t1, v, g1, 1, 'Torre dos Clérigos', 'visita', 60, a);
  select modificato_da into chi from public.tappa where id = t1;
  if chi is distinct from b then raise exception 'FALLITA: si aggiunge una tappa a nome di un altro'; end if;
  log := log || E'\nok  aggiungendo non si firma a nome di un altro';

  -- ── A la cambia, con la versione su cui ha deciso ────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  select modificato_il into quando from public.tappa where id = t1;
  update public.tappa set titolo = 'Torre e chiesa dos Clérigos', versione = 1 where id = t1;
  select count(*) into n from public.tappa
   where id = t1 and modificato_da = a and versione = 2 and modificato_il >= quando;
  if n <> 1 then raise exception 'FALLITA: la tappa cambiata non dice chi l''ha cambiata'; end if;
  log := log || E'\nok  chi cambia una tappa ne diventa l''autore, e il quando avanza';

  -- ── B la cambia sulla versione vecchia: si rifiuta, e resta di A ──────────
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    update public.tappa set durata_stimata_min = 90, versione = 1 where id = t1;
  exception when sqlstate 'TR409' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: una modifica su una versione superata passa'; end if;
  select count(*) into n from public.tappa
   where id = t1 and modificato_da = a and durata_stimata_min = 60 and versione = 2;
  if n <> 1 then raise exception 'FALLITA: il rifiuto ha cambiato la tappa'; end if;
  log := log || E'\nok  sulla versione superata si rifiuta (TR409), e non cambia niente';

  -- Firmare a nome di A una modifica: il server scrive B.
  update public.tappa set durata_stimata_min = 90, versione = 2, modificato_da = a where id = t1;
  select modificato_da into chi from public.tappa where id = t1;
  if chi is distinct from b then raise exception 'FALLITA: si cambia una tappa a nome di un altro'; end if;

  -- Il gesto della coda, senza versione: anche lui dice chi è stato.
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  update public.tappa set stato = 'completata', marcata_il = now() where id = t1;
  select modificato_da into chi from public.tappa where id = t1;
  if chi is distinct from a then raise exception 'FALLITA: marcare non dice chi ha marcato'; end if;
  log := log || E'\nok  modificando non si firma a nome di un altro; anche marcare dice chi';

  -- ── Spesa, voce, nota, viaggio ───────────────────────────────────────────
  insert into public.spesa (id, viaggio_id, importo, valuta, pagante_id, data, descrizione, creato_da)
  values (s1, v, 42, 'EUR', a, '2026-10-10', 'Cena', a);
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  update public.spesa set importo = 48, versione = 1 where id = s1;
  select modificato_da into chi from public.spesa where id = s1;
  if chi is distinct from b then raise exception 'FALLITA: la spesa cambiata non dice chi'; end if;

  insert into public.voce_lista (id, viaggio_id, testo, tipo, quantita, proprietario_id, creato_da)
  values (vb, v, 'Adattatore', 'personale', 1, b, b);
  update public.voce_lista set testo = 'Adattatore tipo A', versione = 1 where id = vb;
  select modificato_da into chi from public.voce_lista where id = vb;
  if chi is distinct from b then raise exception 'FALLITA: la voce cambiata non dice chi'; end if;

  insert into public.nota (id, viaggio_id, testo, origine, creato_da)
  values (n1, v, 'Prendere il tram 22', 'scritta', b);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  update public.nota set eliminato_il = now(), versione = 1 where id = n1;
  select modificato_da into chi from public.nota where id = n1;
  if chi is distinct from a then raise exception 'FALLITA: la nota tolta non dice chi'; end if;

  -- Il viaggio, anche quando lo cambia una funzione del server.
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  perform public.programma_viaggio(v, 1, '2026-10-10', '2026-10-11', '10:00', '18:00',
    jsonb_build_array(
      jsonb_build_object('id', g1, 'data', '2026-10-10', 'inizio', '10:00:00', 'fine', '24:00:00'),
      jsonb_build_object('id', gen_random_uuid(), 'data', '2026-10-11', 'inizio', '00:00:00', 'fine', '18:00:00')));
  select modificato_da into chi from public.viaggio where id = v;
  if chi is distinct from b then raise exception 'FALLITA: le date spostate non dicono chi'; end if;
  log := log || E'\nok  spesa, voce, nota e viaggio dicono chi li ha cambiati, anche dentro le funzioni';

  -- ── La funzione non si chiama dall'API ────────────────────────────────────
  if has_function_privilege('authenticated', 'privato.segna_autore()', 'execute')
     or has_function_privilege('anon', 'privato.segna_autore()', 'execute') then
    raise exception 'FALLITA: segna_autore si può chiamare dall''API';
  end if;
  log := log || E'\nok  segna_autore non si chiama da fuori';

  raise exception 'TUTTE LE PROVE PASSATE (annullate)%', log;
end;
$$;
