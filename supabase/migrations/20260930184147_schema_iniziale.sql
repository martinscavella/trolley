-- Schema iniziale: le entità delle fasi 0–2 (docs/tecnico/01-modello-dati.md).
-- La parte pubblica, i traguardi e il mappamondo arrivano con le loro fasi.
--
-- Convenzioni
-- - Ogni entità sincronizzata ha id generato dal client, creato_da, creato_il,
--   modificato_il, eliminato_il (si cancella marcando, mai togliendo la riga) e versione.
-- - Il server non conosce le regole di dominio: custodisce i dati e fa rispettare
--   chi può leggere e scrivere cosa (ADR-003).
-- - Nessuna policy di DELETE: le cancellazioni sono aggiornamenti di eliminato_il.

-- ─── Versione e colonne immutabili ─────────────────────────────────────────

-- Una modifica che porta la versione su cui è stata fatta viene rifiutata se il
-- server è andato avanti (02-sincronizzazione-e-offline.md §3). Una modifica che
-- non tocca la versione — i quattro gesti della coda — passa sempre: sono aggiunte
-- o cambi di stato ripetibili, e per loro vince l'ultima che arriva.
create function public.aggiorna_riga()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.versione is distinct from old.versione then
    raise exception 'versione superata: attesa %, ricevuta %', old.versione, new.versione
      using errcode = 'TR409';
  end if;
  new.versione := old.versione + 1;
  new.modificato_il := now();
  new.id := old.id;
  new.creato_da := old.creato_da;
  new.creato_il := old.creato_il;
  return new;
end;
$$;

-- ─── Persone ───────────────────────────────────────────────────────────────

create table public.utente (
  id uuid primary key references auth.users (id) on delete cascade,
  nome text not null check (length(trim(nome)) > 0),
  data_nascita date not null,
  telefono_verificato boolean not null default false,
  valuta_predefinita char(3) not null default 'EUR',
  profilo_pubblico_attivo boolean not null default false,
  interno boolean not null default false,
  creato_da uuid not null default auth.uid(),
  creato_il timestamptz not null default now(),
  modificato_il timestamptz not null default now(),
  eliminato_il timestamptz,
  versione integer not null default 1,
  constraint pubblico_richiede_telefono
    check (not profilo_pubblico_attivo or telefono_verificato)
);

-- Sotto i 16 anni un utente non esiste; sotto i 18 non esiste la parte pubblica.
-- È un trigger e non un vincolo perché dipende dalla data di oggi.
create function public.controlla_eta_utente()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' and new.data_nascita > current_date - interval '16 years' then
    raise exception 'servono 16 anni compiuti' using errcode = 'TR403';
  end if;
  if new.profilo_pubblico_attivo and new.data_nascita > current_date - interval '18 years' then
    raise exception 'il profilo pubblico richiede 18 anni compiuti' using errcode = 'TR403';
  end if;
  return new;
end;
$$;

create trigger utente_eta before insert or update on public.utente
  for each row execute function public.controlla_eta_utente();
create trigger utente_aggiorna before update on public.utente
  for each row execute function public.aggiorna_riga();

-- ─── Il viaggio ────────────────────────────────────────────────────────────

create table public.viaggio (
  id uuid primary key default gen_random_uuid(),
  stato text not null default 'idea'
    check (stato in ('idea', 'definito', 'in_corso', 'chiuso', 'archiviato')),
  destinazione_citta text,
  destinazione_paese char(2),
  periodo_approssimativo text,
  data_inizio date,
  data_fine date,
  ora_arrivo time,
  ora_partenza time,
  creatore_id uuid not null references public.utente (id),
  importato boolean not null default false,
  verificato boolean not null default false,
  verifica_per_deroga boolean not null default false,
  creato_da uuid not null default auth.uid() references public.utente (id),
  creato_il timestamptz not null default now(),
  modificato_il timestamptz not null default now(),
  eliminato_il timestamptz,
  versione integer not null default 1,
  constraint definito_ha_date check (
    stato = 'idea'
    or (data_inizio is not null and data_fine is not null
        and ora_arrivo is not null and ora_partenza is not null)
  ),
  constraint date_in_ordine check (data_fine >= data_inizio),
  constraint importato_chiuso_non_verificato
    check (not importato or (stato = 'chiuso' and not verificato))
);

