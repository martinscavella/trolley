-- Prova di «I tuoi dati» e della chiusura dell'account (U.1): scaricare
-- solo ciò che si vede; chiudendo, i viaggi da soli si cancellano, dagli
-- altri si esce lasciando i contributi, il ruolo passa, il profilo resta
-- come lapide senza dati personali, gli eventi cambiano id.
--
-- Va lanciata dopo la migrazione chiusura_account.sql. Come
-- regole_di_accesso.sql: gira dentro un blocco che alla fine solleva
-- un'eccezione e non lascia niente. Il messaggio finale è il resoconto.
--
-- Giulia chiude l'account. Con Marco e Sara è a Porto, di cui è responsabile:
-- Marco è entrato prima di Sara. A Lisbona c'è con Sara, che ne è
-- responsabile. A Berlino è da sola, e ha un'idea. Dario è un estraneo.

do $$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  c uuid := gen_random_uuid();
  d uuid := gen_random_uuid();
  e uuid := gen_random_uuid();
  f uuid := gen_random_uuid();
  g uuid := gen_random_uuid();
  porto uuid := gen_random_uuid();
  berlino uuid := gen_random_uuid();
  idea uuid := gen_random_uuid();
  lisbona uuid := gen_random_uuid();
  solo_e uuid := gen_random_uuid();
  s_porto uuid := gen_random_uuid();
  s_berlino uuid := gen_random_uuid();
  voce_presa uuid := gen_random_uuid();
  voce_mia uuid := gen_random_uuid();
  ev_vecchio uuid := gen_random_uuid();
  ev_e uuid := gen_random_uuid();
  ev_f uuid := gen_random_uuid();
  codice text;
  codice_giulia text;
  dati jsonb;
  anonimo uuid;
  n int;
  fallita boolean;
  log text := '';
