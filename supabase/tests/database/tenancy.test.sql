-- Tenant isolation: a user must never read or change another business's data.
begin;
select plan(15);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'ana@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'beto@example.test'),
  ('33333333-3333-3333-3333-333333333333', 'carla@example.test');

-- Ana creates a business and becomes its owner.
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';
select lives_ok($$ select public.create_business('Tienda Lupita', 'clothing') $$, 'a user can create a business');
select results_eq($$ select role::text from public.memberships $$, $$ values ('owner') $$, 'the creator is the owner');
select results_eq($$ select name from public.businesses $$, $$ values ('Tienda Lupita') $$, 'the owner reads their business');
select throws_ok(
  $$ insert into public.memberships (business_id, user_id, role)
     select id, '22222222-2222-2222-2222-222222222222', 'owner' from public.businesses $$,
  '42501', null, 'not even an owner can insert memberships directly');

-- Carla joins as employee (simulates an accepted invitation).
reset role;
insert into public.memberships (business_id, user_id, role)
  select id, '33333333-3333-3333-3333-333333333333', 'employee' from public.businesses;

-- Beto belongs to nothing.
set local role authenticated;
set local request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222222"}';
select is_empty($$ select * from public.businesses $$, 'an outsider sees no businesses');
select is_empty($$ select * from public.memberships $$, 'an outsider sees no memberships');
select is_empty($$ update public.businesses set name = 'hackeado' returning id $$, 'an outsider cannot rename a business');
select throws_ok(
  $$ insert into public.memberships (business_id, user_id, role)
     values ((select id from public.businesses limit 1), '22222222-2222-2222-2222-222222222222', 'owner') $$,
  '42501', null, 'an outsider cannot add themselves');

-- Carla, the employee.
set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333"}';
select results_eq($$ select name from public.businesses $$, $$ values ('Tienda Lupita') $$, 'an employee reads their business');
select is_empty($$ update public.businesses set name = 'otra' returning id $$, 'an employee cannot rename the business');
select is_empty($$ delete from public.memberships where role = 'owner' returning user_id $$, 'an employee cannot remove the owner');

-- Limits and anonymous access.
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';
select lives_ok($$ select public.create_business('Sucursal 2', 'clothing') $$, 'second business');
select lives_ok($$ select public.create_business('Sucursal 3', 'clothing') $$, 'third business');
select throws_ok($$ select public.create_business('Sucursal 4', 'clothing') $$, 'P0001', 'business limit reached', 'owners are capped at 3 businesses');

set local role anon;
select throws_ok($$ select public.create_business('Anon', 'other') $$, '42501', null, 'anon cannot create businesses');

select * from finish();
rollback;
