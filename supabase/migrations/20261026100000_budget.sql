-- Il budget del viaggio (06, regole 12–17; decisioni, «Il budget»): quanto
-- si pensa di spendere in tutto, insieme. Allo stato idea è il budget di
-- massima, e resta quando arrivano le date. Lo cambia chiunque partecipi,
-- come le date; non ha due versioni: vince l'ultimo. Il budget di ciascuno
-- non è qui: sta solo sul suo telefono.

alter table public.viaggio
  add column budget_importo numeric(12, 2) check (budget_importo > 0),
  add column budget_valuta text check (budget_valuta ~ '^[A-Z]{3}$'),
  add constraint budget_con_la_valuta
    check ((budget_importo is null) = (budget_valuta is null));

grant insert (budget_importo, budget_valuta),
      update (budget_importo, budget_valuta)
  on public.viaggio to authenticated;
