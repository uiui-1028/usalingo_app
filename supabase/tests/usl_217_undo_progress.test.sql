begin;

create extension if not exists pgtap with schema extensions;

select plan(3);

select ok(
  has_table_privilege('authenticated', 'public.user_card_progress', 'delete'),
  'authenticated users can delete card progress for Undo'
);

select ok(
  not has_table_privilege('anon', 'public.user_card_progress', 'delete'),
  'anonymous users cannot delete card progress'
);

select results_eq(
  $$select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_card_progress'
      and policyname = 'user_card_progress_delete_own'
      and cmd = 'DELETE'
      and roles = array['authenticated']::name[]
      and qual = '(auth.uid() = user_id)'$$,
  array[1::bigint],
  'Undo DELETE is limited to the current user by RLS'
);

select * from finish();

rollback;
