.PHONY: build test test-kit test-all lint gallery db-reset test-db functions-serve test-functions db-types

project := ios/Chair.xcodeproj

build:
	xcodebuild build -quiet -project $(project) -scheme Chair -destination 'generic/platform=iOS Simulator'
	xcodebuild build -quiet -project $(project) -scheme ChairWatch -destination 'generic/platform=watchOS Simulator'

test:
	ios/Scripts/test.sh

test-kit:
	ios/Scripts/test.sh --fast

test-all:
	ios/Scripts/test.sh --all

lint:
	swiftlint lint --quiet --strict
	swiftformat --lint ios

gallery:
	@echo "the gallery scheme lands with E0-8 (#9)" >&2; exit 1

db-reset:
	supabase start
	supabase db reset --local

test-db:
	supabase test db

functions-serve:
	supabase functions serve --env-file supabase/functions/.env

test-functions:
	deno test --allow-env supabase/functions

db-types:
	supabase gen types --local --lang swift --swift-access-control public > ios/Packages/ChairKit/Sources/ChairKit/Persistence/Generated/Database.swift
