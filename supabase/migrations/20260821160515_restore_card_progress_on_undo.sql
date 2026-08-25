-- Undo can remove only the signed-in user's newly created progress row.
-- Existing rows are restored with an UPDATE, which is already covered by the
-- ownership policy created with the card-progress schema.
drop policy if exists user_card_progress_delete_own on public.user_card_progress;
create policy user_card_progress_delete_own
  on public.user_card_progress
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

grant delete on table public.user_card_progress to authenticated;
