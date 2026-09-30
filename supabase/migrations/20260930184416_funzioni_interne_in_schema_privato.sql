-- Le funzioni che servono alle regole di accesso e ai trigger non devono essere
-- chiamabili dall'API: stanno in uno schema che PostgREST non espone.
-- Policy, trigger e valori predefiniti le riferiscono per identificativo, quindi
-- spostarle non richiede di riscriverli.

create schema privato;
revoke all on schema privato from public, anon;
grant usage on schema privato to authenticated;

alter function public.e_partecipante(uuid) set schema privato;
alter function public.condivide_viaggio(uuid) set schema privato;
alter function public.aggiorna_riga() set schema privato;
alter function public.controlla_eta_utente() set schema privato;
alter function public.viaggio_crea_partecipazione() set schema privato;
alter function public.genera_codice_invito() set schema privato;
