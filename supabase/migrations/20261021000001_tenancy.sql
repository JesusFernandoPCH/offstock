-- Tenancy: businesses and who belongs to them.
-- Reads are guarded by RLS. Writes that grant roles only happen inside RPCs, so nobody can promote themselves.

create type public.business_type as enum ('clothing', 'food', 'tech', 'other');
create type public.member_role as enum ('owner', 'employee');

create table public.businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 80),
  type public.business_type not null,
  currency text not null default 'MXN' check (currency = 'MXN'),
  logo_path text,
  created_at timestamptz not null default now()
);

create table public.memberships (
  business_id uuid not null references public.businesses (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role public.member_role not null,
  created_at timestamptz not null default now(),
  primary key (business_id, user_id)
);
create index memberships_user_idx on public.memberships (user_id);

alter table public.businesses enable row level security;
alter table public.memberships enable row level security;

-- Security definer so policies on memberships don't recurse into themselves.
create function public.has_role(
  bid uuid,
  roles public.member_role[] default '{owner,employee}'
) returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.memberships m
    where m.business_id = bid and m.user_id = (select auth.uid()) and m.role = any (roles)
  );
$$;

create policy "members read their business" on public.businesses
  for select to authenticated using (public.has_role(id));
create policy "owners update their business" on public.businesses
  for update to authenticated
  using (public.has_role(id, '{owner}')) with check (public.has_role(id, '{owner}'));

create policy "members see coworkers" on public.memberships
  for select to authenticated using (public.has_role(business_id));
create policy "owners remove employees" on public.memberships
  for delete to authenticated using (role = 'employee' and public.has_role(business_id, '{owner}'));

-- Explicit grants: the cloud project does not auto-expose tables. No insert anywhere:
-- rows that grant roles are only created by the RPCs below.
revoke all on public.businesses, public.memberships from anon, authenticated;
grant select, update on public.businesses to authenticated;
grant select, delete on public.memberships to authenticated;

create function public.create_business(p_name text, p_type public.business_type)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  bid uuid;
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  -- Cheap abuse guard on the free tier.
  if (select count(*) from public.memberships where user_id = uid and role = 'owner') >= 3 then
    raise exception 'business limit reached' using errcode = 'P0001';
  end if;

  insert into public.businesses (name, type) values (trim(p_name), p_type) returning id into bid;
  insert into public.memberships (business_id, user_id, role) values (bid, uid, 'owner');
  return bid;
end;
$$;

revoke execute on function public.create_business(text, public.business_type) from public, anon;
revoke execute on function public.has_role(uuid, public.member_role[]) from public, anon;
grant execute on function public.create_business(text, public.business_type) to authenticated;
grant execute on function public.has_role(uuid, public.member_role[]) to authenticated;
