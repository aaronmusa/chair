create function public.delete_account_data(uid uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.point_events
  where match_id in (select id from public.matches where owner_id = uid);
  delete from public.matches where owner_id = uid;
  delete from public.saved_courts where owner_id = uid;
  delete from public.training_sessions where owner_id = uid;
  update public.match_players
  set user_id = null, link_status = 'none'
  where user_id = uid;
  delete from public.profiles where id = uid;
end;
$$;

revoke execute on function public.delete_account_data(uuid) from public, anon, authenticated;
grant execute on function public.delete_account_data(uuid) to service_role;
