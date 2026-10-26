create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  handle text unique check (handle ~ '^[a-z0-9_]{3,20}$'),
  display_name text not null default '',
  avatar_url text,
  home_court text,
  hand text check (hand in ('right', 'left')),
  level text,
  created_at timestamptz not null default now()
);

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  played_at timestamptz not null default now(),
  format text not null check (format in ('singles', 'doubles')),
  rules jsonb not null default '{}'::jsonb,
  status text not null default 'in_progress' check (status in ('in_progress', 'completed', 'abandoned')),
  input_mode text not null default 'manual',
  referee_mode text not null default 'none',
  sets jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index matches_owner_id_idx on public.matches (owner_id);

create table public.match_players (
  match_id uuid not null references public.matches (id) on delete cascade,
  slot text not null check (slot in ('A1', 'A2', 'B1', 'B2')),
  name text not null,
  user_id uuid references auth.users (id) on delete set null,
  link_status text not null default 'none' check (link_status in ('none', 'pending', 'accepted')),
  primary key (match_id, slot),
  check (user_id is not null or link_status = 'none')
);

create index match_players_user_id_idx on public.match_players (user_id) where user_id is not null;

create table public.point_events (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches (id) on delete cascade,
  index integer not null check (index >= 0),
  at timestamptz not null,
  winner_side text check (winner_side in ('A', 'B')),
  outcome text,
  source text not null,
  confidence real check (confidence between 0 and 1),
  corrected boolean not null default false,
  clip_path text,
  unique (match_id, index)
);

create table public.saved_courts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null,
  corners jsonb not null,
  placement text not null,
  created_at timestamptz not null default now()
);

create table public.training_sessions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create function public.owns_match(p_match_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from matches where id = p_match_id and owner_id = auth.uid()
  );
$$;

create function public.is_linked_to_match(p_match_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from match_players
    where match_id = p_match_id and user_id = auth.uid() and link_status = 'accepted'
  );
$$;

revoke execute on function public.owns_match(uuid) from public, anon;
revoke execute on function public.is_linked_to_match(uuid) from public, anon;
grant execute on function public.owns_match(uuid) to authenticated;
grant execute on function public.is_linked_to_match(uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.matches enable row level security;
alter table public.match_players enable row level security;
alter table public.point_events enable row level security;
alter table public.saved_courts enable row level security;
alter table public.training_sessions enable row level security;

create policy profiles_owner_all on public.profiles
  for all to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy matches_owner_all on public.matches
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy matches_linked_read on public.matches
  for select to authenticated
  using (public.is_linked_to_match(id));

create policy match_players_owner_all on public.match_players
  for all to authenticated
  using (public.owns_match(match_id))
  with check (public.owns_match(match_id));

create policy match_players_linked_read on public.match_players
  for select to authenticated
  using (public.is_linked_to_match(match_id));

create policy point_events_owner_all on public.point_events
  for all to authenticated
  using (public.owns_match(match_id))
  with check (public.owns_match(match_id));

create policy point_events_linked_read on public.point_events
  for select to authenticated
  using (public.is_linked_to_match(match_id));

create policy saved_courts_owner_all on public.saved_courts
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy training_sessions_owner_all on public.training_sessions
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());
