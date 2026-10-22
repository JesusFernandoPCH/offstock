-- Employee invitations (owner invites by email; the employee joins on their next sign-in)
-- and an append-only record of which terms version each user accepted.

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  email text not null check (email = lower(trim(email)) and email like '_%@_%'),
  invited_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (business_id, email)
);
create index invitations_email_idx on public.invitations (email);
alter table public.invitations enable row level security;

create policy "owners see invitations" on public.invitations
  for select to authenticated using (public.has_role(business_id, '{owner}'));
create policy "owners revoke invitations" on public.invitations
  for delete to authenticated using (public.has_role(business_id, '{owner}'));

revoke all on public.invitations from anon, authenticated;
grant select, delete on public.invitations to authenticated;

create function public.invite_employee(p_business uuid, p_email text)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.has_role(p_business, '{owner}') then
    raise exception 'only the owner can invite' using errcode = '42501';
  end if;
  insert into public.invitations (business_id, email, invited_by)
  values (p_business, lower(trim(p_email)), auth.uid())
  on conflict (business_id, email) do nothing;
end;
$$;

-- Joins every business that invited the caller's verified email. Safe to call on every sign-in.
create function public.accept_invitations()
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  mail text;
  joined integer;
begin
  select lower(u.email) into mail from auth.users u
  where u.id = uid and u.email_confirmed_at is not null;
  if mail is null then
    return 0;
  end if;

  with taken as (
    delete from public.invitations where email = mail returning business_id
  )
  insert into public.memberships (business_id, user_id, role)
  select business_id, uid, 'employee' from taken
  on conflict do nothing;
  get diagnostics joined = row_count;
  return joined;
end;
$$;

revoke execute on function public.invite_employee(uuid, text) from public, anon;
revoke execute on function public.accept_invitations() from public, anon;
grant execute on function public.invite_employee(uuid, text) to authenticated;
grant execute on function public.accept_invitations() to authenticated;

create table public.terms_acceptances (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  version text not null check (version ~ '^\d{4}-\d{2}-\d{2}$'),
  accepted_at timestamptz not null default now(),
  primary key (user_id, version)
);
alter table public.terms_acceptances enable row level security;

create policy "users read own acceptances" on public.terms_acceptances
  for select to authenticated using (user_id = (select auth.uid()));
create policy "users record own acceptance" on public.terms_acceptances
  for insert to authenticated with check (user_id = (select auth.uid()));

revoke all on public.terms_acceptances from anon, authenticated;
grant select, insert on public.terms_acceptances to authenticated;
