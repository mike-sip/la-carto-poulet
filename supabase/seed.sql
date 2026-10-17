-- Sample ratings for local development. The restaurants use real OSM ids so the import keeps them.
insert into public.restaurants (osm_id, name, kind, address, city, location, cuisine) values
  ('node/308002935', 'Joayo', 'restaurant', null, 'Paris', 'SRID=4326;POINT(2.3488 48.8530)', 'chicken;korean'),
  ('node/706546163', 'Poulet champion', 'fast_food', null, 'Paris', 'SRID=4326;POINT(2.3550 48.8610)', null)
on conflict (osm_id) do nothing;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000001', 'crete@example.com'),
  ('00000000-0000-0000-0000-000000000002', 'poulette@example.com'),
  ('00000000-0000-0000-0000-000000000003', 'troll@example.com');
insert into public.profiles values
  ('00000000-0000-0000-0000-000000000001', 'Crête-de-Feu'),
  ('00000000-0000-0000-0000-000000000002', 'Poulette69'),
  ('00000000-0000-0000-0000-000000000003', 'Troll');

insert into public.ratings (restaurant_id, user_id, stars, comment, hidden, created_at)
select r.id, v.user_id::uuid, v.stars, v.comment, v.hidden, now() - v.age::interval
from public.restaurants r join (values
  ('node/308002935', '00000000-0000-0000-0000-000000000001', 5, 'Les tenders sont croustillants, la sauce maison vaut le détour.', false, '2 days'),
  ('node/308002935', '00000000-0000-0000-0000-000000000002', 4, 'Bon mais un peu d''attente le samedi soir.', false, '8 days'),
  ('node/308002935', '00000000-0000-0000-0000-000000000003', 1, 'Message signalé, jamais affiché.', true, '1 day'),
  ('node/706546163', '00000000-0000-0000-0000-000000000002', 3, null, false, '3 months')
) as v(osm_id, user_id, stars, comment, hidden, age) on v.osm_id = r.osm_id;
