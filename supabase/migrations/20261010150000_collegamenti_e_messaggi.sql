-- I collegamenti e i messaggi (5.4; 11-community, 12-sicurezza-e-moderazione,
-- 05-community-e-sicurezza; tela, 76–78 e 111–116). Si appoggia alla 5.1
-- (sicurezza.sql) e alla 5.3 (profilo_pubblico.sql), e segue le scelte della
-- 5.2 (docs/legale/valutazione-impatto-parte-pubblica.md):
--
-- - Il collegamento è reciproco (11, regola 3): uno chiede, l'altro accetta.
--   La richiesta può portare un messaggio breve, e nient'altro passa prima del
--   sì (regola 4). Accettata, quel messaggio diventa il primo della
--   conversazione; rifiutata, si cancella. Rifiutare non dice niente a chi ha
--   chiesto, oltre al «non accettata» (regola 5); dopo un no si può chiedere
--   di nuovo (M9 non adottata).
-- - Collegamenti e messaggi si toccano solo con funzioni del server (M7): le
--   tabelle non si leggono né si scrivono direttamente.
-- - Tutto segue privato.vede_il_profilo: un profilo spento, sospeso, bloccato
--   o con la parte pubblica chiusa sparisce anche dai collegamenti e dai
--   messaggi, e torna quando si riaccende o si sblocca (11, casi limite; 12,
--   regola 3). Bloccare non cancella niente.
-- - La conversazione è fra due persone, e sopravvive al collegamento (P6,
--   scelto il 10 ottobre 2026): chi toglie il collegamento non la vede più,
--   all'altra persona resta, senza poter scrivere. Chi chiude l'account
--   diventa «Account chiuso». Quando nessuno dei due la vede più, si cancella.
-- - Chi modera può togliere un messaggio segnalato (la terza azione, 05).

-- ─── I collegamenti ───────────────────────────────────────────────────────

-- Uno per coppia, in qualunque verso: chi ha chiesto per ultimo è da_utente.
create table public.collegamento (
  id uuid primary key default gen_random_uuid(),
  da_utente uuid not null references public.utente (id) on delete cascade,
  a_utente uuid not null references public.utente (id) on delete cascade,
  stato text not null default 'richiesto'
    check (stato in ('richiesto', 'accettato', 'rifiutato')),
  -- Il messaggio della richiesta (200 caratteri): lo legge solo chi la riceve,
  -- e solo finché non risponde.
  messaggio text check (length(messaggio) between 1 and 200),
  chiesto_il timestamptz not null default now(),
  risposto_il timestamptz,
  constraint non_se_stessi check (da_utente <> a_utente),
  constraint messaggio_solo_in_attesa check (stato = 'richiesto' or messaggio is null),
  constraint risposta_con_data check ((stato = 'richiesto') = (risposto_il is null))
);

create unique index collegamento_coppia
  on public.collegamento (least(da_utente, a_utente), greatest(da_utente, a_utente));
create index collegamento_a_utente on public.collegamento (a_utente);

alter table public.collegamento enable row level security;
revoke all on public.collegamento from anon, authenticated;

-- ─── I messaggi ───────────────────────────────────────────────────────────

-- Gli orari della conversazione vengono da clock_timestamp(), non da now():
-- dentro una stessa transazione now() è fermo, e «prima» e «dopo» di quando si
-- è tolta una conversazione si confonderebbero.
create table public.messaggio (
  -- Nasce sul telefono: un messaggio rimandato dopo una risposta persa non
  -- arriva due volte.
  id uuid primary key,
  da_utente uuid not null references public.utente (id) on delete cascade,
  a_utente uuid not null references public.utente (id) on delete cascade,
  -- Null quando chi modera l'ha tolto: resta solo nella fotografia della
  -- segnalazione.
  testo text check (length(testo) between 1 and 1000),
  scritto_il timestamptz not null default now(),
  -- Quando chi lo riceve l'ha visto: dice che cosa è da leggere. Chi l'ha
  -- scritto non lo sa: niente conferme di lettura.
  letto_il timestamptz,
  tolto_il timestamptz,
  constraint non_se_stessi check (da_utente <> a_utente),
  constraint testo_o_tolto check ((testo is null) = (tolto_il is not null))
);

