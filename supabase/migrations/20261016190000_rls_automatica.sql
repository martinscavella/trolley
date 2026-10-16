-- La funzione public.rls_auto_enable() (punti aperti, prerequisiti operativi).
-- Non viene dalle nostre migrazioni: l'ha creata Supabase. È la funzione del
-- trigger di eventi ensure_rls, che a ogni CREATE TABLE in public accende da
-- sola le regole di accesso per riga: una rete di sicurezza in più per una
-- tabella dimenticata senza regole, e si tiene.
--
-- Restituisce event_trigger, quindi nessuno può chiamarla a mano, neanche da
-- /rest/v1/rpc. Il controllo di sicurezza la segnala lo stesso, perché è
-- security definer ed eseguibile da anon e authenticated. Il trigger non
-- guarda chi la può eseguire: si toglie l'esecuzione a tutti fuorché al
-- proprietario, e l'avviso tace. La prova è supabase/tests/rls_automatica.sql.
--
-- Se un giorno la funzione non c'è più, la migrazione non fa niente.

do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
  end if;
end;
$$;
