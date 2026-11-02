begin;

create extension if not exists pgtap with schema extensions;

select plan(16);

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

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000003aa', 'link_a@chair.test'),
  ('00000000-0000-0000-0000-0000000003bb', 'link_b@chair.test'),
  ('00000000-0000-0000-0000-0000000003cc', 'link_c@chair.test');

select pg_temp.run_as('00000000-0000-0000-0000-0000000003aa', $sql$
  insert into matches (id, format, updated_at) values ('33333333-3333-3333-3333-333333333333', 'singles', '2026-11-01');
  insert into match_players (match_id, slot, name, user_id, link_status, invited_at) values
    ('33333333-3333-3333-3333-333333333333', 'A1', 'Aaron', null, 'none', null),
    ('33333333-3333-3333-3333-333333333333', 'B1', 'Juan', '00000000-0000-0000-0000-0000000003bb', 'pending', now());
  insert into point_events (match_id, index, at, source) values
    ('33333333-3333-3333-3333-333333333333', 0, now(), 'manual'),
    ('33333333-3333-3333-3333-333333333333', 1, now(), 'manual');
$sql$);

-- Pending grants nothing

select is(pg_temp.count_as('00000000-0000-0000-0000-0000000003bb', 'select * from matches'), 0,
  'a pending invitee reads zero matches');
select is(pg_temp.count_as('00000000-0000-0000-0000-0000000003bb', 'select * from my_matches'), 0,
  'a pending invitee has nothing in my_matches');
select is(pg_temp.count_as('00000000-0000-0000-0000-0000000003bb',
  'select * from pending_invites where match_id = ''33333333-3333-3333-3333-333333333333'' and owner_handle is not null'), 1,
  'the pending invite lists the match with the owner''s handle');

-- C sees nothing

select is(pg_temp.count_as('00000000-0000-0000-0000-0000000003cc',
  'select * from my_matches where id = ''33333333-3333-3333-3333-333333333333'''), 0,
  'C has nothing in my_matches');
select is(pg_temp.count_as('00000000-0000-0000-0000-0000000003cc',
  'select * from pending_invites where match_id = ''33333333-3333-3333-3333-333333333333'''), 0,
  'C has no pending invite for A''s match');

-- The invitee cannot write match_players directly

select pg_temp.run_as('00000000-0000-0000-0000-0000000003bb',
  'update match_players set link_status = ''accepted'' where match_id = ''33333333-3333-3333-3333-333333333333''');
select is((select link_status from match_players where match_id = '33333333-3333-3333-3333-333333333333' and slot = 'B1'),
  'pending', 'RLS rejects the invitee''s direct update');

-- Accepting through the RPC

select throws_ok($$
  select pg_temp.run_as('00000000-0000-0000-0000-0000000003cc',
    'select public.respond_to_invite(''33333333-3333-3333-3333-333333333333'', true)')
$$, 'P0002', null, 'a user without a pending row cannot respond');
select lives_ok($$
  select pg_temp.run_as('00000000-0000-0000-0000-0000000003bb',
    'select public.respond_to_invite(''33333333-3333-3333-3333-333333333333'', true)')
$$, 'the invitee accepts');
select is((select link_status from match_players where match_id = '33333333-3333-3333-3333-333333333333' and slot = 'B1'),
  'accepted', 'the row is accepted');
select isnt((select responded_at from match_players where match_id = '33333333-3333-3333-3333-333333333333' and slot = 'B1'),
  null, 'responded_at is set');
select cmp_ok((select updated_at from matches where id = '33333333-3333-3333-3333-333333333333'),
  '>', '2026-11-01'::timestamptz, 'the parent match moved when B answered');

-- Accepted reads the match

select is(pg_temp.count_as('00000000-0000-0000-0000-0000000003bb', 'select * from matches'), 1,
  'an accepted invitee reads the match');
select is(pg_temp.count_as('00000000-0000-0000-0000-0000000003bb',
  'select * from point_events where match_id = ''33333333-3333-3333-3333-333333333333'''), 2,
  'an accepted invitee reads its points');
select is(pg_temp.count_as('00000000-0000-0000-0000-0000000003bb',
  'select * from my_matches where role = ''linked'''), 1,
  'my_matches lists it once as linked');

-- A stale pending re-upload keeps the answer

select lives_ok($$
  select pg_temp.run_as('00000000-0000-0000-0000-0000000003aa', $sql$
    insert into match_players (match_id, slot, name, user_id, link_status, invited_at)
    values ('33333333-3333-3333-3333-333333333333', 'B1', 'Juan', '00000000-0000-0000-0000-0000000003bb', 'pending', now())
    on conflict (match_id, slot) do update
    set name = excluded.name, user_id = excluded.user_id, link_status = excluded.link_status, invited_at = excluded.invited_at
  $sql$)
$$, 'the owner''s stale re-upload succeeds');
select ok((select link_status = 'accepted' and responded_at is not null
  from match_players where match_id = '33333333-3333-3333-3333-333333333333' and slot = 'B1'),
  'the row stays accepted with its responded_at');

select * from finish();

rollback;
