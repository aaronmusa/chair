alter table public.saved_courts
  drop column corners,
  add column calibration jsonb not null,
  add column last_used_at timestamptz,
  add column latitude double precision,
  add column longitude double precision,
  add column updated_at timestamptz not null default now();

create trigger saved_courts_touch_updated_at
  before update on public.saved_courts
  for each row execute function public.touch_updated_at();
