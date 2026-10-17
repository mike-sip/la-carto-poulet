-- Users write only their own ratings. Column grants keep `hidden` and the timestamps out of their reach,
-- so a reported rating can't be un-hidden by its author.
revoke insert, update on public.ratings from anon, authenticated;
grant insert (restaurant_id, user_id, stars, comment), update (stars, comment), delete on public.ratings to authenticated;

create policy "users add their rating" on public.ratings for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "users edit their rating" on public.ratings for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "users delete their rating" on public.ratings for delete to authenticated
  using ((select auth.uid()) = user_id);

create function public.touch_updated_at() returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end $$;
create trigger ratings_updated_at before update on public.ratings
  for each row execute function public.touch_updated_at();
