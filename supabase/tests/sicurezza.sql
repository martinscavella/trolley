-- Prova dell'impianto di sicurezza (5.1): la parte pubblica chiusa, aperta e
-- chiusa ai nuovi; il telefono verificato solo dalla funzione del server, un
-- numero per account, con il tetto; il profilo pubblico solo dalle sue
-- funzioni; bloccare reciproco e muto; segnalare con il contenuto conservato;
-- la moderazione fuori dall'API; i dati scaricati e la chiusura dell'account.
--
-- Va lanciata dopo la migrazione sicurezza.sql. Come le altre: gira dentro un
-- blocco che alla fine solleva un'eccezione e non lascia niente, nemmeno il
-- cambio di `parte_pubblica` in configurazione. Il messaggio finale è il
-- resoconto.
--
-- Giulia, Marco ed Elena sono maggiorenni; Sara ha 17 anni; Dario è del team.

do $$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  c uuid := gen_random_uuid();
  d uuid := gen_random_uuid();
  e uuid := gen_random_uuid();
  s_marco uuid := gen_random_uuid();
  s_elena uuid := gen_random_uuid();
  s_dario uuid := gen_random_uuid();
  num_giulia text := '+393471234567';
  num_marco text := '+393339876543';
  p jsonb;
  dati jsonb;
  n int;
  i int;
  fallita boolean;
  log text := '';
