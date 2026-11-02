import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.45.4";

import { handleDeleteAccount } from "./delete_account.ts";
import { supabaseDeps } from "./deps.ts";

const url = Deno.env.get("CHAIR_SUPABASE_URL");
const anonKey = Deno.env.get("CHAIR_SUPABASE_ANON_KEY");
const serviceKey = Deno.env.get("CHAIR_SUPABASE_SERVICE_ROLE_KEY");
const options = { auth: { persistSession: false, autoRefreshToken: false } };

async function signedInUser(admin: SupabaseClient, email: string) {
  const password = "delete-me-123";
  const { data, error } = await admin.auth.admin.createUser({ email, password, email_confirm: true });
  if (error) throw error;
  const client = createClient(url!, anonKey!, options);
  const session = await client.auth.signInWithPassword({ email, password });
  if (session.error) throw session.error;
  return { id: data.user.id, client, token: session.data.session!.access_token };
}

async function must<T>(query: PromiseLike<{ data: T; error: unknown }>): Promise<T> {
  const { data, error } = await query;
  if (error) throw error;
  return data;
}

Deno.test({
  name: "deleting A removes A's matches, profile and auth user and leaves B's match with free-text Aaron",
  ignore: !url || !anonKey || !serviceKey,
  sanitizeOps: false,
  sanitizeResources: false,
  fn: async () => {
    const admin = createClient(url!, serviceKey!, options);
    const stamp = crypto.randomUUID().slice(0, 8);
    const a = await signedInUser(admin, `delete_a_${stamp}@chair.test`);
    const b = await signedInUser(admin, `delete_b_${stamp}@chair.test`);

    const ownMatches = [crypto.randomUUID(), crypto.randomUUID()];
    await must(a.client.from("matches").insert(ownMatches.map((id) => ({ id, format: "singles" }))));
    await must(a.client.from("point_events").insert({ match_id: ownMatches[0], index: 0, at: new Date().toISOString(), source: "manual" }));

    const shared = crypto.randomUUID();
    await must(b.client.from("matches").insert({ id: shared, format: "singles" }));
    await must(b.client.from("match_players").insert([
      { match_id: shared, slot: "A1", name: "Juan", user_id: null, link_status: "none" },
      { match_id: shared, slot: "B1", name: "Aaron", user_id: a.id, link_status: "pending" },
    ]));
    await must(a.client.rpc("respond_to_invite", { p_match_id: shared, accept: true }));

    const res = await handleDeleteAccount(
      new Request("http://localhost/delete-account", { method: "POST", headers: { Authorization: `Bearer ${a.token}` } }),
      supabaseDeps(admin),
    );
    assertEquals(res.status, 204);

    const leftover = await must(admin.from("matches").select("id").in("id", ownMatches));
    assertEquals(leftover, []);
    const profile = await must(admin.from("profiles").select("id").eq("id", a.id));
    assertEquals(profile, []);
    const authUser = await admin.auth.admin.getUserById(a.id);
    assert(authUser.error !== null || authUser.data.user === null, "A's auth user is gone");

    const players = await must(b.client.from("match_players").select("slot, name, user_id, link_status").eq("match_id", shared).eq("slot", "B1"));
    assertEquals(players, [{ slot: "B1", name: "Aaron", user_id: null, link_status: "none" }]);

    await must(admin.from("matches").delete().eq("id", shared));
    await admin.auth.admin.deleteUser(b.id);
  },
});
