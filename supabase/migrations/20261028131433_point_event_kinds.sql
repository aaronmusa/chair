alter table public.point_events
  add column event_kind text not null default 'point'
    check (event_kind in ('point', 'fault', 'let', 'undo', 'set_score', 'swap_server', 'swap_ends', 'swap_receivers', 'retire')),
  add column undone boolean not null default false,
  add column payload jsonb;
