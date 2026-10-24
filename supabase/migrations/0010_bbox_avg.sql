-- Same as 0002 plus the average rating, for the "4+ pilons" filter. The return type changes, so drop and recreate.
drop function public.restaurants_in_bbox;

create function public.restaurants_in_bbox(min_lat double precision, min_lng double precision,
                                           max_lat double precision, max_lng double precision)
returns table (id bigint, name text, kind text, address text, city text,
               lat double precision, lng double precision, avg_stars double precision)
language sql stable
set search_path = ''
as $$
  select r.id, r.name, r.kind, r.address, r.city,
         extensions.st_y(r.location::extensions.geometry), extensions.st_x(r.location::extensions.geometry),
         s.avg_stars
  from public.restaurants r
  left join public.restaurant_stats s on s.restaurant_id = r.id
  where r.location operator(extensions.&&) extensions.st_makeenvelope(min_lng, min_lat, max_lng, max_lat, 4326)::extensions.geography
  order by r.location operator(extensions.<->)
           extensions.st_setsrid(extensions.st_makepoint((min_lng + max_lng) / 2, (min_lat + max_lat) / 2), 4326)::extensions.geography
  limit 500;
$$;

grant execute on function public.restaurants_in_bbox to anon, authenticated;
