-- Catalog: owners manage, employees read prices and stock but never costs, outsiders see nothing.
-- Inventory is append-only and sale moves cannot be forged.
begin;
select plan(20);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'ana@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'beto@example.test'),
  ('33333333-3333-3333-3333-333333333333', 'carla@example.test');

-- Fixed ids keep the test readable.
insert into public.businesses (id, name, type) values
  ('b0000000-0000-0000-0000-00000000000a', 'Tienda Lupita', 'clothing'),
  ('b0000000-0000-0000-0000-00000000000b', 'Tecno Beto', 'tech');
insert into public.memberships (business_id, user_id, role) values
  ('b0000000-0000-0000-0000-00000000000a', '11111111-1111-1111-1111-111111111111', 'owner'),
  ('b0000000-0000-0000-0000-00000000000a', '33333333-3333-3333-3333-333333333333', 'employee'),
  ('b0000000-0000-0000-0000-00000000000b', '22222222-2222-2222-2222-222222222222', 'owner');

-- Ana (owner) builds a product.
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

select lives_ok($$
  insert into public.products (id, business_id, name, category)
  values ('a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-00000000000a', 'Playera básica', 'Playeras')
$$, 'the owner adds a product');
select lives_ok($$
  insert into public.variants (id, business_id, product_id, sku, barcode, attrs, price_cents)
  values ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-00000000000a',
          'a0000000-0000-0000-0000-000000000001', 'PLA-M-NEG', '7501234500018', '{"talla":"M","color":"Negro"}', 24900)
$$, 'the owner adds a variant');
select lives_ok($$
  insert into public.variant_costs (variant_id, business_id, cost_cents)
  values ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-00000000000a', 11000)
$$, 'the owner records the cost');
select lives_ok($$
  insert into public.inventory_moves (business_id, variant_id, qty, reason)
  values ('b0000000-0000-0000-0000-00000000000a', 'c0000000-0000-0000-0000-000000000001', 5, 'initial'),
         ('b0000000-0000-0000-0000-00000000000a', 'c0000000-0000-0000-0000-000000000001', -1, 'adjust')
$$, 'the owner records stock moves');
select results_eq($$ select on_hand from public.variant_stock $$, $$ values (4) $$, 'stock is the sum of moves');

select throws_ok($$
  insert into public.inventory_moves (business_id, variant_id, qty, reason)
  values ('b0000000-0000-0000-0000-00000000000a', 'c0000000-0000-0000-0000-000000000001', -1, 'sale')
$$, '42501', null, 'sale moves cannot be written directly');
select throws_ok($$ update public.inventory_moves set qty = 100 $$, '42501', null, 'moves cannot be edited');
select throws_ok($$ delete from public.inventory_moves $$, '42501', null, 'moves cannot be deleted');
select throws_ok($$
  insert into public.variants (business_id, product_id, sku, barcode, price_cents)
  values ('b0000000-0000-0000-0000-00000000000a', 'a0000000-0000-0000-0000-000000000001', 'PLA-L-NEG', '7501234500018', 24900)
$$, '23505', null, 'a barcode is unique within a business');
select throws_ok($$
  insert into public.variants (business_id, product_id, sku, price_cents)
  values ('b0000000-0000-0000-0000-00000000000a', 'a0000000-0000-0000-0000-000000000001', 'PLA-XL', -1)
$$, '23514', null, 'prices cannot be negative');

-- Carla (employee).
set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333"}';
select results_eq($$ select price_cents from public.variants $$, $$ values (24900) $$, 'an employee reads prices');
select results_eq($$ select on_hand from public.variant_stock $$, $$ values (4) $$, 'an employee reads stock');
select is_empty($$ select * from public.variant_costs $$, 'an employee never sees costs');
select throws_ok($$
  insert into public.products (business_id, name) values ('b0000000-0000-0000-0000-00000000000a', 'Gorra')
$$, '42501', null, 'an employee cannot add products');
select is_empty($$ update public.variants set price_cents = 1 returning id $$, 'an employee cannot change prices');
select throws_ok($$
  insert into public.inventory_moves (business_id, variant_id, qty, reason)
  values ('b0000000-0000-0000-0000-00000000000a', 'c0000000-0000-0000-0000-000000000001', 10, 'adjust')
$$, '42501', null, 'an employee cannot adjust stock');

-- Beto owns a different business.
set local request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222222"}';
select is_empty($$ select * from public.products $$, 'an outsider sees no products');
select is_empty($$ select * from public.variant_stock $$, 'an outsider sees no stock');
select throws_ok($$
  insert into public.variants (business_id, product_id, sku, price_cents)
  values ('b0000000-0000-0000-0000-00000000000b', 'a0000000-0000-0000-0000-000000000001', 'ROBADO', 100)
$$, '23503', null, 'a variant cannot point at another business''s product');
select lives_ok($$
  insert into public.products (id, business_id, name)
  values ('a0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-00000000000b', 'Cargador USB-C');
  insert into public.variants (business_id, product_id, sku, barcode, price_cents)
  values ('b0000000-0000-0000-0000-00000000000b', 'a0000000-0000-0000-0000-000000000002', 'CARG-1', '7501234500018', 19900)
$$, 'the same barcode is fine in another business');

select * from finish();
rollback;
