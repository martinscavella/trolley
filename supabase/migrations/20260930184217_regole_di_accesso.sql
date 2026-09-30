-- Regole di accesso: la vera superficie di sicurezza (ADR-003).
--
-- - Un viaggio e tutto ciò che contiene si leggono e scrivono solo da partecipanti attivi.
-- - Una voce di lista personale la vede solo il suo proprietario, nemmeno il creatore.
-- - Nessuna policy di DELETE: si cancella marcando eliminato_il.
-- - anon non vede niente.
-- - Le colonne che la persona non può toccare da sola (data di nascita, account interno,
--   telefono verificato, deroga sulla verifica, creatore) sono escluse dai permessi.

-- ─── Funzioni di supporto ─────────────────────────────────────────────────
-- security definer per non rientrare nelle policy di partecipazione (ricorsione).

create function public.e_partecipante(p_viaggio_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.partecipazione
    where viaggio_id = p_viaggio_id
      and utente_id = (select auth.uid())
      and stato = 'attivo'
      and eliminato_il is null
  );
$$;

-- Due persone che condividono un viaggio attivo si vedono i nomi.
create function public.condivide_viaggio(p_utente_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.partecipazione io
    join public.partecipazione altro on altro.viaggio_id = io.viaggio_id
    where io.utente_id = (select auth.uid())
      and io.stato = 'attivo'
      and altro.utente_id = p_utente_id
  );
$$;

revoke execute on function public.e_partecipante(uuid) from public, anon;
revoke execute on function public.condivide_viaggio(uuid) from public, anon;
grant execute on function public.e_partecipante(uuid) to authenticated;
grant execute on function public.condivide_viaggio(uuid) to authenticated;

-- Le funzioni interne non si chiamano dall'API.
revoke execute on function public.aggiorna_riga() from public, anon, authenticated;
revoke execute on function public.controlla_eta_utente() from public, anon, authenticated;
revoke execute on function public.viaggio_crea_partecipazione() from public, anon, authenticated;
revoke execute on function public.genera_codice_invito() from public, anon;

-- ─── Permessi per tabella ─────────────────────────────────────────────────

do $$
declare
  t text;
begin
  foreach t in array array['utente', 'viaggio', 'partecipazione', 'giorno', 'tappa',
                           'invito', 'spesa', 'spesa_quota', 'voce_lista', 'evento']
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
  end loop;
end;
$$;

-- utente
grant select on public.utente to authenticated;
grant insert (id, nome, data_nascita, valuta_predefinita) on public.utente to authenticated;
grant update (nome, valuta_predefinita, profilo_pubblico_attivo, eliminato_il, versione)
  on public.utente to authenticated;

create policy "si vede se stessi e chi condivide un viaggio" on public.utente
  for select to authenticated
  using (id = (select auth.uid()) or public.condivide_viaggio(id));
create policy "si crea solo se stessi" on public.utente
  for insert to authenticated
  with check (id = (select auth.uid()));
create policy "si modifica solo se stessi" on public.utente
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- viaggio
grant select on public.viaggio to authenticated;
grant insert (id, stato, destinazione_citta, destinazione_paese, periodo_approssimativo,
              data_inizio, data_fine, ora_arrivo, ora_partenza, creatore_id, importato)
  on public.viaggio to authenticated;
grant update (stato, destinazione_citta, destinazione_paese, periodo_approssimativo,
              data_inizio, data_fine, ora_arrivo, ora_partenza, verificato,
              eliminato_il, versione)
  on public.viaggio to authenticated;

-- Il creatore lo vede anche nell'istante fra l'inserimento e la sua partecipazione.
create policy "lo leggono i partecipanti attivi" on public.viaggio
  for select to authenticated
  using (public.e_partecipante(id) or creatore_id = (select auth.uid()));
create policy "lo crea chi ne diventa creatore" on public.viaggio
  for insert to authenticated
  with check (creatore_id = (select auth.uid()));
create policy "lo modificano i partecipanti attivi" on public.viaggio
  for update to authenticated
  using (public.e_partecipante(id))
  with check (public.e_partecipante(id));

-- partecipazione: si legge; si scrive solo attraverso le funzioni (creazione del
-- viaggio, accetta_invito). Uscita e rimozione arrivano con la fase 2.
grant select on public.partecipazione to authenticated;

create policy "la leggono i partecipanti del viaggio" on public.partecipazione
  for select to authenticated
  using (utente_id = (select auth.uid()) or public.e_partecipante(viaggio_id));

