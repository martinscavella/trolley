-- Le spese (fase 1.4, 06-spese.md). Le tabelle ci sono dallo schema iniziale;
-- qui arrivano i tassi di cambio e una regola in più su chi può risultare
-- pagante.

-- ─── Chi ha pagato ────────────────────────────────────────────────────────

-- Il pagante è qualcuno del viaggio: anche chi è uscito o è stato rimosso,
-- perché le sue spese restano dov'erano (06, regola 10). Non un estraneo, a
-- cui un partecipante potrebbe altrimenti attribuire un debito.
drop policy "lo aggiungono i partecipanti" on public.spesa;
drop policy "lo modificano i partecipanti" on public.spesa;

create policy "la registrano i partecipanti, con un pagante del viaggio" on public.spesa
  for insert to authenticated
  with check (privato.e_partecipante(viaggio_id)
              and creato_da = (select auth.uid())
              and exists (select 1 from public.partecipazione p
                           where p.viaggio_id = spesa.viaggio_id
                             and p.utente_id = spesa.pagante_id));
create policy "la modificano i partecipanti, con un pagante del viaggio" on public.spesa
  for update to authenticated
  using (privato.e_partecipante(viaggio_id))
  with check (privato.e_partecipante(viaggio_id)
              and exists (select 1 from public.partecipazione p
                           where p.viaggio_id = spesa.viaggio_id
                             and p.utente_id = spesa.pagante_id));

-- La valuta è un codice di tre lettere maiuscole: `EUR`, non `eur` né `€`.
alter table public.spesa
  add constraint spesa_valuta_codice check (valuta ~ '^[A-Z]{3}$');

-- ─── Tassi di cambio ──────────────────────────────────────────────────────

-- L'ultimo tasso noto per ogni valuta, rispetto all'euro: quante unità di
-- quella valuta vale un euro. Da qui l'app ricava ogni coppia (A → B è
-- per_euro(B) / per_euro(A)). Li scarica il server una volta al giorno, per
-- tutte le valute insieme: il fornitore non vede né persone né viaggi, nemmeno
-- un indirizzo di telefono (04-integrazioni.md, ADR-009).
create table public.tasso_cambio (
  valuta char(3) primary key check (valuta ~ '^[A-Z]{3}$'),
  per_euro numeric(24, 10) not null check (per_euro > 0),
  -- Il giorno a cui si riferisce il tasso secondo il fornitore.
  del date not null,
  scaricato_il timestamptz not null default now()
);

alter table public.tasso_cambio enable row level security;
revoke all on public.tasso_cambio from anon, authenticated;
grant select on public.tasso_cambio to authenticated;

create policy "li legge chiunque abbia un accesso" on public.tasso_cambio
  for select to authenticated using (true);

create extension if not exists http with schema extensions;
create extension if not exists pg_cron;

-- Scarica i tassi del giorno e li scrive. Due indirizzi dello stesso fornitore:
-- se il primo non risponde si prova il secondo; se nessuno risponde restano i
-- tassi di prima, che l'app dichiara con la loro data. Non si inventa niente.
create function privato.aggiorna_tassi()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  indirizzi text[] := array[
    'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/eur.json',
    'https://latest.currency-api.pages.dev/v1/currencies/eur.json'];
  indirizzo text;
  risposta extensions.http_response;
  corpo jsonb;
  scritte integer;
begin
  foreach indirizzo in array indirizzi loop
    begin
      perform extensions.http_set_curlopt('CURLOPT_TIMEOUT', '20');
      risposta := extensions.http_get(indirizzo);
      if risposta.status = 200 then
        corpo := risposta.content::jsonb;
        exit when corpo ? 'eur' and corpo ? 'date';
      end if;
    exception when others then
      corpo := null;
    end;
    corpo := null;
  end loop;

  if corpo is null then
    return 0;
  end if;

  insert into public.tasso_cambio (valuta, per_euro, del, scaricato_il)
  select upper(t.chiave), t.valore::numeric, (corpo ->> 'date')::date, now()
    from jsonb_each_text(corpo -> 'eur') as t(chiave, valore)
   where t.chiave ~ '^[a-z]{3}$'
     and t.valore ~ '^[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$'
     and t.valore::numeric > 0
     and t.valore::numeric < 1e13
  on conflict (valuta) do update
     set per_euro = excluded.per_euro,
         del = excluded.del,
         scaricato_il = excluded.scaricato_il;
  get diagnostics scritte = row_count;
  return scritte;
end;
$$;

revoke execute on function privato.aggiorna_tassi() from public, anon, authenticated;

-- Ogni giorno alle 4 e alle 16 UTC: il fornitore pubblica una volta al giorno,
-- il secondo giro copre un primo andato a vuoto.
select cron.schedule('aggiorna_tassi', '0 4,16 * * *', 'select privato.aggiorna_tassi()');

-- Il primo giro subito, così la tabella non nasce vuota.
select privato.aggiorna_tassi();
