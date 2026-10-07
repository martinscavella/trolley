-- Il tetto delle mappe (U.2, prima dell'ondata 1; ADR-006, «Il tetto»).
--
-- La chiave di Geoapify esce dall'app e sta solo sul server, nella funzione
-- `mappe` (supabase/functions/mappe), che passa riquadri, ricerche e percorsi.
-- Prima di ogni chiamata la funzione chiede qui se si può: il tetto è per
-- persona, per viaggio e per giorno, e lo fa rispettare il server.
--
-- - Si conta solo chi partecipa al viaggio: le mappe servono un viaggio.
-- - Al tetto si dice no e non si conta: la persona resta con le Mappe del
--   telefono (ADR-006, regola 2), e il giorno dopo si ricomincia.
-- - I numeri stanno in `configurazione` (`tetto_mappe`), per cambiarli senza
--   una versione nuova dell'app; senza, valgono quelli scritti qui.
-- - Il giorno è quello del server (UTC).
-- - Il conto serve solo al tetto: dopo una settimana si toglie. Quanto costa
--   una persona lo dice l'evento `consumo_mappe` (07).

-- ─── Il conto ─────────────────────────────────────────────────────────────

create table privato.consumo_mappe (
  utente_id uuid not null,
  viaggio_id uuid not null references public.viaggio(id) on delete cascade,
  giorno date not null,
  riquadri integer not null default 0,
  ricerche integer not null default 0,
  percorsi integer not null default 0,
  primary key (utente_id, viaggio_id, giorno)
);

-- È nello schema privato, che il client non raggiunge: lo scrive solo
-- consuma_mappe.
revoke all on privato.consumo_mappe from public, anon, authenticated;

-- ─── I numeri ─────────────────────────────────────────────────────────────

-- Per persona, per viaggio, per giorno. Un riquadro costa un quarto di
-- credito, una ricerca e un percorso uno: al tetto sono 710 crediti, su 3000
-- al giorno per tutta l'app nel piano gratuito.
insert into public.configurazione (chiave, valore)
values ('tetto_mappe', '{"riquadri": 2000, "ricerche": 150, "percorsi": 60}')
on conflict (chiave) do nothing;

-- ─── Si può? ──────────────────────────────────────────────────────────────

-- Conta una chiamata di [p_tipo] — `riquadri`, `ricerche` o `percorsi` — per
-- chi chiama nel viaggio [p_viaggio], se è sotto il tetto. `true`: la si
-- faccia; `false`: il tetto di oggi è raggiunto, e non si è contato niente.
create function public.consuma_mappe(p_viaggio uuid, p_tipo text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_io uuid := (select auth.uid());
  v_tetto jsonb;
  v_limite integer;
  v_ok boolean;
begin
  if v_io is null then
    raise exception 'accesso richiesto' using errcode = 'TR401';
  end if;
  if p_tipo is null or p_tipo not in ('riquadri', 'ricerche', 'percorsi') then
    raise exception 'tipo di chiamata sconosciuto: %', p_tipo using errcode = '22023';
  end if;
  if not privato.e_partecipante(p_viaggio) then
    raise exception 'non partecipi a questo viaggio' using errcode = 'TR404';
  end if;

  select valore into v_tetto from public.configurazione where chiave = 'tetto_mappe';
  v_limite := coalesce(
    (v_tetto ->> p_tipo)::integer,
    case p_tipo when 'riquadri' then 2000 when 'ricerche' then 150 else 60 end);

  insert into privato.consumo_mappe (utente_id, viaggio_id, giorno)
  values (v_io, p_viaggio, current_date)
  on conflict do nothing;

  -- Una riga sola, aggiornata solo se sotto il tetto: due chiamate insieme
  -- non lo superano.
  update privato.consumo_mappe
     set riquadri = riquadri + (p_tipo = 'riquadri')::integer,
         ricerche = ricerche + (p_tipo = 'ricerche')::integer,
         percorsi = percorsi + (p_tipo = 'percorsi')::integer
   where utente_id = v_io and viaggio_id = p_viaggio and giorno = current_date
     and case p_tipo
           when 'riquadri' then riquadri
           when 'ricerche' then ricerche
           else percorsi
         end < v_limite
  returning true into v_ok;

  return coalesce(v_ok, false);
end;
$$;

revoke execute on function public.consuma_mappe(uuid, text) from public, anon;
grant execute on function public.consuma_mappe(uuid, text) to authenticated;

-- ─── Una settimana, poi via ───────────────────────────────────────────────

select cron.schedule(
  'pulisci_consumo_mappe',
  '30 3 * * *',
  $$delete from privato.consumo_mappe where giorno < current_date - 7$$
);
