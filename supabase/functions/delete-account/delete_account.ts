export type DeleteAccountDeps = {
  userIdFor: (token: string) => Promise<string | null>;
  deleteData: (userId: string) => Promise<void>;
  deleteUser: (userId: string) => Promise<void>;
};

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export async function handleDeleteAccount(req: Request, deps: DeleteAccountDeps): Promise<Response> {
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);

  const token = req.headers.get("Authorization")?.match(/^Bearer (.+)$/)?.[1];
  if (!token) return json({ error: "Sign in to delete your account" }, 401);

  const userId = await deps.userIdFor(token);
  if (!userId) return json({ error: "Sign in to delete your account" }, 401);

  try {
    await deps.deleteData(userId);
    await deps.deleteUser(userId);
  } catch {
    return json({ error: "Couldn't delete the account" }, 500);
  }
  return new Response(null, { status: 204 });
}