create trigger viaggio_aggiorna before update on public.viaggio
  for each row execute function public.aggiorna_riga();

create table public.partecipazione (
  id uuid primary key default gen_random_uuid(),
  viaggio_id uuid not null references public.viaggio (id),
  utente_id uuid not null references public.utente (id),
  ruolo text not null check (ruolo in ('creatore', 'partecipante')),
  stato text not null default 'attivo'
    check (stato in ('invitato', 'attivo', 'uscito', 'rimosso')),
  creato_da uuid not null default auth.uid(),
  creato_il timestamptz not null default now(),
  modificato_il timestamptz not null default now(),
  eliminato_il timestamptz,
  versione integer not null default 1,
  unique (viaggio_id, utente_id)
);

-- Esiste sempre esattamente un creatore attivo.
create unique index un_creatore_per_viaggio on public.partecipazione (viaggio_id)
  where ruolo = 'creatore' and stato = 'attivo';

create trigger partecipazione_aggiorna before update on public.partecipazione
  for each row execute function public.aggiorna_riga();

-- Chi crea il viaggio ne diventa subito il creatore attivo.
create function public.viaggio_crea_partecipazione()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.partecipazione (viaggio_id, utente_id, ruolo, stato, creato_da)
  values (new.id, new.creatore_id, 'creatore', 'attivo', new.creatore_id);
  return new;
end;
$$;

create trigger viaggio_creatore after insert on public.viaggio
  for each row execute function public.viaggio_crea_partecipazione();

create table public.giorno (
  id uuid primary key default gen_random_uuid(),
  viaggio_id uuid not null references public.viaggio (id),
  data date not null,
  finestra_inizio time not null,
  finestra_fine time not null,
  creato_da uuid not null default auth.uid(),
  creato_il timestamptz not null default now(),
  modificato_il timestamptz not null default now(),
  eliminato_il timestamptz,
  versione integer not null default 1,
  unique (viaggio_id, data),
  unique (id, viaggio_id),
  check (finestra_fine > finestra_inizio)
);

create trigger giorno_aggiorna before update on public.giorno
  for each row execute function public.aggiorna_riga();

create table public.tappa (
  id uuid primary key default gen_random_uuid(),
  viaggio_id uuid not null,
  giorno_id uuid not null,
  ordine integer not null,
  titolo text not null check (length(trim(titolo)) > 0),
  luogo_nome text,
  lat double precision check (lat between -90 and 90),
  lon double precision check (lon between -180 and 180),
  durata_stimata_min integer not null check (durata_stimata_min > 0),
  ora_inizio time,
  stato text not null default 'da_fare' check (stato in ('da_fare', 'completata', 'saltata')),
  marcata_il timestamptz,
  marcata_durante_il_viaggio boolean not null default false,
  -- Aggiunta offline quando la giornata era già piena (02 §2): entra lo stesso, segnalata.
  eccedente boolean not null default false,
  creato_da uuid not null default auth.uid(),
  creato_il timestamptz not null default now(),
  modificato_il timestamptz not null default now(),
  eliminato_il timestamptz,
  versione integer not null default 1,
  foreign key (giorno_id, viaggio_id) references public.giorno (id, viaggio_id),
  check ((lat is null) = (lon is null))
);

create trigger tappa_aggiorna before update on public.tappa
  for each row execute function public.aggiorna_riga();

-- Il token è un link, non una credenziale: chi lo riceve entra (03-partecipanti-e-inviti.md).
-- Otto caratteri senza quelli che si confondono, perché si deve poter anche digitare.
create function public.genera_codice_invito()
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  alfabeto constant text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  byte_casuali bytea := extensions.gen_random_bytes(8);
  codice text := '';
begin
  for i in 0..7 loop
    codice := codice || substr(alfabeto, 1 + get_byte(byte_casuali, i) % length(alfabeto), 1);
  end loop;
  return codice;
end;
$$;

create table public.invito (
  id uuid primary key default gen_random_uuid(),
  viaggio_id uuid not null references public.viaggio (id),
  token text not null unique default public.genera_codice_invito(),
  creato_da uuid not null default auth.uid(),
  creato_il timestamptz not null default now(),
  modificato_il timestamptz not null default now(),
  eliminato_il timestamptz,
  versione integer not null default 1
);

