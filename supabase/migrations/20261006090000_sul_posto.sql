-- Sul posto: una delle tre condizioni della verifica del viaggio (fase 3.4,
-- 02-il-viaggio.md, regole 7–9).
--
-- Durante il viaggio l'app dev'essere stata aperta con la posizione attiva,
-- nella città o nel paese della meta. Il confronto lo fa il telefono, con
-- l'elenco delle destinazioni che ha dentro (ADR-005): la posizione non lascia
-- mai il telefono, e al server arriva solo l'esito (06-privacy-e-conformita.md).
-- Si scrive solo un sì: un no non dice niente, perché basta una volta.
--
-- L'esito è di ciascuno, nella sua partecipazione: chi nega il permesso non
-- otterrà mai un viaggio verificato (regola 9), anche se un compagno era sul
-- posto. Lo scrive solo questa funzione, per sé, una volta, e solo mentre il
-- viaggio è in corso — con un giorno di margine per parte, per i fusi orari e
-- per il telefono che lo manda appena torna la rete. Che la posizione
-- coincidesse lo dice l'app, come le altre regole di dominio (ADR-003): il
-- server controlla chi e quando. La deroga amministrativa resta
-- viaggio.verifica_per_deroga, che l'app non scrive.

alter table public.partecipazione add column sul_posto_il timestamptz;

-- Restituisce la partecipazione com'è dopo: l'app la mette nella copia.
create function public.segna_sul_posto(p_viaggio uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_io uuid := (select auth.uid());
  v_oggi date := (now() at time zone 'utc')::date;
  v_riga public.partecipazione;
begin
  if v_io is null then
    raise exception 'accesso richiesto' using errcode = 'TR401';
  end if;
  perform 1
     from public.partecipazione
    where viaggio_id = p_viaggio and utente_id = v_io
      and stato = 'attivo' and eliminato_il is null;
  if not found then
    raise exception 'non partecipi a questo viaggio' using errcode = 'TR404';
  end if;
  perform 1
     from public.viaggio
    where id = p_viaggio and eliminato_il is null and not importato
      and stato in ('definito', 'in_corso')
      and v_oggi between data_inizio - 1 and data_fine + 1;
  if not found then
    raise exception 'il viaggio non è in corso' using errcode = 'TR422';
  end if;
  update public.partecipazione
     set sul_posto_il = coalesce(sul_posto_il, now())
   where viaggio_id = p_viaggio and utente_id = v_io
  returning * into v_riga;
  return to_jsonb(v_riga);
end;
$$;

revoke execute on function public.segna_sul_posto(uuid) from public, anon;
grant execute on function public.segna_sul_posto(uuid) to authenticated;
