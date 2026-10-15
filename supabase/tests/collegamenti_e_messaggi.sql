-- Prova dei collegamenti e dei messaggi (5.4): le tabelle solo dalle loro
-- funzioni; si chiede solo a chi si vede, con un messaggio breve che passa
-- solo a chi riceve; rifiutare dice solo «non accettata», e si può chiedere
-- di nuovo; accettata, la richiesta diventa il primo messaggio; si scrive solo
-- fra collegati; due richieste incrociate sono un sì; il blocco e il profilo
-- spento nascondono e poi restituiscono; segnalando chi ha chiesto resta il
-- messaggio della richiesta; un messaggio si segnala e chi modera lo toglie;
-- chi toglie il collegamento non vede più la conversazione, che resta
-- all'altro finché non la toglie anche lui; chi chiude l'account diventa
-- «Account chiuso», e dove c'era un blocco non resta niente; i dati
-- scaricati; il tetto; i privilegi.
--
-- Va lanciata dopo la migrazione collegamenti_e_messaggi.sql. Come le altre:
-- gira dentro un blocco che alla fine solleva un'eccezione e non lascia
-- niente. Il messaggio finale è il resoconto.
--
-- Giulia, Marco, Elena e Luca sono maggiorenni con il numero verificato e il
-- profilo pubblico acceso; Sara ha 17 anni.

do $$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  c uuid := gen_random_uuid();
  e uuid := gen_random_uuid();
  l uuid := gen_random_uuid();
  m1 uuid := gen_random_uuid();
  m2 uuid := gen_random_uuid();
  m3 uuid := gen_random_uuid();
  m4 uuid := gen_random_uuid();
  m5 uuid := gen_random_uuid();
  seg uuid := gen_random_uuid();
  seg2 uuid := gen_random_uuid();
  esito text;
  p jsonb;
  r jsonb;
  quando timestamptz;
  n int;
  fallita boolean;
  log text := '';
