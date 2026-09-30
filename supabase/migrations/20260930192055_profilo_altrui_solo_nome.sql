-- Chi condivide un viaggio vede il nome dei compagni, non la loro data di nascita,
-- il telefono verificato o se l'account è interno. Il proprio profilo completo si
-- legge con mio_profilo().
revoke select on public.utente from authenticated;
grant select (id, nome, versione, eliminato_il) on public.utente to authenticated;

create function public.mio_profilo()
returns setof public.utente
language sql
stable
security definer
set search_path = ''
as $$
  select * from public.utente where id = (select auth.uid());
$$;

revoke execute on function public.mio_profilo() from public, anon;
grant execute on function public.mio_profilo() to authenticated;
