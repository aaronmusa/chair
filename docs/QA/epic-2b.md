# Epic 2b QA: watch manual scorer

Human checks for Epic 2b (#113) that need a real iPhone and a paired Apple Watch (Series 7 or later). The automated coverage uses `FakeWCSession`: `WatchLinkTests`, `WatchScoringTests`, `WatchKeepAliveTests`, `WatchSetStartTests` (ChairKit), `WatchBridgeTests` (ChairTests) and the `ChairWatchTests` snapshots. An XCTest target drives one app, so nothing automated runs the phone and watch together.

Use a Debug build for the paired run: the watch score screen then shows the last ack time ("ack 84 ms") next to the set label.

## Record

| Check | Date | Build | iPhone / iOS | Watch / watchOS | Result |
|---|---|---|---|---|---|
| 1. Paired run: acks, Join, phone → watch |  |  |  |  |  |
| 2. 90-minute match, phone in a bag |  |  |  |  |  |
| 3. Out of range for 2 min |  |  |  |  |  |
| 4. Accidental touch (10 forearm brushes) |  |  |  |  |  |
| 5. Always On |  |  |  |  |  |
| 6. Workout keep-alive and Fitness (#108) |  |  |  |  |  |
| 7. New match from the watch (#109) |  |  |  |  |  |

Battery for check 2:

| | Watch | iPhone |
|---|---|---|
| Start % |  |  |
| End % |  |  |
| Drain over 90 min |  |  |

Budget: at most 25 % watch drain over 90 min. If it's over, the fix is to send `.state` only at game boundaries while the watch is dimmed (`isLuminanceReduced`); file it against E2b-7 with the numbers.

## 1. Paired run

1. On the phone, start a singles best-of-3 match (Play → New match) and leave it on get-set.
2. Open Chair on the watch. Time from opening to the Join match card showing the score.
3. Tap Join. Score 10 points from the watch with Me/Them (hold until the ring fills), reading the ack time after each.
4. Score 5 points on the phone. Time from each phone tap to the watch score changing.

Pass:
- Join shows the current score within 2 s.
- Every ack while reachable reads under 500 ms.
- A phone-scored point reaches the watch within 1 s, and a double fault scored on the phone shows the "Double fault" bar.

## 2. 90-minute match, phone in a bag

1. Note both battery levels. Start a best-of-3 singles match on the phone, join on the watch, lock the phone and put it in a bag.
2. Play (or simulate) the whole match scoring only from the watch: points, at least one fault and let, an undo (left swipe on the rows and from page 2), and one swap ends.
3. At the end, note the result card, tap Done, then note both battery levels.
4. Unlock the phone and open the match from Matches.

Pass: the phone's summary and point log match what was scored on the watch, in order, with no missing or extra points, and the watch drain is within budget.

## 3. Out of range for 2 minutes

1. Mid-match, leave the phone and walk away with the watch until the watch shows "waiting for phone" (the amber dot), keep scoring 3–4 points, and stay away 2 minutes.
2. Walk back.

Pass: within 10 s of coming back both devices show the same score, and the phone's log has every point once.

## 4. Accidental touch

1. On the score screen with Hold to score on, brush the forearm and wrist across the screen 10 times, as when wiping sweat.

Pass: no point is scored (the phone's score doesn't change and no click haptic plays).

## 5. Always On

1. Mid-match, lower the wrist so the screen dims.

Pass: the dimmed screen shows the two score rows and the server dot only, and touching it does nothing. Raising the wrist shows the full screen within 1 s.

## 6. Workout keep-alive and Fitness

1. Join a match on the watch and allow Health. Lower the wrist for 10 minutes, then raise it.
2. Finish the match on the phone.
3. Repeat step 1 with Health access denied on the watch (Settings → Health → Data Access → Chair).

Pass:
- After 10 minutes Chair is still in front and shows the score within 1 s.
- The workout ends within 5 s of the phone finishing the match and Fitness lists a Tennis workout with its duration.
- With Health denied, scoring still works, the screen stays up, and the score screen shows "Health is off · screen may sleep".

## 7. New match from the watch

1. With no match running and Chair closed on the phone, tap New match on the watch.
2. Open Chair on the phone.

Pass: New match is presented.