begin
  insert into auth.users (id, email) values
    (a, a || '@prova.local'), (b, b || '@prova.local'), (c, c || '@prova.local'),
    (e, e || '@prova.local'), (l, l || '@prova.local');

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (a, 'Giulia', '1995-04-02');
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (b, 'Marco', '1994-03-01');
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita)
  values (c, 'Sara', current_date - interval '17 years');
  perform set_config('request.jwt.claims', json_build_object('sub', e, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (e, 'Elena', '1991-02-02');
  perform set_config('request.jwt.claims', json_build_object('sub', l, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (l, 'Luca', '1992-05-05');

  -- Il numero lo verificherebbe la funzione `telefono`: qui lo si dà per fatto.
  perform set_config('role', 'postgres', true);
  update public.utente set telefono_verificato = true where id in (a, b, e, l);
  perform moderazione.parte_pubblica('aperta');
  perform set_config('role', 'authenticated', true);

  -- ── Le tabelle non si toccano ────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform 1 from public.collegamento;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: i collegamenti si leggono dalla tabella'; end if;
  fallita := false;
  begin
    insert into public.messaggio (id, da_utente, a_utente, testo) values (m1, a, b, 'ciao');
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un messaggio si scrive nella tabella'; end if;
  log := log || E'\nok  collegamenti e messaggi solo dalle loro funzioni (M7)';

  -- ── Si chiede solo a chi si vede ─────────────────────────────────────────
  fallita := false;
  begin
    perform public.chiedi_collegamento(b, 'Ciao');
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: con il profilo spento si chiede di collegarsi'; end if;

  perform public.attiva_profilo_pubblico('2026-10-09');
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  perform public.attiva_profilo_pubblico('2026-10-09');
  perform set_config('request.jwt.claims', json_build_object('sub', e, 'role', 'authenticated')::text, true);
  perform public.attiva_profilo_pubblico('2026-10-09');
  perform set_config('request.jwt.claims', json_build_object('sub', l, 'role', 'authenticated')::text, true);
  perform public.attiva_profilo_pubblico('2026-10-09');

  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform public.chiedi_collegamento(c, 'Ciao');
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si chiede a chi ha 17 anni'; end if;
  fallita := false;
  begin
    perform public.chiedi_collegamento(b, repeat('x', 201));
  exception when sqlstate '22023' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: la richiesta porta più di 200 caratteri'; end if;

  esito := public.chiedi_collegamento(b, '  Ciao Marco, anche tu a Kyoto?  ');
  if esito <> 'richiesto' then raise exception 'FALLITA: chiedere dice %', esito; end if;
  esito := public.chiedi_collegamento(b, 'Di nuovo');
  if esito <> 'nessun_cambio' then raise exception 'FALLITA: chiedere due volte dice %', esito; end if;

  r := public.i_miei_collegamenti();
  if jsonb_array_length(r -> 'ricevute') <> 0 or jsonb_array_length(r -> 'inviate') <> 1
     or r -> 'inviate' -> 0 ->> 'stato' <> 'richiesto' or r -> 'inviate' -> 0 ? 'messaggio' then
    raise exception 'FALLITA: i collegamenti di Giulia sono %', r;
  end if;
  if public.profilo_pubblico(b) -> 'collegamento' ->> 'stato' <> 'inviata' then
    raise exception 'FALLITA: il profilo di Marco per Giulia dice %', public.profilo_pubblico(b) -> 'collegamento';
  end if;
  fallita := false;
  begin
    perform public.scrivi(m1, b, 'Allora?');
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si scrive prima del sì'; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  r := public.i_miei_collegamenti();
  if jsonb_array_length(r -> 'ricevute') <> 1
     or r -> 'ricevute' -> 0 ->> 'messaggio' <> 'Ciao Marco, anche tu a Kyoto?'
     or r -> 'ricevute' -> 0 -> 'profilo' ->> 'nome' <> 'Giulia' then
    raise exception 'FALLITA: le richieste di Marco sono %', r -> 'ricevute';
  end if;
  p := public.profilo_pubblico(a) -> 'collegamento';
  if p ->> 'stato' <> 'ricevuta' or p ->> 'messaggio' <> 'Ciao Marco, anche tu a Kyoto?' then
    raise exception 'FALLITA: il profilo di Giulia per Marco dice %', p;
  end if;
  -- Segnalando chi ha chiesto, la fotografia tiene il messaggio della richiesta.
  perform public.segnala(seg2, 'profilo', a, 'molestie', null, false, false);
  perform set_config('role', 'postgres', true);
  if (select contenuto ->> 'richiesta' from public.segnalazione where id = seg2)
     is distinct from 'Ciao Marco, anche tu a Kyoto?' then
    raise exception 'FALLITA: la segnalazione di chi ha chiesto non tiene la richiesta';
  end if;
  perform set_config('role', 'authenticated', true);
  log := log || E'\nok  si chiede solo a chi si vede, con un messaggio breve che legge solo chi riceve';
  log := log || E'\nok  segnalando chi ha chiesto, la fotografia tiene il messaggio della richiesta';

  -- ── Rifiutare dice solo «non accettata»; si può chiedere di nuovo ────────
  perform public.rispondi(a, false);
  if public.profilo_pubblico(a) -> 'collegamento' <> 'null'::jsonb then
    raise exception 'FALLITA: chi ha rifiutato vede ancora la richiesta';
  end if;
  perform set_config('role', 'postgres', true);
  select count(*) into n from public.collegamento
   where da_utente = a and a_utente = b and stato = 'rifiutato' and messaggio is null;
  if n <> 1 then raise exception 'FALLITA: il messaggio della richiesta rifiutata resta'; end if;
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  if public.profilo_pubblico(b) -> 'collegamento' ->> 'stato' <> 'non_accettata'
     or public.i_miei_collegamenti() -> 'inviate' -> 0 ->> 'stato' <> 'rifiutato' then
    raise exception 'FALLITA: chi ha chiesto non vede «non accettata»';
  end if;
  esito := public.chiedi_collegamento(b, 'Riprovo: consigli su Kyoto?');
  if esito <> 'richiesto' then raise exception 'FALLITA: dopo un no si chiede di nuovo? %', esito; end if;
  log := log || E'\nok  rifiutare dice solo «non accettata» e cancella il messaggio; si chiede di nuovo';

  -- ── Accettata: la richiesta è il primo messaggio ─────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  perform public.rispondi(a, true);
  r := public.conversazione(a);
  if not (r ->> 'collegati')::boolean or r ->> 'nome' <> 'Giulia'
     or jsonb_array_length(r -> 'messaggi') <> 1
     or r -> 'messaggi' -> 0 ->> 'testo' <> 'Riprovo: consigli su Kyoto?'
     or (r -> 'messaggi' -> 0 ->> 'mio')::boolean then
    raise exception 'FALLITA: la conversazione di Marco con Giulia è %', r;
  end if;
  r := public.scrivi(m1, a, 'Nishiki Market, la mattina presto.');
  r := public.scrivi(m1, a, 'Nishiki Market, la mattina presto.');
  if not (r ->> 'mio')::boolean or r ? 'letto_il' then
    raise exception 'FALLITA: il messaggio scritto torna come %', r;
  end if;
  fallita := false;
  begin
    perform public.scrivi(m2, a, '   ');
  exception when sqlstate '22023' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si scrive un messaggio vuoto'; end if;
  fallita := false;
  begin
    perform public.scrivi(m2, a, repeat('x', 1001));
  exception when sqlstate '22023' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si scrive un messaggio di più di 1000 caratteri'; end if;
  if public.i_miei_collegamenti() -> 'collegati' -> 0 ->> 'nome' <> 'Giulia' then
    raise exception 'FALLITA: Giulia non è fra i collegati di Marco';
  end if;

  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  r := public.i_miei_messaggi();
  if jsonb_array_length(r) <> 1 or (r -> 0 ->> 'utente_id')::uuid <> b
     or (r -> 0 ->> 'da_leggere')::int <> 1 or not (r -> 0 ->> 'collegati')::boolean
     or r -> 0 -> 'ultimo' ->> 'testo' <> 'Nishiki Market, la mattina presto.' then
    raise exception 'FALLITA: i messaggi di Giulia sono %', r;
  end if;
  r := public.conversazione(b);
  if jsonb_array_length(r -> 'messaggi') <> 2 then
    raise exception 'FALLITA: il messaggio rimandato è arrivato due volte: %', r -> 'messaggi';
  end if;
  quando := (r -> 'messaggi' -> 1 ->> 'scritto_il')::timestamptz;
  if (public.i_miei_messaggi() -> 0 ->> 'da_leggere')::int <> 0 then
    raise exception 'FALLITA: guardata la conversazione, resta da leggere';
  end if;
  if jsonb_array_length(public.conversazione(b, quando) -> 'messaggi') <> 0 then
    raise exception 'FALLITA: dopo l''ultimo messaggio ce ne sono altri';
  end if;
  if public.profilo_pubblico(b) -> 'collegamento' ->> 'stato' <> 'collegati' then
    raise exception 'FALLITA: il profilo di Marco non dice che siete collegati';
  end if;
  log := log || E'\nok  accettata, la richiesta è il primo messaggio; si scrive, una volta, e si legge';

  -- ── Gli altri non leggono; due richieste incrociate sono un sì ───────────
  perform set_config('request.jwt.claims', json_build_object('sub', e, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform public.conversazione(b);
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: Elena legge una conversazione non sua'; end if;
  esito := public.chiedi_collegamento(l, null);
  perform set_config('request.jwt.claims', json_build_object('sub', l, 'role', 'authenticated')::text, true);
  esito := public.chiedi_collegamento(e, 'Anche io!');
  if esito <> 'accettato' then raise exception 'FALLITA: due richieste incrociate danno %', esito; end if;
  perform public.scrivi(m3, e, 'Ciao Elena');
  log := log || E'\nok  gli altri non leggono; due richieste incrociate sono un sì';

  -- ── Il blocco nasconde, sbloccare restituisce ────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.blocca(b);
  if jsonb_array_length(public.i_miei_messaggi()) <> 0
     or jsonb_array_length(public.i_miei_collegamenti() -> 'collegati') <> 0 then
    raise exception 'FALLITA: chi blocca vede ancora la conversazione';
  end if;
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  if jsonb_array_length(public.i_miei_messaggi()) <> 0 then
    raise exception 'FALLITA: il bloccato vede ancora la conversazione';
  end if;
  fallita := false;
  begin
    perform public.scrivi(m2, a, 'Ci sei?');
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: il bloccato scrive'; end if;
  fallita := false;
  begin
    perform public.conversazione(a);
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: il bloccato apre la conversazione'; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.sblocca(b);
  if jsonb_array_length(public.i_miei_messaggi()) <> 1 then
    raise exception 'FALLITA: sbloccando la conversazione non torna';
  end if;
  log := log || E'\nok  il blocco nasconde nei due versi; sbloccare restituisce';

  -- ── Il profilo spento nasconde, riacceso restituisce ─────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  perform public.spegni_profilo_pubblico();
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  if jsonb_array_length(public.i_miei_messaggi()) <> 0 then
    raise exception 'FALLITA: la conversazione con un profilo spento si vede';
  end if;
  fallita := false;
  begin
    perform public.scrivi(m2, b, 'Ci sei?');
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si scrive a un profilo spento'; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  perform public.attiva_profilo_pubblico('2026-10-09');
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  if jsonb_array_length(public.i_miei_messaggi()) <> 1 then
    raise exception 'FALLITA: riacceso il profilo, la conversazione non torna';
  end if;
  log := log || E'\nok  il profilo spento nasconde la conversazione, riacceso la restituisce';

  -- ── Segnalare un messaggio, e toglierlo ──────────────────────────────────
  fallita := false;
  begin
    perform public.segnala(gen_random_uuid(), 'messaggio',
      (select (x ->> 'id')::uuid from jsonb_array_elements(public.conversazione(b) -> 'messaggi') x
        where (x ->> 'mio')::boolean limit 1), 'molestie');
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si segnala un proprio messaggio'; end if;
  perform public.segnala(seg, 'messaggio', m1, 'molestie', 'Insiste', false, false);
  perform set_config('role', 'postgres', true);
  select contenuto into p from public.segnalazione where id = seg;
  if p ->> 'testo' <> 'Nishiki Market, la mattina presto.' or p ->> 'nome' <> 'Marco'
     or (select a_utente from public.segnalazione where id = seg) <> b then
    raise exception 'FALLITA: la fotografia del messaggio segnalato è %', p;
  end if;
  n := moderazione.togli(seg, 'regola 2');
  if n <> 1 then raise exception 'FALLITA: togliere chiude % segnalazioni', n; end if;
  perform set_config('role', 'authenticated', true);
  r := (select x from jsonb_array_elements(public.conversazione(b) -> 'messaggi') x
         where (x ->> 'id')::uuid = m1);
  if not (r ->> 'tolto')::boolean or r ->> 'testo' is not null then
    raise exception 'FALLITA: il messaggio tolto si legge ancora: %', r;
  end if;
  if (select s.esito from public.le_mie_segnalazioni() s where s.id = seg) <> 'contenuto_rimosso' then
    raise exception 'FALLITA: chi ha segnalato non vede il messaggio tolto';
  end if;
  log := log || E'\nok  un messaggio ricevuto si segnala con la sua fotografia; chi modera lo toglie';

  -- ── Togliere il collegamento: la conversazione resta all'altro ───────────
  perform public.togli_collegamento(b);
  if jsonb_array_length(public.i_miei_messaggi()) <> 0 then
    raise exception 'FALLITA: chi toglie il collegamento vede ancora la conversazione';
  end if;
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  r := public.i_miei_messaggi();
  if jsonb_array_length(r) <> 1 or (r -> 0 ->> 'collegati')::boolean then
    raise exception 'FALLITA: a Marco non resta la conversazione finita: %', r;
  end if;
  if jsonb_array_length(public.conversazione(a) -> 'messaggi') <> 2 then
    raise exception 'FALLITA: nella conversazione finita mancano messaggi';
  end if;
  fallita := false;
  begin
    perform public.scrivi(m2, a, 'Perché?');
  exception when sqlstate 'TR404' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: si scrive in una conversazione finita'; end if;
  perform public.togli_conversazione(a);
  perform set_config('role', 'postgres', true);
  select count(*) into n from public.messaggio
   where least(da_utente, a_utente) = least(a, b) and greatest(da_utente, a_utente) = greatest(a, b);
  if n <> 0 then raise exception 'FALLITA: tolta da tutti e due, la conversazione resta (%)', n; end if;
  perform set_config('role', 'authenticated', true);

  -- Si ricomincia: chi l'aveva tolta vede solo da qui in poi.
  esito := public.chiedi_collegamento(a, 'Ricominciamo?');
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.rispondi(b, true);
  if jsonb_array_length(public.conversazione(b) -> 'messaggi') <> 1 then
    raise exception 'FALLITA: ricominciando torna la conversazione di prima';
  end if;
  log := log || E'\nok  chi toglie il collegamento non vede più; all''altro resta finché non la toglie';

  -- ── I dati scaricati ─────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', e, 'role', 'authenticated')::text, true);
  r := public.i_miei_dati();
  if (r ->> 'versione')::int <> 4
     or jsonb_array_length(r -> 'corrispondenza' -> 'collegamenti') <> 1
     or r -> 'corrispondenza' -> 'messaggi' -> 0 ->> 'testo' <> 'Ciao Elena' then
    raise exception 'FALLITA: i dati di Elena non hanno la corrispondenza: %', r -> 'corrispondenza';
  end if;
  log := log || E'\nok  i dati scaricati hanno collegamenti e messaggi';

  -- ── Il tetto dei messaggi ────────────────────────────────────────────────
  perform set_config('role', 'postgres', true);
  insert into public.configurazione (chiave, valore) values ('tetto_messaggi', '0')
  on conflict (chiave) do update set valore = '0';
  perform set_config('role', 'authenticated', true);
  fallita := false;
  begin
    perform public.scrivi(m4, l, 'Ciao Luca');
  exception when sqlstate 'TR429' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: oltre il tetto del giorno si scrive'; end if;
  perform set_config('role', 'postgres', true);
  update public.configurazione set valore = '500' where chiave = 'tetto_messaggi';
  perform set_config('role', 'authenticated', true);
  log := log || E'\nok  il tetto ferma i messaggi oltre il numero del giorno';

  -- ── Chiudere l'account ───────────────────────────────────────────────────
  -- Elena scrive a Giulia, che poi la blocca; poi Elena chiude l'account.
  esito := public.chiedi_collegamento(a, null);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.rispondi(e, true);
  perform public.scrivi(m5, e, 'Ciao Elena, a presto');
  perform public.blocca(e);
  perform set_config('request.jwt.claims', json_build_object('sub', e, 'role', 'authenticated')::text, true);
  perform public.chiudi_account(false);

  perform set_config('request.jwt.claims', json_build_object('sub', l, 'role', 'authenticated')::text, true);
  r := public.i_miei_messaggi();
  if jsonb_array_length(r) <> 1 or r -> 0 ->> 'nome' is not null
     or (r -> 0 ->> 'collegati')::boolean then
    raise exception 'FALLITA: a Luca la conversazione con chi se n''è andato è %', r;
  end if;
  if jsonb_array_length(public.i_miei_collegamenti() -> 'collegati') <> 0 then
    raise exception 'FALLITA: chi ha chiuso l''account resta fra i collegati';
  end if;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  if exists (select 1 from jsonb_array_elements(public.i_miei_messaggi()) x
              where (x ->> 'utente_id')::uuid = e) then
    raise exception 'FALLITA: a chi aveva bloccato torna la conversazione';
  end if;
  perform set_config('role', 'postgres', true);
  select count(*) into n from public.messaggio where e in (da_utente, a_utente) and a in (da_utente, a_utente);
  if n <> 0 then raise exception 'FALLITA: dove c''era un blocco restano % messaggi', n; end if;
  select count(*) into n from public.collegamento where e in (da_utente, a_utente);
  if n <> 0 then raise exception 'FALLITA: restano % collegamenti di chi ha chiuso', n; end if;
  perform set_config('role', 'authenticated', true);
  log := log || E'\nok  chi chiude diventa «Account chiuso»; dove c''era un blocco non resta niente';

  -- ── I privilegi ──────────────────────────────────────────────────────────
  perform set_config('role', 'postgres', true);
  if has_function_privilege('anon', 'public.chiedi_collegamento(uuid, text)', 'execute')
     or has_function_privilege('anon', 'public.scrivi(uuid, uuid, text)', 'execute')
     or has_function_privilege('anon', 'public.conversazione(uuid, timestamptz)', 'execute')
     or has_function_privilege('anon', 'public.i_miei_messaggi()', 'execute')
     or has_function_privilege('anon', 'public.i_miei_collegamenti()', 'execute')
     or has_function_privilege('authenticated', 'privato.conversazione_per(uuid, uuid)', 'execute')
     or has_function_privilege('authenticated', 'privato.togli_conversazione(uuid, uuid)', 'execute')
     or has_function_privilege('authenticated', 'moderazione.togli(uuid, text)', 'execute')
     or has_table_privilege('authenticated', 'privato.conversazione_tolta', 'select')
     or has_table_privilege('authenticated', 'public.messaggio', 'select')
     or has_table_privilege('authenticated', 'public.collegamento', 'select') then
    raise exception 'FALLITA: un privilegio di troppo';
  end if;
  log := log || E'\nok  niente per anon, e il privato resta privato';

  raise exception 'PASSATE%', log;
end;
$$;
