-- Dividere le spese (fase 2.3, 06-spese.md): per chi è una spesa, e i
-- rimborsi che chiudono un saldo.
--
-- Le quote stanno in spesa_quota dallo schema iniziale: una riga per persona,
-- nella valuta della spesa. Qui arrivano tre cose:
-- - chi può risultare in una quota: qualcuno del viaggio, come il pagante
--   (spese_e_tassi.sql). Un partecipante non attribuisce un debito a un
--   estraneo;
-- - due funzioni che scrivono la spesa e le sue quote insieme, o niente:
--   registra_spesa (il gesto della coda, rimandabile senza duplicare) e
--   cambia_spesa (con la versione, come ogni modifica: 02 §3);
-- - il rimborso: una spesa segnata come tale, pagata da chi dà i soldi e
--   tutta per chi li riceve. Così il saldo si chiude con gli stessi conti di
--   ogni altra spesa, e il totale del viaggio la lascia fuori.
--
-- Che le quote facciano l'importo è una regola di dominio: la controlla
-- l'app (ADR-003). Il server custodisce chi può scrivere cosa.

alter table public.spesa add column rimborso boolean not null default false;

-- ─── Chi può risultare in una quota ───────────────────────────────────────

drop policy "lo aggiungono i partecipanti" on public.spesa_quota;
drop policy "lo modificano i partecipanti" on public.spesa_quota;

-- Anche chi è uscito o è stato tolto: le sue quote restano dov'erano (06,
-- regola 10). Non un estraneo.
create policy "la aggiungono i partecipanti, per qualcuno del viaggio" on public.spesa_quota
  for insert to authenticated
  with check (privato.e_partecipante(viaggio_id)
              and creato_da = (select auth.uid())
              and exists (select 1 from public.partecipazione p
                           where p.viaggio_id = spesa_quota.viaggio_id
                             and p.utente_id = spesa_quota.utente_id));
create policy "la modificano i partecipanti, per qualcuno del viaggio" on public.spesa_quota
  for update to authenticated
  using (privato.e_partecipante(viaggio_id))
  with check (privato.e_partecipante(viaggio_id)
              and exists (select 1 from public.partecipazione p
                           where p.viaggio_id = spesa_quota.viaggio_id
                             and p.utente_id = spesa_quota.utente_id));

-- ─── Una spesa con le sue quote ───────────────────────────────────────────

-- La spesa e le sue quote attive, come le mette nella copia l'app.
create function privato.righe_della_spesa(p_spesa uuid)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'spesa', to_jsonb(s),
    'quote', coalesce(
      (select jsonb_agg(to_jsonb(q) order by q.utente_id)
         from public.spesa_quota q
        where q.spesa_id = s.id and q.eliminato_il is null),
      '[]'::jsonb))
  from public.spesa s
  where s.id = p_spesa;
$$;

revoke execute on function privato.righe_della_spesa(uuid) from public, anon;
grant execute on function privato.righe_della_spesa(uuid) to authenticated;

-- Registra una spesa con le sue quote: il gesto della coda. L'id nasce sul
-- telefono, e rimandarla non la duplica: se la spesa c'è già, le sue quote
-- sono arrivate con lei, nella stessa transazione. Le regole di accesso
-- valgono come per un inserimento diretto (security invoker).
create function public.registra_spesa(p_spesa jsonb, p_quote jsonb default '[]'::jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_id uuid := (p_spesa ->> 'id')::uuid;
  v_viaggio uuid := (p_spesa ->> 'viaggio_id')::uuid;
begin
  insert into public.spesa (id, viaggio_id, importo, valuta, tasso_usato, tasso_al,
                            pagante_id, data, descrizione, rimborso, creato_da)
  values (v_id, v_viaggio,
          (p_spesa ->> 'importo')::numeric,
          p_spesa ->> 'valuta',
          (p_spesa ->> 'tasso_usato')::numeric,
          (p_spesa ->> 'tasso_al')::timestamptz,
          (p_spesa ->> 'pagante_id')::uuid,
          (p_spesa ->> 'data')::date,
          p_spesa ->> 'descrizione',
          coalesce((p_spesa ->> 'rimborso')::boolean, false),
          auth.uid())
  on conflict (id) do nothing;
  if found then
    insert into public.spesa_quota (viaggio_id, spesa_id, utente_id, quota, creato_da)
    select v_viaggio, v_id, (q ->> 'utente_id')::uuid, (q ->> 'quota')::numeric, auth.uid()
      from jsonb_array_elements(coalesce(p_quote, '[]'::jsonb)) q;
  end if;
  return privato.righe_della_spesa(v_id);
end;
$$;

-- Cambia una spesa, con la versione su cui la persona ha deciso: se qualcuno
-- l'ha cambiata nel frattempo, il trigger rifiuta (TR409) e non cambia
-- niente, quote comprese. In p_valori ci sono solo i campi che cambiano;
-- p_quote, se c'è, prende il posto di tutte le quote: chi esce dalla spesa
-- viene marcato, chi c'era già riprende la sua riga.
create function public.cambia_spesa(
  p_spesa uuid,
  p_versione integer,
  p_valori jsonb,
  p_quote jsonb default null
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_viaggio uuid;
begin
  update public.spesa
     set importo = case when p_valori ? 'importo'
                        then (p_valori ->> 'importo')::numeric else importo end,
         valuta = case when p_valori ? 'valuta' then p_valori ->> 'valuta' else valuta end,
         data = case when p_valori ? 'data' then (p_valori ->> 'data')::date else data end,
         descrizione = case when p_valori ? 'descrizione'
                            then p_valori ->> 'descrizione' else descrizione end,
         pagante_id = case when p_valori ? 'pagante_id'
                           then (p_valori ->> 'pagante_id')::uuid else pagante_id end,
         eliminato_il = case when p_valori ? 'eliminato_il'
                             then (p_valori ->> 'eliminato_il')::timestamptz else eliminato_il end,
         versione = p_versione
   where id = p_spesa
  returning viaggio_id into v_viaggio;
  if v_viaggio is null then
    raise exception 'spesa non trovata' using errcode = 'TR404';
  end if;
  if p_quote is not null then
    update public.spesa_quota
       set eliminato_il = now()
     where spesa_id = p_spesa
       and eliminato_il is null
       and utente_id not in (select (q ->> 'utente_id')::uuid
                               from jsonb_array_elements(p_quote) q);
    insert into public.spesa_quota (viaggio_id, spesa_id, utente_id, quota, creato_da)
    select v_viaggio, p_spesa, (q ->> 'utente_id')::uuid, (q ->> 'quota')::numeric, auth.uid()
      from jsonb_array_elements(p_quote) q
    on conflict (spesa_id, utente_id)
      do update set quota = excluded.quota, eliminato_il = null;
  end if;
  return privato.righe_della_spesa(p_spesa);
end;
$$;

revoke execute on function public.registra_spesa(jsonb, jsonb) from public, anon;
revoke execute on function public.cambia_spesa(uuid, integer, jsonb, jsonb) from public, anon;
grant execute on function public.registra_spesa(jsonb, jsonb) to authenticated;
grant execute on function public.cambia_spesa(uuid, integer, jsonb, jsonb) to authenticated;
