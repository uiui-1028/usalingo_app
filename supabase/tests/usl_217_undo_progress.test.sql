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
    from pg_policies as delete_policy
    join pg_policies as select_policy
      on select_policy.schemaname = delete_policy.schemaname
     and select_policy.tablename = delete_policy.tablename
     and select_policy.policyname = 'user_card_progress_select_own'
     and select_policy.qual = delete_policy.qual
    where delete_policy.schemaname = 'public'
      and delete_policy.tablename = 'user_card_progress'
      and delete_policy.policyname = 'user_card_progress_delete_own'
      and delete_policy.cmd = 'DELETE'
      and delete_policy.roles = array['authenticated']::name[]$$,
  array[1::bigint],
  'Undo DELETE is limited to the current user by RLS'
);

select * from finish();

rollback;
