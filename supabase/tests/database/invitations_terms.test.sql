-- Invitations: only owners invite; only the verified invited email joins, and only as employee.
-- Terms: users record and read only their own acceptance.
begin;
select plan(13);

insert into auth.users (id, email, email_confirmed_at) values
  ('11111111-1111-1111-1111-111111111111', 'ana@example.test', now()),
  ('22222222-2222-2222-2222-222222222222', 'beto@example.test', now()),
  ('33333333-3333-3333-3333-333333333333', 'Carla@Example.test', now()),
  ('44444444-4444-4444-4444-444444444444', 'dani@example.test', null);

set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';
select lives_ok($$ select public.create_business('Tienda Lupita', 'clothing') $$, 'ana owns a business');

select lives_ok(
  $$ select public.invite_employee((select id from public.businesses), '  carla@example.TEST ') $$,
  'the owner invites by email');
select lives_ok(
  $$ select public.invite_employee((select id from public.businesses), 'dani@example.test') $$,
  'the owner invites a second person');
select results_eq($$ select email from public.invitations order by email $$,
  $$ values ('carla@example.test'), ('dani@example.test') $$, 'emails are normalized and visible to the owner');

-- Beto is not the owner.
set local request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222222"}';
select throws_ok(
  $$ select public.invite_employee((select business_id from public.invitations limit 1), 'beto@example.test') $$,
  '42501', null, 'a non-owner cannot invite');
select is_empty($$ select * from public.invitations $$, 'a non-owner cannot see invitations');
select is(public.accept_invitations(), 0, 'nobody invited beto');

-- Carla accepts.
set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333"}';
select is(public.accept_invitations(), 1, 'the invited email joins');
select results_eq($$ select role::text from public.memberships where user_id = auth.uid() $$,
  $$ values ('employee') $$, 'they join as employee');
select is(public.accept_invitations(), 0, 'accepting twice does nothing');

-- Dani never confirmed their email.
set local request.jwt.claims = '{"sub":"44444444-4444-4444-4444-444444444444"}';
select is(public.accept_invitations(), 0, 'an unverified email cannot claim an invitation');

-- Terms.
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111"}';
select lives_ok($$ insert into public.terms_acceptances (version) values ('2026-10-21') $$,
  'a user records their own acceptance');
select throws_ok(
  $$ insert into public.terms_acceptances (user_id, version)
     values ('22222222-2222-2222-2222-222222222222', '2026-10-21') $$,
  '42501', null, 'a user cannot accept on behalf of someone else');

select * from finish();
rollback;
