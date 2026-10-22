-- Product photos (private bucket, one folder per business) and an atomic product creation RPC.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-photos', 'product-photos', false, 1048576, array['image/jpeg']);

-- Paths are "<business_id>/<product_id>.jpg"; the first folder decides access.
create policy "members read product photos" on storage.objects
  for select to authenticated
  using (bucket_id = 'product-photos' and public.has_role(((storage.foldername(name))[1])::uuid));
create policy "owners upload product photos" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'product-photos' and public.has_role(((storage.foldername(name))[1])::uuid, '{owner}'));
create policy "owners replace product photos" on storage.objects
  for update to authenticated
  using (bucket_id = 'product-photos' and public.has_role(((storage.foldername(name))[1])::uuid, '{owner}'))
  with check (bucket_id = 'product-photos' and public.has_role(((storage.foldername(name))[1])::uuid, '{owner}'));
create policy "owners delete product photos" on storage.objects
  for delete to authenticated
  using (bucket_id = 'product-photos' and public.has_role(((storage.foldername(name))[1])::uuid, '{owner}'));

-- Product + variants + costs + initial stock in one transaction. Runs as the caller, so every
-- insert still passes the owner-only RLS policies.
-- p_variants: [{"attrs": {...}, "price_cents": 24900, "cost_cents": 11000, "stock": 5, "sku": null, "barcode": null}]
create function public.create_product(
  p_business uuid,
  p_name text,
  p_category text,
  p_attrs jsonb,
  p_variants jsonb
) returns uuid
language plpgsql security invoker set search_path = ''
as $$
declare
  pid uuid;
  v jsonb;
  vid uuid;
  stock integer;
begin
  if jsonb_typeof(p_variants) is distinct from 'array' or jsonb_array_length(p_variants) not between 1 and 200 then
    raise exception 'a product needs between 1 and 200 variants' using errcode = '22023';
  end if;

  insert into public.products (business_id, name, category, attrs)
  values (p_business, trim(p_name), nullif(trim(p_category), ''), coalesce(p_attrs, '{}'))
  returning id into pid;

  for v in select value from jsonb_array_elements(p_variants) loop
    insert into public.variants (business_id, product_id, sku, barcode, attrs, price_cents)
    values (
      p_business, pid,
      coalesce(nullif(trim(v ->> 'sku'), ''), 'SKU-' || upper(substr(md5(gen_random_uuid()::text), 1, 8))),
      nullif(v ->> 'barcode', ''),
      coalesce(v -> 'attrs', '{}'),
      (v ->> 'price_cents')::integer
    )
    returning id into vid;

    if v ->> 'cost_cents' is not null then
      insert into public.variant_costs (variant_id, business_id, cost_cents)
      values (vid, p_business, (v ->> 'cost_cents')::integer);
    end if;

    stock := coalesce((v ->> 'stock')::integer, 0);
    if stock < 0 then
      raise exception 'initial stock cannot be negative' using errcode = '22023';
    elsif stock > 0 then
      insert into public.inventory_moves (business_id, variant_id, qty, reason)
      values (p_business, vid, stock, 'initial');
    end if;
  end loop;

  return pid;
end;
$$;

revoke execute on function public.create_product(uuid, text, text, jsonb, jsonb) from public, anon;
grant execute on function public.create_product(uuid, text, text, jsonb, jsonb) to authenticated;
