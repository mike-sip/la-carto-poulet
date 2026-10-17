begin;
select plan(7);

insert into public.restaurants (osm_id, name, kind, location)
values ('node/1', 'Le Poulet Doré', 'fast_food', 'SRID=4326;POINT(4.84 45.75)');
insert into auth.users (id, email)
select ('00000000-0000-0000-0000-0000000000f' || n)::uuid, 'f' || n || '@test.fr' from generate_series(1, 2) n;
insert into public.profiles
select ('00000000-0000-0000-0000-0000000000f' || n)::uuid, 'TestDel' || n from generate_series(1, 2) n;
-- f1 and f2 each rate, report each other and block each other.
insert into public.ratings (restaurant_id, user_id, stars)
select r.id, ('00000000-0000-0000-0000-0000000000f' || n)::uuid, 3
from public.restaurants r, generate_series(1, 2) n where r.osm_id = 'node/1';
insert into public.reports (rating_id, reporter_id, reason)
select x.id, case when x.user_id = '00000000-0000-0000-0000-0000000000f1'
                  then '00000000-0000-0000-0000-0000000000f2'::uuid else '00000000-0000-0000-0000-0000000000f1'::uuid end, 'spam'
from public.ratings x where x.user_id in ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000f2');
insert into public.blocks values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000f2'),
  ('00000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-0000000000f1');

set local role anon;
select throws_ok($$select public.delete_my_account()$$, '42501', null, 'signed-out visitors cannot call it');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-0000000000f1", "role": "authenticated"}', true);
select lives_ok($$select public.delete_my_account()$$, 'a user deletes their account');

reset role;
select is((select count(*)::int from auth.users where id = '00000000-0000-0000-0000-0000000000f1'), 0, 'auth user gone');
select is((select count(*)::int from public.profiles where user_id = '00000000-0000-0000-0000-0000000000f1'), 0, 'profile gone');
select is((select count(*)::int from public.ratings where user_id = '00000000-0000-0000-0000-0000000000f1'), 0, 'ratings gone');
select is((select count(*)::int from public.reports where reporter_id = '00000000-0000-0000-0000-0000000000f1')
        + (select count(*)::int from public.blocks), 0, 'their reports and blocks gone, both ways');
select is((select count(*)::int from public.ratings where user_id = '00000000-0000-0000-0000-0000000000f2'), 1,
  'the other user keeps their account and rating');

select * from finish();
rollback;
