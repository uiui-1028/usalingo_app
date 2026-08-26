begin;
select plan(16);

select has_schema('private', 'private account lifecycle schema exists');
select has_table('private', 'account_deletions', 'account lifecycle state exists');
select has_function('public', 'request_account_deletion', array['uuid', 'uuid', 'timestamp with time zone'], 'request RPC exists');
select has_function('public', 'advance_account_deletion', array['uuid', 'uuid', 'text', 'text'], 'step RPC exists');
select has_function('public', 'get_account_deletion', array['uuid', 'uuid'], 'idempotency lookup exists');
select has_function('public', 'claim_expired_account_purge', array['uuid'], 'expiry purge claim exists');
select function_privs_are('public', 'request_account_deletion', array['uuid', 'uuid', 'timestamp with time zone'], 'service_role', array['EXECUTE'], 'service role can request withdrawal');
select function_privs_are('public', 'request_account_deletion', array['uuid', 'uuid', 'timestamp with time zone'], 'authenticated', array[]::text[], 'clients cannot call privileged withdrawal RPC');
select function_privs_are('public', 'get_account_deletion', array['uuid', 'uuid'], 'authenticated', array[]::text[], 'clients cannot call lifecycle lookup RPC');
select function_privs_are('public', 'claim_expired_account_purge', array['uuid'], 'authenticated', array[]::text[], 'clients cannot claim final deletion');
select table_privs_are('private', 'account_deletions', 'authenticated', array[]::text[], 'clients cannot read lifecycle state');
select col_is_pk('private', 'account_deletions', 'user_id', 'one lifecycle row exists per user');
select col_is_unique('private', 'account_deletions', 'request_id', 'request IDs are idempotency keys');
select policies_are('public', 'users', array['users_require_active_account', 'users_select_own'], 'users table includes active-account guard');
select policies_are('public', 'user_card_progress', array['user_card_progress_delete_own', 'user_card_progress_insert_own', 'user_card_progress_require_active_account', 'user_card_progress_select_own', 'user_card_progress_update_own'], 'card progress includes active-account guard');
select volatility_is('public', 'is_current_user_active', array[]::text[], 'stable', 'active-account check is stable');

select * from finish();
rollback;
