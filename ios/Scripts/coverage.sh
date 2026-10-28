#!/usr/bin/env bash
#
# Runs ChairKit's tests with coverage, prints per-file line coverage and
# fails if any file under Sources/ChairKit/Engine is below 100 %.

set -euo pipefail

root=$(git rev-parse --show-toplevel)
kit="$root/ios/Packages/ChairKit"
cd "$kit"

swift test --enable-code-coverage --quiet >/dev/null
bin_dir=$(swift build --show-bin-path)
profdata="$bin_dir/codecov/default.profdata"
binary="$bin_dir/ChairKitPackageTests.xctest/Contents/MacOS/ChairKitPackageTests"

report=$(xcrun llvm-cov report "$binary" -instr-profile "$profdata" \
  -ignore-filename-regex='(\.build|Tests|ChairTestSupport)/')
echo "$report"

echo "$report" | awk '
  $1 ~ /(^|\/)Engine\// {
    cover = $10
    sub(/%/, "", cover)
    if (cover + 0 < 100) { print "below 100 %: " $1 " (" $10 ")"; failed = 1 }
  }
  END { exit failed }
'
