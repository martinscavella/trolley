-- L'impianto di sicurezza (5.1; 12-sicurezza-e-moderazione, 05-community-e-
-- sicurezza, 01-account-e-profilo). Si costruisce prima della parte pubblica:
-- il profilo pubblico, la ricerca e i messaggi (5.3, 5.4) ci si appoggiano.
--
-- - La parte pubblica ha un interruttore in `configurazione`: chiusa (l'ondata
--   1), aperta, o chiusa ai nuovi — quando arrivano più segnalazioni di quante
--   se ne riescano a gestire (12, casi limite). Gli account del team la vedono
--   anche chiusa, per provarla.
-- - Il numero di telefono si verifica con un codice SMS, attraverso la
--   funzione `telefono` (supabase/functions/telefono, ADR-011): è lei a
--   chiedere qui se si può mandare un codice, e a scrivere il numero quando è
--   verificato. Il numero sta nello schema privato: un numero, un account, e
--   non lo legge nessuno.
-- - Il profilo pubblico si accende solo da attiva_profilo_pubblico: dai 18
--   anni, con il telefono verificato, accettando le condizioni d'uso, se non
--   è sospeso e se la parte pubblica accoglie profili nuovi.
-- - Bloccare è reciproco: privato.si_bloccano lo dice alle regole della parte
--   pubblica (5.3, 5.4). Non avvisa nessuno.
-- - La segnalazione conserva il contenuto com'era quando è stata fatta (05,
--   regola 2), e chi l'ha fatta ne vede lo stato.
-- - La moderazione è uno strumento interno, fuori dall'app: lo schema
--   `moderazione`, che l'API non raggiunge, si usa dall'editor SQL con
--   l'accesso a Supabase (docs/sicurezza/moderazione.md).

-- ─── La parte pubblica: chiusa, aperta, chiusa ai nuovi ───────────────────

insert into public.configurazione (chiave, valore) values
  ('parte_pubblica', '"chiusa"'),
  -- Al giorno: codici per persona e per numero, tentativi di scriverlo per
  -- persona, codici per tutta l'app. Un SMS costa: senza tetto è il primo
  -- posto da cui si fanno uscire soldi per divertimento (04).
  ('tetto_telefono',
   '{"invii_persona": 5, "invii_numero": 3, "controlli_persona": 10, "invii_giorno": 100}')
on conflict (chiave) do nothing;

-- ─── Il profilo: sospensione e condizioni d'uso ───────────────────────────

alter table public.utente
  -- La sospensione toglie la superficie pubblica, non i dati (12, regola 9).
  -- Il motivo lo legge la persona sospesa.
  add column sospeso_il timestamptz,
  add column sospensione_motivo text,
  -- Quali condizioni d'uso ha accettato accendendo il profilo pubblico, e
  -- quando: le regole che poi si fanno rispettare (12, regola 7).
  add column condizioni_accettate text,
  add column condizioni_accettate_il timestamptz,
  add constraint sospeso_non_pubblico
    check (not profilo_pubblico_attivo or sospeso_il is null),
  add constraint sospensione_con_motivo
    check ((sospeso_il is null) = (sospensione_motivo is null)),
  add constraint pubblico_con_condizioni
    check (not profilo_pubblico_attivo or condizioni_accettate is not null);

-- Il profilo pubblico si accende e si spegne solo dalle due funzioni qui
-- sotto: scriverlo a mano salterebbe le condizioni d'uso e la sospensione.
revoke update (profilo_pubblico_attivo) on public.utente from authenticated;

-- Com'è la parte pubblica adesso. Senza la riga, chiusa.
create function privato.parte_pubblica()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select valore #>> '{}' from public.configurazione where chiave = 'parte_pubblica'),
    'chiusa');
$$;

