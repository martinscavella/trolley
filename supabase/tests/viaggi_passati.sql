-- Prova dei viaggi passati (fase 4.3): nascono chiusi e importati, dicono
-- quando senza date, non si verificano e non danno traguardi; sono di chi li
-- aggiunge, che li cambia e li toglie. E un viaggio non importato non nasce
-- chiuso.
--
-- Va lanciata dopo la migrazione viaggi_passati.sql. Come regole_di_accesso.sql: gira
-- dentro un blocco che alla fine solleva un'eccezione e non lascia niente. Il
-- messaggio finale è il resoconto.
--
-- Due persone: A aggiunge i viaggi passati, D è un estraneo.

do $$
declare
  a uuid := gen_random_uuid();
  d uuid := gen_random_uuid();
  barcellona uuid := gen_random_uuid();
  atene uuid := gen_random_uuid();
  vero uuid := gen_random_uuid();
  oggi date := (now() at time zone 'utc')::date;
  riga jsonb;
  v_stato text;
  v_versione int;
  n int;
  fallita boolean;
  log text := '';
begin
  insert into auth.users (id, email) values
    (a, a || '@prova.local'), (d, d || '@prova.local');

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (d, 'Dario', '1990-01-01');

  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (a, 'Giulia', '1995-04-02');

  -- ── Nasce chiuso, importato, non verificato, e dice quando ───────────────
  riga := public.aggiungi_viaggio_passato(barcellona, 'Barcellona', 'ES', 'agosto 2019', 5::smallint);
  if riga -> 'viaggio' ->> 'stato' <> 'chiuso'
     or (riga -> 'viaggio' ->> 'importato')::boolean is not true
     or (riga -> 'viaggio' ->> 'verificato')::boolean is not false
     or riga -> 'viaggio' ->> 'periodo_approssimativo' <> 'agosto 2019'
     or (riga -> 'viaggio' ->> 'giorni_ricordati')::int <> 5
     or riga -> 'viaggio' ->> 'data_inizio' is not null then
    raise exception 'FALLITA: il viaggio passato non nasce com''è (%)', riga -> 'viaggio';
  end if;
  if jsonb_array_length(riga -> 'giorni') <> 0
     or jsonb_array_length(riga -> 'partecipazioni') <> 1
     or riga -> 'partecipazioni' -> 0 ->> 'ruolo' <> 'creatore' then
    raise exception 'FALLITA: il viaggio passato non ha chi lo ha aggiunto, o ha dei giorni';
  end if;
  riga := public.aggiungi_viaggio_passato(atene, 'Atene', 'GR', 'estate 2015', null);
  if riga -> 'viaggio' ->> 'giorni_ricordati' is not null then
    raise exception 'FALLITA: i giorni non ricordati ci sono';
  end if;
  log := log || E'\nok  un viaggio passato nasce chiuso, importato, con il periodo e i giorni se ci sono';

  -- ── Un viaggio non importato non nasce chiuso ─────────────────────────────
  foreach v_stato in array array['chiuso', 'in_corso', 'archiviato'] loop
    fallita := false;
    begin
      insert into public.viaggio (id, stato, data_inizio, data_fine, ora_arrivo, ora_partenza, creatore_id)
      values (vero, v_stato, oggi - 10, oggi - 8, '10:00', '18:00', a);
    exception when sqlstate 'TR403' then fallita := true;
    end;
    if not fallita then raise exception 'FALLITA: un viaggio nasce %', v_stato; end if;
  end loop;
  insert into public.viaggio (id, stato, creatore_id) values (vero, 'idea', a);
  log := log || E'\nok  un viaggio nasce idea o definito; chiuso solo se è passato';

  -- ── Quello che un viaggio passato non può essere ──────────────────────────
  fallita := false;
  begin
    perform public.aggiungi_viaggio_passato(gen_random_uuid(), 'Roma', 'IT', null, null);
  exception when check_violation then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un viaggio passato senza quando'; end if;
  foreach n in array array[0, 366] loop
    fallita := false;
    begin
      perform public.aggiungi_viaggio_passato(gen_random_uuid(), 'Roma', 'IT', 'maggio 2018', n::smallint);
    exception when check_violation then fallita := true;
    end;
    if not fallita then raise exception 'FALLITA: un viaggio passato di % giorni', n; end if;
  end loop;
  fallita := false;
  begin
    insert into public.viaggio (stato, creatore_id, giorni_ricordati) values ('idea', a, 4);
  exception when check_violation then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: i giorni ricordati in un viaggio vero'; end if;
  fallita := false;
  begin
    insert into public.viaggio (stato, creatore_id, importato, periodo_approssimativo)
    values ('idea', a, true, 'maggio 2018');
  exception when check_violation then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un viaggio importato che non è chiuso'; end if;
  fallita := false;
  begin
    update public.viaggio set stato = 'definito' where id = barcellona;
  exception when sqlstate 'TR403' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un viaggio passato si riapre'; end if;
  fallita := false;
  begin
    update public.viaggio set importato = false where id = barcellona;
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un viaggio passato smette di essere importato'; end if;
  log := log || E'\nok  senza quando, con giorni impossibili, aperto o non più importato: no';

  -- ── Non si verifica e non dà traguardi ───────────────────────────────────
  fallita := false;
  begin
    perform public.segna_verifica(barcellona, true);
  exception when sqlstate 'TR403' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un viaggio passato si verifica'; end if;
  fallita := false;
  begin
    perform public.prendi_traguardi(barcellona, array['primo_viaggio_verificato']);
  exception when sqlstate 'TR403' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un viaggio passato dà un traguardo'; end if;
  fallita := false;
  begin
    perform public.segna_sul_posto(barcellona);
  exception when sqlstate 'TR422' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: sul posto in un viaggio passato'; end if;
  log := log || E'\nok  non si verifica, non si è sul posto, non dà traguardi';

  -- ── Nessun invito ─────────────────────────────────────────────────────────
  fallita := false;
  begin
    insert into public.invito (viaggio_id) values (barcellona);
  exception when insufficient_privilege then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un invito in un viaggio passato'; end if;
  insert into public.invito (viaggio_id) values (vero);
  log := log || E'\nok  in un viaggio passato non si invita nessuno; negli altri sì';

  -- ── È di chi l'ha aggiunto ───────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  select count(*) into n from public.viaggio where id in (barcellona, atene);
  if n <> 0 then raise exception 'FALLITA: un estraneo vede i viaggi passati'; end if;
  update public.viaggio set destinazione_citta = 'Girona' where id = barcellona;

  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  select v.versione into v_versione from public.viaggio v
   where v.id = barcellona and v.destinazione_citta = 'Barcellona';
  if v_versione is null then raise exception 'FALLITA: un estraneo cambia un viaggio passato'; end if;
  update public.viaggio
     set periodo_approssimativo = 'luglio 2019', giorni_ricordati = 6, versione = v_versione
   where id = barcellona;
  fallita := false;
  begin
    update public.viaggio set giorni_ricordati = 7, versione = v_versione where id = barcellona;
  exception when sqlstate 'TR409' then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un viaggio passato si cambia su una versione superata'; end if;
  select v.versione into v_versione from public.viaggio v where v.id = atene;
  update public.viaggio set eliminato_il = now(), versione = v_versione where id = atene;
  select count(*) into n from public.viaggio where id = atene and eliminato_il is not null;
  if n <> 1 then raise exception 'FALLITA: un viaggio passato non si toglie'; end if;
  log := log || E'\nok  un estraneo non lo vede né lo cambia; chi l''ha aggiunto lo cambia e lo toglie';

  raise exception 'TUTTE LE PROVE PASSATE (annullate)%', log;
end;
$$;
