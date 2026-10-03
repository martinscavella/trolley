-- Le cose da portare (fase 1.5, 05-cose-da-portare.md). La tabella c'è dallo
-- schema iniziale; qui arrivano quante, e regole più strette su cosa si può
-- cambiare di una voce e a chi la si può assegnare.

-- ─── Quante ───────────────────────────────────────────────────────────────

-- "Voce — cosa, quante, chi la porta" (05, schermate): cinque magliette sono
-- una voce, non cinque.
alter table public.voce_lista
  add column quantita smallint not null default 1 check (quantita between 1 and 99);

-- Un testo è una cosa da portare, non una nota: lungo al massimo una riga
-- abbondante.
alter table public.voce_lista
  add constraint voce_lista_testo_breve check (length(testo) <= 200);

-- Una voce personale è di chi la scrive e nessun altro la vede (05, regole 1–3):
-- non si assegna a nessuno.
alter table public.voce_lista
  add constraint voce_lista_personale_senza_assegnatario
  check (tipo = 'viaggio' or assegnato_a is null);

-- ─── Cosa si scrive ───────────────────────────────────────────────────────

-- Di una voce si cambiano il testo, quante, chi la porta, la spunta, e la si
-- toglie. Non di chi è, non in che lista sta, non in che viaggio: una voce del
-- viaggio che diventasse personale sparirebbe agli altri, e una personale
-- passata a un altro proprietario gli finirebbe davanti.
revoke insert, update on public.voce_lista from authenticated;
grant insert (id, viaggio_id, testo, tipo, quantita, proprietario_id, assegnato_a,
              spuntata, creato_da)
  on public.voce_lista to authenticated;
grant update (testo, quantita, assegnato_a, spuntata, eliminato_il, versione)
  on public.voce_lista to authenticated;

-- Chi porta una voce è qualcuno del viaggio: anche chi è uscito, perché le sue
-- voci restano finché non tornano libere (05, casi limite); non un estraneo.
drop policy "la aggiunge un partecipante, a suo nome" on public.voce_lista;
drop policy "la modificano i partecipanti, se non è personale" on public.voce_lista;

create policy "la aggiunge un partecipante, a suo nome" on public.voce_lista
  for insert to authenticated
  with check (privato.e_partecipante(viaggio_id)
              and proprietario_id = (select auth.uid())
              and creato_da = (select auth.uid())
              and (assegnato_a is null
                   or exists (select 1 from public.partecipazione p
                               where p.viaggio_id = voce_lista.viaggio_id
                                 and p.utente_id = voce_lista.assegnato_a)));
create policy "la modificano i partecipanti, se non è personale" on public.voce_lista
  for update to authenticated
  using (privato.e_partecipante(viaggio_id)
         and (tipo = 'viaggio' or proprietario_id = (select auth.uid())))
  with check (privato.e_partecipante(viaggio_id)
              and (tipo = 'viaggio' or proprietario_id = (select auth.uid()))
              and (assegnato_a is null
                   or exists (select 1 from public.partecipazione p
                               where p.viaggio_id = voce_lista.viaggio_id
                                 and p.utente_id = voce_lista.assegnato_a)));
