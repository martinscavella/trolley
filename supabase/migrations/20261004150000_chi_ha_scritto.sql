-- Chi ha scritto l'ultima versione (fase 2.2, i conflitti).
--
-- Quando due persone cambiano la stessa cosa, l'app mostra le due versioni con
-- chi ha scritto e quando: «di Marco, salvata alle 18:42» (02 §3). Il quando
-- c'era già (modificato_il); il chi lo scrive il server, non il telefono, così
-- nessuno lo dichiara a nome di un altro.
--
-- Solo sulle cose che si possono trovare in due versioni: viaggio, tappa,
-- spesa, voce_lista, nota. È un trigger a parte, e non un passo in più di
-- aggiorna_riga: quella vale per tutte le tabelle, e non tutte hanno la colonna.

alter table public.viaggio add column modificato_da uuid;
alter table public.tappa add column modificato_da uuid;
alter table public.spesa add column modificato_da uuid;
alter table public.voce_lista add column modificato_da uuid;
alter table public.nota add column modificato_da uuid;

-- Le righe che ci sono già: l'ultima versione nota è di chi le ha create. Con
-- aggiorna_riga spento, così versione e modificato_il restano quelle che sono:
-- i telefoni non vedono cambiare niente.
alter table public.viaggio disable trigger viaggio_aggiorna;
alter table public.tappa disable trigger tappa_aggiorna;
alter table public.spesa disable trigger spesa_aggiorna;
alter table public.voce_lista disable trigger voce_lista_aggiorna;
alter table public.nota disable trigger nota_aggiorna;

update public.viaggio set modificato_da = creato_da;
update public.tappa set modificato_da = creato_da;
update public.spesa set modificato_da = creato_da;
update public.voce_lista set modificato_da = creato_da;
update public.nota set modificato_da = creato_da;

alter table public.viaggio enable trigger viaggio_aggiorna;
alter table public.tappa enable trigger tappa_aggiorna;
alter table public.spesa enable trigger spesa_aggiorna;
alter table public.voce_lista enable trigger voce_lista_aggiorna;
alter table public.nota enable trigger nota_aggiorna;

-- Chi scrive è chi ha l'accesso della richiesta, anche dentro le funzioni
-- security definer (programma_viaggio, passa_il_ruolo). Senza accesso — un
-- lavoro del server — resta vuoto: meglio nessun nome che uno sbagliato.
create function privato.segna_autore()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.modificato_da := auth.uid();
  return new;
end;
$$;

revoke execute on function privato.segna_autore() from public, anon, authenticated;

create trigger viaggio_autore before insert or update on public.viaggio
  for each row execute function privato.segna_autore();
create trigger tappa_autore before insert or update on public.tappa
  for each row execute function privato.segna_autore();
create trigger spesa_autore before insert or update on public.spesa
  for each row execute function privato.segna_autore();
create trigger voce_lista_autore before insert or update on public.voce_lista
  for each row execute function privato.segna_autore();
create trigger nota_autore before insert or update on public.nota
  for each row execute function privato.segna_autore();
