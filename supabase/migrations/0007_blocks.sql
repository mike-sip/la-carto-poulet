-- A user hides another user's comments from their own view. Averages still count them.
create table public.blocks (
  blocker_id uuid not null references public.profiles on delete cascade,
  blocked_id uuid not null references public.profiles on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

alter table public.blocks enable row level security;
revoke all on public.blocks from anon, authenticated;
grant select, insert (blocker_id, blocked_id), delete on public.blocks to authenticated;
-- anon gets no policy, so it reads zero rows; the grant only lets rating_list's subquery run signed out.
grant select on public.blocks to anon;

create policy "users read their blocks" on public.blocks for select to authenticated
  using ((select auth.uid()) = blocker_id);
create policy "users add their blocks" on public.blocks for insert to authenticated
  with check ((select auth.uid()) = blocker_id);
create policy "users remove their blocks" on public.blocks for delete to authenticated
  using ((select auth.uid()) = blocker_id);

create or replace view public.rating_list with (security_invoker = true) as
  select r.id, r.restaurant_id, r.stars, r.comment, r.created_at, p.nickname,
         r.user_id, coalesce(r.user_id = (select auth.uid()), false) as is_mine
  from public.ratings r join public.profiles p using (user_id)
  where not r.hidden
    and not exists (select 1 from public.blocks b where b.blocked_id = r.user_id);

-- The Account screen's list; RLS on blocks keeps it to my own.
create view public.my_blocks with (security_invoker = true) as
  select b.blocked_id, p.nickname, b.created_at
  from public.blocks b join public.profiles p on p.user_id = b.blocked_id;
grant select on public.my_blocks to authenticated;
