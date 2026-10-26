#!/usr/bin/env bash
#
# Builds the Chair Gallery scheme and opens the design gallery on the newest iPhone simulator.

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
[ -n "$udid" ] || { echo "no iPhone simulator found" >&2; exit 1; }

derived="$root/.build/gallery"
xcodebuild build -quiet -project ios/Chair.xcodeproj -scheme "Chair Gallery" \
  -destination "platform=iOS Simulator,id=$udid" -derivedDataPath "$derived"

xcrun simctl bootstatus "$udid" -b >/dev/null
open -a Simulator --args -CurrentDeviceUDID "$udid"
xcrun simctl install "$udid" "$derived/Build/Products/Debug-iphonesimulator/Chair.app"
xcrun simctl launch --terminate-running-process "$udid" com.aaronmusa.chair -ShowGallery
echo "gallery running on $udid"
