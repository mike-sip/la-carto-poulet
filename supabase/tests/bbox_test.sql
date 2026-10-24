begin;
select plan(5);

-- Mid-Atlantic, far from any imported restaurant.
insert into public.restaurants (osm_id, name, kind, location) values
  ('node/901', 'Poulet Centre', 'restaurant', 'SRID=4326;POINT(-30.00 40.00)'),
  ('node/902', 'Poulet Bord', 'fast_food', 'SRID=4326;POINT(-30.09 40.09)'),
  ('node/903', 'Poulet Dehors', 'fast_food', 'SRID=4326;POINT(-31.00 40.00)');

insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000b1', 'b1@test.fr');
insert into public.profiles values ('00000000-0000-0000-0000-0000000000b1', 'TestBbox1');
insert into public.ratings (restaurant_id, user_id, stars)
select id, '00000000-0000-0000-0000-0000000000b1', 4 from public.restaurants where osm_id = 'node/901';

set local role anon;
select is((select count(*)::int from public.restaurants_in_bbox(39.9, -30.1, 40.1, -29.9)), 2,
          'returns only restaurants inside the box');
select is((select name from public.restaurants_in_bbox(39.9, -30.1, 40.1, -29.9) limit 1), 'Poulet Centre',
          'nearest to the centre first');
select is((select array[lat, lng] from public.restaurants_in_bbox(39.9, -30.1, 40.1, -29.9) where name = 'Poulet Centre'),
          array[40.0, -30.0]::double precision[], 'returns lat and lng');

select is((select avg_stars from public.restaurants_in_bbox(39.9, -30.1, 40.1, -29.9) where name = 'Poulet Centre'),
          4.0::double precision, 'returns the average rating');
select is((select avg_stars from public.restaurants_in_bbox(39.9, -30.1, 40.1, -29.9) where name = 'Poulet Bord'),
          null, 'no average when nobody rated it');

select * from finish();
rollback;
