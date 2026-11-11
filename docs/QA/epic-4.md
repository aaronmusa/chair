# Epic 4 QA: camera capture and court calibration

Human checks for Epic 4 (#148), plus the device checks left on #140, #142, #144, #146 and #147. You'll need a real court, an iPhone 13 (the target device), a phone mount that reaches 1.5–2 m (a fence clamp, tripod or net-post clamp), a 30 m tape measure, a tennis ball and a few markers (chalk or cones).

The automated coverage uses synthetic courts and a fake camera:

- **ChairKit:** `HomographyTests`, `CourtModelTests`, `CourtLineDetectorTests` (random cameras, clutter, low mounts, sky), `CaptureTests`, `SavedCourtRepositoryTests`, plus `FootageTests` once the clips from #139 exist.
- **ChairTests:** `PlacementTests`, `CalibrationTests`, `CameraPanelTests`, `SavedCourtsTests`.

None of them can film a real court, heat a phone in the sun or take a phone call.

Use a Debug build, which turns on two readouts:

- **Calibration screen:** tap the ruler button in the bottom bar, then tap anywhere on the preview to show that point's court position in metres ("x 2.06 m · y 3.20 m"). x runs along the net, 0 at the centre. y runs along the court, 0 at the net and positive towards the far end. Tap the ruler again to go back to placing points.
- **Live screen camera panel:** the chip adds the thermal state and battery level ("60 fps · Calibrated · nominal · 82 %").

## Record

| Check | Date | Build | iPhone / iOS | Court, surface | Light | Mount height | Result |
|---|---|---|---|---|---|---|---|
| 1. Net post, court A, bright |  |  |  |  |  |  |  |
| 2. Net post, court A, dusk |  |  |  |  |  |  |  |
| 3. Net post, court B |  |  |  |  |  |  |  |
| 4. Baseline placement |  |  |  |  |  |  |  |
| 5. Umpire chair |  |  |  |  |  |  |  |
| 6. 90-minute capture |  |  |  |  |  |  |  |
| 7. Saved court, same spot and 1 m back |  |  |  |  |  |  |  |
| 8. Interruptions and recalibrate |  |  |  |  |  |  |  |

Lens and frame rate the capture chose (from the calibration pills): ☐ 0.5× · 60 fps ☐ 1× · 60 fps (fallback) ☐ 30 fps.

## Marking the spots

On each court, mark these 7 spots with chalk and measure each from the centre of the net (x along the net, y along the court):

| Spot | Where | Court position (m) |
|---|---|---|
| 1 | Far doubles sideline, halfway to the far baseline | (5.49, 6.00) |
| 2 | Far baseline, centre mark | (0.00, 11.89) |
| 3 | Far service line, centre T | (0.00, 6.40) |
| 4 | Centre of the far service box | (2.06, 3.20) |
| 5 | Far half, mid-court | (2.75, 9.00) |
| 6 | Far half, near the far doubles corner | (4.50, 11.00) |
| 7 | Near sideline, 2 m from the net | (−5.49, 2.00) |

The far side is the sideline opposite the phone. Spot 7 checks the near-side limit: from the net post it should be at the edge of the frame or outside it.

## 1–5. Placement and mapping

For each row in the record:

1. Mount the phone, 0.5× lens, landscape. Note the measured lens height.
2. Start a camera match, pick the placement, then Open camera.
3. Wait for the suggested points (they should appear within 2 s). Note whether they appeared and whether any needed dragging.
4. Check the pills: lens and fps, light, baseline depth, fit.
5. Turn on the ruler. Put the ball on each spot and tap its centre on the preview. Write down the readout next to the tape value.

| Spot | Tape (m) | App (m) | Error (cm) |
|---|---|---|---|
| 1 |  |  |  |
| 2 |  |  |  |
| 3 |  |  |  |
| 4 |  |  |  |
| 5 |  |  |  |
| 6 |  |  |  |
| 7 |  |  |  |

Pass:
- Net post and chair: under 15 cm at the far sideline (spots 1 and 6) and under 30 cm at the far baseline (spot 2).
- Baseline placement: under 20 cm everywhere.
- Spot 7 from the net post is out of frame or flagged as near the edge.

For any spot over target, log a follow-up issue with a photo of the setup, the mount height, and the likely cause: lens, keypoint placement or distortion.

## 6. 90-minute capture on an iPhone 13

1. Calibrate at the net post, then play or simply leave the live screen showing for 90 minutes. Do this in daylight; shade is fine.
2. Every 30 minutes, write down the chip's thermal state and battery level, and check that the scoring buttons still respond straight away.

| Minute | Thermal | Battery | fps on chip | UI responsive |
|---|---|---|---|---|
| 0 |  |  |  |  |
| 30 |  |  |  |  |
| 60 |  |  |  |  |
| 90 |  |  |  |  |

Pass: thermal never goes above `.serious`, the chip stays at 60 fps (30 is allowed only while the state is `.serious`), and the UI stays responsive throughout.

## 7. Saved court

1. After calibrating in check 1, save the court as "QA court" when asked. With Settings › Camera › Use location to find courts on, allow location when asked.
2. Start a new camera match at the same spot. The points should be placed without tapping, Next should be enabled, and there should be no notice.
3. Move the phone 1 m further back and start another match. "Phone position differs from last time" should show, and the points should still be draggable.
4. Turn location off. Start again: no location prompt, and "Saved courts" in the calibration bar still lists "QA court".
5. Sign in on a second device. "QA court" should appear under Settings › Camera › Saved courts, without a thumbnail.

## 8. Interruptions and recalibrate

1. During a camera match, call the phone from another device. The panel should show the camera paused, and the preview should come back after the call.
2. Open the Camera app over Chair, then return. "Another app is using the camera" should show, then clear.
3. Tap Recalibrate. The calibration screen opens with the current points. Move one and tap Next. The live panel's lines should move to match.
4. On the calibration screen, background the app and come back: the points and preview should be restored.

## Before release

- [ ] Apply the production migrations from #145 and #144 (`supabase db push`).
- [ ] Update the chair-legal privacy page for location (used to match saved courts, stored with the account, removed with the court or the account).
- [ ] Update the App Store privacy label: Precise Location, linked to the user, App Functionality.
