# Epic 3 QA: umpire voice

Human checks for Epic 3 (#129) that need a real iPhone (iPhone 13 for the latency target), a Bluetooth speaker and, for check 3, a paired Apple Watch. The automated coverage uses fakes and the simulator:

- **ChairKit:** `AnnouncementFormatterTests` and the `singles_bo3.calls.txt` golden, `CueTests`, `UmpireSpeechTests`, `UmpireSettingsTests`.
- **ChairTests:** `SystemSynthesizerTests`, `UmpireAudioSessionTests`, `UmpireCoordinatorTests`, `UmpireSettingsScreenTests`, `UmpireSettingsSnapshotTests`.

None of them can hear the speaker, lock the screen, flip the silent switch or take a phone call.

Use a Debug build. The strip then ends with the last call's latency, from engine output to first sound ("Fifteen–love · 182 ms").

## Record

| Check | Date | Build | iPhone / iOS | Speaker | Result |
|---|---|---|---|---|---|
| 1. Full manual match, Bluetooth, screen locked |  |  |  |  |  |
| 2. First-call latency |  |  |  |  |  |
| 3. Watch-scored game, phone in a bag |  |  |  |  |  |
| 4. Speaker disconnect mid-match |  |  |  |  |  |
| 5. Phone call during a game |  |  |  |  |  |
| 6. Music in another app |  |  |  |  |  |
| 7. Silent switch, both settings |  |  |  |  |  |
| 8. Pill and route picker |  |  |  |  |  |
| 9. Settings: voice, verbosity, cues, volume, test call |  |  |  |  |  |

Keepalive flag (`keepsAudioAlive`) that ships: ☐ off (default) ☐ on. Fill in this line after check 3.

Mispronunciations (log each as a follow-up issue, not a blocker):

| Name | Heard as | Voice |
|---|---|---|
| Musa |  |  |
| Cruz |  |  |
| Nguyen |  |  |
| Siobhan |  |  |

## 1. Full manual match, Bluetooth speaker, screen locked

1. Pair a Bluetooth speaker and put it at court distance (about 10 m).
2. Start a singles match: Musa against Cruz, best of 3. A doubles match also works: Musa–Cruz against Nguyen–Siobhan.
3. Check that the pill reads "Umpire ON · <speaker name>".
4. Score the match from the phone, locking the screen between points for long stretches.
5. Include one undo, and later one Fix score.

Pass:
- Every point plays a cue then the call. The calls never overlap.
- Game, set and match play the chime cues and "Game and first set, Musa, six games to four"-style calls.
- "Change of ends" follows a set call, never comes before it.
- The undo and the score fix each say one "Correction, <score>", about 2 s after the last change.
- Calls keep playing with the screen locked. If any call fails to play, repeat check 3 with the keepalive flag on.

## 2. First-call latency

1. Kill and relaunch Chair, then start a new match.
2. Read the latency on the strip after the opening "Musa to serve, deuce side".
3. Then score 10 points, reading the latency after each.

Pass: the first call and every later one are under 300 ms on an iPhone 13. As perceived, anything under half a second is acceptable.

Simulator reference: 55–253 ms on an iPhone 17 Pro Max simulator.

## 3. Watch-scored game, phone in a bag

1. Start a match on the phone, join on the watch, lock the phone and put it in a bag with the speaker connected.
2. Score a full game from the watch.

Pass: every point is called from the speaker, word for word what the wrist overlay shows. If any call doesn't start while the phone is in the background:
1. Set `keepsAudioAlive` to true in `UmpirePreferences`. The default lives there; there's no Settings row for it yet.
2. Repeat the game.
3. Record which setting ships.

## 4. Speaker disconnect mid-match

1. During a game, switch the Bluetooth speaker off.
2. Score the next point.

Pass:
- The next call plays on the phone speaker.
- The strip reads "<score> · Speaker disconnected" for that call only.
- The pill changes to "Umpire ON · Speaker".

## 5. Phone call during a game

1. At 30–15, call the phone from another device.
2. Decline the call or hang up.

Pass: the umpire stops during the call and afterwards says "Thirty–fifteen, Musa to serve" once.

## 6. Music in another app

1. Play music in another app, then open Chair and score points.

Pass: the music ducks during each call and comes back to full volume after it.

## 7. Silent switch, both settings

1. With Respect silent mode off (the default), flip the silent switch to silent and score a point.
2. Turn Respect silent mode on in Settings, start a new match, flip to silent and score a point.
3. With Respect silent mode still on, lock the screen and score from the watch.

Pass:
- Step 1: the call plays.
- Step 2: no cue and no speech, and the strip still shows the call.
- Step 3: silent, as the footer says.

## 8. Pill and route picker

1. Tap the pill.
2. Score a point.
3. Tap the pill again.
4. Touch and hold the pill.
5. Turn VoiceOver on and swipe through the live screen.

Pass:
- Step 1: the pill reads "Umpire OFF".
- Step 2: no sound, and the strip updates.
- Step 3: the next point is called.
- Step 4: the system route sheet opens.
- Step 5: there's no separate "AirPlay" element, and the pill has a "Choose speaker" action.

## 9. Settings

1. Settings → Umpire. Pick each English voice and tap Preview.
2. Set Verbosity to Minimal and play a game.
3. Set Verbosity to Full and play a game.
4. Turn Sound cues off.
5. Move the volume slider from 50 % to 100 %.
6. Tap Test call.
7. Tap Output.

Pass:
- Step 1: Preview says "Fifteen–love" in that voice. Note any mispronunciations in the table above.
- Step 2: only scores and game/set/match are called, with no "Out", "Fault" or serve lines.
- Step 3: "<name> to serve, <side> side" is called before every point.
- Step 4: calls start with no cue.
- Step 5: the umpire gets louder while the system volume stays the same.
- Step 6: the set cue plays, then "Game, set and match".
- Step 7: the system route sheet opens.
