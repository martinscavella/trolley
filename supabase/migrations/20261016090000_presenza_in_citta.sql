-- Chi c'è in città (5.5; 11-community, regole 8–13; 05-community-e-sicurezza,
-- «Presenza in città»; tela, 79–81, 117 e 118). Si appoggia alla 5.3
-- (profilo_pubblico.sql: vede_il_profilo) e alla 3.4 (sul_posto.sql), e segue
-- la valutazione d'impatto della 5.2
-- (docs/legale/valutazione-impatto-presenza-in-citta.md):
--
-- - La città è la meta del viaggio, mai la posizione del telefono. Nessuna
--   coordinata, nessuna distanza, nessuno storico: la riga sparisce con il
--   viaggio.
-- - C1: si accende solo con il «sul posto» del telefono per quel viaggio
--   (partecipazione.sul_posto_il). Al server non arriva niente di nuovo.
-- - C2: fino a quando lo legge solo la persona. Gli altri vedono chi c'è.
-- - C4: cambiare la meta o le date, chiudere il viaggio, uscirne, spegnere il
--   profilo pubblico la spengono; la lettura esclude da sé le righe scadute.
-- - C5: si legge solo da una funzione, che non prende la città: la sa dalla
--   presenza di chi chiama. Niente città negli indirizzi né negli eventi.
-- - C7: una presenza alla volta per persona.
-- - C8: nessun «da quando», e in ordine di nome.
-- - Si vede solo chi l'ha accesa a sua volta (11, regola 11), con le regole
--   della parte pubblica: profilo acceso, nessun blocco, M1.

create table public.presenza_citta (
  -- C7: la chiave è la persona.
  utente_id uuid primary key references public.utente (id) on delete cascade,
  viaggio_id uuid not null references public.viaggio (id) on delete cascade,
  citta text not null,
  paese char(2) not null,
  -- L'ultimo giorno del viaggio: la legge solo la persona (C2).
  attiva_fino date not null
);

create index presenza_citta_luogo on public.presenza_citta (paese, lower(citta));
create index presenza_citta_viaggio on public.presenza_citta (viaggio_id);

alter table public.presenza_citta enable row level security;
revoke all on public.presenza_citta from anon, authenticated;

-- ─── Quando vale ──────────────────────────────────────────────────────────

-- Se la presenza [p] vale adesso: non scaduta, e chi l'ha accesa è ancora
-- nel viaggio. Il resto (meta, date, stato) lo garantiscono i trigger qui
-- sotto, che la tolgono quando cambiano.
create function privato.presenza_vale(p public.presenza_citta)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p.attiva_fino >= (now() at time zone 'utc')::date
     and exists (select 1 from public.partecipazione x
                  where x.viaggio_id = p.viaggio_id and x.utente_id = p.utente_id
                    and x.stato = 'attivo' and x.eliminato_il is null);
$$;

revoke execute on function privato.presenza_vale(public.presenza_citta) from public, anon, authenticated;

-- ─── Accendere, spegnere ──────────────────────────────────────────────────

