begin;
select plan(6);

insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000e1', 'e1@test.fr');
insert into public.profiles values ('00000000-0000-0000-0000-0000000000e1', 'TestSug1');

set local role anon;
select throws_ok($$insert into public.suggestions (user_id, name, address) values ('00000000-0000-0000-0000-0000000000e1', 'Chez Coco', '1 rue Haute, Lyon')$$,
  '42501', null, 'signed-out visitors cannot suggest');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-0000000000e1", "role": "authenticated"}', true);
select lives_ok($$insert into public.suggestions (user_id, name, address, note) values (auth.uid(), 'Chez Coco', '1 rue Haute, Lyon', 'Super frango')$$,
  'a user suggests a restaurant');
select throws_ok($$insert into public.suggestions (user_id, name, address) values ('00000000-0000-0000-0000-0000000000e2', 'Chez Coco', '1 rue Haute, Lyon')$$,
  '42501', null, 'cannot suggest in someone else''s name');
select throws_ok($$insert into public.suggestions (user_id, name, address) values (auth.uid(), ' ', '1 rue Haute, Lyon')$$,
  '23514', null, 'a name is required');
select throws_ok($$select * from public.suggestions$$, '42501', null, 'suggestions are not readable');

reset role;
delete from auth.users where id = '00000000-0000-0000-0000-0000000000e1';
select is((select count(*)::int from public.suggestions), 0, 'deleting the account deletes its suggestions');

select * from finish();
rollback;
