import { createClient } from "npm:@supabase/supabase-js@2.45.4";

import { handleDeleteAccount } from "./delete_account.ts";
import { supabaseDeps } from "./deps.ts";

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false, autoRefreshToken: false },
});

Deno.serve((req) => handleDeleteAccount(req, supabaseDeps(admin)));
