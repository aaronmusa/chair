.PHONY: build test test-kit test-all lint gallery

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
	swiftlint lint --quiet --strict ios

gallery:
	@echo "the gallery scheme lands with E0-8 (#9)" >&2; exit 1
