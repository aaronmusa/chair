create extension if not exists citext with schema extensions;

update public.profiles
set handle = 'player_' || left(id::text, 8)
where handle is null;

update public.profiles
set display_name = 'Player'
where display_name = '';

create type public.hand as enum ('left', 'right');
create type public.level as enum ('beginner', 'intermediate', 'advanced');

alter table public.profiles drop constraint profiles_handle_check;
alter table public.profiles drop constraint profiles_hand_check;

alter table public.profiles
  alter column handle type extensions.citext,
  alter column handle set not null,
  add constraint profiles_handle_format check (handle::text ~ '^[a-z0-9_]{3,20}$'),
  alter column display_name set default 'Player',
  add constraint profiles_display_name_length check (char_length(display_name) between 1 and 40),
  alter column hand type public.hand using hand::public.hand,
  alter column level type public.level using level::public.level,
  add column updated_at timestamptz not null default now();

create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  generated_handle text := 'player_' || left(new.id::text, 8);
begin
  if exists (select 1 from profiles where handle = generated_handle) then
    generated_handle := 'player_' || right(replace(new.id::text, '-', ''), 13);
  end if;
  insert into profiles (id, handle, display_name)
  values (
    new.id,
    generated_handle,
    left(coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
      nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
      'Player'
    ), 40)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop policy profiles_owner_all on public.profiles;

create policy profiles_owner_select on public.profiles
  for select to authenticated
  using (id = auth.uid());

create policy profiles_owner_update on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

revoke insert, delete on public.profiles from anon, authenticated;

create view public.public_profiles
with (security_invoker = false)
as select id, handle, display_name, level from public.profiles;

comment on view public.public_profiles is
  'Deliberately security definer: exposes only public columns of profiles, which stays owner-only under RLS.';

revoke all on public.public_profiles from anon, public;
grant select on public.public_profiles to authenticated;

create function public.profiles_search(q text)
returns setof public.public_profiles
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select *
  from public_profiles
  where starts_with(lower(handle::text), lower(trim(q)))
    and id is distinct from auth.uid()
  order by handle
  limit 20;
$$;

create function public.handle_available(h extensions.citext)
returns boolean
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select not exists (select 1 from public_profiles where handle = h);
$$;

revoke execute on function public.profiles_search(text) from public, anon;
revoke execute on function public.handle_available(extensions.citext) from public, anon;
grant execute on function public.profiles_search(text) to authenticated;
grant execute on function public.handle_available(extensions.citext) to authenticated;
