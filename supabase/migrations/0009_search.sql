create extension if not exists unaccent with schema extensions;

-- Restaurants whose name contains the query, ignoring case and accents; names starting with it first. At most 20.
create function public.search_restaurants(q text)
returns table (id bigint, name text, kind text, address text, city text,
               lat double precision, lng double precision)
language sql stable
set search_path = ''
as $$
  with needle as (
    select extensions.unaccent(lower(replace(replace(replace(trim(q), '\', '\\'), '%', '\%'), '_', '\_'))) as n
  )
  select r.id, r.name, r.kind, r.address, r.city,
         extensions.st_y(r.location::extensions.geometry), extensions.st_x(r.location::extensions.geometry)
  from public.restaurants r, needle
  where length(needle.n) >= 2
    and extensions.unaccent(lower(r.name)) like '%' || needle.n || '%'
  order by extensions.unaccent(lower(r.name)) like needle.n || '%' desc, r.name
  limit 20;
$$;

grant execute on function public.search_restaurants to anon, authenticated;
