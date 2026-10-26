# Release pre-flight — Chair

Run before every upload. Record what you verified at the bottom; the value of
this document is the row you add, not the list.

1. **Release build carries no debug code.** Build Release, then grep the binary
   for strings that only exist behind your debug flag:

   ```
   xcodebuild -project ios/Chair.xcodeproj -scheme Chair -configuration Release \
     -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
   strings -a <Release-iphonesimulator>/Chair.app/Chair | grep -c 'GalleryView\|ColorTokenGrid\|UseFakes'
   ```

   It must report 0. **Run the control before believing that zero**, because two
   things make a false pass easy:

   - A Debug build is a small launcher stub with the code in a separate
     `Chair.debug.dylib`. Grepping `Chair.app/Chair` in Debug finds nothing
     either, so a broken grep looks exactly like a clean binary. The same grep
     against the dylib must **find** the strings.
   - Build tooling has been known to silently drop a `configuration` argument
     and build Debug while reporting success. Confirm a `Release-iphonesimulator`
     directory actually appeared.

   The Release bundle, and the watch app inside it, must also contain no
   `.debug.dylib` and no `__preview.dylib`.

2. **Display name** reads "Chair" on the home screen and on the watch.

3. **Launch screen** matches the app's own first frame, in light and dark, on
   iPhone and iPad. iOS caches launch snapshots per app, so a device that has
   run an older build will lie about this — test on one that has not.

4. **App icons** are 1024x1024 with no alpha channel, for the phone and the watch:
   `sips -g pixelWidth -g pixelHeight -g hasAlpha AppIcon.png`

5. **Privacy manifest** (`PrivacyInfo.xcprivacy`) declares tracking, collected
   data types, and a reason for every required-reason API actually used. Check
   for file timestamps, system boot time, disk space, active keyboards and
   UserDefaults before assuming the list is complete.

6. **App Privacy answers** in App Store Connect match what the app really does.
   Profiles, matches and linked opponents live on a server we run, so they are
   collected. Camera frames and audio are processed on device and are not.
   Match stats sent to the coach are collected and leave for a third party.

7. **Build number is higher than the last upload**, in the phone and the watch
   target alike. App Store Connect rejects anything that is not, and the counter
   drifts the moment a build is distributed from a machine without the bump
   coming back into git. Check what is already uploaded rather than trusting the
   project file. `make bump` does the bump, through a PR; `make testflight`
   moves the tag on `main`.

8. **Export compliance** is declared in both Info.plists as
   `ITSAppUsesNonExemptEncryption = NO`, so uploads stop asking. That is only
   true while the app's sole use of encryption is HTTPS through Apple's own
   frameworks. Adding custom cryptography, or a third-party SDK that ships its
   own, makes the declaration false. It is a legal declaration, not a build
   setting.

9. **Anything written to a server is a privacy policy edit as well as a code
   change.** A shipped policy that no longer describes the app is a 5.1.1
   problem, and the drift is invisible from inside the codebase.

10. **The CI archive uploads as "TestFlight and App Store".** In Xcode Cloud
    this is the Archive action's *Deployment Preparation* setting. A build
    uploaded as *TestFlight Internal Testing Only* installs and tests normally
    but can never be attached to an App Store version: the Add Build dialog
    lists it greyed out with no stated reason, and the flag is baked into the
    upload, so the only fix is a fresh build number under the corrected
    setting. Verify it before the first submission of a new app, and again
    after anyone edits the workflow.

11. **Production Supabase is ahead of the build.** Every migration the build
    needs is pushed to `chair-prod` first (`supabase db push`), the `coach`
    function is deployed, and `supabase migration list` shows local and remote
    in step. The deploy rule: the migration lands before the app build that
    needs it, never the other way round.

12. **No server secret ships in the app.** The app carries only the project URL
    and the anon key, from `Secrets.xcconfig`. The Anthropic key lives only in
    the Edge Function's secrets. Grep the Release binary:
    `strings -a <app>/Chair | grep -cE 'sk-ant-|service_role|sb_secret_[A-Za-z0-9]'`
    must report 0.

13. **Sign in with Apple works against production.** The App ID has the
    capability, and `chair-prod`'s Apple provider has the Services ID and key.
    Test a fresh sign-in on a device with the TestFlight build.

14. **Subscriptions are reachable and restorable.** In the TestFlight build on a
    sandbox account: the 21st match opens the paywall, both products show the
    7-day trial, and Restore Purchases brings a bought subscription back.

15. **The watch app installs and scores.** Install the TestFlight build on a
    paired watch, score a game with the phone in a bag, and check the phone
    shows the same score.

16. **Account deletion is reachable in the app** (Guideline 5.1.1(v)) before any
    public release.

17. **The privacy policy still describes the app.** Compare
    [chair-legal](https://aaronmusa.github.io/chair-legal/privacy/) and the
    App Store Connect App Privacy answers with what the build stores and sends,
    and with `PrivacyInfo.xcprivacy`. A new SDK, a new table holding personal
    data, or a new person who can see it means all three change together.

## Record

| Date | Build | Steps verified | Notes |
|---|---|---|---|
| | | | |
