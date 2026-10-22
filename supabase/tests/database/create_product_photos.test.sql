-- create_product is all-or-nothing and owner-only; product photos follow the same rules per business folder.
begin;
select plan(11);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'ana@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'beto@example.test'),
  ('33333333-3333-3333-3333-333333333333', 'carla@example.test');
insert into public.businesses (id, name, type) values
  ('b0000000-0000-0000-0000-00000000000a', 'Tienda Lupita', 'clothing');
insert into public.memberships (business_id, user_id, role) values
  ('b0000000-0000-0000-0000-00000000000a', '11111111-1111-1111-1111-111111111111', 'owner'),
  ('b0000000-0000-0000-0000-00000000000a', '33333333-3333-3333-3333-333333333333', 'employee');

set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

select lives_ok($$
  select public.create_product('b0000000-0000-0000-0000-00000000000a', ' Playera básica ', 'Playeras', '{}',
    '[{"attrs":{"talla":"M","color":"Negro"},"price_cents":24900,"cost_cents":11000,"stock":5},
      {"attrs":{"talla":"G","color":"Negro"},"price_cents":24900,"cost_cents":11000,"stock":0}]')
$$, 'the owner creates a product with two variants');
select results_eq($$ select name from public.products $$, $$ values ('Playera básica') $$, 'the name is trimmed');
select results_eq($$ select count(*)::int from public.variants where sku like 'SKU-%' $$, $$ values (2) $$,
  'missing SKUs are generated');
select results_eq($$ select count(*)::int from public.variant_costs $$, $$ values (2) $$, 'costs are stored');
select results_eq($$ select sum(on_hand)::int from public.variant_stock $$, $$ values (5) $$,
  'initial stock becomes ledger moves (zero stock adds none)');

select throws_ok($$
  select public.create_product('b0000000-0000-0000-0000-00000000000a', 'Gorra', null, '{}',
    '[{"attrs":{},"price_cents":100,"stock":3},{"attrs":{},"price_cents":-5,"stock":1}]')
$$, '23514', null, 'one bad variant rejects the whole product');
select results_eq($$ select count(*)::int from public.products $$, $$ values (1) $$, 'nothing from the failed product remains');
select throws_ok($$
  select public.create_product('b0000000-0000-0000-0000-00000000000a', 'Vacío', null, '{}', '[]')
$$, '22023', null, 'a product needs at least one variant');

select lives_ok($$
  insert into storage.objects (bucket_id, name) values ('product-photos', 'b0000000-0000-0000-0000-00000000000a/p1.jpg')
$$, 'the owner uploads a photo to their business folder');

set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333"}';
select throws_ok($$
  select public.create_product('b0000000-0000-0000-0000-00000000000a', 'Gorra', null, '{}', '[{"attrs":{},"price_cents":100}]')
$$, '42501', null, 'an employee cannot create products');

set local request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222222"}';
select is_empty($$ select * from storage.objects where bucket_id = 'product-photos' $$,
  'an outsider cannot see another business''s photos');

select * from finish();
rollback;
