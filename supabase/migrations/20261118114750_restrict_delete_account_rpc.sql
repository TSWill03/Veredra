-- Restrict the account-deletion RPC to signed-in users only.
-- Supabase may grant EXECUTE to anon explicitly despite revoking PUBLIC.
revoke execute on function public.delete_own_account() from anon;
revoke execute on function public.delete_own_account() from public;
grant execute on function public.delete_own_account() to authenticated;