-- invito
grant select on public.invito to authenticated;
grant insert (id, viaggio_id) on public.invito to authenticated;
grant update (eliminato_il, versione) on public.invito to authenticated;

create policy "lo leggono i partecipanti" on public.invito
  for select to authenticated
  using (public.e_partecipante(viaggio_id));
create policy "lo crea un partecipante" on public.invito
  for insert to authenticated
  with check (public.e_partecipante(viaggio_id) and creato_da = (select auth.uid()));
create policy "lo ritira un partecipante" on public.invito
  for update to authenticated
  using (public.e_partecipante(viaggio_id))
  with check (public.e_partecipante(viaggio_id));

-- giorno, tappa, spesa, spesa_quota: tutto il viaggio a tutti i partecipanti attivi.
do $$
declare
  t text;
begin
  foreach t in array array['giorno', 'tappa', 'spesa', 'spesa_quota']
  loop
    execute format('grant select, insert, update on public.%I to authenticated', t);
    execute format($p$
      create policy "lo leggono i partecipanti" on public.%1$I
        for select to authenticated using (public.e_partecipante(viaggio_id))
    $p$, t);
    execute format($p$
      create policy "lo aggiungono i partecipanti" on public.%1$I
        for insert to authenticated
        with check (public.e_partecipante(viaggio_id) and creato_da = (select auth.uid()))
    $p$, t);
    execute format($p$
      create policy "lo modificano i partecipanti" on public.%1$I
        for update to authenticated
        using (public.e_partecipante(viaggio_id))
        with check (public.e_partecipante(viaggio_id))
    $p$, t);
  end loop;
end;
$$;

-- voce_lista: le personali solo al proprietario.
grant select, insert, update on public.voce_lista to authenticated;

create policy "la leggono i partecipanti, se non è personale" on public.voce_lista
  for select to authenticated
  using (public.e_partecipante(viaggio_id)
         and (tipo = 'viaggio' or proprietario_id = (select auth.uid())));
create policy "la aggiunge un partecipante, a suo nome" on public.voce_lista
  for insert to authenticated
  with check (public.e_partecipante(viaggio_id)
              and proprietario_id = (select auth.uid())
              and creato_da = (select auth.uid()));
create policy "la modificano i partecipanti, se non è personale" on public.voce_lista
  for update to authenticated
  using (public.e_partecipante(viaggio_id)
         and (tipo = 'viaggio' or proprietario_id = (select auth.uid())))
  with check (public.e_partecipante(viaggio_id)
              and (tipo = 'viaggio' or proprietario_id = (select auth.uid())));

-- evento: si scrive solo a proprio nome, non si rilegge dall'app.
grant insert (id, nome, proprieta, avvenuto_il, versione_app) on public.evento to authenticated;

create policy "si registra solo a proprio nome" on public.evento
  for insert to authenticated
  with check (utente_id = (select auth.uid()));

-- ─── Ingresso da invito ───────────────────────────────────────────────────

-- Restituisce il viaggio in cui la persona si trova dopo aver usato il codice.
-- Chi è già dentro viene riconosciuto; chi era uscito rientra; chi è stato rimosso
-- dal creatore non rientra con lo stesso codice.
create function public.accetta_invito(p_token text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_utente uuid := auth.uid();
  v_viaggio uuid;
  v_stato text;
begin
  if v_utente is null then
    raise exception 'accesso richiesto' using errcode = 'TR401';
  end if;
  if not exists (select 1 from public.utente where id = v_utente and eliminato_il is null) then
    raise exception 'profilo mancante' using errcode = 'TR403';
  end if;

  select i.viaggio_id into v_viaggio
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
  where viaggio_id = v_viaggio and utente_id = v_utente;

  if v_stato is null then
    insert into public.partecipazione (viaggio_id, utente_id, ruolo, stato, creato_da)
    values (v_viaggio, v_utente, 'partecipante', 'attivo', v_utente);
  elsif v_stato in ('uscito', 'invitato') then
    update public.partecipazione set stato = 'attivo'
    where viaggio_id = v_viaggio and utente_id = v_utente;
  elsif v_stato = 'rimosso' then
    raise exception 'rimosso dal viaggio' using errcode = 'TR403';
  end if;

  return v_viaggio;
end;
$$;

revoke execute on function public.accetta_invito(text) from public, anon;
grant execute on function public.accetta_invito(text) to authenticated;
