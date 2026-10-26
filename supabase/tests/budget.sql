-- Prova del budget del viaggio (06, regole 12–17): lo mettono e lo cambiano
-- i partecipanti, non gli estranei; senza valuta, o a zero, non c'è.
--
-- Come regole_di_accesso.sql: gira dentro un blocco che alla fine solleva
-- un'eccezione e non lascia niente. Il messaggio finale è il resoconto.

do $$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  d uuid := gen_random_uuid();
  v uuid := gen_random_uuid();
  t text;
  n int;
  fallita boolean;
  log text := '';
begin
  insert into auth.users (id, email) values
    (a, a || '@prova.local'), (b, b || '@prova.local'), (d, d || '@prova.local');

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (d, 'Dario', '1990-01-01');

  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (a, 'Giulia', '1995-04-02');
  perform public.crea_viaggio(v, 'Giappone', 'JP', 'autunno', null, null, null, null, '[]'::jsonb);
  insert into public.invito (viaggio_id) values (v) returning token into t;

  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  insert into public.utente (id, nome, data_nascita) values (b, 'Marco', '1994-07-20');
  perform public.accetta_invito(t);

  -- ── Allo stato idea lo mette chi crea, lo cambia chi partecipa ──────────
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  update public.viaggio set budget_importo = 2500, budget_valuta = 'EUR' where id = v;
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  update public.viaggio set budget_importo = 2800.50 where id = v;
  select count(*) into n from public.viaggio where id = v and budget_importo = 2800.50 and budget_valuta = 'EUR';
  if n <> 1 then raise exception 'FALLITA: chi partecipa non cambia il budget'; end if;
  log := log || E'\nok  lo mettono e lo cambiano i partecipanti, anche da idea';

  -- ── Un estraneo non lo tocca ────────────────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  update public.viaggio set budget_importo = 1 where id = v;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  select count(*) into n from public.viaggio where id = v and budget_importo = 2800.50;
  if n <> 1 then raise exception 'FALLITA: un estraneo cambia il budget'; end if;
  log := log || E'\nok  un estraneo non lo tocca';

  -- ── Senza valuta, a zero o con una valuta strana non c'è ────────────────
  fallita := false;
  begin
    update public.viaggio set budget_valuta = null where id = v;
  exception when check_violation then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un budget senza valuta'; end if;
  fallita := false;
  begin
    update public.viaggio set budget_importo = 0 where id = v;
  exception when check_violation then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: un budget a zero'; end if;
  fallita := false;
  begin
    update public.viaggio set budget_valuta = 'euro' where id = v;
  exception when check_violation then fallita := true;
  end;
  if not fallita then raise exception 'FALLITA: una valuta che non è un codice'; end if;
  log := log || E'\nok  senza valuta, a zero o con una valuta strana no';

  -- ── Si toglie, tutti e due insieme ──────────────────────────────────────
  update public.viaggio set budget_importo = null, budget_valuta = null where id = v;
  select count(*) into n from public.viaggio where id = v and budget_importo is null;
  if n <> 1 then raise exception 'FALLITA: il budget non si toglie'; end if;
  log := log || E'\nok  si toglie';

  raise exception 'PASSATE%', log;
end;
$$;
