import { createClient } from "npm:@supabase/supabase-js@2.45.4";

import { handleCoach } from "./coach.ts";

const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!);

async function userIdFor(token: string): Promise<string | null> {
  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user) return null;
  return data.user.id;
}

Deno.serve((req) => handleCoach(req, { apiKey: Deno.env.get("ANTHROPIC_API_KEY"), userIdFor }));
