#!/usr/bin/env bash
#
# Runs the test suites and prints a one-line summary.
#
#   test.sh                       # ChairKit, ChairUI, app unit tests, and only the UI suites in $UI (none if unset)
#   UI=ChairUITests test.sh
#   test.sh --all                 # ChairKit, ChairUI, app unit tests and every UI suite (end of an epic)
#   test.sh --fast                # ChairKit only, no simulator

set -uo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"

fast=false
all=false
[ "${1:-}" = "--fast" ] && fast=true
[ "${1:-}" = "--all" ] && all=true
ui_suites="${UI:-}"

project="ios/Chair.xcodeproj"
kit="ios/Packages/ChairKit"
ui="ios/Packages/ChairUI"
logs="$root/.build/test-logs"
mkdir -p "$logs"
summary=()
status=0

run() {
  local name=$1; shift
  local log="$logs/$name.log"
  echo "▸ $name"
  if "$@" >"$log" 2>&1; then
    summary+=("$name ok")
  else
    summary+=("$name FAILED")
    status=1
    tail -n 30 "$log"
    echo "  full log: $log"
  fi
}

latest_iphone() {
  xcrun simctl list devices available -j | python3 -c '
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
'
}

run ChairKit swift test --parallel --package-path "$kit" -Xswiftc -warnings-as-errors

if ! $fast; then
  udid=$(latest_iphone)
  if [ -z "$udid" ]; then
    summary+=("simulator MISSING")
    status=1
  else
    destination="platform=iOS Simulator,id=$udid"
    uitest() { (cd "$ui" && xcodebuild test -quiet -scheme ChairUI -destination "$destination"); }
    run ChairUI uitest
    xcodetest() { xcodebuild test -quiet -project "$project" -scheme Chair -destination "$destination" "$@"; }
    if $all; then
      run ChairAllTests xcodetest
    else
      run ChairTests xcodetest -only-testing:ChairTests
      if [ -n "$ui_suites" ]; then
        only=()
        IFS=',' read -ra suites <<<"$ui_suites"
        for suite in "${suites[@]}"; do only+=("-only-testing:ChairUITests/$suite"); done
        run "ChairUITests($ui_suites)" xcodetest "${only[@]}"
      else
        summary+=("ChairUITests skipped (set UI= or use test-all)")
      fi
    fi
  fi
fi

IFS='|'; line="${summary[*]}"; unset IFS
echo "${line//|/ · }"
exit $status
