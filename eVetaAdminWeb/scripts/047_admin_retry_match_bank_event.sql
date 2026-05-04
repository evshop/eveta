-- 047_admin_retry_match_bank_event.sql
-- Expone el mismo matching/acreditación que el webhook (046 match_wallet_topups_with_bank_event)
-- a perfiles admin autenticados, para reintentar desde el panel o verificar manualmente.

create or replace function public.admin_retry_match_bank_event(p_event_id uuid)
returns table (
  topup_id uuid,
  event_id uuid,
  match_status text,
  score integer
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.profile_is_admin() then
    raise exception 'Sin permisos para conciliar pagos.';
  end if;

  return query
  select *
  from public.match_wallet_topups_with_bank_event(p_event_id);
end;
$$;

revoke all on function public.admin_retry_match_bank_event(uuid) from public;
grant execute on function public.admin_retry_match_bank_event(uuid) to authenticated;