-- Se [p_utente] vede la parte pubblica: aperta o chiusa ai nuovi; per il team
-- sempre.
create function privato.parte_pubblica_visibile(p_utente uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select privato.parte_pubblica() in ('aperta', 'chiusa_ai_nuovi')
      or coalesce((select interno from public.utente where id = p_utente), false);
$$;

-- Se [p_utente] può accendere adesso il profilo pubblico: con la parte
-- pubblica aperta; chiusa ai nuovi, solo chi c'era già (ha accettato le
-- condizioni d'uso) e l'ha spento; per il team sempre.
create function privato.accoglie(p_utente uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case privato.parte_pubblica()
           when 'aperta' then true
           when 'chiusa_ai_nuovi' then coalesce(
             (select condizioni_accettate_il is not null
                from public.utente where id = p_utente), false)
           else false
         end
      or coalesce((select interno from public.utente where id = p_utente), false);
$$;

-- ─── Il numero di telefono ────────────────────────────────────────────────

-- Un numero, un account (01, regola 4). Lo scrive solo la funzione `telefono`
-- quando il codice è giusto; il client non lo raggiunge.
create table privato.telefono (
  utente_id uuid primary key references public.utente (id) on delete cascade,
  numero text not null unique check (numero ~ '^\+[1-9][0-9]{7,14}$'),
  verificato_il timestamptz not null default now()
);

revoke all on privato.telefono from public, anon, authenticated;

-- I codici chiesti e i tentativi di scriverli, per il tetto. Dopo una
-- settimana si tolgono.
create table privato.tentativo_telefono (
  giorno date not null default current_date,
  utente_id uuid not null,
  numero text not null,
  invii integer not null default 0,
  controlli integer not null default 0,
  primary key (giorno, utente_id, numero)
);

revoke all on privato.tentativo_telefono from public, anon, authenticated;

select cron.schedule(
  'pulisci_tentativi_telefono',
  '40 3 * * *',
  $$delete from privato.tentativo_telefono where giorno < current_date - 7$$
);

create function privato.tetto_telefono(p_chiave text, p_predefinito integer)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select (valore ->> p_chiave)::integer
       from public.configurazione where chiave = 'tetto_telefono'),
    p_predefinito);
$$;