-- Accende la presenza per [p_viaggio] (tela, 79): con il profilo pubblico,
-- per un viaggio in corso con una città, e dopo il «sul posto» (C1). Se ce
-- n'era un'altra, la sostituisce (C7). Restituisce la propria presenza.
create function public.accendi_presenza(p_viaggio uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_io uuid := (select auth.uid());
  v_oggi date := (now() at time zone 'utc')::date;
  v_viaggio public.viaggio;
  v_sul_posto timestamptz;
begin
  if v_io is null then
    raise exception 'accesso richiesto' using errcode = 'TR401';
  end if;
  if not privato.nella_parte_pubblica(v_io) then
    raise exception 'serve il profilo pubblico acceso' using errcode = 'TR403';
  end if;
  select x.sul_posto_il into v_sul_posto
    from public.partecipazione x
   where x.viaggio_id = p_viaggio and x.utente_id = v_io
     and x.stato = 'attivo' and x.eliminato_il is null;
  if not found then
    raise exception 'non partecipi a questo viaggio' using errcode = 'TR404';
  end if;
  -- Come segna_sul_posto, con un giorno di margine all'inizio per i fusi
  -- orari; alla fine no: dopo l'ultimo giorno non si accende più.
  select * into v_viaggio from public.viaggio
   where id = p_viaggio and eliminato_il is null and not importato
     and stato in ('definito', 'in_corso')
     and v_oggi between data_inizio - 1 and data_fine
     and destinazione_citta is not null and destinazione_paese is not null;
  if not found then
    raise exception 'il viaggio non è in corso, o non ha una città' using errcode = 'TR422';
  end if;
  if v_sul_posto is null then
    raise exception 'il telefono non ti ha ancora trovato sul posto' using errcode = 'TR425';
  end if;

  insert into public.presenza_citta (utente_id, viaggio_id, citta, paese, attiva_fino)
  values (v_io, p_viaggio, v_viaggio.destinazione_citta, v_viaggio.destinazione_paese,
          v_viaggio.data_fine)
  on conflict (utente_id) do update
    set viaggio_id = excluded.viaggio_id, citta = excluded.citta,
        paese = excluded.paese, attiva_fino = excluded.attiva_fino;

  return jsonb_build_object(
    'viaggio_id', p_viaggio,
    'citta', v_viaggio.destinazione_citta,
    'paese', v_viaggio.destinazione_paese,
    'fino', v_viaggio.data_fine);
end;
$$;

-- Spegne la propria presenza: la riga sparisce.
create function public.spegni_presenza()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.presenza_citta where utente_id = (select auth.uid());
$$;

revoke execute on function public.accendi_presenza(uuid) from public, anon;
revoke execute on function public.spegni_presenza() from public, anon;
grant execute on function public.accendi_presenza(uuid) to authenticated;
grant execute on function public.spegni_presenza() to authenticated;

-- ─── Chi c'è ──────────────────────────────────────────────────────────────

-- La propria presenza, se vale, e chi altro c'è nella stessa città (tela, 80
-- e 81): solo chi l'ha accesa a sua volta e si vede con chi chiama, in ordine
-- di nome (C8), al più cento. Di ciascuno il profilo pubblico e a che punto
-- si è; mai fino a quando resta (C2). Senza la propria presenza, nessuno:
-- chi guarda è visto (11, regola 11).
create function public.chi_ce_in_citta()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with io as (select (select auth.uid()) as id),
  mia as (
    select p.* from public.presenza_citta p, io
     where p.utente_id = io.id and privato.presenza_vale(p)
       and privato.nella_parte_pubblica(io.id)
  ),
  altri as (
    select p.utente_id, u.nome
      from mia m
      join public.presenza_citta p
        on p.paese = m.paese and lower(p.citta) = lower(m.citta)
       and p.utente_id <> m.utente_id
      join public.utente u on u.id = p.utente_id
     where privato.presenza_vale(p)
       and privato.vede_il_profilo(m.utente_id, p.utente_id)
     order by u.nome, p.utente_id
     limit 100
  )
  select jsonb_build_object(
    'mia', (select jsonb_build_object('viaggio_id', m.viaggio_id, 'citta', m.citta,
                                      'paese', m.paese, 'fino', m.attiva_fino)
              from mia m),
    'altri', coalesce((
      select jsonb_agg(
               privato.profilo_come_lo_vedono(a.utente_id) || jsonb_build_object(
                 'collegamento', (
                   select case
                     when c.id is null then null
                     when c.stato = 'accettato' then jsonb_build_object('stato', 'collegati')
                     when c.stato = 'richiesto' and c.da_utente = io.id
                       then jsonb_build_object('stato', 'inviata')
                     when c.stato = 'richiesto' then jsonb_build_object('stato', 'ricevuta')
                     when c.da_utente = io.id then jsonb_build_object('stato', 'non_accettata')
                   end
                   from privato.collegamento_fra(io.id, a.utente_id) c))
               order by a.nome, a.utente_id)
        from altri a, io), '[]'::jsonb));
