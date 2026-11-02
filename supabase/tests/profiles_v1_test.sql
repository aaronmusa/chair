begin;

create extension if not exists pgtap with schema extensions;

select plan(17);

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

create function pg_temp.text_as(user_id uuid, statement text)
returns text
language plpgsql
as $$
declare
  result text;
begin
  perform set_config('request.jwt.claim.sub', user_id::text, true);
  set local role authenticated;
  execute statement into result;
  reset role;
  return result;
end;
$$;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000002aa', 'profile_a@chair.test'),
  ('00000000-0000-0000-0000-0000000002bb', 'profile_b@chair.test');

-- Auto-create

select matches((select handle::text from public.profiles where id = '00000000-0000-0000-0000-0000000002aa'),
  '^player_[0-9a-f]{8,13}$', 'a new user gets a generated handle');
select is((select display_name from public.profiles where id = '00000000-0000-0000-0000-0000000002aa'),
  'Player', 'a new user without a name is called Player');
select matches((select handle::text from public.profiles where id = '00000000-0000-0000-0000-0000000002bb'),
  '^player_[0-9a-f]{8,13}$', 'a second user whose id shares the prefix also gets a handle');
select is((select count(distinct handle)::integer from public.profiles where id in (
  '00000000-0000-0000-0000-0000000002aa', '00000000-0000-0000-0000-0000000002bb')),
  2, 'generated handles are unique');

-- Handle rules

select throws_ok($$
  select pg_temp.run_as('00000000-0000-0000-0000-0000000002aa',
    'update profiles set handle = ''Aaron!'' where id = auth.uid()')
$$, '23514', null, 'the check constraint rejects "Aaron!"');
select lives_ok($$
  select pg_temp.run_as('00000000-0000-0000-0000-0000000002aa',
    'update profiles set handle = ''aaron_m'' where id = auth.uid()')
$$, '"aaron_m" is accepted');
select throws_ok($$
  select pg_temp.run_as('00000000-0000-0000-0000-0000000002bb',
    'update profiles set handle = ''AARON_M'' where id = auth.uid()')
$$, '23514', null, '"AARON_M" is rejected');
select is(pg_temp.text_as('00000000-0000-0000-0000-0000000002bb',
  'select public.handle_available(''AARON_M'')::text'), 'false',
  '"AARON_M" collides with "aaron_m"');
select is(pg_temp.text_as('00000000-0000-0000-0000-0000000002bb',
  'select public.handle_available(''aaron_m2'')::text'), 'true',
  '"aaron_m2" is available');
select throws_ok($$
  select pg_temp.run_as('00000000-0000-0000-0000-0000000002aa',
    'update profiles set display_name = '''' where id = auth.uid()')
$$, '23514', null, 'an empty display name is rejected');

-- Visibility

select is(pg_temp.count_as('00000000-0000-0000-0000-0000000002bb',
  'select * from profiles where id = ''00000000-0000-0000-0000-0000000002aa'''), 0,
  'B reads zero rows of A''s profile');
select is(pg_temp.count_as('00000000-0000-0000-0000-0000000002bb',
  'select * from public_profiles where id = ''00000000-0000-0000-0000-0000000002aa'''), 1,
  'B reads A''s public profile');
select is((
  select string_agg(column_name::text, ',' order by ordinal_position)
  from information_schema.columns
  where table_schema = 'public' and table_name = 'public_profiles'
), 'id,handle,display_name,level',
  'public_profiles has only id, handle, display_name and level');
select is(pg_temp.count_as('00000000-0000-0000-0000-0000000002aa',
  'select * from profiles_search(''AARON_'')'), 0,
  'search excludes the caller');
select is(pg_temp.count_as('00000000-0000-0000-0000-0000000002bb',
  'select * from profiles_search(''AAR'') where handle = ''aaron_m'''), 1,
  'search is a case-insensitive prefix match on handle');
select throws_ok($$
  select pg_temp.run_as('00000000-0000-0000-0000-0000000002aa',
    'delete from profiles where id = auth.uid()')
$$, '42501', null, 'a user cannot delete a profile directly');
select throws_ok($$
  select pg_temp.run_as('00000000-0000-0000-0000-0000000002aa',
    'insert into profiles (id, handle) values (gen_random_uuid(), ''sneaky'')')
$$, '42501', null, 'a user cannot insert a profile directly');

select * from finish();

rollback;
