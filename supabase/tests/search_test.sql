begin;
select plan(4);

insert into public.restaurants (osm_id, name, kind, location) values
  ('node/951', 'Zzrôtisserie Tèst', 'restaurant', 'SRID=4326;POINT(-30.00 40.00)'),
  ('node/952', 'Chez Zzrotisserie', 'fast_food', 'SRID=4326;POINT(-30.10 40.10)'),
  ('node/953', 'Zz100% Poulet', 'fast_food', 'SRID=4326;POINT(-30.20 40.20)');

set local role anon;
select is(array(select name from public.search_restaurants('ZZROTISSERIE')),
          array['Zzrôtisserie Tèst', 'Chez Zzrotisserie'], 'ignores case and accents, prefix matches first');
select is((select array[lat, lng] from public.search_restaurants('zzrôtisserie tèst')),
          array[40.0, -30.0]::double precision[], 'returns lat and lng');
select is((select count(*)::int from public.search_restaurants('z')), 0, 'needs at least 2 characters');
select is(array(select name from public.search_restaurants('zz100%')), array['Zz100% Poulet'], '% is matched literally');

select * from finish();
rollback;
