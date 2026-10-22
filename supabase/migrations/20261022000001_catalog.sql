-- Catalog and inventory ledger (ADR-0002).
-- products → variants (one per size/color, own SKU/barcode/price) → inventory_moves (append-only).
-- Costs live in their own owner-only table so employees never see margins.

create function public.set_updated_at() returns trigger
language plpgsql set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create table public.products (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 120),
  category text check (char_length(category) <= 60),
  attrs jsonb not null default '{}' check (jsonb_typeof(attrs) = 'object'),
  photo_path text check (char_length(photo_path) <= 300),
  sat_product_key text check (sat_product_key ~ '^\d{8}$'),
  sat_unit_key text check (sat_unit_key ~ '^[A-Z0-9]{1,3}$'),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, business_id)
);
create index products_business_idx on public.products (business_id, updated_at);

create table public.variants (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null,
  product_id uuid not null,
  sku text not null check (char_length(trim(sku)) between 1 and 40),
  barcode text check (barcode ~ '^\d{8,14}$'),
  attrs jsonb not null default '{}' check (jsonb_typeof(attrs) = 'object'),
  price_cents integer not null check (price_cents >= 0),
  min_stock integer not null default 0 check (min_stock >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Composite keys make it impossible to attach a variant to another business's product.
  foreign key (product_id, business_id) references public.products (id, business_id) on delete cascade,
  unique (id, business_id),
  unique (business_id, sku),
  unique (business_id, barcode)
);
create index variants_product_idx on public.variants (product_id);
create index variants_business_idx on public.variants (business_id, updated_at);

create table public.variant_costs (
  variant_id uuid primary key,
  business_id uuid not null,
  cost_cents integer not null check (cost_cents >= 0),
  updated_at timestamptz not null default now(),
  foreign key (variant_id, business_id) references public.variants (id, business_id) on delete cascade
);

create type public.move_reason as enum ('initial', 'purchase', 'return', 'adjust', 'sale');

create table public.inventory_moves (
  id uuid primary key default gen_random_uuid(), -- clients may send their own id (idempotent retries)
  business_id uuid not null,
  variant_id uuid not null,
  qty integer not null check (qty <> 0),
  reason public.move_reason not null,
  note text check (char_length(note) <= 200),
  ref_id uuid,
  created_by uuid not null default auth.uid() references auth.users (id),
  created_at timestamptz not null default now(),
  foreign key (variant_id, business_id) references public.variants (id, business_id)
);
create index inventory_moves_variant_idx on public.inventory_moves (variant_id);
create index inventory_moves_business_idx on public.inventory_moves (business_id, created_at);

create trigger products_updated_at before update on public.products
  for each row execute function public.set_updated_at();
create trigger variants_updated_at before update on public.variants
  for each row execute function public.set_updated_at();
create trigger variant_costs_updated_at before update on public.variant_costs
  for each row execute function public.set_updated_at();

-- ponytail: on-hand is summed on read; add a trigger-maintained cache when a business has enough moves to notice.
create view public.variant_stock with (security_invoker = true) as
  select v.id as variant_id, v.business_id, coalesce(sum(m.qty), 0)::integer as on_hand
  from public.variants v
  left join public.inventory_moves m on m.variant_id = v.id
  group by v.id, v.business_id;

alter table public.products enable row level security;
alter table public.variants enable row level security;
alter table public.variant_costs enable row level security;
alter table public.inventory_moves enable row level security;

create policy "members read products" on public.products
  for select to authenticated using (public.has_role(business_id));
create policy "owners add products" on public.products
  for insert to authenticated with check (public.has_role(business_id, '{owner}'));
create policy "owners edit products" on public.products
  for update to authenticated
  using (public.has_role(business_id, '{owner}')) with check (public.has_role(business_id, '{owner}'));

create policy "members read variants" on public.variants
  for select to authenticated using (public.has_role(business_id));
create policy "owners add variants" on public.variants
  for insert to authenticated with check (public.has_role(business_id, '{owner}'));
create policy "owners edit variants" on public.variants
  for update to authenticated
  using (public.has_role(business_id, '{owner}')) with check (public.has_role(business_id, '{owner}'));

create policy "owners read costs" on public.variant_costs
  for select to authenticated using (public.has_role(business_id, '{owner}'));
create policy "owners add costs" on public.variant_costs
  for insert to authenticated with check (public.has_role(business_id, '{owner}'));
create policy "owners edit costs" on public.variant_costs
  for update to authenticated
  using (public.has_role(business_id, '{owner}')) with check (public.has_role(business_id, '{owner}'));

create policy "members read moves" on public.inventory_moves
  for select to authenticated using (public.has_role(business_id));
-- Sales moves are written only by the checkout RPC (Phase 3), never directly.
create policy "owners record stock moves" on public.inventory_moves
  for insert to authenticated with check (
    public.has_role(business_id, '{owner}')
    and reason in ('initial', 'purchase', 'return', 'adjust')
    and created_by = (select auth.uid())
  );

-- No delete anywhere: products/variants are deactivated, moves are corrected with new moves.
revoke all on public.products, public.variants, public.variant_costs, public.inventory_moves, public.variant_stock
  from anon, authenticated;
grant select, insert, update on public.products, public.variants, public.variant_costs to authenticated;
grant select, insert on public.inventory_moves to authenticated;
grant select on public.variant_stock to authenticated;
