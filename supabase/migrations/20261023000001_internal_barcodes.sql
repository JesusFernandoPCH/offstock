-- Variants without a factory barcode get an internal EAN-13 in the GS1 in-store range (prefix 2),
-- so every piece can be labeled and scanned at the counter.

create sequence public.internal_barcode_seq;

create function public.ean13(body text)
returns text
language sql
immutable
set search_path = ''
as $$
  -- body: 12 digits; check digit weights alternate 1, 3 from the left.
  select body || ((10 - (
    select sum(substr(body, i, 1)::int * case when i % 2 = 0 then 3 else 1 end)
    from generate_series(1, 12) i
  ) % 10) % 10)::text;
$$;

create function public.assign_internal_barcode()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.barcode is null then
    new.barcode := public.ean13('2' || lpad(nextval('public.internal_barcode_seq')::text, 11, '0'));
  end if;
  return new;
end;
$$;

revoke all on function public.assign_internal_barcode() from public, anon, authenticated;

create trigger variants_internal_barcode
  before insert on public.variants
  for each row execute function public.assign_internal_barcode();

update public.variants
set barcode = public.ean13('2' || lpad(nextval('public.internal_barcode_seq')::text, 11, '0'))
where barcode is null;
