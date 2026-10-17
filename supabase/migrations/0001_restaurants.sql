create extension if not exists postgis with schema extensions;

create table public.restaurants (
  id bigint generated always as identity primary key,
  osm_id text not null unique,  -- "node/123", "way/456"
  name text not null,
  kind text not null check (kind in ('fast_food', 'restaurant')),
  address text,
  city text,
  location extensions.geography(Point, 4326) not null,
  brand text,
  cuisine text,
  updated_at timestamptz not null default now()
);

create index restaurants_location_idx on public.restaurants using gist (location);

-- Anyone reads; only the import script (service key, bypasses RLS) writes.
alter table public.restaurants enable row level security;
create policy "restaurants are public" on public.restaurants for select using (true);
revoke insert, update, delete on public.restaurants from anon, authenticated;
