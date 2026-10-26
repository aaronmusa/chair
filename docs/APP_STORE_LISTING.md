# App Store listing — Chair

Fill this in, then check every field fits before pasting anything into App Store
Connect:

```
make check-listing
```

The limits in the headings are what the checker reads. Leave them alone.

Write the description unwrapped, one line per paragraph. Hard wraps paste into
App Store Connect as literal line breaks and split sentences in half.

## Name (30)

```
Chair
```

Check the name is free in App Store Connect before anything else; "Chair" alone
may be taken (roadmap open question). Fallback: "Chair: Tennis Umpire".

## Subtitle (30)

```
AI umpire for tennis matches
```

Say the one thing that separates this app from the others in its category. This
is the field that answers Guideline 4.3 in six words.

## Promotional text (170)

```
Set your phone on the net post and play. Chair calls the points, announces the score through a speaker, and keeps the stats for both of you.
```

Editable without shipping a build, unlike everything else here.

## Description (4000)

```
Chair is an umpire for recreational tennis. Put your iPhone or iPad on the net post, tap the four corners of the court, and play: Chair follows the rally, proposes each point, and announces the score in proper umpire phrasing through your phone or a Bluetooth speaker.
Every call is yours to correct. A proposed point is accepted after five seconds unless someone objects by voice, a raised hand or a tap on the Apple Watch, and you can step back through the score at any time. An optional referee on a second iPhone or iPad has the final say.
No camera? Score a match by tap on your iPhone, or on your Apple Watch with the phone in your bag. The umpire voice still calls the score.
After the match, see the stats and a point-by-point log, and share the result with your opponent so it appears in both of your histories.
Chair Pro adds unlimited matches, a coach that reads your match and suggests what to work on, serve training, and clip export. Free accounts include 20 matches.
```

The first two lines are all most people read before deciding whether to tap
"more". Spend them on the differentiator, not on "welcome to Chair".

## Keywords (100, comma separated, no spaces after commas)

```
tennis,umpire,score,scorekeeper,referee,line call,match,stats,coach,doubles,singles,serve
```

The app name is already indexed, so repeating it is wasted. Apple matches
singular and plural, so pick one.

## In-app purchases

An in-app purchase description is capped at 55 characters, not the ~170 the
app-level fields allow.

### Pro monthly display name (30)

```
Chair Pro Monthly
```

### Pro monthly description (55)

```
Unlimited matches, AI coach, training and clip export.
```

### Pro yearly display name (30)

```
Chair Pro Yearly
```

### Pro yearly description (55)

```
A year of unlimited matches, coaching and training.
```

## App Review information

Put this in **Notes**. If anything in the app sits behind a gate — a paywall, a
usage limit, an account — say exactly how a reviewer reaches it. A reviewer who
cannot reach an in-app purchase files a 2.1, and that is the most common
in-app-purchase rejection there is.

```
Chair scores a tennis match. Camera mode needs a court; manual mode does not:
on the Play tab choose "No camera" and tap a side to give it the point.

The free tier allows 20 matches. The review account below has already played
20, so starting a new match opens the Chair Pro paywall straight away. Both
subscriptions start with a 7-day free trial and can be bought in the sandbox.

Review account (Sign in with Apple is also supported): to be added before
submission (Epic 8).
```

## Other fields

- **Category**: Sports, secondary Health & Fitness
- **Age rating**: answer the questionnaire honestly; most utilities land at 4+
- **Privacy Policy URL**: https://aaronmusa.github.io/chair-legal/privacy/
- **Support URL**: https://aaronmusa.github.io/chair-legal/support/
- **EULA**: Apple's standard one, plus the subscription terms Guideline 3.1.2 asks for in the description or a link
- **Copyright**: `2026 Aaron Musa` — no © symbol, App Store Connect adds it

## Screenshots

Three sets: 6.9" iPhone (1320 x 2868), 13" iPad (2064 x 2752) and Apple Watch
(Ultra, 422 x 514). App Store Connect scales each down for the smaller sizes in
its family.

Only the first three appear in search results, so spend them on what the app
does that others do not: the camera calling a point, the umpire's score, the
watch.

Rules worth holding to:

- The screen itself must be the real app. Captions, backgrounds and device
  frames around it are fine; a mocked-up screen is not.
- Never screenshot the paywall. It sells nothing, and the purchase has its own
  required review screenshot in App Store Connect.
- Use real-looking content: real names and a believable score, not "Player 1".
- Check no debug affordance is visible before compositing.
- Live-match screens are landscape. They still come out of the simulator in the
  portrait frame; rotate them with `sips -r 270` before compositing.

Captures go in `docs/store-shots/captures/<device>/`, one config per device in
`docs/store-shots/<device>.json`. `make shots` renders all three sets into
`.build/store-shots/`.
