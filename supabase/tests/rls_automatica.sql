-- Prova della funzione public.rls_auto_enable() dopo la migrazione
-- rls_automatica.sql: anon e authenticated non la eseguono più, e il trigger
-- di eventi ensure_rls accende ancora da solo le regole di accesso su una
-- tabella nuova in public.
--
-- Come le altre: gira dentro un blocco che alla fine solleva un'eccezione e
-- non lascia niente, nemmeno la tabella di prova. Il messaggio finale è il
-- resoconto. Va lanciata dall'editor SQL, come proprietario.

do $$
declare
  log text := '';
begin
  if to_regprocedure('public.rls_auto_enable()') is null then
    raise exception 'PASSATE%', E'\nok  la funzione non c''è: niente da provare';
  end if;

  if has_function_privilege('anon', 'public.rls_auto_enable()', 'execute')
     or has_function_privilege('authenticated', 'public.rls_auto_enable()', 'execute') then
    raise exception 'FALLITA: anon o authenticated eseguono ancora rls_auto_enable';
  end if;
  log := log || E'\nok  anon e authenticated non la eseguono';

  if not exists (
    select 1 from pg_event_trigger
    where evtname = 'ensure_rls'
      and evtfoid = 'public.rls_auto_enable()'::regprocedure
      and evtenabled <> 'D'
  ) then
    raise exception 'FALLITA: il trigger di eventi ensure_rls non c''è o è spento';
  end if;

  create table public.prova_rls_automatica (id int);
  if not (select relrowsecurity from pg_class where oid = 'public.prova_rls_automatica'::regclass) then
    raise exception 'FALLITA: la tabella nuova è nata senza regole di accesso';
  end if;
  log := log || E'\nok  una tabella nuova nasce con le regole di accesso accese';

  raise exception 'PASSATE%', log;
end;
$$;
