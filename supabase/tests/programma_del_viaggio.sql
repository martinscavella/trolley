-- Prova di crea_viaggio, programma_viaggio e torna_idea: date e giorni scritti
-- insieme, con le regole di accesso di chi chiama.
--
-- Come regole_di_accesso.sql: gira dentro un blocco che alla fine solleva
-- un'eccezione e non lascia niente. Il messaggio finale è il resoconto.
--
-- Tre persone: A crea i viaggi, B entra con l'invito, C è un estraneo.

do $$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  c uuid := gen_random_uuid();
  idea uuid := gen_random_uuid();
  v uuid := gen_random_uuid();
  g1 uuid := gen_random_uuid();
  g2 uuid := gen_random_uuid();
  g3 uuid := gen_random_uuid();
  g4 uuid := gen_random_uuid();
  t uuid := gen_random_uuid();
  codice text;
  righe jsonb;
  ver int;
  n int;
  fallita boolean;
  log text := '';
begin
  insert into auth.users (id, email) values
    (a, a || '@prova.local'), (b, b || '@prova.local'), (c, c || '@prova.local');

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (a, 'Giulia', '1995-04-02');

  -- ── Nascere ─────────────────────────────────────────────────────────────
  perform public.crea_viaggio(idea, 'Lisbona', 'PT', 'agosto 2027', null, null, null, null, '[]');
  select count(*) into n from public.viaggio
   where id = idea and stato = 'idea' and periodo_approssimativo = 'agosto 2027' and creatore_id = a;
  if n <> 1 then raise exception 'FALLITA: l''idea non nasce idea, con il suo periodo'; end if;
  select count(*) into n from public.partecipazione where viaggio_id = idea and ruolo = 'creatore';
  if n <> 1 then raise exception 'FALLITA: chi crea l''idea non ne è il creatore'; end if;
  select count(*) into n from public.giorno where viaggio_id = idea;
  if n <> 0 then raise exception 'FALLITA: un''idea ha dei giorni'; end if;
  log := log || E'\nok  senza date nasce un''idea, senza giorni';

  righe := public.crea_viaggio(v, 'Porto', 'PT', 'ignorato', '2026-10-10', '2026-10-12', '10:00', '18:00',
    jsonb_build_array(
      jsonb_build_object('id', g1, 'data', '2026-10-10', 'inizio', '10:00:00', 'fine', '24:00:00'),
      jsonb_build_object('id', g2, 'data', '2026-10-11', 'inizio', '00:00:00', 'fine', '24:00:00'),
      jsonb_build_object('id', g3, 'data', '2026-10-12', 'inizio', '00:00:00', 'fine', '18:00:00')));
  select count(*) into n from public.viaggio
   where id = v and stato = 'definito' and periodo_approssimativo is null;
  if n <> 1 then raise exception 'FALLITA: con le date non nasce definito, o tiene il periodo'; end if;
  select count(*) into n from public.giorno
   where viaggio_id = v and eliminato_il is null and creato_da = a;
  if n <> 3 then raise exception 'FALLITA: il viaggio definito ha % giorni invece di 3', n; end if;
  select count(*) into n from public.giorno where id = g1 and finestra_fine = '24:00';
  if n <> 1 then raise exception 'FALLITA: la giornata non arriva a mezzanotte'; end if;
  log := log || E'\nok  con le date nasce definito, con i suoi giorni';

  if righe->'viaggio'->>'stato' <> 'definito'
     or jsonb_array_length(righe->'giorni') <> 3
     or righe->'giorni'->0->>'data' <> '2026-10-10'
     or righe->'giorni'->0->>'finestra_fine' <> '24:00:00'
     or jsonb_array_length(righe->'partecipazioni') <> 1 then
    raise exception 'FALLITA: crea_viaggio non restituisce le righe scritte: %', righe;
  end if;
  log := log || E'\nok  si ricevono indietro le righe scritte, per la copia locale';

  fallita := false;
  begin
    perform public.crea_viaggio(gen_random_uuid(), 'Faro', 'PT', null, '2026-11-01', '2026-11-02', '10:00', '09:00',
      jsonb_build_array(
        jsonb_build_object('id', gen_random_uuid(), 'data', '2026-11-01', 'inizio', '10:00:00', 'fine', '24:00:00'),
        jsonb_build_object('id', gen_random_uuid(), 'data', '2026-11-02', 'inizio', '18:00:00', 'fine', '09:00:00')));
  exception when check_violation then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si accetta un giorno che finisce prima di cominciare'; end if;
  select count(*) into n from public.viaggio where destinazione_citta = 'Faro';
  if n <> 0 then raise exception 'FALLITA: il viaggio resta a metà senza i suoi giorni'; end if;
  log := log || E'\nok  o tutto o niente: un giorno sbagliato non lascia un viaggio a metà';

  -- ── Da idea a definito ──────────────────────────────────────────────────
  select versione into ver from public.viaggio where id = idea;
  perform public.programma_viaggio(idea, ver, '2027-08-01', '2027-08-02', '09:00', '20:00',
    jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'data', '2027-08-01', 'inizio', '09:00:00', 'fine', '24:00:00'),
      jsonb_build_object('id', gen_random_uuid(), 'data', '2027-08-02', 'inizio', '00:00:00', 'fine', '20:00:00')));
  select count(*) into n from public.viaggio
   where id = idea and stato = 'definito' and periodo_approssimativo is null and data_fine = '2027-08-02';
  if n <> 1 then raise exception 'FALLITA: l''idea non diventa definita'; end if;
  select count(*) into n from public.giorno where viaggio_id = idea and eliminato_il is null;
  if n <> 2 then raise exception 'FALLITA: l''idea definita ha % giorni invece di 2', n; end if;
  log := log || E'\nok  fissare le date fa diventare definita l''idea';

  -- ── Spostare le date ────────────────────────────────────────────────────
  insert into public.tappa (id, viaggio_id, giorno_id, ordine, titolo, durata_stimata_min)
  values (t, v, g1, 1, 'Cantine', 120);

  select versione into ver from public.viaggio where id = v;
  perform public.programma_viaggio(v, ver, '2026-10-11', '2026-10-13', '12:00', '18:00',
    jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'data', '2026-10-11', 'inizio', '12:00:00', 'fine', '24:00:00'),
      jsonb_build_object('id', gen_random_uuid(), 'data', '2026-10-12', 'inizio', '00:00:00', 'fine', '24:00:00'),
      jsonb_build_object('id', g4, 'data', '2026-10-13', 'inizio', '00:00:00', 'fine', '18:00:00')));
  select count(*) into n from public.giorno where id = g1 and eliminato_il is not null;
  if n <> 1 then raise exception 'FALLITA: il giorno uscito dalle date non si marca'; end if;
  select count(*) into n from public.giorno
   where id = g2 and eliminato_il is null and finestra_inizio = '12:00';
  if n <> 1 then raise exception 'FALLITA: il giorno rimasto non ha la nuova finestra, o ha cambiato riga'; end if;
  select count(*) into n from public.giorno
   where id = g3 and eliminato_il is null and finestra_fine = '24:00';
  if n <> 1 then raise exception 'FALLITA: il vecchio ultimo giorno non diventa una giornata intera'; end if;
  select count(*) into n from public.giorno where viaggio_id = v and eliminato_il is null;
  if n <> 3 then raise exception 'FALLITA: dopo lo spostamento i giorni sono % invece di 3', n; end if;
  select count(*) into n from public.tappa where id = t and eliminato_il is null;
  if n <> 1 then raise exception 'FALLITA: spostando le date si perde una tappa'; end if;
  log := log || E'\nok  spostare le date marca i giorni usciti, tiene gli altri e non perde tappe';

  fallita := false;
  begin
    perform public.programma_viaggio(v, ver, '2026-10-10', '2026-10-10', '10:00', '18:00',
      jsonb_build_array(jsonb_build_object('id', gen_random_uuid(), 'data', '2026-10-10', 'inizio', '10:00:00', 'fine', '18:00:00')));
  exception when sqlstate 'TR409' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si spostano le date partendo da una versione superata'; end if;
  log := log || E'\nok  date spostate su una versione superata: rifiutate';

  -- ── Tornare a idea, e di nuovo definito ─────────────────────────────────
  select versione into ver from public.viaggio where id = v;
  righe := public.torna_idea(v, ver, 'primavera 2027');
  if righe->'viaggio'->>'stato' <> 'idea' or jsonb_array_length(righe->'giorni') <> 0 then
    raise exception 'FALLITA: torna_idea restituisce ancora dei giorni: %', righe;
  end if;
  select count(*) into n from public.viaggio
   where id = v and stato = 'idea' and data_inizio is null and ora_arrivo is null
     and periodo_approssimativo = 'primavera 2027';
  if n <> 1 then raise exception 'FALLITA: tornando a idea restano le date, o manca il periodo'; end if;
  select count(*) into n from public.giorno where viaggio_id = v and eliminato_il is null;
  if n <> 0 then raise exception 'FALLITA: un''idea tornata tale ha ancora % giorni', n; end if;
  select count(*) into n from public.giorno where viaggio_id = v;
  if n <> 4 then raise exception 'FALLITA: tornando a idea si cancellano dei giorni'; end if;
  log := log || E'\nok  tornare a idea toglie le date e marca i giorni, senza cancellarli';

  select versione into ver from public.viaggio where id = v;
  perform public.programma_viaggio(v, ver, '2026-10-10', '2026-10-12', '10:00', '18:00',
    jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'data', '2026-10-10', 'inizio', '10:00:00', 'fine', '24:00:00'),
      jsonb_build_object('id', gen_random_uuid(), 'data', '2026-10-11', 'inizio', '00:00:00', 'fine', '24:00:00'),
      jsonb_build_object('id', gen_random_uuid(), 'data', '2026-10-12', 'inizio', '00:00:00', 'fine', '18:00:00')));
  select count(*) into n from public.tappa tp
    join public.giorno g on g.id = tp.giorno_id
   where tp.id = t and g.id = g1 and g.eliminato_il is null;
  if n <> 1 then raise exception 'FALLITA: rifissando le stesse date la tappa non ritrova il suo giorno'; end if;
  select count(*) into n from public.giorno where viaggio_id = v;
  if n <> 4 then raise exception 'FALLITA: rifissando le date si duplicano i giorni'; end if;
  log := log || E'\nok  rifissare le stesse date riporta i giorni di prima, con le loro tappe';

  insert into public.invito (viaggio_id) values (v) returning token into codice;

  -- ── C: estraneo ─────────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (c, 'Carlo', '1990-01-01');

  fallita := false;
  begin
    perform public.programma_viaggio(v, ver + 1, '2030-01-01', '2030-01-01', '10:00', '18:00',
      jsonb_build_array(jsonb_build_object('id', gen_random_uuid(), 'data', '2030-01-01', 'inizio', '10:00:00', 'fine', '18:00:00')));
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un estraneo sposta le date di un viaggio'; end if;

  fallita := false;
  begin
    perform public.torna_idea(v, ver + 1, null);
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un estraneo riporta a idea un viaggio'; end if;

  fallita := false;
  begin
    perform privato.applica_giorni(v,
      jsonb_build_array(jsonb_build_object('id', gen_random_uuid(), 'data', '2030-01-01', 'inizio', '10:00:00', 'fine', '18:00:00')));
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un estraneo aggiunge giorni chiamando la funzione interna'; end if;

  fallita := false;
  begin
    perform public.crea_viaggio(v, 'Intruso', null, null, null, null, null, null, '[]');
  exception when unique_violation then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un estraneo riscrive un viaggio creandolo con lo stesso id'; end if;

  righe := privato.righe_del_viaggio(v);
  if righe->'viaggio' <> 'null'::jsonb or jsonb_array_length(righe->'giorni') <> 0 then
    raise exception 'FALLITA: un estraneo legge il viaggio attraverso la funzione interna';
  end if;
  log := log || E'\nok  un estraneo non tocca date né giorni, per nessuna strada';

  -- ── B: entra con l'invito, e sposta le date anche lui ───────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (b, 'Marco', '1994-07-20');
  perform public.accetta_invito(codice);

  select versione into ver from public.viaggio where id = v;
  perform public.programma_viaggio(v, ver, '2026-10-10', '2026-10-11', '10:00', '20:00',
    jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'data', '2026-10-10', 'inizio', '10:00:00', 'fine', '24:00:00'),
      jsonb_build_object('id', gen_random_uuid(), 'data', '2026-10-11', 'inizio', '00:00:00', 'fine', '20:00:00')));
  select count(*) into n from public.giorno where viaggio_id = v and eliminato_il is null;
  if n <> 2 then raise exception 'FALLITA: il partecipante non riesce a spostare le date'; end if;
  log := log || E'\nok  anche chi è entrato con l''invito sposta le date';

  -- ── anon ────────────────────────────────────────────────────────────────
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  fallita := false;
  begin
    perform public.crea_viaggio(gen_random_uuid(), 'Nessuno', null, null, null, null, null, null, '[]');
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: anon crea un viaggio'; end if;
  log := log || E'\nok  senza accesso non si crea niente';

  raise exception 'TUTTE LE PROVE PASSATE (annullate)%', log;
end;
$$;
