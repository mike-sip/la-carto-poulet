begin;
select plan(6);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000c1', 'c1@test.fr'),
  ('00000000-0000-0000-0000-0000000000c2', 'c2@test.fr');
insert into public.profiles values ('00000000-0000-0000-0000-0000000000c2', 'TestAutre');

set local role anon;
select throws_ok($$insert into public.profiles values ('00000000-0000-0000-0000-0000000000c1', 'TestAnon')$$,
  '42501', null, 'anon cannot create a profile');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-0000000000c1", "role": "authenticated"}', true);
select lives_ok($$insert into public.profiles values ('00000000-0000-0000-0000-0000000000c1', 'TestMoi')$$,
  'a user creates their own profile');
select throws_ok($$insert into public.profiles values ('00000000-0000-0000-0000-0000000000c2', 'TestPirate')$$,
  '42501', null, 'a user cannot create a profile for someone else');
select throws_ok($$update public.profiles set nickname = 'TestAutre' where user_id = '00000000-0000-0000-0000-0000000000c1'$$,
  '23505', null, 'nicknames are unique');
update public.profiles set nickname = 'TestVol' where user_id = '00000000-0000-0000-0000-0000000000c2';
select is((select nickname from public.profiles where user_id = '00000000-0000-0000-0000-0000000000c2'), 'TestAutre',
  'a user cannot rename someone else');
select throws_ok($$select email from auth.users$$, '42501', null, 'signed-in users cannot read emails');

select * from finish();
rollback;