create index messaggio_coppia
  on public.messaggio (least(da_utente, a_utente), greatest(da_utente, a_utente), scritto_il);
create index messaggio_da_leggere on public.messaggio (a_utente) where letto_il is null;

alter table public.messaggio enable row level security;
revoke all on public.messaggio from anon, authenticated;

-- Fino a quando una persona non vede più la conversazione con un'altra: ha
-- tolto il collegamento, o la conversazione rimasta. I messaggi di prima non
-- li vede più; quelli che nessuno dei due vede più si cancellano.
create table privato.conversazione_tolta (
  utente_id uuid not null references public.utente (id) on delete cascade,
  altro_id uuid not null references public.utente (id) on delete cascade,
  fino_al timestamptz not null default now(),
  primary key (utente_id, altro_id)
);

revoke all on privato.conversazione_tolta from public, anon, authenticated;

-- Messaggi al giorno per persona: tanti per parlarsi davvero, non per
-- riempire il database da uno script. Le richieste non hanno tetto (M8 non
-- adottata).
insert into public.configurazione (chiave, valore) values ('tetto_messaggi', '500')
on conflict (chiave) do nothing;

-- ─── Chi vede che cosa ────────────────────────────────────────────────────

-- Se [p_utente] è nella parte pubblica: profilo acceso, non sospeso, dove la
-- parte pubblica c'è. È la metà di vede_il_profilo che riguarda chi guarda.
create function privato.nella_parte_pubblica(p_utente uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select u.profilo_pubblico_attivo and u.sospeso_il is null
                     from public.utente u
                    where u.id = p_utente and u.eliminato_il is null), false)
     and privato.parte_pubblica_visibile(p_utente);
$$;

revoke execute on function privato.nella_parte_pubblica(uuid) from public, anon, authenticated;

-- Il collegamento fra due persone, in qualunque verso.
create function privato.collegamento_fra(p_uno uuid, p_altro uuid)
returns public.collegamento
language sql
stable
security definer
set search_path = ''
as $$
  select c.* from public.collegamento c
   where least(c.da_utente, c.a_utente) = least(p_uno, p_altro)
     and greatest(c.da_utente, c.a_utente) = greatest(p_uno, p_altro);
$$;

revoke execute on function privato.collegamento_fra(uuid, uuid) from public, anon, authenticated;

-- Da quando [p_io] vede i messaggi con [p_altro]: dopo l'ultima volta che ha
-- tolto la conversazione.
create function privato.visibili_dal(p_io uuid, p_altro uuid)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select t.fino_al from privato.conversazione_tolta t
                    where t.utente_id = p_io and t.altro_id = p_altro),
                  '-infinity'::timestamptz);
$$;

revoke execute on function privato.visibili_dal(uuid, uuid) from public, anon, authenticated;

-- Se [p_io] vede la conversazione con [p_altro], e se ci può scrivere.
-- Collegati: solo se si vedono (vede_il_profilo), e allora si scrive.
-- Non più collegati: la conversazione rimasta, se ha ancora messaggi per lui,
-- se lui è nella parte pubblica e se nessuno dei due ha bloccato l'altro;
-- chi dall'altra parte ha chiuso l'account o spento il profilo non conta.
create function privato.conversazione_per(p_io uuid, p_altro uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when exists (select 1 from privato.collegamento_fra(p_io, p_altro) c
                  where c.stato = 'accettato') then
      case when privato.vede_il_profilo(p_io, p_altro) then 'collegati' end
    when privato.nella_parte_pubblica(p_io)
         and not privato.si_bloccano(p_io, p_altro)
         and exists (select 1 from public.messaggio m
                      where least(m.da_utente, m.a_utente) = least(p_io, p_altro)
                        and greatest(m.da_utente, m.a_utente) = greatest(p_io, p_altro)
                        and m.scritto_il > privato.visibili_dal(p_io, p_altro)) then
      'finita'
  end;
$$;

revoke execute on function privato.conversazione_per(uuid, uuid) from public, anon, authenticated;

-- Un messaggio come lo vede [p_io].
create function privato.messaggio_per(p_io uuid, m public.messaggio)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', m.id,
    'mio', m.da_utente = p_io,
    'testo', m.testo,
    'scritto_il', m.scritto_il,
    'tolto', m.tolto_il is not null);
