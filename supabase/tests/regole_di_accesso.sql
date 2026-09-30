-- Prova delle regole di accesso (ADR-003: "è lì che si sbaglia").
--
-- Gira dentro un solo blocco che alla fine solleva un'eccezione, quindi non lascia
-- niente nel database: si può lanciare anche sul progetto remoto. Il messaggio finale
-- è il resoconto: "TUTTE LE PROVE PASSATE" oppure la prima prova fallita.
--
-- Tre persone: A crea il viaggio, B entra con l'invito, C è un estraneo.

do $$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  c uuid := gen_random_uuid();
  v uuid := gen_random_uuid();
  g uuid := gen_random_uuid();
  t uuid := gen_random_uuid();
  codice text;
  n int;
  r uuid;
  fallita boolean;
  log text := '';
begin
  insert into auth.users (id, email) values
    (a, a || '@prova.local'), (b, b || '@prova.local'), (c, c || '@prova.local');

  -- ── A: profilo e viaggio ────────────────────────────────────────────────
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);

  insert into public.utente (id, nome, data_nascita) values (a, 'Giulia', '1995-04-02');

  insert into public.viaggio (id, stato, data_inizio, data_fine, ora_arrivo, ora_partenza, creatore_id)
  values (v, 'definito', '2026-10-10', '2026-10-12', '10:00', '18:00', a);

  select count(*) into n from public.partecipazione where viaggio_id = v and ruolo = 'creatore' and stato = 'attivo';
  if n <> 1 then raise exception 'FALLITA: il creatore non ha la sua partecipazione'; end if;
  log := log || E'\nok  creatore iscritto al proprio viaggio';

  fallita := false;
  begin
    insert into public.viaggio (stato, creatore_id) values ('idea', b);
  exception when others then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: A crea un viaggio a nome di B'; end if;
  log := log || E'\nok  non si crea un viaggio a nome di un altro';

  fallita := false;
  begin
    update public.viaggio set verifica_per_deroga = true where id = v;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un utente si concede la deroga sulla verifica'; end if;
  log := log || E'\nok  la deroga sulla verifica non è in mano all''app';

  fallita := false;
  begin
    update public.utente set data_nascita = '1990-01-01' where id = a;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: la data di nascita è modificabile'; end if;
  log := log || E'\nok  la data di nascita non si modifica da soli';

  insert into public.giorno (id, viaggio_id, data, finestra_inizio, finestra_fine)
  values (g, v, '2026-10-10', '10:00', '23:59');
  insert into public.tappa (id, viaggio_id, giorno_id, ordine, titolo, durata_stimata_min)
  values (t, v, g, 1, 'Museo', 90);
  insert into public.voce_lista (viaggio_id, testo, tipo) values
    (v, 'Crema solare', 'viaggio'),
    (v, 'Regalo per B', 'personale');

  insert into public.invito (viaggio_id) values (v) returning token into codice;
  if codice !~ '^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{8}$' then
    raise exception 'FALLITA: codice invito malformato: %', codice;
  end if;
  log := log || E'\nok  codice invito di otto caratteri leggibili';

  update public.tappa set titolo = 'Museo civico', versione = 1 where id = t;
  select count(*) into n from public.tappa where id = t and versione = 2;
  if n <> 1 then raise exception 'FALLITA: la versione non avanza'; end if;
  log := log || E'\nok  la versione avanza a ogni modifica';

  -- ── C: estraneo ─────────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);

  fallita := false;
  begin
    insert into public.utente (id, nome, data_nascita) values (c, 'Troppo giovane', current_date - interval '15 years');
  exception when sqlstate 'TR403' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: esiste un utente sotto i 16 anni'; end if;
  log := log || E'\nok  sotto i 16 anni non si crea un account';

  insert into public.utente (id, nome, data_nascita) values (c, 'Carlo', '1990-01-01');

  select count(*) into n from public.viaggio where id = v;
  if n <> 0 then raise exception 'FALLITA: un estraneo vede il viaggio'; end if;
  select count(*) into n from public.tappa where viaggio_id = v;
  if n <> 0 then raise exception 'FALLITA: un estraneo vede le tappe'; end if;
  select count(*) into n from public.invito where viaggio_id = v;
  if n <> 0 then raise exception 'FALLITA: un estraneo vede il codice invito'; end if;
  select count(*) into n from public.utente where id = a;
  if n <> 0 then raise exception 'FALLITA: un estraneo vede il profilo del creatore'; end if;
  log := log || E'\nok  un estraneo non vede niente del viaggio né chi c''è';

  fallita := false;
  begin
    insert into public.tappa (viaggio_id, giorno_id, ordine, titolo, durata_stimata_min)
    values (v, g, 2, 'Intrusione', 30);
  exception when others then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un estraneo aggiunge una tappa'; end if;
  log := log || E'\nok  un estraneo non scrive nel viaggio';

  -- ── B: entra con l'invito ───────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);

  fallita := false;
  begin
    perform public.accetta_invito(codice);
  exception when sqlstate 'TR403' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si entra con un invito senza profilo'; end if;
  log := log || E'\nok  senza profilo (età) non si accetta un invito';

  insert into public.utente (id, nome, data_nascita) values (b, 'Marco', '1994-07-20');

  fallita := false;
  begin
    perform public.accetta_invito('XXXXXXXX');
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un codice inesistente viene accettato'; end if;
  log := log || E'\nok  un codice inesistente si rifiuta';

  -- Digitato a mano: minuscolo e con il trattino.
  r := public.accetta_invito(lower(substr(codice, 1, 4) || '-' || substr(codice, 5)));
  if r <> v then raise exception 'FALLITA: l''invito apre un altro viaggio'; end if;
  r := public.accetta_invito(codice);
  if r <> v then raise exception 'FALLITA: il secondo uso dell''invito non riconosce B'; end if;
  select count(*) into n from public.partecipazione where viaggio_id = v and utente_id = b;
  if n <> 1 then raise exception 'FALLITA: il secondo invito duplica la partecipazione'; end if;
  log := log || E'\nok  l''invito apre quel viaggio, anche digitato, e non duplica';

  select count(*) into n from public.tappa where viaggio_id = v;
  if n <> 1 then raise exception 'FALLITA: l''invitato non vede le tappe'; end if;
  select count(*) into n from public.utente where id = a;
  if n <> 1 then raise exception 'FALLITA: l''invitato non vede il nome del creatore'; end if;
  log := log || E'\nok  l''invitato vede il viaggio e chi c''è';

  fallita := false;
  begin
    perform data_nascita from public.utente where id = a;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un compagno di viaggio legge la data di nascita'; end if;
  select count(*) into n from public.mio_profilo() where id = b and data_nascita = '1994-07-20';
  if n <> 1 then raise exception 'FALLITA: il proprio profilo completo non si legge'; end if;
  log := log || E'\nok  dei compagni si vede il nome, non la data di nascita';

  select count(*) into n from public.voce_lista where viaggio_id = v;
  if n <> 1 then raise exception 'FALLITA: l''invitato vede % voci, doveva vederne 1 (la personale è di A)', n; end if;
  log := log || E'\nok  le voci personali restano del proprietario';

  fallita := false;
  begin
    update public.tappa set titolo = 'Titolo vecchio', versione = 1 where id = t;
  exception when sqlstate 'TR409' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: una modifica su versione superata passa'; end if;
  log := log || E'\nok  una modifica su versione superata viene rifiutata';

  update public.tappa set stato = 'completata', marcata_il = now() where id = t;
  select count(*) into n from public.tappa where id = t and stato = 'completata';
  if n <> 1 then raise exception 'FALLITA: marcare la tappa senza versione non riesce'; end if;
  log := log || E'\nok  i gesti della coda passano senza controllo di versione';

  fallita := false;
  begin
    delete from public.tappa where id = t;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si cancella una riga invece di marcarla'; end if;
  log := log || E'\nok  nessuna cancellazione vera';

  -- Un lotto di eventi che riparte non duplica niente.
  r := gen_random_uuid();
  insert into public.evento (id, nome, avvenuto_il) values (r, 'viaggio_corretto_aperto', now())
    on conflict (id) do nothing;
  insert into public.evento (id, nome, avvenuto_il) values (r, 'viaggio_corretto_aperto', now())
    on conflict (id) do nothing;
  log := log || E'\nok  un evento reinviato non dà errore';

  fallita := false;
  begin
    perform nome from public.evento;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: gli eventi si rileggono dall''app'; end if;
  log := log || E'\nok  gli eventi si scrivono ma non si rileggono';

  -- ── anon ────────────────────────────────────────────────────────────────
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  fallita := false;
  begin
    perform count(*) from public.viaggio;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: anon legge i viaggi'; end if;
  log := log || E'\nok  senza accesso non si legge niente';

  raise exception 'TUTTE LE PROVE PASSATE (annullate)%', log;
end;
$$;
