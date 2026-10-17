begin;
select plan(8);

insert into public.restaurants (osm_id, name, kind, location)
values ('node/1', 'Le Poulet Doré', 'fast_food', 'SRID=4326;POINT(4.84 45.75)');
insert into auth.users (id, email)
select ('00000000-0000-0000-0000-0000000000e' || n)::uuid, 'e' || n || '@test.fr' from generate_series(1, 3) n;
insert into public.profiles
select ('00000000-0000-0000-0000-0000000000e' || n)::uuid, 'TestBlk' || n from generate_series(1, 3) n;
-- e1 blocks e2; e3 looks on.
insert into public.ratings (restaurant_id, user_id, stars, comment)
select id, '00000000-0000-0000-0000-0000000000e2', 2, 'Troll' from public.restaurants where osm_id = 'node/1';
create temp table t as select id from public.restaurants where osm_id = 'node/1';
grant select on t to anon, authenticated;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-0000000000e1", "role": "authenticated"}', true);
select throws_ok($$insert into public.blocks (blocker_id, blocked_id) values (auth.uid(), auth.uid())$$,
  '23514', null, 'cannot block yourself');
select throws_ok($$insert into public.blocks (blocker_id, blocked_id) values ('00000000-0000-0000-0000-0000000000e3', '00000000-0000-0000-0000-0000000000e2')$$,
  '42501', null, 'cannot block in someone else''s name');
select lives_ok($$insert into public.blocks (blocker_id, blocked_id) values (auth.uid(), '00000000-0000-0000-0000-0000000000e2')$$,
  'a user blocks another');
select is((select count(*)::int from public.rating_list where restaurant_id = (select id from t)), 0,
  'the blocker no longer sees the blocked user''s comments');
select is((select rating_count from public.restaurant_stats where restaurant_id = (select id from t)), 1,
  'the blocked user''s rating still counts in the average');
select is((select nickname from public.my_blocks), 'TestBlk2', 'the blocker sees who they blocked');

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-0000000000e3", "role": "authenticated"}', true);
select is((select count(*)::int from public.rating_list where restaurant_id = (select id from t)) +
          (select count(*)::int from public.my_blocks), 1,
  'others still see the comment and not the block');

set local role anon;
select is((select count(*)::int from public.rating_list where restaurant_id = (select id from t)), 1,
  'signed-out visitors still see the comment');

select * from finish();
rollback;
