import { type SupabaseClient } from "npm:@supabase/supabase-js@2.45.4";

import { type DeleteAccountDeps } from "./delete_account.ts";

export function supabaseDeps(admin: SupabaseClient): DeleteAccountDeps {
  return {
    userIdFor: async (token) => {
      const { data, error } = await admin.auth.getUser(token);
      if (error || !data.user) return null;
      return data.user.id;
    },
    deleteData: async (userId) => {
      const { error } = await admin.rpc("delete_account_data", { uid: userId });
      if (error) throw error;
    },
    deleteUser: async (userId) => {
      const { error } = await admin.auth.admin.deleteUser(userId);
      if (error) throw error;
    },
  };
}
