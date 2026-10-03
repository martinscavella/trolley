-- L'itinerario con un assistente (fase 1.6, 04-itinerario.md, regole 7–14).
-- Trolley non chiama nessun modello: prepara la richiesta, la persona la porta
-- sul suo assistente e incolla qui la risposta. Servono due cose che lo schema
-- non aveva: le note del viaggio, dove il testo incollato si salva sempre, e
-- una configurazione che si cambia senza un rilascio, per dire quali modelli
-- consigliare.

-- ─── Le note del viaggio ──────────────────────────────────────────────────

-- Il testo incollato si salva sempre, anche quando non si riesce a leggerlo:
-- nessuno deve rifare il giro da capo (04, regola 11). È una nota del viaggio,
-- e la vede chi ci partecipa, come le tappe che ne nascono.
create table public.nota (
  id uuid primary key default gen_random_uuid(),
  viaggio_id uuid not null references public.viaggio (id),
  -- Una risposta lunga di un assistente sta comoda in ventimila caratteri.
  testo text not null check (length(trim(testo)) > 0 and length(testo) <= 20000),
  -- `incollata` se viene dalla risposta di un assistente; `scritta` per quelle
  -- che si scriveranno a mano (02-il-viaggio.md, regola 2).
  origine text not null default 'scritta' check (origine in ('scritta', 'incollata')),
  creato_da uuid not null default auth.uid() references public.utente (id),
  creato_il timestamptz not null default now(),
  modificato_il timestamptz not null default now(),
  eliminato_il timestamptz,
  versione integer not null default 1
);

create trigger nota_aggiorna before update on public.nota
  for each row execute function privato.aggiorna_riga();

create index nota_viaggio on public.nota (viaggio_id);
create index nota_creato_da on public.nota (creato_da);

alter table public.nota enable row level security;
revoke all on public.nota from anon, authenticated;
grant select on public.nota to authenticated;
-- Di una nota si cambia il testo, e la si toglie. Non di chi è, non da dove
-- viene, non in che viaggio sta.
grant insert (id, viaggio_id, testo, origine, creato_da) on public.nota to authenticated;
grant update (testo, eliminato_il, versione) on public.nota to authenticated;

create policy "la leggono i partecipanti" on public.nota
  for select to authenticated
  using (privato.e_partecipante(viaggio_id));
create policy "la scrive un partecipante, a suo nome" on public.nota
  for insert to authenticated
  with check (privato.e_partecipante(viaggio_id) and creato_da = (select auth.uid()));
create policy "la cambiano i partecipanti" on public.nota
  for update to authenticated
  using (privato.e_partecipante(viaggio_id))
  with check (privato.e_partecipante(viaggio_id));

-- ─── La configurazione ────────────────────────────────────────────────────

-- Quello che cambia più spesso dell'app e non deve aspettare un rilascio: per
-- primi i modelli da consigliare, che cambiano nome di continuo (decisioni/
-- prodotto.md, "Quali modelli suggerire"). La legge chi ha un accesso; la
-- scrive solo chi gestisce il progetto, dal pannello di Supabase.
create table public.configurazione (
  chiave text primary key check (chiave ~ '^[a-z_]+$'),
  valore jsonb not null,
  aggiornata_il timestamptz not null default now()
);

alter table public.configurazione enable row level security;
revoke all on public.configurazione from anon, authenticated;
grant select on public.configurazione to authenticated;

create policy "la legge chiunque abbia un accesso" on public.configurazione
  for select to authenticated using (true);

-- Fascia medio-alta: il livello dei modelli a pagamento dei principali
-- assistenti, non quelli gratuiti e leggeri. Una frase per riga, così come si
-- mostra.
insert into public.configurazione (chiave, valore) values
  ('modelli_suggeriti',
   '["Claude Sonnet 5 o superiore", "il modello di punta a pagamento di ChatGPT o di Gemini"]'::jsonb);
