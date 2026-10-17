begin;
select plan(3);

-- Mid-Atlantic, far from any imported restaurant.
insert into public.restaurants (osm_id, name, kind, location) values
  ('node/901', 'Poulet Centre', 'restaurant', 'SRID=4326;POINT(-30.00 40.00)'),
  ('node/902', 'Poulet Bord', 'fast_food', 'SRID=4326;POINT(-30.09 40.09)'),
  ('node/903', 'Poulet Dehors', 'fast_food', 'SRID=4326;POINT(-31.00 40.00)');

set local role anon;
select is((select count(*)::int from public.restaurants_in_bbox(39.9, -30.1, 40.1, -29.9)), 2,
          'returns only restaurants inside the box');
select is((select name from public.restaurants_in_bbox(39.9, -30.1, 40.1, -29.9) limit 1), 'Poulet Centre',
          'nearest to the centre first');
select is((select array[lat, lng] from public.restaurants_in_bbox(39.9, -30.1, 40.1, -29.9) where name = 'Poulet Centre'),
          array[40.0, -30.0]::double precision[], 'returns lat and lng');

select * from finish();
rollback;
