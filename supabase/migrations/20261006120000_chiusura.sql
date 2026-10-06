-- La chiusura del viaggio, la verifica scritta e i traguardi (fase 4.1,
-- 10-chiusura-e-ricordo.md; 02-il-viaggio.md, regole 4 e 7–9).
--
-- - Un viaggio si chiude da solo il giorno dopo la fine, quando il primo
--   telefono di chi partecipa lo vede, o prima a mano da chi ne è
--   responsabile. Si chiude solo con chiudi_viaggio, e non si riapre: lo
--   stato `chiuso` non si scrive e non si toglie direttamente.
-- - La verifica è di ciascuno, come «sul posto» (sul_posto.sql): la calcola
--   il telefono con le regole di dominio (dominio/verifica.dart) e la scrive
--   segna_verifica, una volta, nella propria partecipazione. Il server
--   controlla solo quello che sa: senza essere stati sul posto, o con un
--   viaggio importato, non si è verificati. La deroga amministrativa
--   (verifica_per_deroga) vale come sul posto, e la scrive solo chi gestisce
--   il progetto. viaggio.verificato vuol dire: verificato per almeno uno, e
--   non lo scrive più l'app.
-- - I traguardi sono di chi li prende, uno per tipo, con il viaggio che l'ha
--   dato. Quali traguardi esistono, e quando si prendono, lo dice l'app
--   (dominio/traguardi.dart): il server li accetta solo da un viaggio
--   verificato per chi li prende.

-- ─── Lo stato chiuso ──────────────────────────────────────────────────────

create function privato.chiusura_protetta()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (new.stato = 'chiuso') is distinct from (old.stato = 'chiuso')
     and coalesce(current_setting('trolley.chiusura', true), '') <> 'si' then
    raise exception 'un viaggio si chiude solo con chiudi_viaggio, e non si riapre'
      using errcode = 'TR403';
  end if;
  return new;
end;
$$;

create trigger viaggio_chiusura before update of stato on public.viaggio
  for each row execute function privato.chiusura_protetta();

revoke execute on function privato.chiusura_protetta() from public, anon, authenticated;

-- Verificato non si dichiara: lo scrive segna_verifica.
revoke update (verificato) on public.viaggio from authenticated;

-- ─── Chiudere ─────────────────────────────────────────────────────────────

