begin;
select plan(8);

insert into public.restaurants (osm_id, name, kind, location)
values ('node/1', 'Le Poulet Doré', 'fast_food', 'SRID=4326;POINT(4.84 45.75)');
insert into auth.users (id, email)
select ('00000000-0000-0000-0000-0000000000d' || n)::uuid, 'd' || n || '@test.fr' from generate_series(1, 4) n;
insert into public.profiles
select ('00000000-0000-0000-0000-0000000000d' || n)::uuid, 'TestRep' || n from generate_series(1, 4) n;
-- d1 wrote the comment; d2, d3, d4 report it.
insert into public.ratings (restaurant_id, user_id, stars, comment)
select id, '00000000-0000-0000-0000-0000000000d1', 1, 'Insulte' from public.restaurants where osm_id = 'node/1';
create temp table t as select r.id from public.ratings r join public.restaurants x on x.id = r.restaurant_id where x.osm_id = 'node/1';
grant select on t to anon, authenticated;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-0000000000d1", "role": "authenticated"}', true);
select throws_ok($$insert into public.reports (rating_id, reporter_id, reason) select id, auth.uid(), 'spam' from t$$,
  '42501', null, 'cannot report your own comment');

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-0000000000d2", "role": "authenticated"}', true);
select lives_ok($$insert into public.reports (rating_id, reporter_id, reason) select id, auth.uid(), 'insult' from t$$,
  'a user reports a comment with a reason');
select throws_ok($$insert into public.reports (rating_id, reporter_id, reason) select id, auth.uid(), 'spam' from t$$,
  '23505', null, 'a user reports a comment only once');
select throws_ok($$insert into public.reports (rating_id, reporter_id, reason) select id, '00000000-0000-0000-0000-0000000000d3', 'spam' from t$$,
  '42501', null, 'cannot report in someone else''s name');
select throws_ok($$select * from public.reports$$, '42501', null, 'reports are not readable');

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-0000000000d3", "role": "authenticated"}', true);
insert into public.reports (rating_id, reporter_id, reason) select id, auth.uid(), 'insult' from t;
select is((select count(*)::int from public.rating_list where id = (select id from t)), 1, 'still visible after 2 reports');

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-0000000000d4", "role": "authenticated"}', true);
insert into public.reports (rating_id, reporter_id, reason) select id, auth.uid(), 'other' from t;
set local role anon;
select is((select count(*)::int from public.rating_list where id = (select id from t)), 0, 'hidden for everyone at the 3rd report');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-0000000000d1", "role": "authenticated"}', true);
select is((select array[(select count(*)::int from public.rating_list where id = (select id from t)),
                        (select count(*)::int from public.ratings where id = (select id from t) and hidden)]),
  array[0, 1], 'the author sees their hidden rating only in the form, not in the list');

select * from finish();
rollback;
