begin;

create extension if not exists pgtap with schema extensions;

select plan(4);

select has_column('public', 'point_events', 'updated_at', 'point_events has updated_at');

insert into public.matches (id, owner_id, played_at, format, rules, status, input_mode, referee_mode, sets)
values (
  '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000000a', now(), 'singles',
  '{}'::jsonb, 'in_progress', 'manual', 'none', '[]'::jsonb
);
insert into public.point_events (match_id, index, at, source, event_kind, updated_at)
values ('00000000-0000-0000-0000-0000000000f1', 0, now(), 'manual', 'point', '2000-01-01');

select is(
  (select updated_at from public.point_events where match_id = '00000000-0000-0000-0000-0000000000f1' and index = 0),
  '2000-01-01'::timestamptz,
  'an insert keeps the given updated_at'
);

update public.point_events set source = 'manual', updated_at = '2001-01-01'
where match_id = '00000000-0000-0000-0000-0000000000f1' and index = 0;

select is(
  (select updated_at from public.point_events where match_id = '00000000-0000-0000-0000-0000000000f1' and index = 0),
  '2000-01-01'::timestamptz,
  'an update that changes nothing keeps updated_at'
);

update public.point_events set undone = true
where match_id = '00000000-0000-0000-0000-0000000000f1' and index = 0;

select ok(
  (select updated_at > '2000-01-01' from public.point_events where match_id = '00000000-0000-0000-0000-0000000000f1' and index = 0),
  'an update bumps updated_at'
);

select * from finish();
rollback;