$$;

revoke execute on function public.chi_ce_in_citta() from public, anon;
grant execute on function public.chi_ce_in_citta() to authenticated;

-- ─── Quando si spegne da sola (C4) ────────────────────────────────────────

-- Cambiare la meta o le date, chiudere, archiviare o cancellare il viaggio.
create function privato.spegni_presenze_del_viaggio()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (old.destinazione_citta, old.destinazione_paese, old.data_inizio, old.data_fine)
       is distinct from
     (new.destinazione_citta, new.destinazione_paese, new.data_inizio, new.data_fine)
     or new.stato not in ('definito', 'in_corso')
     or new.eliminato_il is not null then
    delete from public.presenza_citta where viaggio_id = new.id;
  end if;
  return new;
end;
$$;

revoke execute on function privato.spegni_presenze_del_viaggio() from public, anon, authenticated;

create trigger viaggio_spegne_presenze
  after update on public.viaggio
  for each row execute function privato.spegni_presenze_del_viaggio();

-- Uscire dal viaggio, o esserne tolti.
create function privato.spegni_presenza_di_chi_esce()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.stato <> 'attivo' or new.eliminato_il is not null then
    delete from public.presenza_citta
     where utente_id = new.utente_id and viaggio_id = new.viaggio_id;
  end if;
  return new;
end;
$$;

revoke execute on function privato.spegni_presenza_di_chi_esce() from public, anon, authenticated;

create trigger partecipazione_spegne_presenza
  after update on public.partecipazione
  for each row execute function privato.spegni_presenza_di_chi_esce();

-- Spegnere il profilo pubblico, essere sospesi, chiudere l'account.
create function privato.spegni_presenza_senza_profilo()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not new.profilo_pubblico_attivo or new.sospeso_il is not null
     or new.eliminato_il is not null then
    delete from public.presenza_citta where utente_id = new.id;
  end if;
  return new;
end;
$$;

revoke execute on function privato.spegni_presenza_senza_profilo() from public, anon, authenticated;

create trigger utente_spegne_presenza
  after update on public.utente
  for each row execute function privato.spegni_presenza_senza_profilo();

-- Le righe scadute non si leggono già (presenza_vale); qui spariscono (11,
-- regola 10). Ogni ora: non resta una riga oltre il giorno dopo la fine.
select cron.schedule(
  'pulisci-presenze-scadute',
  '23 * * * *',
  $$delete from public.presenza_citta where attiva_fino < (now() at time zone 'utc')::date$$
);

-- ─── I tuoi dati ──────────────────────────────────────────────────────────

-- La propria presenza, se c'è: per i_miei_dati, che li legge con i diritti
-- della persona.
create function public.la_mia_presenza()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('viaggio_id', p.viaggio_id, 'citta', p.citta,
                            'paese', p.paese, 'fino', p.attiva_fino)
    from public.presenza_citta p
   where p.utente_id = (select auth.uid());
$$;

revoke execute on function public.la_mia_presenza() from public, anon;
grant execute on function public.la_mia_presenza() to authenticated;

-- Come in collegamenti_e_messaggi.sql, versione 5: più la presenza in città.
create or replace function public.i_miei_dati()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'formato', 'trolley.dati',
    'versione', 5,
    'esportato_il', now(),
    'email', (select auth.jwt() ->> 'email'),
    'profilo', (select to_jsonb(u) from public.mio_profilo() u),
    'telefono', public.la_mia_parte_pubblica() ->> 'telefono',
    'profilo_pubblico', public.il_mio_profilo_pubblico(),
    'corrispondenza', public.la_mia_corrispondenza(),
    'presenza_in_citta', public.la_mia_presenza(),
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
