begin;
select plan(5);

select has_table('public', 'restaurants', 'restaurants exists');
select col_is_unique('public', 'restaurants', 'osm_id', 'osm_id is unique');

insert into public.restaurants (osm_id, name, kind, location)
values ('node/1', 'Le Poulet Doré', 'fast_food', 'SRID=4326;POINT(4.84 45.75)');

set local role anon;
select is((select count(*)::int from public.restaurants), 1, 'anon can read');
select throws_ok(
  $$insert into public.restaurants (osm_id, name, kind, location) values ('node/2', 'x', 'restaurant', 'SRID=4326;POINT(2.35 48.85)')$$,
  '42501', null, 'anon cannot insert');

set local role authenticated;
select throws_ok($$delete from public.restaurants$$, '42501', null, 'signed-in users cannot delete');

select * from finish();
rollback;
