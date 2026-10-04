-- La lista del viaggio (fase 2.4, 05-cose-da-portare.md): chi porta cosa, le
-- voci che tornano libere quando chi le portava lascia il viaggio, e lo
-- spostamento di una voce da una lista all'altra.
--
-- Le voci del viaggio e l'assegnatario ci sono dallo schema iniziale, e la
-- regola di lettura delle personali dalla 1.5. Qui arrivano tre cose:
-- - chi porta una voce è qualcuno che è nel viaggio adesso. Nella 1.5 bastava
--   esserci passati, perché le voci di chi usciva restavano sue finché non
--   tornavano libere: ora tornano libere nel momento stesso in cui esce, dentro
--   esci_dal_viaggio e rimuovi_partecipante, e un assegnatario uscito non
--   esiste più;
-- - lasciata_da: chi la portava quando ha lasciato il viaggio. Serve all'avviso
--   «Luca ha lasciato il viaggio: … sono tornate libere» (05, casi limite), e si
--   vuota da sé quando qualcuno la prende. La scrive solo il server;
-- - sposta_voce: una voce non cambia mai lista (cose_da_portare.sql), perché una
--   voce del viaggio diventata personale sparirebbe agli altri senza che la loro
--   copia lo sappia. Spostarla è toglierla da una lista e farne nascere una
--   nuova nell'altra, insieme o niente: chi aveva la vecchia la vede togliere,
--   come ogni voce tolta.
--
-- Chi può spostare cosa (solo una voce libera o propria) è una regola di
-- dominio: la controlla l'app (ADR-003). Togliere una voce del viaggio lo può
-- già chiunque partecipi.

-- ─── Chi la portava ───────────────────────────────────────────────────────

alter table public.voce_lista
  add column lasciata_da uuid references public.utente (id);

create index voce_lista_lasciata on public.voce_lista (lasciata_da);

-- Una voce presa da qualcuno non è più «tornata libera»: l'avviso non la conta.
create function privato.voce_presa()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.assegnato_a is not null then
    new.lasciata_da := null;
  end if;
  return new;
end;
$$;

revoke execute on function privato.voce_presa() from public, anon, authenticated;

create trigger voce_lista_presa before insert or update on public.voce_lista
  for each row execute function privato.voce_presa();

-- ─── Chi porta una voce ───────────────────────────────────────────────────

-- Chi è nel viaggio adesso: non un estraneo, e non più chi è uscito o è stato
-- tolto.
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
                                 and p.utente_id = voce_lista.assegnato_a
                                 and p.stato = 'attivo'
                                 and p.eliminato_il is null)));
create policy "la modificano i partecipanti, se non è personale" on public.voce_lista
  for update to authenticated
  using (privato.e_partecipante(viaggio_id)
         and (tipo = 'viaggio' or proprietario_id = (select auth.uid())))
  with check (privato.e_partecipante(viaggio_id)
              and (tipo = 'viaggio' or proprietario_id = (select auth.uid()))
              and (assegnato_a is null
                   or exists (select 1 from public.partecipazione p
                               where p.viaggio_id = voce_lista.viaggio_id
                                 and p.utente_id = voce_lista.assegnato_a
                                 and p.stato = 'attivo'
                                 and p.eliminato_il is null)));

-- Le voci che oggi portasse già qualcuno uscito tornano libere: nella 1.5
-- nascevano tutte personali, quindi di norma non ce n'è nessuna.
update public.voce_lista vl
   set lasciata_da = vl.assegnato_a, assegnato_a = null
 where vl.assegnato_a is not null
   and not exists (select 1 from public.partecipazione p
                    where p.viaggio_id = vl.viaggio_id
                      and p.utente_id = vl.assegnato_a
                      and p.stato = 'attivo'
                      and p.eliminato_il is null);

-- Le voci che [p_utente] portava in [p_viaggio] tornano libere, anche quelle
-- tolte: se qualcuno le rimette, non tornano a un assegnatario che non c'è.
-- Restituisce le righe cambiate, come le mette nella copia l'app.
create function privato.libera_voci(p_viaggio uuid, p_utente uuid)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  with liberate as (
    update public.voce_lista
       set lasciata_da = assegnato_a, assegnato_a = null
     where viaggio_id = p_viaggio and assegnato_a = p_utente
    returning *
  )
  select coalesce(jsonb_agg(to_jsonb(l)), '[]'::jsonb) from liberate l;
$$;

revoke execute on function privato.libera_voci(uuid, uuid) from public, anon, authenticated;

-- ─── Uscire e togliere qualcuno ───────────────────────────────────────────

