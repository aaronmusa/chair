alter table public.match_players
  add column invited_at timestamptz,
  add column responded_at timestamptz,
  add column updated_at timestamptz not null default now();

alter table public.match_players drop constraint match_players_link_status_check;
alter table public.match_players
  add constraint match_players_link_status_check
  check (link_status in ('none', 'pending', 'accepted', 'declined'));

create index match_players_user_id_link_status_idx on public.match_players (user_id, link_status);

create function public.match_players_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.user_id is null then
    new.link_status := 'none';
    new.invited_at := null;
    new.responded_at := null;
  elsif new.user_id is distinct from old.user_id then
    new.responded_at := null;
  elsif old.link_status in ('accepted', 'declined') then
    new.link_status := old.link_status;
    new.responded_at := old.responded_at;
  end if;
  return new;
end;
$$;

create trigger match_players_guard
  before update on public.match_players
  for each row execute function public.match_players_guard();

create trigger match_players_touch_updated_at
  before update on public.match_players
  for each row execute function public.touch_updated_at();

create function public.match_players_bump_match()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (to_jsonb(new) - 'updated_at') is distinct from (to_jsonb(old) - 'updated_at')
     and not public.owns_match(new.match_id) then
    update public.matches set updated_at = now() where id = new.match_id;
  end if;
  return null;
end;
$$;

revoke execute on function public.match_players_bump_match() from public, anon, authenticated;

create trigger match_players_bump_match
  after update on public.match_players
  for each row execute function public.match_players_bump_match();

create function public.respond_to_invite(
  p_match_id uuid,
  accept boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.match_players
  set link_status = case when accept then 'accepted' else 'declined' end,
      responded_at = now()
  where match_id = p_match_id
    and user_id = auth.uid()
    and link_status = 'pending';
  if not found then
    raise exception 'no pending invite for this match' using errcode = 'P0002';
  end if;
end;
$$;

revoke execute on function public.respond_to_invite(uuid, boolean) from public, anon;
grant execute on function public.respond_to_invite(uuid, boolean) to authenticated;

create view public.my_matches
with (security_invoker = true)
as
select
  m.*,
  case when m.owner_id = auth.uid() then 'owner' else 'linked' end as role
from public.matches m;

revoke all on public.my_matches from anon, public;
grant select on public.my_matches to authenticated;

create view public.pending_invites
with (security_invoker = false)
as
select
  mp.match_id,
  mp.slot,
  mp.invited_at,
  m.owner_id,
  p.handle as owner_handle,
  p.display_name as owner_display_name,
  m.played_at,
  m.format,
  m.status,
  m.sets
from public.match_players mp
join public.matches m on m.id = mp.match_id
join public.profiles p on p.id = m.owner_id
where mp.user_id = auth.uid()
  and mp.link_status = 'pending';

comment on view public.pending_invites is
  'Deliberately security definer: RLS hides matches from a pending invitee, so the view filters on auth.uid() itself.';

revoke all on public.pending_invites from anon, public;
grant select on public.pending_invites to authenticated;
