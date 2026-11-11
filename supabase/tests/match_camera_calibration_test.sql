begin;

create extension if not exists pgtap with schema extensions;

select plan(4);

select has_column('public', 'matches', 'camera_placement', 'matches records the camera placement');
select has_column('public', 'matches', 'calibration', 'matches records the court calibration');

insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000001aa', 'owner@chair.test');

select lives_ok($$
  insert into public.matches (owner_id, played_at, format, rules, status, input_mode, referee_mode, sets, camera_placement, calibration)
  values ('00000000-0000-0000-0000-0000000001aa', now(), 'singles', '{}', 'in_progress', 'camera', 'none', '[]', 'netPost', '{"keypoints": []}')
$$, 'a camera match stores its placement and calibration');

select throws_ok($$
  insert into public.matches (owner_id, played_at, format, rules, status, input_mode, referee_mode, sets, camera_placement)
  values ('00000000-0000-0000-0000-0000000001aa', now(), 'singles', '{}', 'in_progress', 'camera', 'none', '[]', 'roof')
$$, '23514', null, 'an unknown placement is refused');

select * from finish();
rollback;
