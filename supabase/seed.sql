insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
)
select
  '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated', email,
  extensions.crypt('chair-local', extensions.gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''
from (values
  ('00000000-0000-0000-0000-00000000000a'::uuid, 'aaron@chair.test'),
  ('00000000-0000-0000-0000-00000000000b'::uuid, 'juan@chair.test')
) as seed (id, email);

insert into auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at, last_sign_in_at)
select gen_random_uuid(), id, id::text, jsonb_build_object('sub', id::text, 'email', email), 'email', now(), now(), now()
from auth.users
where email in ('aaron@chair.test', 'juan@chair.test');

insert into public.profiles (id, handle, display_name, hand, level) values
  ('00000000-0000-0000-0000-00000000000a', 'aaron', 'Aaron', 'right', 'intermediate'),
  ('00000000-0000-0000-0000-00000000000b', 'juan', 'Juan', 'left', 'intermediate');
