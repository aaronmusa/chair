export type CoachCard = {
  headline: string;
  points: string[];
};

export const placeholderCard: CoachCard = {
  headline: "Coach is warming up",
  points: [
    "Match coaching arrives in a later update.",
    "Your points and stats are saved and will be used when it does.",
  ],
};

export type CoachDeps = {
  apiKey: string | undefined;
  userIdFor: (token: string) => Promise<string | null>;
};

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export async function handleCoach(req: Request, deps: CoachDeps): Promise<Response> {
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);

  const token = req.headers.get("Authorization")?.match(/^Bearer (.+)$/)?.[1];
  if (!token) return json({ error: "Sign in to use the coach" }, 401);

  const userId = await deps.userIdFor(token);
  if (!userId) return json({ error: "Sign in to use the coach" }, 401);

  if (!deps.apiKey) return json({ error: "Coach is not configured" }, 503);

  return json(placeholderCard, 200);
}
