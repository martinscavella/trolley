-- Prova delle tappe (fase 1.2): i due gesti della coda che le riguardano
-- (aggiungere e marcare), le modifiche con la versione, l'ordine di una giornata.
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
  altro uuid := gen_random_uuid();
  g1 uuid := gen_random_uuid();
  g2 uuid := gen_random_uuid();
  g_altro uuid := gen_random_uuid();
  t1 uuid := gen_random_uuid();
  t2 uuid := gen_random_uuid();
  t3 uuid := gen_random_uuid();
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

  perform public.crea_viaggio(v, 'Porto', 'PT', null, '2026-10-10', '2026-10-11', '10:00', '18:00',
    jsonb_build_array(
      jsonb_build_object('id', g1, 'data', '2026-10-10', 'inizio', '10:00:00', 'fine', '24:00:00'),
      jsonb_build_object('id', g2, 'data', '2026-10-11', 'inizio', '00:00:00', 'fine', '18:00:00')));
  perform public.crea_viaggio(altro, 'Faro', 'PT', null, '2026-11-01', '2026-11-01', '09:00', '20:00',
    jsonb_build_array(
      jsonb_build_object('id', g_altro, 'data', '2026-11-01', 'inizio', '09:00:00', 'fine', '20:00:00')));
  insert into public.invito (viaggio_id) values (v) returning token into codice;

  -- ── Aggiungere: un gesto della coda ─────────────────────────────────────
  insert into public.tappa (id, viaggio_id, giorno_id, ordine, titolo, tipo, durata_stimata_min)
  values (t1, v, g1, 1, 'Livraria Lello', 'visita', 90);
  select count(*) into n from public.tappa
   where id = t1 and creato_da = a and stato = 'da_fare' and versione = 1 and tipo = 'visita';
  if n <> 1 then raise exception 'FALLITA: la tappa non nasce da fare, a nome di chi la aggiunge'; end if;
  log := log || E'\nok  si aggiunge una tappa con l''id nato sul telefono';

  -- La coda rimanda quello che non sa se è arrivato: la seconda volta non fa niente.
  insert into public.tappa (id, viaggio_id, giorno_id, ordine, titolo, tipo, durata_stimata_min)
  values (t1, v, g1, 1, 'Livraria Lello', 'visita', 90)
  on conflict (id) do nothing;
  select count(*) into n from public.tappa where viaggio_id = v;
  if n <> 1 then raise exception 'FALLITA: rimandare la stessa tappa la duplica'; end if;
  log := log || E'\nok  rimandare la stessa tappa non la duplica';

  fallita := false;
  begin
    insert into public.tappa (viaggio_id, giorno_id, ordine, titolo, tipo, durata_stimata_min)
    values (v, g1, 2, 'Tipo inventato', 'shopping', 60);
  exception when check_violation then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si accetta un tipo che non esiste'; end if;
  log := log || E'\nok  il tipo è uno di quelli previsti, o nessuno';

  fallita := false;
  begin
    insert into public.tappa (viaggio_id, giorno_id, ordine, titolo, durata_stimata_min)
    values (v, g_altro, 2, 'Giorno di un altro viaggio', 60);
  exception when foreign_key_violation then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: una tappa finisce nel giorno di un altro viaggio'; end if;
  log := log || E'\nok  una tappa sta solo nei giorni del suo viaggio';

  insert into public.tappa (id, viaggio_id, giorno_id, ordine, titolo, durata_stimata_min)
  values (t2, v, g1, 2, 'Ponte Dom Luís', 60),
         (t3, v, g1, 3, 'Cena a Ribeira', 90);

  -- ── B: entra con l'invito, e marca la tappa di A ───────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (b, 'Marco', '1994-07-20');
  perform public.accetta_invito(codice);

  -- Marcare non porta la versione: passa sempre, vince l'ultima che arriva.
  update public.tappa
     set stato = 'completata', marcata_il = now(), marcata_durante_il_viaggio = true
   where id = t1;
  select count(*) into n from public.tappa where id = t1 and stato = 'completata' and versione = 2;
  if n <> 1 then raise exception 'FALLITA: chi partecipa non marca la tappa di un altro'; end if;
  log := log || E'\nok  chi partecipa marca anche le tappe degli altri, senza versione';

  -- ── A: modifica con la versione che aveva visto ─────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    update public.tappa set durata_stimata_min = 120, versione = 1 where id = t1;
  exception when sqlstate 'TR409' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si modifica una tappa su una versione superata'; end if;
  log := log || E'\nok  una modifica su una versione superata si rifiuta';

  select versione into ver from public.tappa where id = t1;
  fallita := false;
  begin
    update public.tappa set giorno_id = g_altro, versione = ver where id = t1;
  exception when foreign_key_violation then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: una tappa si sposta nel giorno di un altro viaggio'; end if;
  update public.tappa set giorno_id = g2, ordine = 1, versione = ver where id = t1;
  select count(*) into n from public.tappa where id = t1 and giorno_id = g2;
  if n <> 1 then raise exception 'FALLITA: una tappa non si sposta in un altro giorno'; end if;
  log := log || E'\nok  una tappa si sposta fra i giorni del suo viaggio, non oltre';

  -- ── L'ordine di una giornata ────────────────────────────────────────────
  select count(*) into n from public.ordina_tappe(g1, array[t3, t2]);
  if n <> 2 then raise exception 'FALLITA: ordina_tappe non restituisce le righe scritte'; end if;
  select count(*) into n from public.tappa
   where (id = t3 and ordine = 1) or (id = t2 and ordine = 2);
  if n <> 2 then raise exception 'FALLITA: la giornata non prende l''ordine voluto'; end if;
  log := log || E'\nok  una giornata si riordina in una scrittura sola';

  select count(*) into n from public.ordina_tappe(g2, array[t3, t2]);
  if n <> 0 then raise exception 'FALLITA: ordina_tappe tocca tappe di un altro giorno'; end if;
  log := log || E'\nok  si riordinano solo le tappe del giorno indicato';

  select versione into ver from public.tappa where id = t2;
  update public.tappa set eliminato_il = now(), versione = ver where id = t2;
  select count(*) into n from public.ordina_tappe(g1, array[t2, t3]);
  if n <> 1 then raise exception 'FALLITA: una tappa tolta si riordina ancora'; end if;
  select count(*) into n from public.tappa where id = t2 and eliminato_il is not null;
  if n <> 1 then raise exception 'FALLITA: togliere una tappa la cancella davvero'; end if;
  log := log || E'\nok  una tappa tolta resta marcata, e non si riordina più';

  -- ── C: estraneo ─────────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (c, 'Carlo', '1990-01-01');

  select count(*) into n from public.ordina_tappe(g1, array[t3]);
  if n <> 0 then raise exception 'FALLITA: un estraneo riordina le tappe'; end if;
  update public.tappa set stato = 'saltata' where id = t3;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLITA: un estraneo marca una tappa'; end if;
  fallita := false;
  begin
    insert into public.tappa (id, viaggio_id, giorno_id, ordine, titolo, durata_stimata_min)
    values (t2, v, g1, 9, 'Sovrascrittura', 30)
    on conflict (id) do nothing;
  exception when others then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un estraneo aggiunge una tappa rimandandola'; end if;
  log := log || E'\nok  un estraneo non riordina, non marca, non aggiunge';

  -- ── anon ────────────────────────────────────────────────────────────────
  if has_function_privilege('anon', 'public.ordina_tappe(uuid, uuid[])', 'execute') then
    raise exception 'FALLITA: anon può chiamare ordina_tappe';
  end if;
  log := log || E'\nok  senza accesso non si riordina niente';

  raise exception 'TUTTE LE PROVE PASSATE (annullate)%', log;
end;
$$;
