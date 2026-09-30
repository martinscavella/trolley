-- Con un conflitto, on conflict do nothing richiede che la riga esistente sia visibile
-- a chi scrive. Si vede solo la propria, e di quella solo l'id (permesso per colonna).
create policy "si riconoscono solo i propri eventi" on public.evento
  for select to authenticated
  using (utente_id = (select auth.uid()));
