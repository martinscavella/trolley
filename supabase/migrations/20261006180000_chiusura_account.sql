-- I tuoi dati e chiudere l'account (U.1, prima dell'ondata 1; 06-privacy,
-- «Diritti delle persone» e «Conservazione»; 01-account-e-profilo, casi limite).
--
-- - Scaricarli: i_miei_dati() mette in un JSON solo il profilo, i viaggi come
--   la persona li vede, i suoi traguardi e i suoi eventi. Con l'accesso di chi
--   chiama: le regole di accesso decidono che cosa c'è, come nell'app.
-- - Chiudere: chiudi_account() cancella i viaggi in cui si è da soli, esce da
--   quelli con altri (il ruolo passa a chi è entrato per primo dopo), toglie
--   ciò che è solo suo, cancella l'accesso. Il profilo resta come lapide senza
--   dati personali: i contributi nei viaggi altrui restano, attribuiti a un
--   partecipante non più presente, e le spese restano nei saldi.
-- - Gli eventi di chi chiude restano per le soglie, ma con un id nuovo che non
--   porta al profilo. Quelli di un account interno si cancellano: non contano
--   comunque.

-- ─── La lapide ────────────────────────────────────────────────────────────

-- Il profilo non dipende più dall'accesso: cancellando l'accesso resta, vuoto.
alter table public.utente drop constraint utente_id_fkey;

alter table public.utente alter column nome drop not null;
alter table public.utente alter column data_nascita drop not null;
alter table public.utente drop constraint utente_nome_check;
alter table public.utente add constraint utente_nome_o_lapide check (
  (eliminato_il is null and data_nascita is not null
   and nome is not null and length(trim(nome)) > 0)
  or (eliminato_il is not null and nome is null and data_nascita is null)
);

-- Chiudere l'account passa solo da chiudi_account: scrivere eliminato_il a mano
-- lascerebbe un accesso vivo con un profilo morto.
revoke update (eliminato_il) on public.utente from authenticated;

-- Gli eventi non dipendono dal profilo: quelli di chi chiude cambiano id.
alter table public.evento drop constraint evento_utente_id_fkey;

-- I propri eventi si leggono (fino a qui solo l'id, per rimandarli senza
-- duplicarli): stanno nei dati che si scaricano. La regola di lettura c'è già
-- («si riconoscono solo i propri eventi»).
grant select (utente_id, nome, proprieta, avvenuto_il, ricevuto_il, versione_app)
  on public.evento to authenticated;

-- ─── Scaricare i propri dati ──────────────────────────────────────────────

create function public.i_miei_dati()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'formato', 'trolley.dati',
    'versione', 1,
    'esportato_il', now(),
    'email', (select auth.jwt() ->> 'email'),
    'profilo', (select to_jsonb(u) from public.mio_profilo() u),
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
    'eventi', coalesce((
      select jsonb_agg(jsonb_build_object(
        'nome', e.nome, 'proprieta', e.proprieta,
        'avvenuto_il', e.avvenuto_il, 'versione_app', e.versione_app)
        order by e.avvenuto_il)
        from public.evento e
       where e.utente_id = (select auth.uid())), '[]'::jsonb)
  );
$$;

revoke execute on function public.i_miei_dati() from public, anon;
grant execute on function public.i_miei_dati() to authenticated;

-- ─── Chiudere l'account ───────────────────────────────────────────────────

-- Toglie un viaggio e tutto ciò che contiene. Solo per chiudi_account, sui
-- viaggi in cui chi chiude è rimasto da solo.
create function privato.cancella_viaggio(p_viaggio uuid)
returns void
language sql
security invoker
set search_path = ''
as $$
  delete from public.spesa_quota where viaggio_id = p_viaggio;
  delete from public.spesa where viaggio_id = p_viaggio;
  delete from public.tappa where viaggio_id = p_viaggio;
  delete from public.giorno where viaggio_id = p_viaggio;
  delete from public.voce_lista where viaggio_id = p_viaggio;
  delete from public.nota where viaggio_id = p_viaggio;
  delete from public.invito where viaggio_id = p_viaggio;
  delete from public.traguardo where viaggio_id = p_viaggio;
  delete from public.partecipazione where viaggio_id = p_viaggio;
  delete from public.viaggio where id = p_viaggio;
$$;

revoke execute on function privato.cancella_viaggio(uuid) from public, anon, authenticated;

-- Chi chiama chiude il proprio account. [p_misurazione] è la scelta della
-- persona sulla misurazione, che sta sul telefono: se l'ha spenta, la chiusura
-- non lascia nemmeno il suo evento.
create function public.chiudi_account(p_misurazione boolean default true)
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

    update public.utente
       set nome = null,
           data_nascita = null,
           telefono_verificato = false,
           profilo_pubblico_attivo = false,
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

revoke execute on function public.chiudi_account(boolean) from public, anon;
grant execute on function public.chiudi_account(boolean) to authenticated;
