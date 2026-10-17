-- Signed-in users pick their own nickname and can change it; nobody else's.
create policy "users create their profile" on public.profiles for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "users rename themselves" on public.profiles for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
