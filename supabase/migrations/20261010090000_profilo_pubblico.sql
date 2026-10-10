-- Il profilo pubblico e la ricerca (5.3; 11-community, 05-community-e-
-- sicurezza; tela, 73–75 e 108–110). Si appoggia all'impianto della 5.1
-- (sicurezza.sql) e segue le scelte delle valutazioni d'impatto (5.2,
-- docs/legale/valutazione-impatto-parte-pubblica.md):
--
-- - Chi guarda si fa guardare (M1): i profili degli altri e la ricerca si
--   vedono solo con il proprio profilo pubblico acceso, e mai fra due persone
--   che si bloccano. Lo dice una funzione sola, privato.vede_il_profilo.
-- - Niente ricerca per nome (M2): si cerca per meta e per gusti, al più trenta
--   risultati, con un tetto di ricerche al giorno. I criteri viaggiano nel
--   corpo della richiesta, non nell'indirizzo che finisce nei registri.
-- - Sul profilo solo i viaggi chiusi e finiti (M4), che la persona non ha
--   nascosto (M3); di ciascuno la meta, il mese, i giorni, se è verificato o
--   importato (M5). Mai le date precise, mai chi c'era.
-- - I gusti sono una lista chiusa (M6): li controlla anche il server, perché
--   un testo libero sarebbe una biografia.
--
-- Il profilo di un altro e i risultati non si conservano sul telefono: la
-- parte pubblica si guarda com'è adesso, con la rete.

-- ─── I gusti ──────────────────────────────────────────────────────────────

-- Cosa piace in viaggio: le voci dell'itinerario (dominio/itinerario.dart,
-- Interesse), con il nome che hanno qui. Una voce nuova si aggiunge in tutti
-- e due i posti, e solo se non dice una religione, la salute, l'orientamento
-- o la politica (M6).
alter table public.utente
  add column gusti text[] not null default '{}',
  add constraint gusti_dalla_lista check (
    gusti <@ array['arte', 'cibo', 'storia', 'natura', 'panorami', 'shopping',
                   'vita_notturna']::text[]);

-- Gli altri non li leggono dalla tabella (profilo_altrui_solo_nome.sql: solo
-- id, nome, versione, eliminato_il), e non si scrivono a mano: scegli_gusti.

-- Sceglie i gusti di chi chiama: quelli della lista, una volta ciascuno,
-- nell'ordine della lista. Si possono scegliere anche a profilo spento.
create function public.scegli_gusti(p_gusti text[])
returns text[]
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_io uuid := (select auth.uid());
  v_lista constant text[] := array['arte', 'cibo', 'storia', 'natura', 'panorami',
                                   'shopping', 'vita_notturna'];
  v_gusti text[];
begin
  if v_io is null then
    raise exception 'accesso richiesto' using errcode = 'TR401';
  end if;
  if not coalesce(p_gusti, '{}') <@ v_lista then
    raise exception 'gusto sconosciuto' using errcode = '22023';
  end if;
  select coalesce(array_agg(g order by i), '{}') into v_gusti
    from unnest(v_lista) with ordinality as l(g, i)
   where g = any (coalesce(p_gusti, '{}'));
  update public.utente set gusti = v_gusti
   where id = v_io and eliminato_il is null;
  if not found then
    raise exception 'profilo mancante' using errcode = 'TR403';
  end if;
  return v_gusti;
end;
$$;

revoke execute on function public.scegli_gusti(text[]) from public, anon;
grant execute on function public.scegli_gusti(text[]) to authenticated;

-- ─── I viaggi sul profilo ─────────────────────────────────────────────────

-- I viaggi che una persona ha tolto dal suo profilo pubblico (M3). Sta nello
-- schema privato: non lo legge nessuno, nemmeno i compagni di quel viaggio.
create table privato.fuori_dal_profilo (
  utente_id uuid not null references public.utente (id) on delete cascade,
  viaggio_id uuid not null references public.viaggio (id) on delete cascade,
  primary key (utente_id, viaggio_id)
);

revoke all on privato.fuori_dal_profilo from public, anon, authenticated;

