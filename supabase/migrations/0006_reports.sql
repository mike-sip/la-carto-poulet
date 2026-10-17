create table public.reports (
  rating_id bigint not null references public.ratings on delete cascade,
  reporter_id uuid not null references public.profiles on delete cascade,
  reason text not null check (reason in ('insult', 'spam', 'off_topic', 'other')),
  created_at timestamptz not null default now(),
  primary key (rating_id, reporter_id)
);

-- Write-only for users: nobody reads reports except the admin in the dashboard.
alter table public.reports enable row level security;
revoke all on public.reports from anon, authenticated;
grant insert (rating_id, reporter_id, reason) on public.reports to authenticated;
create policy "users report others' ratings" on public.reports for insert to authenticated
  with check ((select auth.uid()) = reporter_id
              and not exists (select 1 from public.ratings r where r.id = rating_id and r.user_id = (select auth.uid())));

-- security definer: reporters can neither count others' reports nor touch `hidden`.
create function public.hide_after_three_reports() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (select count(*) from public.reports where rating_id = new.rating_id) >= 3 then
    update public.ratings set hidden = true where id = new.rating_id;
  end if;
  return new;
end $$;
revoke execute on function public.hide_after_three_reports() from public, anon, authenticated;
create trigger reports_hide after insert on public.reports
  for each row execute function public.hide_after_three_reports();

-- My own ratings stay readable to me even once hidden, so the form can say why they vanished.
-- The views filter `hidden` themselves so a hidden rating still shows and counts nowhere.
create policy "users read their own ratings" on public.ratings for select to authenticated
  using ((select auth.uid()) = user_id);

create or replace view public.restaurant_stats with (security_invoker = true) as
  select restaurant_id, round(avg(stars), 1)::float8 as avg_stars, count(*)::int as rating_count
  from public.ratings where not hidden group by restaurant_id;

-- user_id lets the app block an author; is_mine hides "Signaler" on my own comments.
create or replace view public.rating_list with (security_invoker = true) as
  select r.id, r.restaurant_id, r.stars, r.comment, r.created_at, p.nickname,
         r.user_id, coalesce(r.user_id = (select auth.uid()), false) as is_mine
  from public.ratings r join public.profiles p using (user_id)
  where not r.hidden;