-- Per la funzione `telefono`, prima di mandare un codice a [p_numero] per
-- [p_utente]. Se la risposta è `ok` l'invio è contato; altrimenti perché no:
-- `profilo` (non c'è), `chiusa` (la parte pubblica non accoglie), `eta`
-- (meno di 18 anni), `numero` (non è un numero), `usato` (è di un altro
-- account), `gia` (è già il suo, verificato), `tetto` (troppi per oggi).
create function public.telefono_invio(p_utente uuid, p_numero text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_utente public.utente;
begin
  select * into v_utente from public.utente
   where id = p_utente and eliminato_il is null;
  if not found then return 'profilo'; end if;
  if not privato.accoglie(p_utente) then
    return 'chiusa';
  end if;
  if v_utente.data_nascita > current_date - interval '18 years' then
    return 'eta';
  end if;
  if p_numero is null or p_numero !~ '^\+[1-9][0-9]{7,14}$' then
    return 'numero';
  end if;
  if exists (select 1 from privato.telefono
              where numero = p_numero and utente_id <> p_utente) then
    return 'usato';
  end if;
  if exists (select 1 from privato.telefono
              where numero = p_numero and utente_id = p_utente) then
    return 'gia';
  end if;

  -- Uno alla volta: due richieste insieme non superano il tetto.
  perform pg_advisory_xact_lock(hashtext('tentativo_telefono'));
  if (select coalesce(sum(invii), 0) from privato.tentativo_telefono
       where giorno = current_date and utente_id = p_utente)
       >= privato.tetto_telefono('invii_persona', 5)
     or (select coalesce(sum(invii), 0) from privato.tentativo_telefono
          where giorno = current_date and numero = p_numero)
       >= privato.tetto_telefono('invii_numero', 3)
     or (select coalesce(sum(invii), 0) from privato.tentativo_telefono
          where giorno = current_date)
       >= privato.tetto_telefono('invii_giorno', 100) then
    return 'tetto';
  end if;

  insert into privato.tentativo_telefono (utente_id, numero, invii)
  values (p_utente, p_numero, 1)
  on conflict (giorno, utente_id, numero)
  do update set invii = privato.tentativo_telefono.invii + 1;
  return 'ok';
end;
$$;

-- Per la funzione `telefono`, prima di controllare un codice: `ok` (contato)
-- o `tetto`. Così il codice non si indovina provando.
create function public.telefono_controllo(p_utente uuid, p_numero text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtext('tentativo_telefono'));
  if (select coalesce(sum(controlli), 0) from privato.tentativo_telefono
       where giorno = current_date and utente_id = p_utente)
       >= privato.tetto_telefono('controlli_persona', 10) then
    return 'tetto';
  end if;
  insert into privato.tentativo_telefono (utente_id, numero, controlli)
  values (p_utente, p_numero, 1)
  on conflict (giorno, utente_id, numero)
  do update set controlli = privato.tentativo_telefono.controlli + 1;
  return 'ok';
end;
$$;

-- Per la funzione `telefono`, quando il fornitore dice che il codice è
-- giusto: il numero diventa quello di [p_utente]. `ok`, oppure `usato` (nel
-- frattempo è diventato di un altro) o `profilo`.
create function public.telefono_conferma(p_utente uuid, p_numero text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.utente
                  where id = p_utente and eliminato_il is null) then
    return 'profilo';
  end if;
  begin
    insert into privato.telefono (utente_id, numero)
    values (p_utente, p_numero)
    on conflict (utente_id)
    do update set numero = excluded.numero, verificato_il = now();
  exception when unique_violation then
    return 'usato';
  end;
  update public.utente set telefono_verificato = true
   where id = p_utente and not telefono_verificato;
  return 'ok';
end;
$$;

-- Le chiama solo la funzione `telefono`, con la chiave del server: dall'app
-- si potrebbe dire «verificato» senza aver ricevuto niente.
revoke execute on function public.telefono_invio(uuid, text) from public, anon, authenticated;
revoke execute on function public.telefono_controllo(uuid, text) from public, anon, authenticated;
revoke execute on function public.telefono_conferma(uuid, text) from public, anon, authenticated;
grant execute on function public.telefono_invio(uuid, text) to service_role;
grant execute on function public.telefono_controllo(uuid, text) to service_role;
grant execute on function public.telefono_conferma(uuid, text) to service_role;

-- ─── Il proprio profilo pubblico ──────────────────────────────────────────

-- Quanto serve alla schermata del profilo pubblico (tela, 68–69), per chi
-- chiama. `null` senza profilo.
create function public.la_mia_parte_pubblica()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'visibile', privato.parte_pubblica_visibile(u.id),
    'accoglie', privato.accoglie(u.id),
    'maggiorenne', u.data_nascita <= current_date - interval '18 years',
    'telefono', t.numero,
    'attivo', u.profilo_pubblico_attivo,
    'sospeso_il', u.sospeso_il,
    'sospensione_motivo', u.sospensione_motivo,
    'condizioni', u.condizioni_accettate)
  from public.utente u
  left join privato.telefono t on t.utente_id = u.id
  where u.id = (select auth.uid()) and u.eliminato_il is null;
$$;

-- Accende il profilo pubblico di chi chiama, che accetta le condizioni d'uso
-- [p_condizioni] (la loro versione, sito/condizioni.html).
create function public.attiva_profilo_pubblico(p_condizioni text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_io uuid := (select auth.uid());
  v_utente public.utente;
begin
  if v_io is null then
    raise exception 'accesso richiesto' using errcode = 'TR401';
  end if;
  select * into v_utente from public.utente
   where id = v_io and eliminato_il is null
   for update;
  if not found then
    raise exception 'profilo mancante' using errcode = 'TR403';
  end if;
  if v_utente.sospeso_il is not null then
    raise exception 'il profilo pubblico è sospeso' using errcode = 'TR424';
  end if;
  if v_utente.profilo_pubblico_attivo then
    return;
  end if;
  if not privato.accoglie(v_io) then
    raise exception 'la parte pubblica non accoglie profili nuovi' using errcode = 'TR423';
  end if;
  if not v_utente.telefono_verificato then
    raise exception 'serve il numero di telefono verificato' using errcode = 'TR403';
  end if;
  if p_condizioni is null or length(trim(p_condizioni)) not between 1 and 40 then
    raise exception 'servono le condizioni d''uso accettate' using errcode = '22023';
  end if;
  -- I 18 anni li controlla il trigger utente_eta.
  update public.utente
     set profilo_pubblico_attivo = true,
         condizioni_accettate = trim(p_condizioni),
         condizioni_accettate_il = now()
   where id = v_io;
end;
$$;

-- Lo spegne. Sempre possibile, anche sospesi o con la parte pubblica chiusa.
create function public.spegni_profilo_pubblico()
returns void
language sql
security definer
set search_path = ''
as $$
  update public.utente set profilo_pubblico_attivo = false
   where id = (select auth.uid()) and profilo_pubblico_attivo;
$$;

revoke execute on function public.la_mia_parte_pubblica() from public, anon;
revoke execute on function public.attiva_profilo_pubblico(text) from public, anon;
revoke execute on function public.spegni_profilo_pubblico() from public, anon;
grant execute on function public.la_mia_parte_pubblica() to authenticated;
grant execute on function public.attiva_profilo_pubblico(text) to authenticated;
grant execute on function public.spegni_profilo_pubblico() to authenticated;

-- ─── Bloccare ─────────────────────────────────────────────────────────────

-- Chi blocca e chi è bloccato. L'effetto è reciproco (05): nessuno dei due
-- compare all'altro. La riga si toglie sbloccando: non serve ricordare chi
-- aveva bloccato chi.
create table public.blocco (
  da_utente uuid not null references public.utente (id) on delete cascade,
  a_utente uuid not null references public.utente (id) on delete cascade,
  creato_il timestamptz not null default now(),
  primary key (da_utente, a_utente),
  constraint non_se_stessi check (da_utente <> a_utente)
);

create index blocco_a_utente on public.blocco (a_utente);

alter table public.blocco enable row level security;
revoke all on public.blocco from anon, authenticated;

-- Si legge chi si è bloccato, mai chi ci ha bloccato: bloccare non avvisa
-- (12, regola 4). Si scrive con blocca e sblocca.
grant select on public.blocco to authenticated;
create policy "si vede chi si è bloccato" on public.blocco
  for select to authenticated
  using (da_utente = (select auth.uid()));

-- Se uno dei due ha bloccato l'altro: per le regole della parte pubblica.
create function privato.si_bloccano(p_uno uuid, p_altro uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.blocco
     where (da_utente = p_uno and a_utente = p_altro)
        or (da_utente = p_altro and a_utente = p_uno));
$$;

create function public.blocca(p_utente uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_io uuid := (select auth.uid());
begin
  if v_io is null then
    raise exception 'accesso richiesto' using errcode = 'TR401';
  end if;
  if p_utente is null or p_utente = v_io
     or not exists (select 1 from public.utente
                     where id = p_utente and eliminato_il is null) then
    raise exception 'persona sconosciuta' using errcode = 'TR404';
  end if;
  insert into public.blocco (da_utente, a_utente)
  values (v_io, p_utente)
  on conflict do nothing;
end;
$$;

create function public.sblocca(p_utente uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.blocco
   where da_utente = (select auth.uid()) and a_utente = p_utente;
$$;

-- Le persone bloccate, con il nome, dalla più recente (tela, 72). Il nome di
-- chi si è bloccato si legge anche se non si condivide un viaggio: serve a
-- sbloccarlo.
create function public.persone_bloccate()
returns table (utente_id uuid, nome text, dal timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select b.a_utente, u.nome, b.creato_il
    from public.blocco b
    join public.utente u on u.id = b.a_utente
   where b.da_utente = (select auth.uid()) and u.eliminato_il is null
   order by b.creato_il desc;
$$;

revoke execute on function public.blocca(uuid) from public, anon;
revoke execute on function public.sblocca(uuid) from public, anon;
revoke execute on function public.persone_bloccate() from public, anon;
grant execute on function public.blocca(uuid) to authenticated;
grant execute on function public.sblocca(uuid) to authenticated;
grant execute on function public.persone_bloccate() to authenticated;

-- ─── Segnalare ────────────────────────────────────────────────────────────

create table public.segnalazione (
  -- Nasce sul telefono: una risposta persa non la manda due volte.
  id uuid primary key,
  da_utente uuid not null references public.utente (id),
  -- Chi è segnalato: per un profilo è il profilo, per un messaggio chi l'ha
  -- scritto. Serve alla coda e alla sospensione.
  a_utente uuid not null references public.utente (id),
  tipo_oggetto text not null check (tipo_oggetto in ('profilo', 'messaggio')),
  oggetto_id uuid not null,
  motivo text not null
    check (motivo in ('molestie', 'falso', 'inappropriato', 'minore', 'altro')),
  nota text check (length(nota) between 1 and 500),
  -- Il contenuto com'era quando è stato segnalato (05, regola 2).
  contenuto jsonb not null,
  stato text not null default 'ricevuta' check (stato in ('ricevuta', 'gestita')),
  esito text check (esito in ('nessuna_azione', 'contenuto_rimosso', 'profilo_sospeso')),
  -- Per chi modera; chi ha segnalato non la legge.
  nota_moderazione text,
  -- Se chi ha segnalato misura (la scelta sta sul suo telefono): solo allora
  -- la gestione diventa un evento a suo nome.
  misurata boolean not null default false,
  creata_il timestamptz not null default now(),
  gestita_il timestamptz,
  constraint gestita_con_esito check (
    (stato = 'gestita') = (esito is not null and gestita_il is not null)),
  constraint non_se_stessi check (da_utente <> a_utente)
);

create index segnalazione_da on public.segnalazione (da_utente, creata_il);
create index segnalazione_a on public.segnalazione (a_utente) where stato = 'ricevuta';

-- Non si legge né si scrive direttamente: si segnala con segnala, si guarda
-- con le_mie_segnalazioni.
alter table public.segnalazione enable row level security;
revoke all on public.segnalazione from anon, authenticated;

-- Segnala [p_oggetto], di tipo [p_tipo], per [p_motivo], con una [p_nota]
-- facoltativa; con [p_blocca] blocca anche chi l'ha fatto (tela, 70: «Blocca
-- anche» è già acceso). Chi è segnalato non viene avvisato.
create function public.segnala(
  p_id uuid,
  p_tipo text,
  p_oggetto uuid,
  p_motivo text,
  p_nota text default null,
  p_blocca boolean default false,
  p_misurazione boolean default true
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_io uuid := (select auth.uid());
  v_interno boolean;
  v_segnalato public.utente;
  v_nota text := nullif(left(trim(coalesce(p_nota, '')), 500), '');
begin
  if v_io is null then
    raise exception 'accesso richiesto' using errcode = 'TR401';
  end if;
  select interno into v_interno from public.utente
   where id = v_io and eliminato_il is null;
  if not found then
    raise exception 'profilo mancante' using errcode = 'TR403';
  end if;
  -- Già arrivata: la risposta si era persa.
  if exists (select 1 from public.segnalazione where id = p_id and da_utente = v_io) then
    return;
  end if;
  if p_motivo is null
     or p_motivo not in ('molestie', 'falso', 'inappropriato', 'minore', 'altro') then
    raise exception 'motivo sconosciuto: %', p_motivo using errcode = '22023';
  end if;
  -- I messaggi arrivano con la 5.4, e con loro il loro ramo qui.
  if p_tipo is distinct from 'profilo' then
    raise exception 'si segnala un profilo' using errcode = '22023';
  end if;

  -- Un profilo si segnala se è, o è stato, nella parte pubblica: chi ha
  -- accettato le condizioni d'uso. Spegnere il profilo non fa sfuggire.
  select * into v_segnalato from public.utente
   where id = p_oggetto and id <> v_io and eliminato_il is null
     and condizioni_accettate_il is not null;
  if not found then
    raise exception 'profilo non trovato' using errcode = 'TR404';
  end if;

  if (select count(*) from public.segnalazione
       where da_utente = v_io and creata_il > now() - interval '1 day') >= 20 then
    raise exception 'troppe segnalazioni oggi' using errcode = 'TR429';
  end if;

  insert into public.segnalazione
    (id, da_utente, a_utente, tipo_oggetto, oggetto_id, motivo, nota, contenuto, misurata)
  values
    (p_id, v_io, v_segnalato.id, 'profilo', v_segnalato.id, p_motivo, v_nota,
     jsonb_build_object(
       'nome', v_segnalato.nome,
       'profilo_pubblico_attivo', v_segnalato.profilo_pubblico_attivo,
       'preso_il', now()),
     coalesce(p_misurazione, false) and not v_interno);

  if p_blocca then
    insert into public.blocco (da_utente, a_utente)
    values (v_io, v_segnalato.id)
    on conflict do nothing;
  end if;

  -- 07: `segnalazione_ricevuta`. La scrive il server, come quella gestita:
  -- le ore fra le due sono quelle vere. Il motivo è una delle cinque voci,
  -- mai la nota.
  if coalesce(p_misurazione, false) and not v_interno then
    insert into public.evento (id, utente_id, nome, proprieta, avvenuto_il)
    values (gen_random_uuid(), v_io, 'segnalazione_ricevuta',
            jsonb_build_object('tipo', 'profilo', 'motivo', p_motivo), now());
  end if;
end;
$$;

-- Le proprie segnalazioni, dalla più recente, con il loro stato (tela, 71).
-- Il nome è quello che il segnalato aveva quando è stato segnalato.
create function public.le_mie_segnalazioni()
returns table (
  id uuid,
  tipo_oggetto text,
  nome text,
  motivo text,
  stato text,
  esito text,
  creata_il timestamptz,
  gestita_il timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select s.id, s.tipo_oggetto, s.contenuto ->> 'nome', s.motivo, s.stato,
         s.esito, s.creata_il, s.gestita_il
    from public.segnalazione s
   where s.da_utente = (select auth.uid())
   order by s.creata_il desc;
$$;

revoke execute on function public.segnala(uuid, text, uuid, text, text, boolean, boolean)
  from public, anon;
revoke execute on function public.le_mie_segnalazioni() from public, anon;
grant execute on function public.segnala(uuid, text, uuid, text, text, boolean, boolean)
  to authenticated;
grant execute on function public.le_mie_segnalazioni() to authenticated;

-- ─── La moderazione, dall'editor SQL ──────────────────────────────────────

-- Fuori dall'API: né l'app né le funzioni del server ci arrivano. La usa chi
-- modera, con il suo accesso a Supabase (05, regola 5). Il processo è in
-- docs/sicurezza/moderazione.md.
create schema moderazione;
revoke all on schema moderazione from public, anon, authenticated, service_role;

-- Una segnalazione gestita: lo stato che chi ha segnalato vede, e l'evento
-- `segnalazione_gestita` a suo nome, con le ore passate, se misura.
create function privato.segna_gestita(p_segnalazione uuid, p_esito text, p_nota text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_s public.segnalazione;
begin
  update public.segnalazione
     set stato = 'gestita', esito = p_esito, gestita_il = now(),
         nota_moderazione = coalesce(p_nota, nota_moderazione)
   where id = p_segnalazione and stato = 'ricevuta'
  returning * into v_s;
  if not found then
    raise exception 'nessuna segnalazione aperta con questo id' using errcode = 'TR404';
  end if;
  if v_s.misurata and exists (select 1 from public.utente
                               where id = v_s.da_utente and eliminato_il is null
                                 and not interno) then
    insert into public.evento (id, utente_id, nome, proprieta, avvenuto_il)
    values (gen_random_uuid(), v_s.da_utente, 'segnalazione_gestita',
            jsonb_build_object(
              'ore', round(extract(epoch from v_s.gestita_il - v_s.creata_il) / 3600, 1),
              'esito', p_esito,
              'tipo', v_s.tipo_oggetto),
            now());
  end if;
end;
$$;

revoke execute on function privato.segna_gestita(uuid, text, text) from public, anon, authenticated;

-- Le segnalazioni aperte, nell'ordine in cui guardarle: prima i minori e le
-- molestie, poi chi è segnalato da più persone, poi la più vecchia.
create view moderazione.coda as
select s.id,
       case s.motivo when 'minore' then 1 when 'molestie' then 1
                     when 'falso' then 2 when 'inappropriato' then 2 else 3 end
         as priorita,
       s.motivo,
       date_trunc('minute', now() - s.creata_il) as attesa,
       s.tipo_oggetto,
       s.a_utente,
       u.nome as segnalato,
       u.sospeso_il is not null as gia_sospeso,
       (select count(distinct x.da_utente) from public.segnalazione x
         where x.a_utente = s.a_utente and x.stato = 'ricevuta') as da_quante_persone,
       (select count(*) from public.segnalazione x
         where x.a_utente = s.a_utente and x.esito = 'profilo_sospeso') as sospensioni_prima,
       s.da_utente,
       -- Chi segnala spesso a vuoto: le segnalazioni infondate ripetute sono a
       -- loro volta da sanzionare (12, casi limite).
       (select count(*) from public.segnalazione x
         where x.da_utente = s.da_utente and x.esito = 'nessuna_azione') as archiviate_di_chi_segnala,
       s.nota,
       s.contenuto,
       s.creata_il
  from public.segnalazione s
  join public.utente u on u.id = s.a_utente
 where s.stato = 'ricevuta'
 order by priorita, da_quante_persone desc, s.creata_il;

-- Archiviare: non c'è niente da fare. Chi ha segnalato lo vede gestito.
create function moderazione.archivia(p_segnalazione uuid, p_nota text default null)
returns void
language sql
set search_path = ''
as $$
  select privato.segna_gestita(p_segnalazione, 'nessuna_azione', p_nota);
$$;

-- Sospendere il profilo pubblico di chi è segnalato. [p_motivo] lo legge la
-- persona sospesa: le regole delle condizioni d'uso che ha violato, senza dire
-- chi l'ha segnalata. Tutte le segnalazioni aperte su di lei si chiudono così.
create function moderazione.sospendi(p_segnalazione uuid, p_motivo text, p_nota text default null)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_a uuid;
  v_s uuid;
  v_n integer := 0;
begin
  if p_motivo is null or length(trim(p_motivo)) = 0 then
    raise exception 'serve il motivo, che la persona leggerà';
  end if;
  select a_utente into v_a from public.segnalazione
   where id = p_segnalazione and stato = 'ricevuta';
  if not found then
    raise exception 'nessuna segnalazione aperta con questo id';
  end if;
  update public.utente
     set sospeso_il = now(),
         sospensione_motivo = trim(p_motivo),
         profilo_pubblico_attivo = false
   where id = v_a and eliminato_il is null;
  for v_s in
    select id from public.segnalazione
     where a_utente = v_a and stato = 'ricevuta' order by creata_il
  loop
    perform privato.segna_gestita(v_s, 'profilo_sospeso', p_nota);
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;

-- Togliere la sospensione: la persona può riaccendere il profilo da sé.
create function moderazione.riattiva(p_utente uuid)
returns void
language sql
set search_path = ''
as $$
  update public.utente set sospeso_il = null, sospensione_motivo = null
   where id = p_utente;
$$;

-- Aprire, chiudere ai nuovi o chiudere la parte pubblica (12, casi limite:
-- meglio una funzione sospesa che una non sorvegliata).
create function moderazione.parte_pubblica(p_stato text)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if p_stato not in ('chiusa', 'aperta', 'chiusa_ai_nuovi') then
    raise exception 'stato sconosciuto: % (chiusa, aperta, chiusa_ai_nuovi)', p_stato;
  end if;
  insert into public.configurazione (chiave, valore)
  values ('parte_pubblica', to_jsonb(p_stato))
  on conflict (chiave) do update set valore = excluded.valore, aggiornata_il = now();
end;
$$;

revoke execute on function moderazione.archivia(uuid, text) from public;
revoke execute on function moderazione.sospendi(uuid, text, text) from public;
revoke execute on function moderazione.riattiva(uuid) from public;
revoke execute on function moderazione.parte_pubblica(text) from public;

-- ─── I tuoi dati: anche il telefono, i blocchi, le segnalazioni ───────────

create or replace function public.i_miei_dati()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'formato', 'trolley.dati',
    'versione', 2,
    'esportato_il', now(),
    'email', (select auth.jwt() ->> 'email'),
    'profilo', (select to_jsonb(u) from public.mio_profilo() u),
    'telefono', public.la_mia_parte_pubblica() ->> 'telefono',
    'viaggi', coalesce((
      select jsonb_agg(jsonb_build_object(
        'viaggio', to_jsonb(v),
        'persone', coalesce((
          select jsonb_agg(jsonb_build_object('id', u.id, 'nome', u.nome))
            from public.utente u
           where u.id in (select p.utente_id from public.partecipazione p
                           where p.viaggio_id = v.id)), '[]'::jsonb),
        'partecipazioni', coalesce((
          select jsonb_agg(to_jsonb(p)) from public.partecipazione p
           where p.viaggio_id = v.id), '[]'::jsonb),
        'giorni', coalesce((
          select jsonb_agg(to_jsonb(g) order by g.data) from public.giorno g
           where g.viaggio_id = v.id), '[]'::jsonb),
        'tappe', coalesce((
          select jsonb_agg(to_jsonb(t)) from public.tappa t
           where t.viaggio_id = v.id), '[]'::jsonb),
        'spese', coalesce((
          select jsonb_agg(to_jsonb(s) order by s.data) from public.spesa s
           where s.viaggio_id = v.id), '[]'::jsonb),
        'quote', coalesce((
          select jsonb_agg(to_jsonb(q)) from public.spesa_quota q
           where q.viaggio_id = v.id), '[]'::jsonb),
        'voci', coalesce((
          select jsonb_agg(to_jsonb(l)) from public.voce_lista l
           where l.viaggio_id = v.id), '[]'::jsonb),
        'note', coalesce((
          select jsonb_agg(to_jsonb(n)) from public.nota n
           where n.viaggio_id = v.id), '[]'::jsonb)
      ) order by v.creato_il)
      from public.viaggio v), '[]'::jsonb),
    'traguardi', coalesce((
      select jsonb_agg(to_jsonb(t) order by t.preso_il) from public.traguardo t),
      '[]'::jsonb),
    'persone_bloccate', coalesce((
      select jsonb_agg(to_jsonb(b)) from public.persone_bloccate() b), '[]'::jsonb),
    'segnalazioni', coalesce((
      select jsonb_agg(to_jsonb(s)) from public.le_mie_segnalazioni() s), '[]'::jsonb),
    'eventi', coalesce((
      select jsonb_agg(jsonb_build_object(
        'nome', e.nome, 'proprieta', e.proprieta,
        'avvenuto_il', e.avvenuto_il, 'versione_app', e.versione_app)
        order by e.avvenuto_il)
        from public.evento e
       where e.utente_id = (select auth.uid())), '[]'::jsonb)
  );
$$;

-- ─── Chiudere l'account: anche il telefono e i blocchi ────────────────────

-- Come in chiusura_account.sql, più: il numero e i tentativi si cancellano,
-- i blocchi in tutte e due le direzioni si tolgono, il profilo pubblico perde
-- condizioni e sospensione. Le segnalazioni restano per chi modera (06,
-- «Conservazione»), ma non diventano più eventi a nome di chi ha chiuso.
create or replace function public.chiudi_account(p_misurazione boolean default true)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_io uuid := (select auth.uid());
  v_interno boolean;
  v_viaggio record;
  v_erede uuid;
  v_cancellati integer := 0;
  v_lasciati integer := 0;
  v_anonimo uuid := gen_random_uuid();
begin
  if v_io is null then
    raise exception 'accesso richiesto' using errcode = 'TR401';
  end if;

  select interno into v_interno
    from public.utente
   where id = v_io and eliminato_il is null
   for update;

  -- Chi ha un accesso ma non ha mai fatto il profilo non ha niente da togliere.
  if found then
    for v_viaggio in
      select p.viaggio_id, p.ruolo
        from public.partecipazione p
       where p.utente_id = v_io and p.stato = 'attivo' and p.eliminato_il is null
       order by p.viaggio_id
         for update
    loop
      select q.utente_id into v_erede
        from public.partecipazione q
       where q.viaggio_id = v_viaggio.viaggio_id and q.utente_id <> v_io
         and q.stato = 'attivo' and q.eliminato_il is null
       order by q.creato_il, q.utente_id
       limit 1;

      if v_erede is null then
        perform privato.cancella_viaggio(v_viaggio.viaggio_id);
        v_cancellati := v_cancellati + 1;
        continue;
      end if;

      -- Come passa_il_ruolo: prima si toglie, poi si dà (un_creatore_per_viaggio).
      if v_viaggio.ruolo = 'creatore' then
        update public.partecipazione set ruolo = 'partecipante'
         where viaggio_id = v_viaggio.viaggio_id and utente_id = v_io;
        update public.partecipazione set ruolo = 'creatore'
         where viaggio_id = v_viaggio.viaggio_id and utente_id = v_erede;
        update public.viaggio set creatore_id = v_erede
         where id = v_viaggio.viaggio_id;
      end if;
      -- Come esci_dal_viaggio: le voci che portava tornano libere.
      update public.partecipazione set stato = 'uscito'
       where viaggio_id = v_viaggio.viaggio_id and utente_id = v_io;
      perform privato.libera_voci(v_viaggio.viaggio_id, v_io);
      v_lasciati := v_lasciati + 1;
    end loop;

    -- Ciò che era solo suo, anche nei viaggi lasciati prima.
    delete from public.voce_lista where proprietario_id = v_io and tipo = 'personale';
    delete from public.traguardo where utente_id = v_io;
    -- I link che ha mandato non fanno più entrare nessuno.
    update public.invito set eliminato_il = now()
     where creato_da = v_io and eliminato_il is null;

    -- La parte pubblica (5.1): il numero torna libero, i blocchi spariscono.
    delete from privato.telefono where utente_id = v_io;
    delete from privato.tentativo_telefono where utente_id = v_io;
    delete from public.blocco where da_utente = v_io or a_utente = v_io;
    update public.segnalazione set misurata = false where da_utente = v_io;

    update public.utente
       set nome = null,
           data_nascita = null,
           telefono_verificato = false,
           profilo_pubblico_attivo = false,
           condizioni_accettate = null,
           condizioni_accettate_il = null,
           sospeso_il = null,
           sospensione_motivo = null,
           valuta_predefinita = 'EUR',
           eliminato_il = now()
     where id = v_io;

    if v_interno then
      delete from public.evento where utente_id = v_io;
    else
      if p_misurazione then
        insert into public.evento (id, utente_id, nome, proprieta, avvenuto_il)
        values (gen_random_uuid(), v_io, 'account_chiuso',
                jsonb_build_object('viaggi_cancellati', v_cancellati,
                                   'viaggi_lasciati', v_lasciati),
                now());
      end if;
      -- Un id solo per tutti i suoi eventi: le soglie che seguono una persona
      -- nel tempo restano calcolabili, ma non portano più a lei.
      update public.evento set utente_id = v_anonimo where utente_id = v_io;
    end if;
  end if;

  delete from auth.users where id = v_io;
end;
$$;
