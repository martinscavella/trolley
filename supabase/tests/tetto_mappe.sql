-- Prova del tetto delle mappe (U.2): si conta per persona, per viaggio e per
-- giorno; al tetto si dice no senza contare; conta solo chi partecipa; i
-- numeri vengono da configurazione; il conto se ne va con il viaggio.
--
-- Va lanciata dopo la migrazione tetto_mappe.sql. Come regole_di_accesso.sql:
-- gira dentro un blocco che alla fine solleva un'eccezione e non lascia
-- niente. Il messaggio finale è il resoconto.
--
-- Giulia e Marco sono a Porto; Giulia ha anche Berlino, da sola. Dario è un
-- estraneo.

do $$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  d uuid := gen_random_uuid();
  porto uuid := gen_random_uuid();
  berlino uuid := gen_random_uuid();
  codice text;
  ok boolean;
  n int;
  i int;
  fallita boolean;
  log text := '';
begin
  insert into auth.users (id, email) values
    (a, a || '@prova.local'), (b, b || '@prova.local'), (d, d || '@prova.local');

  -- Tetti piccoli, per arrivarci in fretta.
  update public.configurazione
     set valore = '{"riquadri": 3, "ricerche": 2, "percorsi": 1}'
   where chiave = 'tetto_mappe';
  select count(*) into n from public.configurazione where chiave = 'tetto_mappe';
  if n <> 1 then raise exception 'FALLITA: il tetto non è in configurazione'; end if;

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (b, 'Marco', '1994-03-01');
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (d, 'Dario', '1990-01-01');

  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (a, 'Giulia', '1995-04-02');
  insert into public.viaggio (id, stato, destinazione_citta, creatore_id) values (porto, 'idea', 'Porto', a);
  insert into public.viaggio (id, stato, destinazione_citta, creatore_id) values (berlino, 'idea', 'Berlino', a);
  insert into public.invito (viaggio_id) values (porto) returning token into codice;
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  perform public.accetta_invito(codice);

  -- ── Fino al tetto sì, poi no ──────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  for i in 1..3 loop
    if not public.consuma_mappe(porto, 'riquadri') then
      raise exception 'FALLITA: il riquadro % è sotto il tetto e si rifiuta', i;
    end if;
  end loop;
  if public.consuma_mappe(porto, 'riquadri') then
    raise exception 'FALLITA: il quarto riquadro passa il tetto';
  end if;
  if public.consuma_mappe(porto, 'riquadri') then
    raise exception 'FALLITA: dopo il tetto si passa di nuovo';
  end if;
  if not public.consuma_mappe(porto, 'ricerche') or not public.consuma_mappe(porto, 'ricerche')
     or public.consuma_mappe(porto, 'ricerche') then
    raise exception 'FALLITA: le ricerche non si fermano alla seconda';
  end if;
  if not public.consuma_mappe(porto, 'percorsi') or public.consuma_mappe(porto, 'percorsi') then
    raise exception 'FALLITA: i percorsi non si fermano al primo';
  end if;
  log := log || E'\nok  fino al tetto sì, poi no; ogni tipo ha il suo';

  -- ── Al tetto non si conta ─────────────────────────────────────────────────
  perform set_config('role', 'postgres', true);
  select count(*) into n from privato.consumo_mappe
   where utente_id = a and viaggio_id = porto and giorno = current_date
     and riquadri = 3 and ricerche = 2 and percorsi = 1;
  if n <> 1 then raise exception 'FALLITA: il conto di Giulia a Porto non è 3, 2, 1'; end if;
  perform set_config('role', 'authenticated', true);
  log := log || E'\nok  al tetto non si conta';

  -- ── Per persona e per viaggio ─────────────────────────────────────────────
  if not public.consuma_mappe(berlino, 'riquadri') then
    raise exception 'FALLITA: il tetto di Porto ferma Giulia a Berlino';
  end if;
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  if not public.consuma_mappe(porto, 'riquadri') then
    raise exception 'FALLITA: il tetto di Giulia ferma Marco';
  end if;
  log := log || E'\nok  ognuno ha il suo tetto, in ogni viaggio';

  -- ── Per giorno ────────────────────────────────────────────────────────────
  perform set_config('role', 'postgres', true);
  update privato.consumo_mappe set giorno = current_date - 1
   where utente_id = a and viaggio_id = porto;
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  if not public.consuma_mappe(porto, 'percorsi') then
    raise exception 'FALLITA: il tetto di ieri ferma Giulia oggi';
  end if;
  log := log || E'\nok  il giorno dopo si ricomincia';

  -- ── Solo chi partecipa, solo con l'accesso, solo i tre tipi ───────────────
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform public.consuma_mappe(porto, 'riquadri');
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un estraneo usa le mappe di Porto'; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform public.consuma_mappe(porto, 'satellite');
  exception when sqlstate '22023' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un tipo sconosciuto si conta'; end if;

  fallita := false;
  begin
    select count(*) into n from privato.consumo_mappe;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: il conto si legge dal client'; end if;

  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  fallita := false;
  begin
    perform public.consuma_mappe(porto, 'riquadri');
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: senza accesso si usano le mappe'; end if;
  perform set_config('role', 'authenticated', true);
  log := log || E'\nok  solo chi partecipa, con l''accesso, per i tre tipi; il conto non si legge';

  -- ── Senza numeri in configurazione valgono quelli scritti ─────────────────
  perform set_config('role', 'postgres', true);
  delete from public.configurazione where chiave = 'tetto_mappe';
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  if not public.consuma_mappe(porto, 'riquadri') then
    raise exception 'FALLITA: senza configurazione il tetto è zero';
  end if;
  log := log || E'\nok  senza configurazione valgono i numeri scritti';

  -- ── Il conto se ne va con il viaggio ──────────────────────────────────────
  perform set_config('role', 'postgres', true);
  perform privato.cancella_viaggio(berlino);
  select count(*) into n from privato.consumo_mappe where viaggio_id = berlino;
  if n <> 0 then raise exception 'FALLITA: il conto di un viaggio cancellato resta'; end if;
  select count(*) into n from cron.job where jobname = 'pulisci_consumo_mappe';
  if n <> 1 then raise exception 'FALLITA: nessuno pulisce il conto'; end if;
  log := log || E'\nok  il conto se ne va con il viaggio, e dopo una settimana';

  raise exception 'TUTTE LE PROVE PASSATE (annullate)%', log;
end;
$$;
