-- Partecipanti, inviti e i poteri di chi è responsabile del viaggio (fase 2.1,
-- 03-partecipanti-e-inviti.md).
--
-- La partecipazione non si scrive mai direttamente dall'app: la cambiano solo
-- queste funzioni, una per gesto, che controllano chi può fare cosa. Il ruolo
-- `creatore` nell'app si chiama «responsabile del viaggio» (decisioni/prodotto.md):
-- all'inizio è chi l'ha creato, ma si può passare. Chi l'ha creato davvero resta
-- in viaggio.creato_da, che non cambia mai.
--
-- - Chiunque esce da solo (regola 7). Il creatore prima passa il ruolo: un
--   viaggio senza creatore non può esistere (casi limite).
-- - Solo il creatore toglie qualcuno (regola 6), e mai se stesso.
-- - Chi esce o viene tolto non perde i suoi contributi (regola 8): le righe
--   restano dove sono, a suo nome, e i compagni continuano a vederne il nome.
-- - Togliere qualcuno ritira i link d'invito ancora validi: quello con cui è
--   entrato potrebbe essere passato di mano (casi limite: il link inoltrato).
--   Per rientrare gli serve un link nuovo di chi è responsabile del viaggio.

-- ─── Uscire ───────────────────────────────────────────────────────────────

create function public.esci_dal_viaggio(p_viaggio uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_io uuid := (select auth.uid());
  v_ruolo text;
begin
  if v_io is null then
    raise exception 'accesso richiesto' using errcode = 'TR401';
  end if;
  select ruolo into v_ruolo
    from public.partecipazione
   where viaggio_id = p_viaggio and utente_id = v_io
     and stato = 'attivo' and eliminato_il is null
   for update;
  if v_ruolo is null then
    raise exception 'non partecipi a questo viaggio' using errcode = 'TR404';
  end if;
  if v_ruolo = 'creatore' then
    raise exception 'prima passa il ruolo a qualcun altro' using errcode = 'TR412';
  end if;
  update public.partecipazione
     set stato = 'uscito'
   where viaggio_id = p_viaggio and utente_id = v_io;
end;
$$;

-- ─── Togliere qualcuno ────────────────────────────────────────────────────

-- Restituisce le righe del viaggio, come programma_viaggio: l'app le mette nella
-- copia così come sono.
create function public.rimuovi_partecipante(p_viaggio uuid, p_utente uuid)
returns jsonb
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
  perform 1
     from public.partecipazione
    where viaggio_id = p_viaggio and utente_id = v_io
      and ruolo = 'creatore' and stato = 'attivo' and eliminato_il is null
    for update;
  if not found then
    raise exception 'solo chi è responsabile del viaggio toglie qualcuno'
      using errcode = 'TR403';
  end if;
  update public.partecipazione
     set stato = 'rimosso'
   where viaggio_id = p_viaggio and utente_id = p_utente
     and ruolo = 'partecipante' and stato = 'attivo' and eliminato_il is null;
  if not found then
    raise exception 'non partecipa a questo viaggio' using errcode = 'TR404';
  end if;
  update public.invito
     set eliminato_il = now()
   where viaggio_id = p_viaggio and eliminato_il is null;
  return privato.righe_del_viaggio(p_viaggio);
end;
$$;

-- ─── Passare il ruolo ─────────────────────────────────────────────────────

-- Il creatore diventa un partecipante come gli altri e [p_a] il creatore; il
-- viaggio segue, perché chi lo legge come creatore (la regola di lettura del
-- viaggio) sia chi lo è adesso. Prima si toglie il ruolo, poi lo si dà: un solo
-- creatore attivo per viaggio, sempre (un_creatore_per_viaggio).
create function public.passa_il_ruolo(p_viaggio uuid, p_a uuid)
returns jsonb
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
  perform 1
     from public.partecipazione
    where viaggio_id = p_viaggio and utente_id = v_io
      and ruolo = 'creatore' and stato = 'attivo' and eliminato_il is null
    for update;
  if not found then
    raise exception 'solo chi è responsabile del viaggio passa il ruolo'
      using errcode = 'TR403';
  end if;
  perform 1
     from public.partecipazione
    where viaggio_id = p_viaggio and utente_id = p_a
      and ruolo = 'partecipante' and stato = 'attivo' and eliminato_il is null
    for update;
  if not found then
    raise exception 'non partecipa a questo viaggio' using errcode = 'TR404';
  end if;
  update public.partecipazione set ruolo = 'partecipante'
   where viaggio_id = p_viaggio and utente_id = v_io;
  update public.partecipazione set ruolo = 'creatore'
   where viaggio_id = p_viaggio and utente_id = p_a;
  update public.viaggio set creatore_id = p_a where id = p_viaggio;
  return privato.righe_del_viaggio(p_viaggio);
end;
$$;

-- ─── Entrare da un invito ─────────────────────────────────────────────────

-- Come prima (regole_di_accesso.sql), più il rientro di chi è stato tolto: con
-- un link valido creato da chi è responsabile adesso. Quelli che c'erano quando
-- è stato tolto sono già stati ritirati, quindi un link valido è per forza nuovo.
create or replace function public.accetta_invito(p_token text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_utente uuid := (select auth.uid());
  v_viaggio uuid;
  v_da uuid;
  v_stato text;
begin
  if v_utente is null then
    raise exception 'accesso richiesto' using errcode = 'TR401';
  end if;
  if not exists (select 1 from public.utente where id = v_utente and eliminato_il is null) then
    raise exception 'profilo mancante' using errcode = 'TR403';
  end if;

  select i.viaggio_id, i.creato_da into v_viaggio, v_da
  from public.invito i
  join public.viaggio v on v.id = i.viaggio_id
  where i.token = upper(replace(trim(p_token), '-', ''))
    and i.eliminato_il is null
    and v.eliminato_il is null;

  if v_viaggio is null then
    raise exception 'invito non valido' using errcode = 'TR404';
  end if;

  select stato into v_stato
  from public.partecipazione
  where viaggio_id = v_viaggio and utente_id = v_utente
  for update;

  if v_stato is null then
    insert into public.partecipazione (viaggio_id, utente_id, ruolo, stato, creato_da)
    values (v_viaggio, v_utente, 'partecipante', 'attivo', v_utente);
  elsif v_stato in ('uscito', 'invitato') then
    update public.partecipazione set stato = 'attivo'
    where viaggio_id = v_viaggio and utente_id = v_utente;
  elsif v_stato = 'rimosso' then
    if not exists (
      select 1 from public.partecipazione
       where viaggio_id = v_viaggio and utente_id = v_da
         and ruolo = 'creatore' and stato = 'attivo' and eliminato_il is null
    ) then
      raise exception 'rimosso dal viaggio' using errcode = 'TR403';
    end if;
    update public.partecipazione set stato = 'attivo'
    where viaggio_id = v_viaggio and utente_id = v_utente;
  end if;

  return v_viaggio;
end;
$$;

-- ─── Chi può chiamarle ────────────────────────────────────────────────────

revoke execute on function public.esci_dal_viaggio(uuid) from public, anon;
revoke execute on function public.rimuovi_partecipante(uuid, uuid) from public, anon;
revoke execute on function public.passa_il_ruolo(uuid, uuid) from public, anon;
grant execute on function public.esci_dal_viaggio(uuid) to authenticated;
grant execute on function public.rimuovi_partecipante(uuid, uuid) to authenticated;
grant execute on function public.passa_il_ruolo(uuid, uuid) to authenticated;