-- Restituisce il viaggio com'è dopo: l'app lo mette nella copia. Chiudere un
-- viaggio già chiuso non fa niente.
create function public.chiudi_viaggio(p_viaggio uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_io uuid := (select auth.uid());
  v_oggi date := (now() at time zone 'utc')::date;
  v_ruolo text;
  v_viaggio public.viaggio;
begin
  if v_io is null then
    raise exception 'accesso richiesto' using errcode = 'TR401';
  end if;
  select ruolo into v_ruolo
    from public.partecipazione
   where viaggio_id = p_viaggio and utente_id = v_io
     and stato = 'attivo' and eliminato_il is null;
  if v_ruolo is null then
    raise exception 'non partecipi a questo viaggio' using errcode = 'TR404';
  end if;
  select * into v_viaggio
    from public.viaggio
   where id = p_viaggio and eliminato_il is null
   for update;
  if v_viaggio.stato = 'chiuso' then
    return to_jsonb(v_viaggio);
  end if;
  -- Un giorno di margine per i fusi orari: il telefono guarda la sua data.
  if v_viaggio.stato not in ('definito', 'in_corso')
     or v_viaggio.data_inizio > v_oggi + 1 then
    raise exception 'il viaggio non è cominciato' using errcode = 'TR422';
  end if;
  -- Prima dell'ultimo giorno lo chiude solo chi ne è responsabile (regola 4);
  -- dopo, chiunque: è la chiusura da sola.
  if v_oggi < v_viaggio.data_fine and v_ruolo <> 'creatore' then
    raise exception 'solo chi è responsabile chiude il viaggio prima della fine'
      using errcode = 'TR403';
  end if;
  perform set_config('trolley.chiusura', 'si', true);
  update public.viaggio set stato = 'chiuso'
   where id = p_viaggio
  returning * into v_viaggio;
  perform set_config('trolley.chiusura', '', true);
  return to_jsonb(v_viaggio);
end;
$$;

-- ─── La verifica, di ciascuno ─────────────────────────────────────────────

alter table public.partecipazione add column verificato boolean;

-- Restituisce la propria partecipazione com'è dopo. Si scrive una volta: la
-- seconda restituisce quello che c'era.
create function public.segna_verifica(p_viaggio uuid, p_verificato boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_io uuid := (select auth.uid());
  v_mia public.partecipazione;
  v_viaggio public.viaggio;
begin
  if v_io is null then
    raise exception 'accesso richiesto' using errcode = 'TR401';
  end if;
  select * into v_mia
    from public.partecipazione
   where viaggio_id = p_viaggio and utente_id = v_io
     and stato = 'attivo' and eliminato_il is null
   for update;
  if not found then
    raise exception 'non partecipi a questo viaggio' using errcode = 'TR404';
  end if;
  select * into v_viaggio from public.viaggio where id = p_viaggio;
  if v_viaggio.stato <> 'chiuso' then
    raise exception 'il viaggio non è chiuso' using errcode = 'TR422';
  end if;
  if v_mia.verificato is not null then
    return to_jsonb(v_mia);
  end if;
  if p_verificato
     and (v_viaggio.importato
          or (v_mia.sul_posto_il is null and not v_viaggio.verifica_per_deroga)) then
    raise exception 'senza essere stati sul posto il viaggio non è verificato'
      using errcode = 'TR403';
  end if;
  update public.partecipazione set verificato = p_verificato
   where id = v_mia.id
  returning * into v_mia;
  if p_verificato then
    update public.viaggio set verificato = true
     where id = p_viaggio and not verificato;
  end if;
  return to_jsonb(v_mia);
end;
$$;

-- ─── I traguardi ──────────────────────────────────────────────────────────

create table public.traguardo (
  id uuid primary key default gen_random_uuid(),
  utente_id uuid not null references public.utente (id),
  tipo text not null check (char_length(tipo) between 1 and 40),
  viaggio_id uuid not null references public.viaggio (id),
  preso_il timestamptz not null default now(),
  constraint un_traguardo_per_tipo unique (utente_id, tipo)
);

create index traguardo_viaggio on public.traguardo (viaggio_id);

alter table public.traguardo enable row level security;
revoke all on public.traguardo from anon, authenticated;
grant select on public.traguardo to authenticated;

create policy "li legge chi li ha presi" on public.traguardo
  for select to authenticated
  using (utente_id = (select auth.uid()));

-- Prende i traguardi che l'app ha visto maturare con un viaggio verificato
-- per chi li prende. Uno per tipo: quelli già presi restano con il viaggio
-- che li ha dati. Restituisce tutti i propri.
create function public.prendi_traguardi(p_viaggio uuid, p_tipi text[])
returns setof public.traguardo
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
      and stato = 'attivo' and eliminato_il is null and verificato;
  if not found then
    raise exception 'i traguardi si prendono solo con un viaggio verificato'
      using errcode = 'TR403';
  end if;
  insert into public.traguardo (utente_id, tipo, viaggio_id)
  select v_io, t, p_viaggio from unnest(p_tipi) as t
  on conflict (utente_id, tipo) do nothing;
  return query
    select * from public.traguardo where utente_id = v_io order by preso_il, tipo;
end;
$$;

revoke execute on function public.chiudi_viaggio(uuid) from public, anon;
revoke execute on function public.segna_verifica(uuid, boolean) from public, anon;
revoke execute on function public.prendi_traguardi(uuid, text[]) from public, anon;
grant execute on function public.chiudi_viaggio(uuid) to authenticated;
grant execute on function public.segna_verifica(uuid, boolean) to authenticated;
grant execute on function public.prendi_traguardi(uuid, text[]) to authenticated;
