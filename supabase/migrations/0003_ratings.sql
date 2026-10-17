-- Nicknames for comment authors; Task 6 adds sign-in and the write policies.
create table public.profiles (
  user_id uuid primary key references auth.users on delete cascade,
  nickname text not null unique check (char_length(nickname) between 3 and 20)
);

alter table public.profiles enable row level security;
create policy "nicknames are public" on public.profiles for select using (true);

create table public.ratings (
  id bigint generated always as identity primary key,
  -- An import that drops a restaurant drops its ratings too.
  restaurant_id bigint not null references public.restaurants on delete cascade,
  user_id uuid not null references public.profiles on delete cascade,
  stars smallint not null check (stars between 1 and 5),
  comment text check (char_length(comment) <= 1000),
  hidden boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (restaurant_id, user_id)
);

-- Hidden (reported) ratings never leave the database; Task 7 adds the write policies.
alter table public.ratings enable row level security;
create policy "visible ratings are public" on public.ratings for select using (not hidden);

-- security_invoker: both views go through the ratings RLS, so hidden ratings count nowhere.
create view public.restaurant_stats with (security_invoker = true) as
  select restaurant_id, round(avg(stars), 1)::float8 as avg_stars, count(*)::int as rating_count
  from public.ratings group by restaurant_id;

create view public.rating_list with (security_invoker = true) as
  select r.id, r.restaurant_id, r.stars, r.comment, r.created_at, p.nickname
  from public.ratings r join public.profiles p using (user_id);

grant select on public.restaurant_stats, public.rating_list to anon, authenticated;