-- Come in partecipanti.sql, più le voci che tornano libere.
create or replace function public.esci_dal_viaggio(p_viaggio uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_io uuid := (select auth.uid());
  v_ruolo text;
begin
  if v_io is null then
    raise exception 'accesso richiesto' using errcode = 'TR401';
  end if;
  select ruolo into v_ruolo
    from public.partecipazione
   where viaggio_id = p_viaggio and utente_id = v_io
     and stato = 'attivo' and eliminato_il is null
   for update;
  if v_ruolo is null then
    raise exception 'non partecipi a questo viaggio' using errcode = 'TR404';
  end if;
  if v_ruolo = 'creatore' then
    raise exception 'prima passa il ruolo a qualcun altro' using errcode = 'TR412';
  end if;
  update public.partecipazione
     set stato = 'uscito'
   where viaggio_id = p_viaggio and utente_id = v_io;
  perform privato.libera_voci(p_viaggio, v_io);
end;
$$;

-- Come in partecipanti.sql, più le voci che tornano libere: arrivano con le
-- righe del viaggio, perché la copia di chi toglie le mostri subito libere.
create or replace function public.rimuovi_partecipante(p_viaggio uuid, p_utente uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_io uuid := (select auth.uid());
  v_voci jsonb;
begin
  if v_io is null then
    raise exception 'accesso richiesto' using errcode = 'TR401';
  end if;
  perform 1
     from public.partecipazione
    where viaggio_id = p_viaggio and utente_id = v_io
      and ruolo = 'creatore' and stato = 'attivo' and eliminato_il is null
    for update;
  if not found then
    raise exception 'solo chi è responsabile del viaggio toglie qualcuno'
      using errcode = 'TR403';
  end if;
  update public.partecipazione
     set stato = 'rimosso'
   where viaggio_id = p_viaggio and utente_id = p_utente
     and ruolo = 'partecipante' and stato = 'attivo' and eliminato_il is null;
  if not found then
    raise exception 'non partecipa a questo viaggio' using errcode = 'TR404';
  end if;
  update public.invito
     set eliminato_il = now()
   where viaggio_id = p_viaggio and eliminato_il is null;
  v_voci := privato.libera_voci(p_viaggio, p_utente);
  -- Le personali di chi è tolto non sono mai assegnate: fra le liberate
  -- ci sono solo voci del viaggio, che chi toglie può leggere.
  return privato.righe_del_viaggio(p_viaggio) || jsonb_build_object('voci', v_voci);
end;
$$;

-- ─── Spostare una voce ────────────────────────────────────────────────────

-- Toglie [p_voce] dalla sua lista, sulla versione [p_versione] che la persona
-- ha visto, e fa nascere [p_nuova] nell'altra con lo stesso testo, quante e
-- spunta. Nella lista del viaggio la porta chi la sposta, che la teneva fra le
-- sue; in quella personale non la porta nessuno, per definizione.
--
-- Con l'accesso di chi chiama: le regole di accesso valgono per tutti e due i
-- passi, come se li facesse a mano. Se la voce è cambiata intanto il server
-- rifiuta (TR409, aggiorna_riga), come ogni modifica (02 §3). Se [p_nuova]
-- c'è già lo spostamento era arrivato e la risposta si era persa: si
-- restituiscono le due righe com'erano.
create function public.sposta_voce(p_voce uuid, p_versione integer, p_nuova uuid)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_io uuid := (select auth.uid());
  v_vecchia public.voce_lista;
  v_nuova public.voce_lista;
begin
  if v_io is null then
    raise exception 'accesso richiesto' using errcode = 'TR401';
  end if;
  select * into v_nuova from public.voce_lista where id = p_nuova;
  if found then
    select * into v_vecchia from public.voce_lista where id = p_voce;
    return jsonb_build_object('vecchia', to_jsonb(v_vecchia), 'nuova', to_jsonb(v_nuova));
  end if;

  update public.voce_lista
     set eliminato_il = now(), versione = p_versione
   where id = p_voce and eliminato_il is null
  returning * into v_vecchia;
  if not found then
    raise exception 'voce non trovata' using errcode = 'TR404';
  end if;

  insert into public.voce_lista
    (id, viaggio_id, testo, tipo, quantita, proprietario_id, assegnato_a,
     spuntata, creato_da)
  values
    (p_nuova, v_vecchia.viaggio_id, v_vecchia.testo,
     case v_vecchia.tipo when 'viaggio' then 'personale' else 'viaggio' end,
     v_vecchia.quantita, v_io,
     case v_vecchia.tipo when 'viaggio' then null else v_io end,
     v_vecchia.spuntata, v_io)
  returning * into v_nuova;

  return jsonb_build_object('vecchia', to_jsonb(v_vecchia), 'nuova', to_jsonb(v_nuova));
end;
$$;

revoke execute on function public.sposta_voce(uuid, integer, uuid) from public, anon;
grant execute on function public.sposta_voce(uuid, integer, uuid) to authenticated;
