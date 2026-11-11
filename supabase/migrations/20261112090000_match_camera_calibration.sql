alter table public.matches
  add column camera_placement text check (camera_placement in ('netPost', 'baseline', 'chair')),
  add column calibration jsonb;
