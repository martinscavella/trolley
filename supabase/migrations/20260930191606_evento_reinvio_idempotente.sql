-- Gli eventi partono a lotti e un lotto può ripartire (07-misurazione.md: idempotenti).
-- insert ... on conflict (id) do nothing richiede il permesso di lettura sulla colonna
-- del conflitto. Lo si concede solo su id: senza una policy di lettura le righe
-- restano comunque invisibili all'app.
grant select (id) on public.evento to authenticated;
