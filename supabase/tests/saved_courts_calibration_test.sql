begin;

create extension if not exists pgtap with schema extensions;

select plan(11);

select hasnt_column('public', 'saved_courts', 'corners', 'saved_courts no longer has corners');
select col_not_null('public', 'saved_courts', 'calibration', 'a saved court always has a calibration');
select col_is_null('public', 'saved_courts', 'last_used_at', 'last_used_at is optional');
select col_is_null('public', 'saved_courts', 'latitude', 'latitude is optional');
select col_is_null('public', 'saved_courts', 'longitude', 'longitude is optional');
select col_not_null('public', 'saved_courts', 'updated_at', 'saved_courts has updated_at');

insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000001aa', 'owner@chair.test');

insert into public.saved_courts (id, owner_id, name, calibration, placement, updated_at)
values (
  '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000001aa', 'Home',
  '{"keypoints": []}'::jsonb, 'netPost', '2000-01-01'
);

select is(
  (select updated_at from public.saved_courts where id = '00000000-0000-0000-0000-0000000000c1'),
  '2000-01-01'::timestamptz,
  'an insert keeps the given updated_at'
);

update public.saved_courts set name = 'Home' where id = '00000000-0000-0000-0000-0000000000c1';

select is(
  (select updated_at from public.saved_courts where id = '00000000-0000-0000-0000-0000000000c1'),
  '2000-01-01'::timestamptz,
  'an update that changes nothing keeps updated_at'
);

update public.saved_courts set name = 'Riverside 3', latitude = -33.86, longitude = 151.21
where id = '00000000-0000-0000-0000-0000000000c1';

select ok(
  (select updated_at > '2000-01-01' from public.saved_courts where id = '00000000-0000-0000-0000-0000000000c1'),
  'a rename bumps updated_at'
);

select policies_are('public', 'saved_courts', array['saved_courts_owner_all'], 'saved courts stay owner-only');

select public.delete_account_data('00000000-0000-0000-0000-0000000001aa');

select is(
  (select count(*)::int from public.saved_courts where owner_id = '00000000-0000-0000-0000-0000000001aa'),
  0,
  'deleting the account removes its saved courts'
);

select * from finish();
rollback;
