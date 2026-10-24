-- Missing restaurants sent from the app. The admin adds the good ones to OpenStreetMap; the monthly import picks them up.
create table public.suggestions (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles on delete cascade,
  name text not null check (length(trim(name)) between 2 and 100),
  address text not null check (length(trim(address)) between 2 and 200),
  note text check (length(note) <= 500),
  created_at timestamptz not null default now()
);

-- Write-only for users, like reports: only the admin reads them, in the dashboard.
alter table public.suggestions enable row level security;
revoke all on public.suggestions from anon, authenticated;
grant insert (user_id, name, address, note) on public.suggestions to authenticated;
create policy "users suggest in their own name" on public.suggestions for insert to authenticated
  with check ((select auth.uid()) = user_id);
