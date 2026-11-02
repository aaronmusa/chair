alter table public.point_events
  add column updated_at timestamptz not null default now();

create function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (to_jsonb(new) - 'updated_at') is distinct from (to_jsonb(old) - 'updated_at') then
    new.updated_at = now();
  else
    new.updated_at = old.updated_at;
  end if;
  return new;
end;
$$;

create trigger point_events_touch_updated_at
  before update on public.point_events
  for each row execute function public.touch_updated_at();
