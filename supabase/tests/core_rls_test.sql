begin;

create extension if not exists pgtap with schema extensions;

select plan(22);

create function pg_temp.count_as(user_id uuid, statement text)
returns integer
language plpgsql
as $$
declare
  n integer;
begin
  perform set_config('request.jwt.claim.sub', user_id::text, true);
  set local role authenticated;
  execute 'select count(*)::integer from (' || statement || ') s' into n;
  reset role;
  return n;
end;
$$;

create function pg_temp.run_as(user_id uuid, statement text)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', user_id::text, true);
  set local role authenticated;
  execute statement;
  reset role;
end;
$$;

select ok(bool_and(relrowsecurity), 'RLS is on for every core table')
from pg_class
where oid in (
  'public.profiles'::regclass, 'public.matches'::regclass, 'public.match_players'::regclass,
  'public.point_events'::regclass, 'public.saved_courts'::regclass, 'public.training_sessions'::regclass
);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000001aa', 'owner@chair.test'),
  ('00000000-0000-0000-0000-0000000001bb', 'opponent@chair.test'),
  ('00000000-0000-0000-0000-0000000001cc', 'stranger@chair.test');

insert into public.profiles (id, handle, display_name) values
  ('00000000-0000-0000-0000-0000000001aa', 'rls_owner', 'Owner'),
  ('00000000-0000-0000-0000-0000000001bb', 'rls_juan', 'Juan');

insert into public.matches (id, owner_id, format) values
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-0000000001aa', 'singles');

insert into public.match_players (match_id, slot, name, user_id, link_status) values
  ('11111111-1111-1111-1111-111111111111', 'A1', 'Owner', '00000000-0000-0000-0000-0000000001aa', 'accepted'),
  ('11111111-1111-1111-1111-111111111111', 'B1', 'Juan', null, 'none');

insert into public.point_events (match_id, index, at, winner_side, outcome, source) values
  ('11111111-1111-1111-1111-111111111111', 0, now(), 'A', 'ace', 'manual'),
  ('11111111-1111-1111-1111-111111111111', 1, now(), 'B', 'winner', 'manual'),
  ('11111111-1111-1111-1111-111111111111', 2, now(), 'A', 'unforcedError', 'manual');

insert into public.saved_courts (owner_id, name, corners, placement) values
  ('00000000-0000-0000-0000-0000000001aa', 'Home', '[]', 'netPost');

-- The owner reads and writes their own rows

select is(pg_temp.count_as('00000000-0000-0000-0000-0000000001aa', 'select * from matches'), 1,
  'the owner reads their match');
select is(pg_temp.count_as('00000000-0000-0000-0000-0000000001aa', 'select * from point_events'), 3,
  'the owner reads its points');
select is(pg_temp.count_as('00000000-0000-0000-0000-0000000001aa', 'select * from saved_courts'), 1,
  'the owner reads their saved court');
select lives_ok($$
  select pg_temp.run_as('00000000-0000-0000-0000-0000000001aa',
    'update matches set status = ''completed'' where id = ''11111111-1111-1111-1111-111111111111''')
$$, 'the owner updates their match');

-- An unlinked player sees nothing

select is(pg_temp.count_as('00000000-0000-0000-0000-0000000001bb', 'select * from matches'), 0,
  'an unlinked user reads zero matches');
select is(pg_temp.count_as('00000000-0000-0000-0000-0000000001bb', 'select * from point_events'), 0,
  'an unlinked user reads zero points');
select is(pg_temp.count_as('00000000-0000-0000-0000-0000000001bb', 'select * from match_players'), 0,
  'an unlinked user reads zero match players');
select is(pg_temp.count_as('00000000-0000-0000-0000-0000000001bb',
  'select * from profiles where id = ''00000000-0000-0000-0000-0000000001aa'''), 0,
  'a user cannot read someone else''s profile');
select is(pg_temp.count_as('00000000-0000-0000-0000-0000000001bb', 'select * from saved_courts'), 0,
  'a user cannot read someone else''s saved court');

-- A pending link is not enough

update public.match_players
set user_id = '00000000-0000-0000-0000-0000000001bb', link_status = 'pending'
where match_id = '11111111-1111-1111-1111-111111111111' and slot = 'B1';

select is(pg_temp.count_as('00000000-0000-0000-0000-0000000001bb', 'select * from matches'), 0,
  'a pending link reads zero matches');

-- An accepted link reads that match and its points

update public.match_players
set link_status = 'accepted'
where match_id = '11111111-1111-1111-1111-111111111111' and slot = 'B1';

select is(pg_temp.count_as('00000000-0000-0000-0000-0000000001bb', 'select * from matches'), 1,
  'an accepted link reads that one match');
select is(pg_temp.count_as('00000000-0000-0000-0000-0000000001bb', 'select * from point_events'), 3,
  'an accepted link reads its points');
select is(pg_temp.count_as('00000000-0000-0000-0000-0000000001bb', 'select * from match_players'), 2,
  'an accepted link reads the match players');
select is(pg_temp.count_as('00000000-0000-0000-0000-0000000001bb', 'select * from saved_courts'), 0,
  'a linked player still cannot read the owner''s courts');

select lives_ok($$
  select pg_temp.run_as('00000000-0000-0000-0000-0000000001bb',
    'update matches set status = ''abandoned'' where id = ''11111111-1111-1111-1111-111111111111''')
$$, 'a linked player''s update runs');
select is((select status from public.matches where id = '11111111-1111-1111-1111-111111111111'), 'completed',
  'but it changes nothing: a linked player cannot write the match');

select throws_ok($$
  select pg_temp.run_as('00000000-0000-0000-0000-0000000001bb',
    'insert into point_events (match_id, index, at, source) values (''11111111-1111-1111-1111-111111111111'', 3, now(), ''manual'')')
$$, '42501', null, 'a linked player cannot add points');

select throws_ok($$
  select pg_temp.run_as('00000000-0000-0000-0000-0000000001bb',
    'insert into matches (owner_id, format) values (''00000000-0000-0000-0000-0000000001aa'', ''singles'')')
$$, '42501', null, 'nobody can create a match owned by someone else');

-- A stranger sees nothing at all

select is(pg_temp.count_as('00000000-0000-0000-0000-0000000001cc', 'select * from matches'), 0,
  'a stranger reads zero matches');
select is(pg_temp.count_as('00000000-0000-0000-0000-0000000001cc', 'select * from point_events'), 0,
  'a stranger reads zero points');

-- Anonymous callers see nothing

set local role anon;
select is((select count(*)::integer from public.matches), 0, 'anon reads zero matches');
reset role;

select * from finish();
rollback;
