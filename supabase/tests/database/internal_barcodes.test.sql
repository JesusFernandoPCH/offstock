-- Variants without a factory code get a valid, unique internal EAN-13; factory codes are kept.
begin;
select plan(5);

select is(public.ean13('400638133393'), '4006381333931', 'check digit matches a known EAN-13');

insert into auth.users (id, email) values ('11111111-1111-1111-1111-111111111111', 'ana@example.test');
insert into public.businesses (id, name, type) values ('b0000000-0000-0000-0000-00000000000a', 'Tienda Lupita', 'clothing');
insert into public.memberships (business_id, user_id, role) values
  ('b0000000-0000-0000-0000-00000000000a', '11111111-1111-1111-1111-111111111111', 'owner');

set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';

select public.create_product('b0000000-0000-0000-0000-00000000000a', 'Playera', null, '{}',
  '[{"attrs":{"talla":"M"},"price_cents":24900,"stock":1},
    {"attrs":{"talla":"G"},"price_cents":24900,"stock":1},
    {"attrs":{"talla":"EG"},"price_cents":24900,"stock":1,"barcode":"4006381333931"}]');

select results_eq($$ select count(*)::int from public.variants where barcode ~ '^2\d{12}$' $$, $$ values (2) $$,
  'variants without a code get an internal one with prefix 2');
select results_eq($$ select count(*)::int from public.variants
  where barcode ~ '^2' and public.ean13(left(barcode, 12)) = barcode $$, $$ values (2) $$,
  'internal codes carry a valid check digit');
select results_eq($$ select count(distinct barcode)::int from public.variants $$, $$ values (3) $$, 'codes are unique');
select results_eq($$ select barcode from public.variants where attrs ->> 'talla' = 'EG' $$, $$ values ('4006381333931') $$,
  'a factory code is kept');

select * from finish();
rollback;
