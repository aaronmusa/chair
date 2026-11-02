# Epic 2a QA: accounts, linking and two-device sync

Human checks for Epic 2a (#94) that need real devices against the Chair Supabase project (`stftzhxjsbpaoxbgjbkg`). Automated coverage for the same flows runs against the local stack in `ChairKit` (`SupabaseMatchRemoteTests`, `SupabaseLinkingTests`, `SupabaseAuthServiceTests`, `SupabaseProfileRemoteTests`).

## Record

| Check | Date | Build | Device 1 | Device 2 | Result |
|---|---|---|---|---|---|
| 1. Same account, two devices |  |  |  |  |  |
| 2. Two accounts, link and accept |  |  |  |  |  |
| 3. Sign in with Apple on a device (#89) |  |  |  | n/a |  |
| 4. Scan a player's QR code (#92) |  |  |  |  |  |
| 5. Airplane-mode sync within 60 s (#72) |  |  |  | n/a |  |

## 1. Same account, two devices

1. Install the same build on both devices and sign in with the same Apple ID on each (Settings → Account → Sign in with Apple).
2. On device 1, start a singles match from Play → New match, score a few points, and finish it (or end it early).
3. On device 2, bring Chair to the foreground and start a timer.

Pass: the match appears in device 2's Matches tab with the same score and point list within 60 s of foregrounding.

## 2. Two accounts, link and accept

1. Device A and device B are signed in with different Apple IDs. On B, note the handle in Settings → Account → Profile.
2. On A, start a new match. On the opponent's row tap Link, search B's handle, and pick it. The row shows Pending. Score and finish the match.
3. On B, foreground Chair. The Matches tab shows a badge and Play shows "1 match invite". Open it and tap Accept.
4. On A, foreground Chair and open the match summary.

Pass:
- B's Matches tab lists the match as "vs <A's name>" with W/L from B's side, and the summary shows B's column first with a lock and "Scored by @<A's handle>". There's no Delete or Fix score.
- A's summary shows the opponent's chip as Linked.
- Repeat with Decline: B never sees the match in Matches and A's chip reads Declined.

## 3. Sign in with Apple on a device

1. Fresh install, signed out. Settings → Account → Sign in with Apple.

Pass: the sheet closes, the Account row shows `@player_…` (or your handle), and Profile opens with your Apple name if Apple shared it.

## 4. Scan a player's QR code

1. Device B opens Settings → Account → Profile; the QR code is under "Your code".
2. Device A opens New match → Link on the opponent row → "Scan a player's QR code" and points the camera at B's code.

Pass: the picker closes with B linked and the row shows Pending.

## 5. Airplane-mode sync

1. Signed in, turn on airplane mode, score a full match, check Settings → Sync shows waiting uploads.
2. Turn airplane mode off and start a timer.

Pass: Settings → Sync reads 0 waiting within 60 s and the match shows on a second device signed into the same account.