begin
  insert into auth.users (id, email) values
    (a, a || '@prova.local'), (b, b || '@prova.local'), (c, c || '@prova.local'),
    (d, d || '@prova.local'), (e, e || '@prova.local');

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (a, 'Giulia', '1995-04-02');
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (b, 'Marco', '1994-03-01');
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita)
  values (c, 'Sara', current_date - interval '17 years');
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (d, 'Dario', '1990-01-01');
  perform set_config('request.jwt.claims', json_build_object('sub', e, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (e, 'Elena', '1991-02-02');

  perform set_config('role', 'postgres', true);
  update public.utente set interno = true where id = d;
  perform moderazione.parte_pubblica('chiusa');

  -- ── Chiusa: non la vede nessuno, tranne il team ──────────────────────────
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  p := public.la_mia_parte_pubblica();
  if (p ->> 'visibile')::boolean or (p ->> 'accoglie')::boolean
     or not (p ->> 'maggiorenne')::boolean or p ->> 'telefono' is not null
     or (p ->> 'attivo')::boolean then
    raise exception 'FALLITA: Giulia con la parte chiusa vede %', p;
  end if;
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  p := public.la_mia_parte_pubblica();
  if not (p ->> 'visibile')::boolean or not (p ->> 'accoglie')::boolean then
    raise exception 'FALLITA: il team non vede la parte chiusa (%)', p;
  end if;
  perform set_config('role', 'service_role', true);
  if public.telefono_invio(a, num_giulia) <> 'chiusa' then
    raise exception 'FALLITA: con la parte chiusa parte un SMS';
  end if;
  if public.telefono_invio(d, '+393400000001') <> 'ok' then
    raise exception 'FALLITA: il team non riceve il codice con la parte chiusa';
  end if;
  log := log || E'\nok  chiusa: niente parte pubblica e niente SMS, tranne per il team';

  -- ── Il telefono passa solo dalla funzione del server ─────────────────────
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  fallita := false;
  begin
    perform public.telefono_conferma(a, num_giulia);
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: dall''app ci si dichiara verificati'; end if;
  fallita := false;
  begin
    perform public.telefono_invio(a, num_giulia);
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: dall''app si contano gli invii'; end if;
  fallita := false;
  begin
    update public.utente set telefono_verificato = true where id = a;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: il telefono verificato si scrive a mano'; end if;
  fallita := false;
  begin
    perform 1 from privato.telefono;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: i numeri si leggono dall''app'; end if;
  fallita := false;
  begin
    update public.utente set profilo_pubblico_attivo = true where id = a;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: il profilo pubblico si accende a mano'; end if;
  log := log || E'\nok  il numero e il profilo pubblico non si scrivono dall''app, i numeri non si leggono';

  -- ── Aperta: il codice, i no e il tetto ───────────────────────────────────
  perform set_config('role', 'postgres', true);
  perform moderazione.parte_pubblica('aperta');
  perform set_config('role', 'service_role', true);
  if public.telefono_invio(c, '+393401112223') <> 'eta' then
    raise exception 'FALLITA: un codice a chi ha 17 anni';
  end if;
  if public.telefono_invio(a, '3471234567') <> 'numero'
     or public.telefono_invio(a, '+0123') <> 'numero' then
    raise exception 'FALLITA: un codice a un numero che non è un numero';
  end if;
  if public.telefono_invio(gen_random_uuid(), num_giulia) <> 'profilo' then
    raise exception 'FALLITA: un codice a chi non ha un profilo';
  end if;
  for i in 1..3 loop
    if public.telefono_invio(a, num_giulia) <> 'ok' then
      raise exception 'FALLITA: il codice numero % non parte', i;
    end if;
  end loop;
  if public.telefono_invio(a, num_giulia) <> 'tetto' then
    raise exception 'FALLITA: più di tre codici allo stesso numero in un giorno';
  end if;
  if public.telefono_invio(b, num_giulia) <> 'tetto' then
    raise exception 'FALLITA: il tetto del numero si aggira da un altro account';
  end if;
  if public.telefono_invio(a, '+393470000001') <> 'ok'
     or public.telefono_invio(a, '+393470000002') <> 'ok'
     or public.telefono_invio(a, '+393470000003') <> 'tetto' then
    raise exception 'FALLITA: più di cinque codici a una persona in un giorno';
  end if;
  for i in 1..10 loop
    if public.telefono_controllo(a, num_giulia) <> 'ok' then
      raise exception 'FALLITA: il tentativo numero % non si fa', i;
    end if;
  end loop;
  if public.telefono_controllo(a, num_giulia) <> 'tetto' then
    raise exception 'FALLITA: il codice si indovina provando';
  end if;
  log := log || E'\nok  aperta: niente codici sotto i 18 anni o a numeri strani; tetto per numero, persona e tentativi';

  -- ── Un numero, un account ────────────────────────────────────────────────
  if public.telefono_conferma(a, num_giulia) <> 'ok' then
    raise exception 'FALLITA: il numero di Giulia non si conferma';
  end if;
  perform set_config('role', 'postgres', true);
  if not (select telefono_verificato from public.utente where id = a)
     or (select numero from privato.telefono where utente_id = a) <> num_giulia then
    raise exception 'FALLITA: Giulia non risulta verificata';
  end if;
  perform set_config('role', 'service_role', true);
  if public.telefono_invio(b, num_giulia) not in ('usato', 'tetto')
     or public.telefono_conferma(b, num_giulia) <> 'usato' then
    raise exception 'FALLITA: il numero di Giulia vale anche per Marco';
  end if;
  perform set_config('role', 'postgres', true);
  delete from privato.tentativo_telefono;
  perform set_config('role', 'service_role', true);
  if public.telefono_invio(b, num_giulia) <> 'usato' then
    raise exception 'FALLITA: a Marco parte un codice per il numero di Giulia';
  end if;
  if public.telefono_invio(a, num_giulia) <> 'gia' then
    raise exception 'FALLITA: un codice per il numero già verificato';
  end if;
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  if public.la_mia_parte_pubblica() ->> 'telefono' <> num_giulia then
    raise exception 'FALLITA: Giulia non vede il suo numero';
  end if;
  log := log || E'\nok  un numero vale per un account, e non si dice di quale';

  -- ── Accendere il profilo pubblico ────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  begin
    perform public.attiva_profilo_pubblico('2026-10-09');
    raise exception 'FALLITA: profilo pubblico senza telefono';
  exception when sqlstate 'TR403' then null;
  end;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  begin
    perform public.attiva_profilo_pubblico('  ');
    raise exception 'FALLITA: profilo pubblico senza condizioni d''uso';
  exception when sqlstate '22023' then null;
  end;
  perform public.attiva_profilo_pubblico('2026-10-09');
  perform public.attiva_profilo_pubblico('2026-10-09');
  p := public.la_mia_parte_pubblica();
  if not (p ->> 'attivo')::boolean or p ->> 'condizioni' <> '2026-10-09' then
    raise exception 'FALLITA: il profilo di Giulia non si accende (%)', p;
  end if;
  -- Sara ha un numero, ma 17 anni.
  perform set_config('role', 'service_role', true);
  perform public.telefono_conferma(c, '+393401112223');
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  begin
    perform public.attiva_profilo_pubblico('2026-10-09');
    raise exception 'FALLITA: profilo pubblico a 17 anni';
  exception when sqlstate 'TR403' then null;
  end;
  log := log || E'\nok  si accende con il telefono e le condizioni, dai 18 anni, una volta sola';

  -- ── Chiusa ai nuovi: chi c'era resta e torna, i nuovi aspettano ───────────
  perform set_config('role', 'service_role', true);
  perform public.telefono_conferma(b, num_marco);
  perform public.telefono_conferma(e, '+393405556667');
  perform set_config('role', 'postgres', true);
  perform moderazione.parte_pubblica('chiusa_ai_nuovi');
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  p := public.la_mia_parte_pubblica();
  if not (p ->> 'visibile')::boolean or (p ->> 'accoglie')::boolean then
    raise exception 'FALLITA: chiusa ai nuovi, Marco vede %', p;
  end if;
  begin
    perform public.attiva_profilo_pubblico('2026-10-09');
    raise exception 'FALLITA: chiusa ai nuovi, Marco entra';
  exception when sqlstate 'TR423' then null;
  end;
  perform set_config('role', 'service_role', true);
  if public.telefono_invio(b, '+393339999999') <> 'chiusa' then
    raise exception 'FALLITA: chiusa ai nuovi, a Marco parte un SMS';
  end if;
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.spegni_profilo_pubblico();
  if (public.la_mia_parte_pubblica() ->> 'attivo')::boolean then
    raise exception 'FALLITA: il profilo di Giulia non si spegne';
  end if;
  perform public.attiva_profilo_pubblico('2026-10-09');
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  perform set_config('role', 'service_role', true);
  perform public.telefono_conferma(d, '+393400000001');
  perform set_config('role', 'authenticated', true);
  perform public.attiva_profilo_pubblico('2026-10-09');
  perform set_config('role', 'postgres', true);
  perform moderazione.parte_pubblica('aperta');
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  perform public.attiva_profilo_pubblico('2026-10-09');
  log := log || E'\nok  chiusa ai nuovi: chi c''era si spegne e si riaccende, i nuovi no (il team sì)';

  -- ── Bloccare ─────────────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.blocca(e);
  perform public.blocca(e);
  if (select count(*) from public.persone_bloccate()) <> 1
     or (select nome from public.persone_bloccate()) <> 'Elena' then
    raise exception 'FALLITA: Giulia non vede Elena fra le persone bloccate';
  end if;
  begin
    perform public.blocca(a);
    raise exception 'FALLITA: ci si blocca da soli';
  exception when sqlstate 'TR404' then null;
  end;
  fallita := false;
  begin
    insert into public.blocco (da_utente, a_utente) values (b, e);
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un blocco si scrive a nome di un altro'; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', e, 'role', 'authenticated')::text, true);
  if exists (select 1 from public.blocco) or exists (select 1 from public.persone_bloccate()) then
    raise exception 'FALLITA: Elena sa di essere bloccata';
  end if;
  perform set_config('role', 'postgres', true);
  if not privato.si_bloccano(a, e) or not privato.si_bloccano(e, a)
     or privato.si_bloccano(a, b) then
    raise exception 'FALLITA: il blocco non vale nei due versi';
  end if;
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.sblocca(e);
  perform set_config('role', 'postgres', true);
  if privato.si_bloccano(a, e) then raise exception 'FALLITA: lo sblocco non toglie il blocco'; end if;
  perform set_config('role', 'authenticated', true);
  log := log || E'\nok  bloccare vale nei due versi, non si vede da chi è bloccato, si toglie';

  -- ── Segnalare ────────────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  begin
    perform public.segnala(gen_random_uuid(), 'profilo', c, 'falso');
    raise exception 'FALLITA: si segnala chi non è mai stato nella parte pubblica';
  exception when sqlstate 'TR404' then null;
  end;
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  perform public.segnala(s_marco, 'profilo', a, 'molestie', '  Mi scrive di continuo  ', true, true);
  perform public.segnala(s_marco, 'profilo', a, 'molestie', 'di nuovo', true, true);
  begin
    perform public.segnala(gen_random_uuid(), 'profilo', a, 'antipatia');
    raise exception 'FALLITA: un motivo che non c''è';
  exception when sqlstate '22023' then null;
  end;
  begin
    perform public.segnala(gen_random_uuid(), 'messaggio', a, 'molestie');
    raise exception 'FALLITA: si segnala un messaggio prima della 5.4';
  exception when sqlstate '22023' then null;
  end;
  fallita := false;
  begin
    perform 1 from public.segnalazione;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: le segnalazioni si leggono dalla tabella'; end if;
  select count(*) into n from public.le_mie_segnalazioni() s
   where s.id = s_marco and s.nome = 'Giulia' and s.stato = 'ricevuta' and s.esito is null;
  if n <> 1 or (select count(*) from public.le_mie_segnalazioni()) <> 1 then
    raise exception 'FALLITA: Marco non vede la sua segnalazione, una volta sola';
  end if;
  if not exists (select 1 from public.persone_bloccate() where utente_id = a) then
    raise exception 'FALLITA: «Blocca anche» non ha bloccato Giulia';
  end if;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  if exists (select 1 from public.le_mie_segnalazioni()) then
    raise exception 'FALLITA: Giulia sa di essere stata segnalata';
  end if;
  -- Spegnere il profilo non fa sfuggire.
  perform public.spegni_profilo_pubblico();
  perform set_config('request.jwt.claims', json_build_object('sub', e, 'role', 'authenticated')::text, true);
  perform public.segnala(s_elena, 'profilo', a, 'altro', null, false, false);
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  perform public.segnala(s_dario, 'profilo', a, 'falso', null, false, true);
  perform set_config('role', 'postgres', true);
  if (select nota from public.segnalazione where id = s_marco) <> 'Mi scrive di continuo'
     or (select contenuto ->> 'nome' from public.segnalazione where id = s_marco) <> 'Giulia' then
    raise exception 'FALLITA: la segnalazione non conserva nota e contenuto';
  end if;
  select count(*) into n from public.evento where nome = 'segnalazione_ricevuta';
  if n <> 1 or not exists (select 1 from public.evento
                            where nome = 'segnalazione_ricevuta' and utente_id = b
                              and proprieta = '{"tipo": "profilo", "motivo": "molestie"}') then
    raise exception 'FALLITA: segnalazione_ricevuta non è solo di Marco, che misura (% eventi)', n;
  end if;
  perform set_config('role', 'authenticated', true);
  log := log || E'\nok  si segnala chi è stato nella parte pubblica, una volta, con il contenuto; nessuno lo sa';

  -- ── La moderazione è fuori dall'API ──────────────────────────────────────
  fallita := false;
  begin
    perform moderazione.archivia(s_elena);
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: dall''app si modera'; end if;
  perform set_config('role', 'service_role', true);
  fallita := false;
  begin
    perform 1 from moderazione.coda;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: le funzioni del server leggono la coda'; end if;
  perform set_config('role', 'postgres', true);
  if (select id from moderazione.coda limit 1) <> s_marco
     or (select da_quante_persone from moderazione.coda limit 1) <> 3 then
    raise exception 'FALLITA: in cima alla coda non ci sono le molestie, da tre persone';
  end if;
  log := log || E'\nok  la coda e le azioni si usano solo dall''editor, le molestie in cima';

  -- ── Archiviare e sospendere ──────────────────────────────────────────────
  perform moderazione.archivia(s_elena, 'niente di concreto');
  if (select stato || '/' || esito from public.segnalazione where id = s_elena)
     <> 'gestita/nessuna_azione' then
    raise exception 'FALLITA: l''archiviazione non chiude la segnalazione';
  end if;
  begin
    perform moderazione.sospendi(s_marco, '  ');
    raise exception 'FALLITA: si sospende senza un motivo';
  exception when raise_exception then
    if sqlerrm like 'FALLITA%' then raise; end if;
  end;
  if moderazione.sospendi(s_marco, 'Condizioni d''uso, regola 2: messaggi molesti.') <> 2 then
    raise exception 'FALLITA: la sospensione non chiude le due segnalazioni aperte';
  end if;
  if exists (select 1 from public.segnalazione where a_utente = a and stato = 'ricevuta') then
    raise exception 'FALLITA: restano segnalazioni aperte su Giulia';
  end if;
  select count(*) into n from public.evento where nome = 'segnalazione_gestita';
  if n <> 1 or not exists (
       select 1 from public.evento where nome = 'segnalazione_gestita' and utente_id = b
          and proprieta ->> 'esito' = 'profilo_sospeso' and proprieta ? 'ore') then
    raise exception 'FALLITA: segnalazione_gestita non è solo di Marco (% eventi)', n;
  end if;
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  p := public.la_mia_parte_pubblica();
  if p ->> 'sospeso_il' is null or p ->> 'sospensione_motivo' not like 'Condizioni d''uso%'
     or (p ->> 'attivo')::boolean then
    raise exception 'FALLITA: Giulia non sa di essere sospesa (%)', p;
  end if;
  begin
    perform public.attiva_profilo_pubblico('2026-10-09');
    raise exception 'FALLITA: da sospesa si riaccende';
  exception when sqlstate 'TR424' then null;
  end;
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  if (select stato || '/' || esito from public.le_mie_segnalazioni()) <> 'gestita/profilo_sospeso' then
    raise exception 'FALLITA: Marco non sa che la sua segnalazione è gestita';
  end if;
  perform set_config('role', 'postgres', true);
  perform moderazione.riattiva(a);
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.attiva_profilo_pubblico('2026-10-09');
  perform set_config('role', 'postgres', true);
  fallita := false;
  begin
    perform moderazione.parte_pubblica('mezza');
  exception when raise_exception then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: la parte pubblica ha uno stato inventato'; end if;
  perform set_config('role', 'authenticated', true);
  log := log || E'\nok  archiviare e sospendere chiudono, con il motivo per chi è sospeso e lo stato per chi ha segnalato';

  -- ── Il tetto delle segnalazioni ──────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', e, 'role', 'authenticated')::text, true);
  for i in 1..19 loop
    perform public.segnala(gen_random_uuid(), 'profilo', a, 'altro', null, false, false);
  end loop;
  begin
    perform public.segnala(gen_random_uuid(), 'profilo', a, 'altro', null, false, false);
    raise exception 'FALLITA: più di venti segnalazioni in un giorno';
  exception when sqlstate 'TR429' then null;
  end;
  log := log || E'\nok  non più di venti segnalazioni al giorno';

  -- ── I tuoi dati ──────────────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  dati := public.i_miei_dati();
  if dati ->> 'telefono' <> num_giulia or (dati ->> 'versione')::int < 2
     or not (dati -> 'profilo' ? 'condizioni_accettate') then
    raise exception 'FALLITA: i dati di Giulia non hanno il telefono e la parte pubblica';
  end if;
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  dati := public.i_miei_dati();
  if jsonb_array_length(dati -> 'persone_bloccate') <> 1
     or jsonb_array_length(dati -> 'segnalazioni') <> 1
     or dati -> 'segnalazioni' -> 0 ? 'contenuto' then
    raise exception 'FALLITA: i dati di Marco non hanno blocchi e segnalazioni (%)', dati;
  end if;
  log := log || E'\nok  i dati scaricati portano il numero, chi si è bloccato, le proprie segnalazioni';

  -- ── Chiudere l'account ───────────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.chiudi_account(true);
  perform set_config('role', 'postgres', true);
  if exists (select 1 from privato.telefono where utente_id = a)
     or exists (select 1 from privato.tentativo_telefono where utente_id = a)
     or exists (select 1 from public.blocco where a in (da_utente, a_utente)) then
    raise exception 'FALLITA: chiudendo restano il numero o i blocchi di Giulia';
  end if;
  if (select count(*) from public.segnalazione where a_utente = a) <> 22 then
    raise exception 'FALLITA: chiudendo spariscono le segnalazioni su Giulia';
  end if;
  if exists (select 1 from public.utente where id = a
              and (condizioni_accettate is not null or sospeso_il is not null
                   or profilo_pubblico_attivo or telefono_verificato)) then
    raise exception 'FALLITA: la lapide di Giulia ha ancora la parte pubblica';
  end if;
  delete from privato.tentativo_telefono;
  perform set_config('role', 'service_role', true);
  if public.telefono_invio(b, num_giulia) <> 'ok' then
    raise exception 'FALLITA: il numero di Giulia non torna libero';
  end if;
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  if exists (select 1 from public.persone_bloccate()) then
    raise exception 'FALLITA: Marco vede ancora bloccata una persona che non c''è più';
  end if;
  perform public.chiudi_account(true);
  perform set_config('role', 'postgres', true);
  if exists (select 1 from public.segnalazione where da_utente = b and misurata) then
    raise exception 'FALLITA: le segnalazioni di chi ha chiuso diventerebbero eventi a suo nome';
  end if;
  log := log || E'\nok  chiudendo il numero torna libero, i blocchi spariscono, le segnalazioni restano mute';

  -- ── Le pulizie ───────────────────────────────────────────────────────────
  select count(*) into n from cron.job where jobname = 'pulisci_tentativi_telefono';
  if n <> 1 then raise exception 'FALLITA: nessuno pulisce i tentativi'; end if;
  log := log || E'\nok  i tentativi si tolgono dopo una settimana';

  raise exception 'TUTTE LE PROVE PASSATE (annullate)%', log;
end;
$$;
