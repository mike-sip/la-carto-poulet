-- Restaurants inside the visible map rectangle, nearest to its centre first, at most 500.
create function public.restaurants_in_bbox(min_lat double precision, min_lng double precision,
                                           max_lat double precision, max_lng double precision)
returns table (id bigint, name text, kind text, address text, city text,
               lat double precision, lng double precision)
language sql stable
set search_path = ''
as $$
  select r.id, r.name, r.kind, r.address, r.city,
         extensions.st_y(r.location::extensions.geometry), extensions.st_x(r.location::extensions.geometry)
  from public.restaurants r
  where r.location operator(extensions.&&) extensions.st_makeenvelope(min_lng, min_lat, max_lng, max_lat, 4326)::extensions.geography
  order by r.location operator(extensions.<->)
           extensions.st_setsrid(extensions.st_makepoint((min_lng + max_lng) / 2, (min_lat + max_lat) / 2), 4326)::extensions.geography
  limit 500;
$$;

grant execute on function public.restaurants_in_bbox to anon, authenticated;
