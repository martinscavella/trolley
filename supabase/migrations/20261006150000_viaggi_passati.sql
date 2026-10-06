-- I viaggi passati, inseriti come ricordo (fase 4.3; 10-chiusura-e-ricordo.md,
-- regole 5–6; 02-il-viaggio.md, regola 10).
--
-- - Un viaggio importato nasce chiuso, non verificato, e lo resta: lo diceva
--   già importato_chiuso_non_verificato. Dice quando con il periodo, nella
--   forma delle idee («agosto 2019»), e quanti giorni se la persona se li
--   ricorda: date e orari non li sa, e non si inventano.
-- - Nasce chiuso solo un viaggio importato. Fino a qui un viaggio scritto
--   direttamente poteva nascere chiuso senza esserlo mai stato: un viaggio
--   finto che sembrava vero, e che le metriche avrebbero contato.
-- - Un viaggio passato è di chi l'ha aggiunto: non ci si invita nessuno.
--   Ognuno aggiunge il suo.
-- - Si cambia e si toglie come un viaggio, con la versione: lo fa chi
--   partecipa, cioè chi l'ha aggiunto.

-- ─── Quando, senza date ───────────────────────────────────────────────────

alter table public.viaggio add column giorni_ricordati smallint;

alter table public.viaggio drop constraint definito_ha_date;
alter table public.viaggio add constraint definito_ha_date check (
  stato = 'idea'
  or importato
  or (data_inizio is not null and data_fine is not null
      and ora_arrivo is not null and ora_partenza is not null)
);

alter table public.viaggio add constraint importato_dice_quando
  check (not importato or periodo_approssimativo is not null or data_inizio is not null);

alter table public.viaggio add constraint giorni_ricordati_dei_passati
  check (giorni_ricordati is null or (importato and giorni_ricordati between 1 and 365));

grant insert (giorni_ricordati) on public.viaggio to authenticated;
grant update (giorni_ricordati) on public.viaggio to authenticated;

-- ─── Come nasce un viaggio ────────────────────────────────────────────────

-- Idea o definito; chiuso solo se è importato. In corso, chiuso e archiviato
-- si diventa dopo.
create function privato.viaggio_nasce()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not new.importato and new.stato not in ('idea', 'definito') then
    raise exception 'un viaggio nasce idea o definito; chiuso solo se è passato'
      using errcode = 'TR403';
  end if;
  return new;
end;
$$;

create trigger viaggio_nascita before insert on public.viaggio
  for each row execute function privato.viaggio_nasce();

revoke execute on function privato.viaggio_nasce() from public, anon, authenticated;

-- ─── Aggiungere un viaggio passato ────────────────────────────────────────

-- Restituisce le righe scritte, come crea_viaggio: il viaggio e chi
-- partecipa. Giorni non ne ha.
create function public.aggiungi_viaggio_passato(
  p_id uuid,
  p_destinazione_citta text,
  p_destinazione_paese text,
  p_periodo text,
  p_giorni smallint
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
begin
  insert into public.viaggio (id, stato, destinazione_citta, destinazione_paese,
                              periodo_approssimativo, giorni_ricordati,
                              creatore_id, importato)
  values (p_id, 'chiuso', p_destinazione_citta, p_destinazione_paese,
          p_periodo, p_giorni, (select auth.uid()), true);
  return privato.righe_del_viaggio(p_id);
end;
$$;

revoke execute on function public.aggiungi_viaggio_passato(uuid, text, text, text, smallint) from public, anon;
grant execute on function public.aggiungi_viaggio_passato(uuid, text, text, text, smallint) to authenticated;

-- ─── Nessun invito in un viaggio passato ──────────────────────────────────

drop policy "lo crea un partecipante" on public.invito;
create policy "lo crea un partecipante, se il viaggio non è passato" on public.invito
  for insert to authenticated
  with check (
    privato.e_partecipante(viaggio_id)
    and creato_da = (select auth.uid())
    and not exists (
      select 1 from public.viaggio v where v.id = viaggio_id and v.importato
    )
  );
