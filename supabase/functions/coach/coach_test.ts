import { assertEquals } from "jsr:@std/assert@1.0.8";

import { type CoachDeps, handleCoach, placeholderCard } from "./coach.ts";

const signedIn: CoachDeps = {
  apiKey: "test-key",
  userIdFor: (token) => Promise.resolve(token === "good" ? "user-1" : null),
};

function post(headers: HeadersInit = {}): Request {
  return new Request("http://localhost/coach", { method: "POST", headers });
}

Deno.test("a valid token gets the placeholder card", async () => {
  const res = await handleCoach(post({ Authorization: "Bearer good" }), signedIn);
  assertEquals(res.status, 200);
  assertEquals(await res.json(), placeholderCard);
});

Deno.test("no token is a 401", async () => {
  const res = await handleCoach(post(), signedIn);
  assertEquals(res.status, 401);
});

Deno.test("a token that isn't a signed-in user is a 401", async () => {
  const res = await handleCoach(post({ Authorization: "Bearer anon" }), signedIn);
  assertEquals(res.status, 401);
});

Deno.test("a missing API key is a 503, never a card", async () => {
  const res = await handleCoach(post({ Authorization: "Bearer good" }), { ...signedIn, apiKey: undefined });
  assertEquals(res.status, 503);
});

Deno.test("GET is refused", async () => {
  const res = await handleCoach(new Request("http://localhost/coach"), signedIn);
  assertEquals(res.status, 405);
});
