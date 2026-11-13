#!/usr/bin/env bash
#
# Renders ChairUI's AppIconArt to the 1024 px iPhone (light, dark, tinted) and
# Watch app icons, opaque, via a test on the newest iPhone simulator.

set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"

udid=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
def version(runtime):
    return tuple(int(p) for p in runtime.rsplit("iOS-", 1)[1].split("-"))
ios = sorted((r for r in devices if "SimRuntime.iOS-" in r), key=version, reverse=True)
for runtime in ios:
    phones = [d for d in devices[runtime] if d["name"].startswith("iPhone") and "(" not in d["name"]]
    if phones:
        print(phones[0]["udid"])
        break
')

TEST_RUNNER_CHAIR_ICON_OUT="$root/ios" xcodebuild test -quiet \
  -project ios/Chair.xcodeproj -scheme Chair \
  -destination "platform=iOS Simulator,id=$udid" \
  -only-testing:ChairTests/AppIconRenderTests

for icon in ios/Chair/Resources/Assets.xcassets/AppIcon.appiconset/*.png ios/ChairWatch/Assets.xcassets/AppIcon.appiconset/AppIcon.png; do
  echo "$icon $(sips -g pixelWidth -g pixelHeight -g hasAlpha "$icon" | awk '/:/{printf "%s ", $2}')"
done
