begin;
select plan(13);

insert into public.restaurants (osm_id, name, kind, location)
values ('node/1', 'Le Poulet Doré', 'fast_food', 'SRID=4326;POINT(4.84 45.75)');
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@test.fr'),
  ('00000000-0000-0000-0000-00000000000b', 'b@test.fr');
insert into public.profiles values
  ('00000000-0000-0000-0000-00000000000a', 'TestPoulette'),
  ('00000000-0000-0000-0000-00000000000b', 'TestTroll');
insert into public.ratings (restaurant_id, user_id, stars, comment, hidden)
select id, '00000000-0000-0000-0000-00000000000a'::uuid, 4, 'Croustillant', false from public.restaurants where osm_id = 'node/1'
union all
select id, '00000000-0000-0000-0000-00000000000b'::uuid, 1, 'Spam', true from public.restaurants where osm_id = 'node/1';

set local role anon;
select is((select count(*)::int from public.ratings r join public.restaurants x on x.id = r.restaurant_id where x.osm_id = 'node/1'), 1, 'anon cannot read a hidden rating');
select is((select array_agg(nickname) from public.rating_list l join public.restaurants x on x.id = l.restaurant_id where x.osm_id = 'node/1'), array['TestPoulette'], 'the list shows the nickname, not the hidden one');
select is((select avg_stars from public.restaurant_stats s join public.restaurants x on x.id = s.restaurant_id where x.osm_id = 'node/1'), 4.0::float8, 'hidden ratings do not count in the average');
select throws_ok($$select email from auth.users$$, '42501', null, 'anon cannot read emails');

-- Writes, as user a (who already rated) and user c (who hasn't).
reset role;
insert into auth.users (id, email) values ('00000000-0000-0000-0000-00000000000c', 'c@test.fr');
insert into public.profiles values ('00000000-0000-0000-0000-00000000000c', 'TestNouveau');
create temp table t as select id from public.restaurants where osm_id = 'node/1';
grant select on t to authenticated;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-00000000000c", "role": "authenticated"}', true);
select lives_ok($$insert into public.ratings (restaurant_id, user_id, stars, comment) select id, auth.uid(), 5, 'Cocorico' from t$$,
  'a user adds their rating');
select throws_ok($$insert into public.ratings (restaurant_id, user_id, stars) select id, auth.uid(), 3 from t$$,
  '23505', null, 'one rating per user per restaurant');
select throws_ok($$insert into public.ratings (restaurant_id, user_id, stars) select id, '00000000-0000-0000-0000-00000000000b', 3 from t$$,
  '42501', null, 'a user cannot rate for someone else');
select throws_ok($$update public.ratings set stars = 0 where user_id = auth.uid()$$, '23514', null, '0 drumsticks rejected');
select throws_ok($$update public.ratings set stars = 6 where user_id = auth.uid()$$, '23514', null, '6 drumsticks rejected');
select throws_ok($$update public.ratings set comment = repeat('x', 1001) where user_id = auth.uid()$$, '23514', null, '1001 chars rejected');
select throws_ok($$update public.ratings set hidden = false where user_id = auth.uid()$$, '42501', null, 'a user cannot un-hide a rating');
update public.ratings set stars = 1 where user_id = '00000000-0000-0000-0000-00000000000a';
delete from public.ratings where user_id = '00000000-0000-0000-0000-00000000000a';
reset role;
select is((select stars from public.ratings where user_id = '00000000-0000-0000-0000-00000000000a'), 4::smallint,
  'a user cannot change or delete someone else''s rating');

delete from public.restaurants where osm_id = 'node/1';
select is((select count(*)::int from public.ratings where user_id in ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b')), 0, 'removing a restaurant removes its ratings');

select * from finish();
rollback;
