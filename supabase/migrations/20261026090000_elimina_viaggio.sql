-- Eliminare un viaggio (02, regola 13; decisioni, «Eliminare un viaggio»):
-- solo chi ci è rimasto da solo, in qualunque stato, con tutto quello che
-- contiene. Gli inviti non ancora accettati non contano: se ne vanno con il
-- viaggio. Si cancella come per chi chiude l'account, con
-- privato.cancella_viaggio.

create function public.elimina_viaggio(p_viaggio uuid)
returns void
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
  -- Il viaggio si blocca: nessuno entra mentre lo si elimina.
  perform 1 from public.viaggio where id = p_viaggio for update;
  if not exists (
    select 1 from public.partecipazione
     where viaggio_id = p_viaggio and utente_id = v_io
       and stato = 'attivo' and eliminato_il is null
  ) then
    raise exception 'non partecipi a questo viaggio' using errcode = 'TR404';
  end if;
  if exists (
    select 1 from public.partecipazione
     where viaggio_id = p_viaggio and utente_id <> v_io
       and stato = 'attivo' and eliminato_il is null
  ) then
    raise exception 'nel viaggio ci sono altri: lo elimina solo chi è rimasto da solo'
      using errcode = 'TR413';
  end if;
  perform privato.cancella_viaggio(p_viaggio);
end;
$$;

revoke execute on function public.elimina_viaggio(uuid) from public, anon;
grant execute on function public.elimina_viaggio(uuid) to authenticated;