-- I viaggi che possono stare sul profilo di [p_utente]: chiusi, suoi (ci
-- partecipa ancora), e finiti — un viaggio chiuso a mano prima della fine
-- compare dopo la fine (M4; 11, regola 2). Gli importati sono passati per
-- costruzione. Di ciascuno solo quello che il profilo mostra: la meta, il
-- primo giorno del mese in cui è cominciato (mai le date), quanti giorni, il
-- periodo di un importato, se è verificato per questa persona. `sul_profilo`
-- dice se la persona l'ha lasciato visibile.
create function privato.viaggi_del_profilo(p_utente uuid)
returns table (
  viaggio_id uuid,
  citta text,
  paese text,
  mese date,
  periodo text,
  giorni integer,
  verificato boolean,
  importato boolean,
  sul_profilo boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select v.id,
         v.destinazione_citta,
         v.destinazione_paese,
         date_trunc('month', v.data_inizio)::date,
         case when v.importato then v.periodo_approssimativo end,
         case when v.importato then v.giorni_ricordati::integer
              else (v.data_fine - v.data_inizio) + 1 end,
         coalesce(p.verificato, false) and not v.importato,
         v.importato,
         not exists (select 1 from privato.fuori_dal_profilo f
                      where f.utente_id = p_utente and f.viaggio_id = v.id)
    from public.partecipazione p
    join public.viaggio v on v.id = p.viaggio_id
   where p.utente_id = p_utente
     and p.stato = 'attivo' and p.eliminato_il is null
     and v.eliminato_il is null and v.stato = 'chiuso'
     and (v.importato or v.data_fine < current_date);
$$;

revoke execute on function privato.viaggi_del_profilo(uuid) from public, anon, authenticated;

-- Mette o toglie [p_viaggio] dal profilo pubblico di chi chiama. Vale per un
-- viaggio di cui è partecipante, anche prima che sia chiuso: la scelta resta.
create function public.mostra_sul_profilo(p_viaggio uuid, p_mostra boolean)
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
  perform 1 from public.partecipazione
   where viaggio_id = p_viaggio and utente_id = v_io
     and stato = 'attivo' and eliminato_il is null;
  if not found then
    raise exception 'non partecipi a questo viaggio' using errcode = 'TR404';
  end if;
  if coalesce(p_mostra, true) then
    delete from privato.fuori_dal_profilo
     where utente_id = v_io and viaggio_id = p_viaggio;
  else
    insert into privato.fuori_dal_profilo (utente_id, viaggio_id)
    values (v_io, p_viaggio)
    on conflict do nothing;
  end if;
end;
$$;

revoke execute on function public.mostra_sul_profilo(uuid, boolean) from public, anon;
grant execute on function public.mostra_sul_profilo(uuid, boolean) to authenticated;

-- ─── Chi vede chi ─────────────────────────────────────────────────────────

-- Se [p_chi] vede il profilo pubblico di [p_di] (05, «Profilo pubblico»):
-- tutti e due con il profilo pubblico acceso e senza sospensione — chi guarda
-- si fa guardare (M1) —, tutti e due dove la parte pubblica c'è (chiusa, solo
-- il team vede il team), e nessuno dei due ha bloccato l'altro.
create function privato.vede_il_profilo(p_chi uuid, p_di uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_chi is not null and p_di is not null and p_chi <> p_di
     and (select count(*) = 2 from public.utente u
           where u.id in (p_chi, p_di)
             and u.profilo_pubblico_attivo and u.sospeso_il is null
             and u.eliminato_il is null)
     and privato.parte_pubblica_visibile(p_chi)
     and privato.parte_pubblica_visibile(p_di)
     and not privato.si_bloccano(p_chi, p_di);
$$;

revoke execute on function privato.vede_il_profilo(uuid, uuid) from public, anon, authenticated;

-- Il profilo di [p_utente] com'è sulla parte pubblica: quello che vedono gli
-- altri, e l'anteprima di «Così ti vedono» (tela, 73 e 75). I viaggi sono
-- solo quelli sul profilo.
create function privato.profilo_come_lo_vedono(p_utente uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', u.id,
    'nome', u.nome,
    'dal', date_trunc('month', u.creato_il)::date,
    'gusti', to_jsonb(u.gusti),
    'traguardi', (select count(*) from public.traguardo t where t.utente_id = u.id),
    'viaggi', coalesce((
      select jsonb_agg(jsonb_build_object(
               'citta', v.citta, 'paese', v.paese, 'mese', v.mese,
               'periodo', v.periodo, 'giorni', v.giorni,
               'verificato', v.verificato, 'importato', v.importato))
        from privato.viaggi_del_profilo(u.id) v
       where v.sul_profilo), '[]'::jsonb))
  from public.utente u
  where u.id = p_utente and u.eliminato_il is null;
$$;

revoke execute on function privato.profilo_come_lo_vedono(uuid) from public, anon, authenticated;

-- Il profilo pubblico di [p_utente], per chi chiama. Se non lo può vedere —
-- spento, sospeso, bloccato, o chi chiama ha il suo spento — la risposta è la
-- stessa: non c'è. Non si distingue un blocco da un profilo spento.
create function public.profilo_pubblico(p_utente uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_io uuid := (select auth.uid());
begin
  if v_io is null then
    raise exception 'accesso richiesto' using errcode = 'TR401';
  end if;
  if not privato.vede_il_profilo(v_io, p_utente) then
    raise exception 'profilo non trovato' using errcode = 'TR404';
  end if;
  return privato.profilo_come_lo_vedono(p_utente);
end;
$$;

-- Il proprio profilo pubblico (tela, 75 e 109): com'è per gli altri, più
-- tutti i viaggi che ci possono stare, ciascuno con la sua scelta. Anche a
-- profilo spento: si sceglie prima di accendere (105).
create function public.il_mio_profilo_pubblico()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select privato.profilo_come_lo_vedono(u.id) || jsonb_build_object(
    'attivo', u.profilo_pubblico_attivo,
    'tutti_i_viaggi', coalesce((
      select jsonb_agg(jsonb_build_object(
               'viaggio_id', v.viaggio_id,
               'citta', v.citta, 'paese', v.paese, 'mese', v.mese,
               'periodo', v.periodo, 'giorni', v.giorni,
               'verificato', v.verificato, 'importato', v.importato,
               'sul_profilo', v.sul_profilo))
        from privato.viaggi_del_profilo(u.id) v), '[]'::jsonb))
  from public.utente u
  where u.id = (select auth.uid()) and u.eliminato_il is null;
$$;

revoke execute on function public.profilo_pubblico(uuid) from public, anon;
revoke execute on function public.il_mio_profilo_pubblico() from public, anon;
grant execute on function public.profilo_pubblico(uuid) to authenticated;
grant execute on function public.il_mio_profilo_pubblico() to authenticated;

-- ─── Cercare ──────────────────────────────────────────────────────────────

-- Ricerche al giorno per persona: abbastanza per cercare davvero, troppo
-- poche per scorrere tutti i profili (M2).
insert into public.configurazione (chiave, valore) values ('tetto_ricerca', '60')
on conflict (chiave) do nothing;

-- Quante ricerche ha fatto oggi una persona. Quante, mai che cosa.
create table privato.ricerca_viaggiatori (
  utente_id uuid not null references public.utente (id) on delete cascade,
  giorno date not null default current_date,
  quante integer not null default 0,
  primary key (utente_id, giorno)
);

revoke all on privato.ricerca_viaggiatori from public, anon, authenticated;

-- Cerca viaggiatori per meta — un paese, o una città di quel paese — e per
-- gusti (tela, 74). Serve almeno uno dei due: senza, non si vede nessuno (M2).
-- Chi cerca deve avere il profilo pubblico acceso (M1). Al più trenta, prima
-- chi ha più gusti fra quelli cercati, poi chi ha viaggiato più di recente
-- nella meta. Di ciascuno il profilo com'è sulla parte pubblica: cosa avete
-- in comune lo calcola il telefono di chi cerca.
--
-- Ogni ricerca legge i viaggi di ogni profilo acceso: con le persone della
-- beta va bene, con molte di più servirà un indice delle mete pubbliche.
create function public.cerca_viaggiatori(
  p_paese text default null,
  p_citta text default null,
  p_gusti text[] default '{}'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_io uuid := (select auth.uid());
  v_gusti text[] := coalesce(p_gusti, '{}');
  v_paese text := nullif(upper(trim(coalesce(p_paese, ''))), '');
  v_citta text := nullif(lower(trim(coalesce(p_citta, ''))), '');
  v_tetto integer;
  v_quante integer;
begin
  if v_io is null then
    raise exception 'accesso richiesto' using errcode = 'TR401';
  end if;
  if not exists (select 1 from public.utente
                  where id = v_io and profilo_pubblico_attivo and sospeso_il is null
                    and eliminato_il is null)
     or not privato.parte_pubblica_visibile(v_io) then
    raise exception 'serve il profilo pubblico acceso' using errcode = 'TR403';
  end if;
  if not v_gusti <@ array['arte', 'cibo', 'storia', 'natura', 'panorami', 'shopping',
                          'vita_notturna']::text[] then
    raise exception 'gusto sconosciuto' using errcode = '22023';
  end if;
  if v_citta is not null and v_paese is null then
    raise exception 'una città si cerca con il suo paese' using errcode = '22023';
  end if;
  if v_paese is null and cardinality(v_gusti) = 0 then
    raise exception 'serve una meta o un gusto' using errcode = '22023';
  end if;

  v_tetto := coalesce(
    (select (valore #>> '{}')::integer from public.configurazione
      where chiave = 'tetto_ricerca'), 60);
  insert into privato.ricerca_viaggiatori as r (utente_id, giorno, quante)
  values (v_io, current_date, 1)
  on conflict (utente_id, giorno) do update set quante = r.quante + 1
  returning quante into v_quante;
  if v_quante > v_tetto then
    raise exception 'troppe ricerche oggi' using errcode = 'TR429';
  end if;

  return coalesce((
    select jsonb_agg(privato.profilo_come_lo_vedono(t.id) order by t.comuni desc, t.recente desc nulls last, t.nome)
      from (
        select u.id, u.nome,
               cardinality(array(select unnest(u.gusti) intersect select unnest(v_gusti))) as comuni,
               (select max(coalesce(v.mese, '0001-01-01'::date))
                  from privato.viaggi_del_profilo(u.id) v
                 where v.sul_profilo and v.paese = v_paese
                   and (v_citta is null or lower(trim(v.citta)) = v_citta)) as recente
          from public.utente u
         where u.id <> v_io
           and privato.vede_il_profilo(v_io, u.id)
           and (cardinality(v_gusti) = 0 or u.gusti && v_gusti)
           and (v_paese is null or exists (
                 select 1 from privato.viaggi_del_profilo(u.id) v
                  where v.sul_profilo and v.paese = v_paese
                    and (v_citta is null or lower(trim(v.citta)) = v_citta)))
         order by comuni desc, recente desc nulls last, u.nome
         limit 30
      ) t), '[]'::jsonb);
end;
$$;

revoke execute on function public.cerca_viaggiatori(text, text, text[]) from public, anon;
grant execute on function public.cerca_viaggiatori(text, text, text[]) to authenticated;

-- Il conto serve solo a sapere se oggi si è sotto il tetto.
select cron.schedule(
  'pulisci-ricerca-viaggiatori',
  '17 3 * * *',
  $$delete from privato.ricerca_viaggiatori where giorno < current_date - 7$$
);

-- ─── I tuoi dati e la lapide ──────────────────────────────────────────────

-- I gusti arrivano già con il profilo (to_jsonb di mio_profilo). Le scelte dei
-- viaggi sul profilo stanno nello schema privato: le dice il_mio_profilo_
-- pubblico, che i_miei_dati include da qui in poi.
create or replace function public.i_miei_dati()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'formato', 'trolley.dati',
    'versione', 3,
    'esportato_il', now(),
    'email', (select auth.jwt() ->> 'email'),
    'profilo', (select to_jsonb(u) from public.mio_profilo() u),
    'telefono', public.la_mia_parte_pubblica() ->> 'telefono',
    'profilo_pubblico', public.il_mio_profilo_pubblico(),
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

-- Chi chiude l'account (chiudi_account) lascia una lapide senza dati
-- personali: niente gusti, e nessuna scelta sui viaggi del profilo. Lo fa
-- un trigger, così vale qualunque strada scriva eliminato_il.
create function privato.lapide_senza_parte_pubblica()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.gusti := '{}';
  delete from privato.fuori_dal_profilo where utente_id = new.id;
  delete from privato.ricerca_viaggiatori where utente_id = new.id;
  return new;
end;
$$;

revoke execute on function privato.lapide_senza_parte_pubblica() from public, anon, authenticated;

create trigger utente_lapide_senza_parte_pubblica
  before update of eliminato_il on public.utente
  for each row
  when (old.eliminato_il is null and new.eliminato_il is not null)
  execute function privato.lapide_senza_parte_pubblica();
