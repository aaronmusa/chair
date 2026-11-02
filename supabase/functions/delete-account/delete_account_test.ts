import { assertEquals } from "jsr:@std/assert@1.0.8";

import { type DeleteAccountDeps, handleDeleteAccount } from "./delete_account.ts";

function recording(calls: string[], failing?: string): DeleteAccountDeps {
  return {
    userIdFor: (token) => Promise.resolve(token === "good" ? "user-1" : null),
    deleteData: (userId) => {
      calls.push(`data:${userId}`);
      return failing === "data" ? Promise.reject(new Error("db")) : Promise.resolve();
    },
    deleteUser: (userId) => {
      calls.push(`user:${userId}`);
      return Promise.resolve();
    },
  };
}

function post(headers: HeadersInit = {}): Request {
  return new Request("http://localhost/delete-account", { method: "POST", headers });
}

Deno.test("a signed-in user's data goes first, then the auth user, and the answer is 204", async () => {
  const calls: string[] = [];
  const res = await handleDeleteAccount(post({ Authorization: "Bearer good" }), recording(calls));
  assertEquals(res.status, 204);
  assertEquals(calls, ["data:user-1", "user:user-1"]);
});

Deno.test("no token is a 401 and deletes nothing", async () => {
  const calls: string[] = [];
  const res = await handleDeleteAccount(post(), recording(calls));
  assertEquals(res.status, 401);
  assertEquals(calls, []);
});

Deno.test("a token that isn't a signed-in user is a 401", async () => {
  const calls: string[] = [];
  const res = await handleDeleteAccount(post({ Authorization: "Bearer anon" }), recording(calls));
  assertEquals(res.status, 401);
  assertEquals(calls, []);
});

Deno.test("a failed data delete keeps the auth user and answers 500", async () => {
  const calls: string[] = [];
  const res = await handleDeleteAccount(post({ Authorization: "Bearer good" }), recording(calls, "data"));
  assertEquals(res.status, 500);
  assertEquals(calls, ["data:user-1"]);
});

Deno.test("GET is a 405", async () => {
  const res = await handleDeleteAccount(new Request("http://localhost/delete-account"), recording([]));
  assertEquals(res.status, 405);
});