create trigger invito_aggiorna before update on public.invito
  for each row execute function public.aggiorna_riga();

-- ─── Spese ─────────────────────────────────────────────────────────────────

create table public.spesa (
  id uuid primary key default gen_random_uuid(),
  viaggio_id uuid not null references public.viaggio (id),
  importo numeric(12, 2) not null check (importo > 0),
  valuta char(3) not null,
  tasso_usato numeric(18, 8),
  tasso_al timestamptz,
  pagante_id uuid not null references public.utente (id),
  data date not null,
  descrizione text,
  creato_da uuid not null default auth.uid(),
  creato_il timestamptz not null default now(),
  modificato_il timestamptz not null default now(),
  eliminato_il timestamptz,
  versione integer not null default 1,
  unique (id, viaggio_id),
  -- Una conversione senza la sua data è una bugia.
  check ((tasso_usato is null) = (tasso_al is null))
);

create trigger spesa_aggiorna before update on public.spesa
  for each row execute function public.aggiorna_riga();

create table public.spesa_quota (
  id uuid primary key default gen_random_uuid(),
  viaggio_id uuid not null,
  spesa_id uuid not null,
  utente_id uuid not null references public.utente (id),
  quota numeric(12, 2) not null check (quota >= 0),
  creato_da uuid not null default auth.uid(),
  creato_il timestamptz not null default now(),
  modificato_il timestamptz not null default now(),
  eliminato_il timestamptz,
  versione integer not null default 1,
  foreign key (spesa_id, viaggio_id) references public.spesa (id, viaggio_id),
  unique (spesa_id, utente_id)
);

create trigger spesa_quota_aggiorna before update on public.spesa_quota
  for each row execute function public.aggiorna_riga();

-- ─── Liste ─────────────────────────────────────────────────────────────────

create table public.voce_lista (
  id uuid primary key default gen_random_uuid(),
  viaggio_id uuid not null references public.viaggio (id),
  testo text not null check (length(trim(testo)) > 0),
  tipo text not null check (tipo in ('viaggio', 'personale')),
  proprietario_id uuid not null default auth.uid() references public.utente (id),
  assegnato_a uuid references public.utente (id),
  spuntata boolean not null default false,
  creato_da uuid not null default auth.uid(),
  creato_il timestamptz not null default now(),
  modificato_il timestamptz not null default now(),
  eliminato_il timestamptz,
  versione integer not null default 1
);

create trigger voce_lista_aggiorna before update on public.voce_lista
  for each row execute function public.aggiorna_riga();

-- ─── Misurazione ───────────────────────────────────────────────────────────

-- 07-misurazione.md: azioni, mai contenuti. Idempotente sull'id generato dal client.
-- avvenuto_il è l'orario del gesto, non quello dell'invio.
create table public.evento (
  id uuid primary key,
  utente_id uuid not null default auth.uid() references public.utente (id) on delete cascade,
  nome text not null,
  proprieta jsonb not null default '{}',
  avvenuto_il timestamptz not null,
  ricevuto_il timestamptz not null default now(),
  versione_app text
);

create index evento_nome_avvenuto on public.evento (nome, avvenuto_il);

-- ─── Indici per le regole di accesso ──────────────────────────────────────

create index partecipazione_utente on public.partecipazione (utente_id, viaggio_id) where stato = 'attivo';
create index giorno_viaggio on public.giorno (viaggio_id);
create index tappa_viaggio on public.tappa (viaggio_id);
create index tappa_giorno on public.tappa (giorno_id, viaggio_id);
create index invito_viaggio on public.invito (viaggio_id);
create index spesa_viaggio on public.spesa (viaggio_id);
create index spesa_pagante on public.spesa (pagante_id);
create index spesa_quota_spesa on public.spesa_quota (spesa_id, viaggio_id);
create index spesa_quota_utente on public.spesa_quota (utente_id);
create index voce_lista_viaggio on public.voce_lista (viaggio_id);
create index voce_lista_proprietario on public.voce_lista (proprietario_id);
create index voce_lista_assegnato on public.voce_lista (assegnato_a);
create index viaggio_creatore_idx on public.viaggio (creatore_id);
create index viaggio_creato_da on public.viaggio (creato_da);
create index evento_utente on public.evento (utente_id);