begin
  insert into auth.users (id, email) values
    (a, a || '@prova.local'), (b, b || '@prova.local'), (c, c || '@prova.local'),
    (d, d || '@prova.local'), (e, e || '@prova.local'), (f, f || '@prova.local'),
    (g, g || '@prova.local');

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (b, 'Marco', '1994-03-01');
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (c, 'Sara', '1993-06-11');
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (d, 'Dario', '1990-01-01');
  perform set_config('request.jwt.claims', json_build_object('sub', e, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (e, 'Elena', '1991-02-02');
  perform set_config('request.jwt.claims', json_build_object('sub', f, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (f, 'Franco', '1992-03-03');

  -- Porto: Giulia lo crea, Marco entra dal suo link.
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (a, 'Giulia', '1995-04-02');
  perform public.crea_viaggio(porto, 'Porto', 'PT', null, '2026-10-10', '2026-10-11', '10:00', '18:00',
    jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'data', '2026-10-10', 'inizio', '10:00:00', 'fine', '24:00:00'),
      jsonb_build_object('id', gen_random_uuid(), 'data', '2026-10-11', 'inizio', '00:00:00', 'fine', '18:00:00')));
  insert into public.invito (viaggio_id) values (porto) returning token into codice;
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  perform public.accetta_invito(codice);

  -- Sara entra dopo: nella stessa transazione now() è uguale per tutti, quindi
  -- la sua partecipazione nasce qui, un minuto più tardi.
  perform set_config('role', 'postgres', true);
  insert into public.partecipazione (viaggio_id, utente_id, ruolo, stato, creato_da, creato_il)
  values (porto, c, 'partecipante', 'attivo', c, now() + interval '1 minute');
  perform set_config('role', 'authenticated', true);

  -- A Porto Giulia paga una cena per due, porta la crema, ha lo spazzolino
  -- fra le sue cose, e ha in giro un altro link.
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.registra_spesa(
    jsonb_build_object('id', s_porto, 'viaggio_id', porto, 'importo', '40.00', 'valuta', 'EUR',
                       'pagante_id', a, 'data', '2026-10-10', 'descrizione', 'Cena'),
    jsonb_build_array(jsonb_build_object('utente_id', a, 'quota', '20.00'),
                      jsonb_build_object('utente_id', b, 'quota', '20.00')));
  insert into public.voce_lista (id, viaggio_id, testo, tipo, assegnato_a)
  values (voce_presa, porto, 'Crema solare', 'viaggio', a);
  insert into public.voce_lista (id, viaggio_id, testo, tipo)
  values (voce_mia, porto, 'Spazzolino', 'personale');
  insert into public.invito (viaggio_id) values (porto) returning token into codice_giulia;

  -- Berlino da sola, con una spesa; e un'idea.
  perform public.crea_viaggio(berlino, 'Berlino', 'DE', null, '2026-11-02', '2026-11-02', '10:00', '18:00',
    jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'data', '2026-11-02', 'inizio', '10:00:00', 'fine', '18:00:00')));
  perform public.registra_spesa(
    jsonb_build_object('id', s_berlino, 'viaggio_id', berlino, 'importo', '12.00', 'valuta', 'EUR',
                       'pagante_id', a, 'data', '2026-11-02'),
    jsonb_build_array(jsonb_build_object('utente_id', a, 'quota', '12.00')));
  insert into public.viaggio (id, stato, creatore_id) values (idea, 'idea', a);
  insert into public.evento (id, nome, avvenuto_il) values (ev_vecchio, 'viaggio_creato', now());

  -- Lisbona è di Sara; Giulia entra.
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  perform public.crea_viaggio(lisbona, 'Lisbona', 'PT', 'maggio 2027', null, null, null, null, '[]'::jsonb);
  insert into public.invito (viaggio_id) values (lisbona) returning token into codice;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.accetta_invito(codice);

  -- I traguardi li scrive solo il server.
  perform set_config('role', 'postgres', true);
  insert into public.traguardo (utente_id, tipo, viaggio_id) values
    (a, 'organizzare', berlino), (a, 'in_compagnia', porto);
  perform set_config('role', 'authenticated', true);

  -- ── I tuoi dati: solo ciò che si vede ───────────────────────────────────
  perform set_config('request.jwt.claims',
    json_build_object('sub', a, 'role', 'authenticated', 'email', 'giulia@prova.local')::text, true);
  dati := public.i_miei_dati();
  if dati ->> 'formato' <> 'trolley.dati' or dati ->> 'email' <> 'giulia@prova.local'
     or dati -> 'profilo' ->> 'nome' <> 'Giulia'
     or dati -> 'profilo' ->> 'data_nascita' <> '1995-04-02' then
    raise exception 'FALLITA: i dati non portano il profilo (%)', dati -> 'profilo';
  end if;
  if jsonb_array_length(dati -> 'viaggi') <> 4
     or jsonb_array_length(dati -> 'traguardi') <> 2
     or jsonb_array_length(dati -> 'eventi') <> 1 then
    raise exception 'FALLITA: i dati di Giulia non hanno 4 viaggi, 2 traguardi, 1 evento';
  end if;
  select count(*) into n
    from jsonb_array_elements(dati -> 'viaggi') v
   where v -> 'viaggio' ->> 'id' = porto::text
     and jsonb_array_length(v -> 'voci') = 2
     and jsonb_array_length(v -> 'spese') = 1
     and jsonb_array_length(v -> 'quote') = 2
     and jsonb_array_length(v -> 'giorni') = 2
     and jsonb_array_length(v -> 'persone') = 3;
  if n <> 1 then raise exception 'FALLITA: Porto nei dati di Giulia non è com''è'; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  dati := public.i_miei_dati();
  if jsonb_array_length(dati -> 'viaggi') <> 1
     or jsonb_array_length(dati -> 'traguardi') <> 0
     or jsonb_array_length(dati -> 'eventi') <> 0
     or jsonb_array_length(dati -> 'viaggi' -> 0 -> 'voci') <> 1
     or dati -> 'profilo' ->> 'nome' <> 'Marco' then
    raise exception 'FALLITA: Marco scarica cose che non vede (%)', dati;
  end if;
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  dati := public.i_miei_dati();
  if jsonb_array_length(dati -> 'viaggi') <> 0 then
    raise exception 'FALLITA: un estraneo scarica i viaggi degli altri';
  end if;
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  fallita := false;
  begin
    perform public.i_miei_dati();
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: senza accesso si scaricano dei dati'; end if;
  fallita := false;
  begin
    perform public.chiudi_account();
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: senza accesso si chiude un account'; end if;
  perform set_config('role', 'authenticated', true);
  log := log || E'\nok  ognuno scarica il suo profilo, i viaggi che vede, i suoi traguardi ed eventi';

  -- ── La chiusura passa solo da chiudi_account ─────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    update public.utente set eliminato_il = now() where id = b;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un profilo si chiude a mano'; end if;
  log := log || E'\nok  un profilo non si chiude scrivendolo';

  -- ── Giulia chiude ────────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.chiudi_account(true);

  perform set_config('role', 'postgres', true);
  select count(*) into n from auth.users where id = a;
  if n <> 0 then raise exception 'FALLITA: l''accesso di Giulia c''è ancora'; end if;
  select count(*) into n from public.utente
   where id = a and nome is null and data_nascita is null and eliminato_il is not null
     and not telefono_verificato and not profilo_pubblico_attivo;
  if n <> 1 then raise exception 'FALLITA: il profilo di Giulia non è una lapide'; end if;
  log := log || E'\nok  l''accesso sparisce, il profilo resta senza nome né data di nascita';

  select count(*) into n from public.viaggio where id in (berlino, idea);
  if n <> 0 then raise exception 'FALLITA: i viaggi da sola ci sono ancora'; end if;
  select count(*) into n from public.spesa where viaggio_id = berlino;
  if n <> 0 then raise exception 'FALLITA: le spese di Berlino ci sono ancora'; end if;
  select count(*) into n from public.giorno where viaggio_id = berlino;
  if n <> 0 then raise exception 'FALLITA: i giorni di Berlino ci sono ancora'; end if;
  select count(*) into n from public.partecipazione where viaggio_id in (berlino, idea);
  if n <> 0 then raise exception 'FALLITA: le partecipazioni dei viaggi cancellati ci sono ancora'; end if;
  log := log || E'\nok  i viaggi in cui era da sola, e l''idea, si cancellano con tutto dentro';

  select count(*) into n from public.viaggio where id = porto and creatore_id = b;
  if n <> 1 then raise exception 'FALLITA: Porto non passa a Marco'; end if;
  select count(*) into n from public.partecipazione
   where viaggio_id = porto and ruolo = 'creatore' and stato = 'attivo';
  if n <> 1 then raise exception 'FALLITA: Porto non ha un solo responsabile'; end if;
  select count(*) into n from public.partecipazione
   where viaggio_id = porto and utente_id = b and ruolo = 'creatore';
  if n <> 1 then raise exception 'FALLITA: il ruolo non va a chi è entrato per primo'; end if;
  select count(*) into n from public.partecipazione
   where viaggio_id = porto and utente_id = a and ruolo = 'partecipante' and stato = 'uscito';
  if n <> 1 then raise exception 'FALLITA: Giulia non esce da Porto'; end if;
  select count(*) into n from public.partecipazione
   where viaggio_id = lisbona and utente_id = a and stato = 'uscito';
  if n <> 1 then raise exception 'FALLITA: Giulia non esce da Lisbona'; end if;
  select count(*) into n from public.viaggio where id = lisbona and creatore_id = c;
  if n <> 1 then raise exception 'FALLITA: Lisbona cambia responsabile'; end if;
  log := log || E'\nok  dai viaggi con altri esce; il ruolo passa a chi è entrato per primo';

  select count(*) into n from public.spesa where id = s_porto and pagante_id = a;
  if n <> 1 then raise exception 'FALLITA: la cena pagata da Giulia sparisce'; end if;
  select count(*) into n from public.spesa_quota where spesa_id = s_porto;
  if n <> 2 then raise exception 'FALLITA: le quote della cena cambiano'; end if;
  select count(*) into n from public.voce_lista
   where id = voce_presa and assegnato_a is null and lasciata_da = a;
  if n <> 1 then raise exception 'FALLITA: la crema non torna libera'; end if;
  select count(*) into n from public.voce_lista where id = voce_mia;
  if n <> 0 then raise exception 'FALLITA: lo spazzolino di Giulia resta'; end if;
  select count(*) into n from public.traguardo where utente_id = a;
  if n <> 0 then raise exception 'FALLITA: i traguardi di Giulia restano'; end if;
  select count(*) into n from public.invito where token = codice_giulia and eliminato_il is null;
  if n <> 0 then raise exception 'FALLITA: il link di Giulia fa ancora entrare'; end if;
  log := log || E'\nok  le spese restano nei saldi, le voci tornano libere, ciò che era solo suo va via';

  select count(*) into n from public.evento where utente_id = a;
  if n <> 0 then raise exception 'FALLITA: degli eventi portano ancora a Giulia'; end if;
  select utente_id into anonimo from public.evento where id = ev_vecchio;
  select count(*) into n from public.evento
   where utente_id = anonimo and nome = 'account_chiuso'
     and (proprieta ->> 'viaggi_cancellati')::int = 2
     and (proprieta ->> 'viaggi_lasciati')::int = 2;
  if anonimo is null or n <> 1 then
    raise exception 'FALLITA: gli eventi di Giulia non hanno un id nuovo, lo stesso per tutti';
  end if;
  select count(*) into n from public.utente where id = anonimo;
  if n <> 0 then raise exception 'FALLITA: l''id nuovo porta a un profilo'; end if;
  log := log || E'\nok  gli eventi restano, con account_chiuso, sotto un id nuovo che non porta a lei';

  -- Marco vede ancora Porto, la cena e chi l'ha pagata, senza nome.
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  select count(*) into n from public.utente where id = a and nome is null and eliminato_il is not null;
  if n <> 1 then raise exception 'FALLITA: Marco non vede che Giulia ha chiuso'; end if;
  select count(*) into n from public.spesa where id = s_porto;
  if n <> 1 then raise exception 'FALLITA: Marco non vede più la cena'; end if;
  log := log || E'\nok  i compagni vedono i contributi, e chi li ha fatti senza nome';

  -- Il link di Giulia non fa entrare Dario.
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform public.accetta_invito(codice_giulia);
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si entra con il link di chi ha chiuso'; end if;

  -- Rimandata (la risposta si era persa): non fa niente e non sbaglia.
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.chiudi_account(true);
  log := log || E'\nok  i suoi link non fanno entrare; chiudere di nuovo non fa niente';

  -- ── Interno, misurazione spenta, senza profilo ───────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', e, 'role', 'authenticated')::text, true);
  perform public.crea_viaggio(solo_e, 'Roma', 'IT', 'giugno 2027', null, null, null, null, '[]'::jsonb);
  insert into public.evento (id, nome, avvenuto_il) values (ev_e, 'viaggio_creato', now());
  perform set_config('role', 'postgres', true);
  update public.utente set interno = true where id = e;
  perform set_config('role', 'authenticated', true);
  perform public.chiudi_account(true);

  perform set_config('request.jwt.claims', json_build_object('sub', f, 'role', 'authenticated')::text, true);
  insert into public.evento (id, nome, avvenuto_il) values (ev_f, 'viaggio_creato', now());
  perform public.chiudi_account(false);

  perform set_config('request.jwt.claims', json_build_object('sub', g, 'role', 'authenticated')::text, true);
  perform public.chiudi_account(true);

  perform set_config('role', 'postgres', true);
  select count(*) into n from public.evento where id = ev_e;
  if n <> 0 then raise exception 'FALLITA: gli eventi di un account interno restano'; end if;
  select utente_id into anonimo from public.evento where id = ev_f;
  if anonimo is null or anonimo = f then
    raise exception 'FALLITA: gli eventi di chi ha spento la misurazione non cambiano id';
  end if;
  select count(*) into n from public.evento where utente_id = anonimo;
  if n <> 1 then raise exception 'FALLITA: con la misurazione spenta resta account_chiuso'; end if;
  select count(*) into n from auth.users where id in (e, f, g);
  if n <> 0 then raise exception 'FALLITA: un accesso resta'; end if;
  select count(*) into n from public.viaggio where id = solo_e;
  if n <> 0 then raise exception 'FALLITA: il viaggio di un account interno resta'; end if;
  log := log || E'\nok  interno: niente eventi; misurazione spenta: niente account_chiuso; senza profilo: si chiude';

  raise exception 'TUTTE LE PROVE PASSATE (annullate)%', log;
end;
$$;