$$;

revoke execute on function privato.messaggio_per(uuid, public.messaggio) from public, anon, authenticated;

-- [p_io] non vede più la conversazione con [p_altro] fino a adesso; i
-- messaggi che nessuno dei due vede più si cancellano.
create function privato.togli_conversazione(p_io uuid, p_altro uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into privato.conversazione_tolta (utente_id, altro_id, fino_al)
  values (p_io, p_altro, clock_timestamp())
  on conflict (utente_id, altro_id) do update set fino_al = excluded.fino_al;
  delete from public.messaggio m
   where least(m.da_utente, m.a_utente) = least(p_io, p_altro)
     and greatest(m.da_utente, m.a_utente) = greatest(p_io, p_altro)
     and m.scritto_il <= least(privato.visibili_dal(p_io, p_altro),
                               privato.visibili_dal(p_altro, p_io));
end;
$$;

revoke execute on function privato.togli_conversazione(uuid, uuid) from public, anon, authenticated;

-- ─── Chiedere, rispondere ─────────────────────────────────────────────────

-- Accetta [c]: il messaggio della richiesta diventa il primo della
-- conversazione, con l'ora in cui era stato scritto.
create function privato.accetta(c public.collegamento)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.collegamento
     set stato = 'accettato', messaggio = null, risposto_il = now()
   where id = c.id;
  if c.messaggio is not null then
    insert into public.messaggio (id, da_utente, a_utente, testo, scritto_il)
    values (gen_random_uuid(), c.da_utente, c.a_utente, c.messaggio, c.chiesto_il);
  end if;
end;
$$;

revoke execute on function privato.accetta(public.collegamento) from public, anon, authenticated;

-- Chiede a [p_utente] di collegarsi, con un [p_messaggio] facoltativo (tela,
-- 76). Si chiede solo a chi si vede. Se l'altro aveva già chiesto, è un sì
-- da tutti e due: il collegamento esiste. Dopo un no si può chiedere di
-- nuovo. Dice com'è andata: 'richiesto', 'accettato', o 'nessun_cambio' se
-- la richiesta c'era già (una risposta persa) o si è già collegati.
create function public.chiedi_collegamento(p_utente uuid, p_messaggio text default null)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_io uuid := (select auth.uid());
  v_messaggio text := nullif(trim(coalesce(p_messaggio, '')), '');
  v_c public.collegamento;
begin
  if v_io is null then
    raise exception 'accesso richiesto' using errcode = 'TR401';
  end if;
  if not privato.vede_il_profilo(v_io, p_utente) then
    raise exception 'profilo non trovato' using errcode = 'TR404';
  end if;
  if length(v_messaggio) > 200 then
    raise exception 'il messaggio della richiesta è di 200 caratteri al più' using errcode = '22023';
  end if;

  select c.* into v_c from public.collegamento c
   where least(c.da_utente, c.a_utente) = least(v_io, p_utente)
     and greatest(c.da_utente, c.a_utente) = greatest(v_io, p_utente)
     for update;

  if not found then
    insert into public.collegamento (da_utente, a_utente, messaggio, chiesto_il)
    values (v_io, p_utente, v_messaggio, clock_timestamp());
    return 'richiesto';
  end if;
  if v_c.stato = 'accettato' or (v_c.stato = 'richiesto' and v_c.da_utente = v_io) then
    return 'nessun_cambio';
  end if;
  if v_c.stato = 'richiesto' then
    perform privato.accetta(v_c);
    return 'accettato';
  end if;
  -- Rifiutata prima, in un verso o nell'altro: una richiesta nuova.
  update public.collegamento
     set da_utente = v_io, a_utente = p_utente, stato = 'richiesto',
         messaggio = v_messaggio, chiesto_il = clock_timestamp(), risposto_il = null
   where id = v_c.id;
  return 'richiesto';
end;
$$;

-- Risponde alla richiesta di [p_utente]: con [p_accetta] il collegamento
-- esiste; altrimenti la richiesta resta «non accettata» per chi l'ha fatta, e
-- il suo messaggio si cancella. Chi ha chiesto non riceve altro.
create function public.rispondi(p_utente uuid, p_accetta boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_io uuid := (select auth.uid());
  v_c public.collegamento;
begin
  if v_io is null then
    raise exception 'accesso richiesto' using errcode = 'TR401';
  end if;
  select c.* into v_c from public.collegamento c
   where c.da_utente = p_utente and c.a_utente = v_io and c.stato = 'richiesto'
     for update;
  if not found or not privato.vede_il_profilo(v_io, p_utente) then
    raise exception 'nessuna richiesta da questa persona' using errcode = 'TR404';
  end if;
  if coalesce(p_accetta, false) then
    perform privato.accetta(v_c);
  else
    update public.collegamento
       set stato = 'rifiutato', messaggio = null, risposto_il = now()
     where id = v_c.id;
  end if;
end;
$$;

-- Toglie la propria richiesta a [p_utente]: in attesa (la si ritira) o non
-- accettata (non la si vede più).
create function public.ritira_richiesta(p_utente uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.collegamento
   where da_utente = (select auth.uid()) and a_utente = p_utente
     and stato in ('richiesto', 'rifiutato');
$$;

-- Toglie il collegamento con [p_utente]: non vi scrivete più, e chi lo toglie
-- non vede più la conversazione. All'altra persona resta (P6).
create function public.togli_collegamento(p_utente uuid)
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
  delete from public.collegamento c
   where least(c.da_utente, c.a_utente) = least(v_io, p_utente)
     and greatest(c.da_utente, c.a_utente) = greatest(v_io, p_utente)
     and c.stato = 'accettato';
  if not found then
    raise exception 'non siete collegati' using errcode = 'TR404';
  end if;
  perform privato.togli_conversazione(v_io, p_utente);
end;
$$;

-- Toglie la conversazione rimasta con [p_utente] (tela, 116): da qui in poi
-- non la si vede più.
create function public.togli_conversazione(p_utente uuid)
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
  perform privato.togli_conversazione(v_io, p_utente);
end;
$$;

revoke execute on function public.chiedi_collegamento(uuid, text) from public, anon;
revoke execute on function public.rispondi(uuid, boolean) from public, anon;
revoke execute on function public.ritira_richiesta(uuid) from public, anon;
revoke execute on function public.togli_collegamento(uuid) from public, anon;
revoke execute on function public.togli_conversazione(uuid) from public, anon;
grant execute on function public.chiedi_collegamento(uuid, text) to authenticated;
grant execute on function public.rispondi(uuid, boolean) to authenticated;
grant execute on function public.ritira_richiesta(uuid) to authenticated;
grant execute on function public.togli_collegamento(uuid) to authenticated;
grant execute on function public.togli_conversazione(uuid) to authenticated;

-- I collegamenti di chi chiama (tela, 77), solo con chi si vede: le richieste
-- ricevute, con il messaggio e il profilo di chi chiede (per dire che cosa
-- avete in comune); quelle inviate, in attesa o non accettate; i collegati.
create function public.i_miei_collegamenti()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with io as (select (select auth.uid()) as id),
  miei as (
    select c.*,
           case when c.da_utente = io.id then c.a_utente else c.da_utente end as altro,
           c.da_utente = io.id as chiesto_da_me
      from public.collegamento c, io
     where io.id in (c.da_utente, c.a_utente)
       and privato.vede_il_profilo(io.id,
             case when c.da_utente = io.id then c.a_utente else c.da_utente end)
  )
  select jsonb_build_object(
    'ricevute', coalesce((
      select jsonb_agg(jsonb_build_object(
               'utente_id', m.altro, 'nome', u.nome, 'messaggio', m.messaggio,
               'chiesto_il', m.chiesto_il,
               'profilo', privato.profilo_come_lo_vedono(m.altro))
               order by m.chiesto_il desc)
        from miei m join public.utente u on u.id = m.altro
       where m.stato = 'richiesto' and not m.chiesto_da_me), '[]'::jsonb),
    'inviate', coalesce((
      select jsonb_agg(jsonb_build_object(
               'utente_id', m.altro, 'nome', u.nome, 'stato', m.stato,
               'chiesto_il', m.chiesto_il)
               order by m.chiesto_il desc)
        from miei m join public.utente u on u.id = m.altro
       where m.stato in ('richiesto', 'rifiutato') and m.chiesto_da_me), '[]'::jsonb),
    'collegati', coalesce((
      select jsonb_agg(jsonb_build_object(
               'utente_id', m.altro, 'nome', u.nome, 'dal', m.risposto_il)
               order by u.nome)
        from miei m join public.utente u on u.id = m.altro
       where m.stato = 'accettato'), '[]'::jsonb));
$$;

revoke execute on function public.i_miei_collegamenti() from public, anon;
grant execute on function public.i_miei_collegamenti() to authenticated;

-- ─── Scrivere e leggere ───────────────────────────────────────────────────

-- Scrive [p_testo] a [p_utente], con l'[p_id] nato sul telefono: solo fra
-- persone collegate che si vedono (11, regola 4). Restituisce il messaggio.
create function public.scrivi(p_id uuid, p_utente uuid, p_testo text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_io uuid := (select auth.uid());
  v_testo text := trim(coalesce(p_testo, ''));
  v_m public.messaggio;
  v_tetto integer;
begin
  if v_io is null then
    raise exception 'accesso richiesto' using errcode = 'TR401';
  end if;
  -- Già arrivato: la risposta si era persa.
  select * into v_m from public.messaggio where id = p_id and da_utente = v_io;
  if found then
    return privato.messaggio_per(v_io, v_m);
  end if;
  if length(v_testo) not between 1 and 1000 then
    raise exception 'un messaggio è fra 1 e 1000 caratteri' using errcode = '22023';
  end if;
  if privato.conversazione_per(v_io, p_utente) is distinct from 'collegati' then
    raise exception 'non siete collegati' using errcode = 'TR404';
  end if;
  v_tetto := coalesce(
    (select (valore #>> '{}')::integer from public.configurazione
      where chiave = 'tetto_messaggi'), 500);
  if (select count(*) from public.messaggio
       where da_utente = v_io and scritto_il > now() - interval '1 day') >= v_tetto then
    raise exception 'troppi messaggi oggi' using errcode = 'TR429';
  end if;
  insert into public.messaggio (id, da_utente, a_utente, testo, scritto_il)
  values (p_id, v_io, p_utente, v_testo, clock_timestamp())
  returning * into v_m;
  return privato.messaggio_per(v_io, v_m);
end;
$$;

-- La conversazione con [p_utente] (tela, 78 e 116): chi è, se vi potete
-- scrivere, e i messaggi — gli ultimi trecento, o quelli dopo [p_dopo] per
-- chi la sta guardando. Quelli ricevuti diventano letti.
create function public.conversazione(p_utente uuid, p_dopo timestamptz default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_io uuid := (select auth.uid());
  v_stato text;
  v_dal timestamptz;
begin
  if v_io is null then
    raise exception 'accesso richiesto' using errcode = 'TR401';
  end if;
  v_stato := privato.conversazione_per(v_io, p_utente);
  if v_stato is null then
    raise exception 'conversazione non trovata' using errcode = 'TR404';
  end if;
  v_dal := greatest(privato.visibili_dal(v_io, p_utente), coalesce(p_dopo, '-infinity'));

  update public.messaggio set letto_il = now()
   where a_utente = v_io and da_utente = p_utente and letto_il is null
     and scritto_il > privato.visibili_dal(v_io, p_utente);

  return jsonb_build_object(
    'utente_id', p_utente,
    'nome', (select u.nome from public.utente u
              where u.id = p_utente and u.eliminato_il is null),
    'collegati', v_stato = 'collegati',
    'dal', (select c.risposto_il from privato.collegamento_fra(v_io, p_utente) c
             where c.stato = 'accettato'),
    'messaggi', coalesce((
      select jsonb_agg(privato.messaggio_per(v_io, x.m) order by (x.m).scritto_il, (x.m).id)
        from (select m from public.messaggio m
               where least(m.da_utente, m.a_utente) = least(v_io, p_utente)
                 and greatest(m.da_utente, m.a_utente) = greatest(v_io, p_utente)
                 and m.scritto_il > v_dal
               order by m.scritto_il desc, m.id desc
               limit 300) x), '[]'::jsonb));
end;
$$;

-- Le conversazioni di chi chiama (tela, 111), dalla più recente: con chi, se
-- vi potete scrivere, l'ultimo messaggio, quanti da leggere. Ci sono anche i
-- collegati a cui non si è ancora scritto.
create function public.i_miei_messaggi()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with io as (select (select auth.uid()) as id),
  altri as (
    select distinct case when c.da_utente = io.id then c.a_utente else c.da_utente end as altro
      from public.collegamento c, io
     where c.stato = 'accettato' and io.id in (c.da_utente, c.a_utente)
    union
    select distinct case when m.da_utente = io.id then m.a_utente else m.da_utente end
      from public.messaggio m, io
     where io.id in (m.da_utente, m.a_utente)
  ),
  conversazioni as (
    select a.altro, privato.conversazione_per(io.id, a.altro) as stato,
           privato.visibili_dal(io.id, a.altro) as dal_quando, io.id as io
      from altri a, io
  ),
  righe as (
    select c.altro, c.stato,
           (select u.nome from public.utente u
             where u.id = c.altro and u.eliminato_il is null) as nome,
           (select k.risposto_il from privato.collegamento_fra(c.io, c.altro) k
             where k.stato = 'accettato') as collegati_dal,
           (select m from public.messaggio m
             where least(m.da_utente, m.a_utente) = least(c.io, c.altro)
               and greatest(m.da_utente, m.a_utente) = greatest(c.io, c.altro)
               and m.scritto_il > c.dal_quando
             order by m.scritto_il desc, m.id desc
             limit 1) as ultimo,
           (select count(*) from public.messaggio m
             where m.a_utente = c.io and m.da_utente = c.altro and m.letto_il is null
               and m.scritto_il > c.dal_quando) as da_leggere,
           c.io
      from conversazioni c
     where c.stato is not null
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'utente_id', r.altro,
           'nome', r.nome,
           'collegati', r.stato = 'collegati',
           'dal', r.collegati_dal,
           'ultimo', case when (r.ultimo).id is not null
                          then privato.messaggio_per(r.io, r.ultimo) end,
           'da_leggere', r.da_leggere)
           order by coalesce((r.ultimo).scritto_il, r.collegati_dal) desc), '[]'::jsonb)
    from righe r;
$$;

revoke execute on function public.scrivi(uuid, uuid, text) from public, anon;
revoke execute on function public.conversazione(uuid, timestamptz) from public, anon;
revoke execute on function public.i_miei_messaggi() from public, anon;
grant execute on function public.scrivi(uuid, uuid, text) to authenticated;
grant execute on function public.conversazione(uuid, timestamptz) to authenticated;
grant execute on function public.i_miei_messaggi() to authenticated;

-- ─── Il profilo di un altro dice a che punto siete ────────────────────────

-- Come in profilo_pubblico.sql, più `collegamento` (tela, 73, 112 e 113):
-- null se non c'è niente fra voi, o se la tua richiesta l'ha rifiutata chi
-- guarda; altrimenti 'collegati', 'inviata', 'ricevuta' (con il messaggio) o
-- 'non_accettata'.
create or replace function public.profilo_pubblico(p_utente uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_io uuid := (select auth.uid());
  v_c public.collegamento;
begin
  if v_io is null then
    raise exception 'accesso richiesto' using errcode = 'TR401';
  end if;
  if not privato.vede_il_profilo(v_io, p_utente) then
    raise exception 'profilo non trovato' using errcode = 'TR404';
  end if;
  v_c := privato.collegamento_fra(v_io, p_utente);
  return privato.profilo_come_lo_vedono(p_utente) || jsonb_build_object(
    'collegamento', case
      when v_c.id is null then null
      when v_c.stato = 'accettato' then
        jsonb_build_object('stato', 'collegati', 'dal', v_c.risposto_il)
      when v_c.stato = 'richiesto' and v_c.da_utente = v_io then
        jsonb_build_object('stato', 'inviata', 'dal', v_c.chiesto_il)
      when v_c.stato = 'richiesto' then
        jsonb_build_object('stato', 'ricevuta', 'dal', v_c.chiesto_il,
                           'messaggio', v_c.messaggio)
      when v_c.da_utente = v_io then
        jsonb_build_object('stato', 'non_accettata', 'dal', v_c.chiesto_il)
    end);
end;
$$;

-- ─── Segnalare un messaggio, e toglierlo ──────────────────────────────────

-- Come in sicurezza.sql, più i messaggi (12, regola 1): si segnala un
-- messaggio ricevuto in una conversazione che si vede. La fotografia tiene il
-- testo, chi l'ha scritto e quando; chi è segnalato è chi l'ha scritto. Di un
-- profilo che ha chiesto di collegarsi, la fotografia tiene anche il messaggio
-- della richiesta ancora in attesa: le molestie possono arrivare da lì, e
-- rifiutando quel messaggio si cancella.
create or replace function public.segnala(
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
  v_messaggio public.messaggio;
  v_contenuto jsonb;
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

  if p_tipo = 'profilo' then
    -- Un profilo si segnala se è, o è stato, nella parte pubblica: chi ha
    -- accettato le condizioni d'uso. Spegnere il profilo non fa sfuggire.
    select * into v_segnalato from public.utente
     where id = p_oggetto and id <> v_io and eliminato_il is null
       and condizioni_accettate_il is not null;
    if not found then
      raise exception 'profilo non trovato' using errcode = 'TR404';
    end if;
    v_contenuto := jsonb_build_object(
      'nome', v_segnalato.nome,
      'profilo_pubblico_attivo', v_segnalato.profilo_pubblico_attivo,
      'richiesta', (select c.messaggio from public.collegamento c
                     where c.da_utente = v_segnalato.id and c.a_utente = v_io
                       and c.stato = 'richiesto'),
      'preso_il', now());
  elsif p_tipo = 'messaggio' then
    -- Un messaggio ricevuto, non ancora tolto, in una conversazione che chi
    -- segnala vede.
    select * into v_messaggio from public.messaggio
     where id = p_oggetto and a_utente = v_io and tolto_il is null
       and scritto_il > privato.visibili_dal(v_io, da_utente);
    if not found or privato.conversazione_per(v_io, v_messaggio.da_utente) is null then
      raise exception 'messaggio non trovato' using errcode = 'TR404';
    end if;
    select * into v_segnalato from public.utente where id = v_messaggio.da_utente;
    v_contenuto := jsonb_build_object(
      'nome', v_segnalato.nome,
      'testo', v_messaggio.testo,
      'scritto_il', v_messaggio.scritto_il,
      'preso_il', now());
  else
    raise exception 'si segnala un profilo o un messaggio' using errcode = '22023';
  end if;

  if (select count(*) from public.segnalazione
       where da_utente = v_io and creata_il > now() - interval '1 day') >= 20 then
    raise exception 'troppe segnalazioni oggi' using errcode = 'TR429';
  end if;

  insert into public.segnalazione
    (id, da_utente, a_utente, tipo_oggetto, oggetto_id, motivo, nota, contenuto, misurata)
  values
    (p_id, v_io, v_segnalato.id, p_tipo, p_oggetto, p_motivo, v_nota, v_contenuto,
     coalesce(p_misurazione, false) and not v_interno);

  if p_blocca and v_segnalato.eliminato_il is null then
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
            jsonb_build_object('tipo', p_tipo, 'motivo', p_motivo), now());
  end if;
end;
$$;

-- La terza azione (05; docs/sicurezza/moderazione.md): togliere il messaggio
-- segnalato. Le due persone vedono «Messaggio tolto da chi modera»; il testo
-- resta solo nella fotografia della segnalazione. Si chiudono così tutte le
-- segnalazioni aperte su quel messaggio. Dice quante.
create function moderazione.togli(p_segnalazione uuid, p_nota text default null)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_oggetto uuid;
  v_s uuid;
  v_n integer := 0;
begin
  select oggetto_id into v_oggetto from public.segnalazione
   where id = p_segnalazione and stato = 'ricevuta' and tipo_oggetto = 'messaggio';
  if not found then
    raise exception 'nessuna segnalazione aperta su un messaggio con questo id';
  end if;
  update public.messaggio set testo = null, tolto_il = now()
   where id = v_oggetto and tolto_il is null;
  for v_s in
    select id from public.segnalazione
     where tipo_oggetto = 'messaggio' and oggetto_id = v_oggetto and stato = 'ricevuta'
     order by creata_il
  loop
    perform privato.segna_gestita(v_s, 'contenuto_rimosso', p_nota);
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;

revoke execute on function moderazione.togli(uuid, text) from public;

-- ─── I tuoi dati ──────────────────────────────────────────────────────────

-- I collegamenti e i messaggi di chi chiama, tutti, anche con chi oggi non si
-- vede: per i_miei_dati, che li legge con i diritti della persona.
create function public.la_mia_corrispondenza()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with io as (select (select auth.uid()) as id)
  select jsonb_build_object(
    'collegamenti', coalesce((
      select jsonb_agg(jsonb_build_object(
               'con', case when c.da_utente = io.id then c.a_utente else c.da_utente end,
               'nome', u.nome,
               'stato', c.stato,
               'chiesto_da_me', c.da_utente = io.id,
               'messaggio', c.messaggio,
               'chiesto_il', c.chiesto_il,
               'risposto_il', c.risposto_il) order by c.chiesto_il)
        from public.collegamento c
        join public.utente u
          on u.id = case when c.da_utente = io.id then c.a_utente else c.da_utente end
       where io.id in (c.da_utente, c.a_utente)), '[]'::jsonb),
    'messaggi', coalesce((
      select jsonb_agg(jsonb_build_object(
               'con', case when m.da_utente = io.id then m.a_utente else m.da_utente end,
               'nome', u.nome,
               'da_me', m.da_utente = io.id,
               'testo', m.testo,
               'scritto_il', m.scritto_il,
               'tolto', m.tolto_il is not null) order by m.scritto_il)
        from public.messaggio m
        join public.utente u
          on u.id = case when m.da_utente = io.id then m.a_utente else m.da_utente end
       where io.id in (m.da_utente, m.a_utente)
         and m.scritto_il > privato.visibili_dal(io.id,
               case when m.da_utente = io.id then m.a_utente else m.da_utente end)),
      '[]'::jsonb))
  from io;
$$;

revoke execute on function public.la_mia_corrispondenza() from public, anon;
grant execute on function public.la_mia_corrispondenza() to authenticated;

-- Come in profilo_pubblico.sql, versione 4: più collegamenti e messaggi.
create or replace function public.i_miei_dati()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'formato', 'trolley.dati',
    'versione', 4,
    'esportato_il', now(),
    'email', (select auth.jwt() ->> 'email'),
    'profilo', (select to_jsonb(u) from public.mio_profilo() u),
    'telefono', public.la_mia_parte_pubblica() ->> 'telefono',
    'profilo_pubblico', public.il_mio_profilo_pubblico(),
    'corrispondenza', public.la_mia_corrispondenza(),
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

-- ─── Chiudere l'account ───────────────────────────────────────────────────

-- Come in sicurezza.sql, più i collegamenti e i messaggi (P6): i collegamenti
-- di chi se ne va spariscono, le conversazioni restano agli altri con
-- «Account chiuso»; dove c'era un blocco, in un verso o nell'altro, non resta
-- a nessuno: chi aveva bloccato non deve ritrovarsela.
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
  v_altro uuid;
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

    -- I collegamenti e i messaggi (5.4): prima dei blocchi, che servono qui.
    delete from public.collegamento where v_io in (da_utente, a_utente);
    for v_altro in
      select distinct case when m.da_utente = v_io then m.a_utente else m.da_utente end
        from public.messaggio m
       where v_io in (m.da_utente, m.a_utente)
    loop
      if privato.si_bloccano(v_io, v_altro) then
        insert into privato.conversazione_tolta (utente_id, altro_id, fino_al)
        values (v_altro, v_io, clock_timestamp())
        on conflict (utente_id, altro_id) do update set fino_al = excluded.fino_al;
      end if;
      perform privato.togli_conversazione(v_io, v_altro);
    end loop;

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
