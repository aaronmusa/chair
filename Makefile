.PHONY: build test test-kit test-all test-footage footage coverage lint gallery db-reset test-db functions-serve test-functions db-types hooks bump testflight check-listing shots

project := ios/Chair.xcodeproj
FOOTAGE_SOURCE ?= $(HOME)/Library/Mobile Documents/com~apple~CloudDocs/Chair Footage
FOOTAGE_DIR ?= $(HOME)/chair-footage

build:
	@installed=$$(xcodebuild -version | awk 'NR == 1 { print $$2 }'); expected=$$(cat .xcode-version); \
	[ "$$installed" = "$$expected" ] || echo "warning: building with Xcode $$installed, but .xcode-version says $$expected" >&2
	xcodebuild build -quiet -project $(project) -scheme Chair -destination 'generic/platform=iOS Simulator'
	xcodebuild build -quiet -project $(project) -scheme ChairWatch -destination 'generic/platform=watchOS Simulator'

test:
	ios/Scripts/test.sh

test-kit:
	ios/Scripts/test.sh --fast

test-all:
	ios/Scripts/test.sh --all

footage:
	@test -d "$(FOOTAGE_SOURCE)" || { echo "no footage folder at $(FOOTAGE_SOURCE); set FOOTAGE_SOURCE" >&2; exit 1; }
	mkdir -p "$(FOOTAGE_DIR)"
	rsync -av "$(FOOTAGE_SOURCE)/" "$(FOOTAGE_DIR)/"

test-footage:
	FOOTAGE_DIR="$(FOOTAGE_DIR)" CHAIR_FOOTAGE_REQUIRED=1 swift test --package-path ios/Packages/ChairKit --filter FootageTests

coverage:
	ios/Scripts/coverage.sh

lint:
	swiftlint lint --quiet --strict
	swiftformat --lint ios

gallery:
	ios/Scripts/gallery.sh

db-reset:
	supabase start
	supabase db reset --local

test-db:
	supabase test db

functions-serve:
	supabase functions serve --env-file supabase/functions/.env

test-functions:
	deno test --allow-env --allow-net supabase/functions

db-types:
	supabase gen types --local --lang swift --swift-access-control public > ios/Packages/ChairKit/Sources/ChairKit/Persistence/Generated/Database.swift

hooks:
	hooks/install-hooks.sh

bump:
	ios/Scripts/bump-build.sh $(if $(TAG),--tag $(TAG))

testflight:
	@test "$$(git rev-parse --abbrev-ref HEAD)" = main || { echo "switch to main first" >&2; exit 1; }
	git pull --ff-only
	@test -z "$$(git status --porcelain)" || { echo "main has uncommitted changes" >&2; exit 1; }
	ios/Scripts/bump-build.sh --tag-only xcbuild/testflight

check-listing:
	xcrun swift ios/Scripts/check-listing.swift docs/APP_STORE_LISTING.md

shots:
	for device in iphone ipad watch; do \
		xcrun swift ios/Scripts/make-store-shots.swift docs/store-shots/$$device.json docs/store-shots/captures/$$device .build/store-shots/$$device || exit 1; \
	done
