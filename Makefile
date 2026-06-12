.PHONY: build run run-unsigned test app clean bump-version

# Single source of truth for app identity (APP_EXECUTABLE, APP_BUNDLE_NAME, …).
include packaging/app.env

build:
	swift build

# Build and launch the signed .app bundle. This is the only way Touch ID and the
# Keychain work: storing the DEK behind a `.userPresence` access control uses the
# data-protection keychain, which requires a signed binary with the
# keychain-access-groups entitlement (see packaging/App.entitlements). A bare
# `swift run` binary is unsigned and fails with errSecMissingEntitlement (-34018).
run: app
	open "dist/$(APP_BUNDLE_NAME).app"

# Bare `swift run` — fast, but the Keychain/Touch ID paths will NOT work (unsigned).
# Useful only for UI/flows that don't unlock a vault.
run-unsigned: build
	swift run $(APP_EXECUTABLE)

test:
	@if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then \
		DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test; \
	else \
		swift test; \
	fi

app:
	./packaging/build-app.sh

clean:
	rm -rf .build dist

bump-version:
	chmod +x packaging/bump-version.sh
	./packaging/bump-version.sh $(or $(BUMP),patch)
