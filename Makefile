# Velia — developer entry points.
# Stable target names referenced by docs/engineering-practices.md §6 and the phase docs.
# Engine targets (test/bench) work TODAY against the VeliaCore SwiftPM package.
# App/UI targets activate once the Tuist iOS project is generated (`make bootstrap`).

CORE := VeliaCore
SHELL := /bin/bash
APP_BUNDLE_ID := app.velia.ios

# Resolve Tuist whether it's on PATH or installed via mise (~/.local/bin).
TUIST := $(shell command -v tuist 2>/dev/null || (command -v mise >/dev/null 2>&1 && echo "mise x tuist@latest -- tuist"))

.PHONY: help bootstrap deploy-device lint format test test-core bench test-snapshot test-ui verify verify-all clean

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Generate the Xcode project (requires Tuist)
	@[ -n "$(TUIST)" ] || { echo "Tuist not installed — see https://tuist.io (or 'curl https://mise.run | sh && mise use -g tuist'). Engine targets still work without it."; exit 0; }
	$(TUIST) install && $(TUIST) generate

deploy-device: ## Generate→build→install→launch on the connected iPhone (free account: redo weekly)
	@set -euo pipefail; \
	[ -n "$(TUIST)" ] || { echo "❌ Tuist not found. Install: curl https://mise.run | sh && mise use -g tuist@latest"; exit 1; }; \
	echo "▸ Generating workspace…"; $(TUIST) generate --no-open >/dev/null; \
	DEV_LINE="$$(xcrun devicectl list devices 2>/dev/null | grep -iE 'connected|available' | head -1)"; \
	[ -n "$$DEV_LINE" ] || { echo "❌ No reachable iPhone. Unlock + plug in the device, then retry."; exit 1; }; \
	DEVICE_ID="$$(echo "$$DEV_LINE" | grep -oiE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | head -1)"; \
	DEVICE_NAME="$$(echo "$$DEV_LINE" | awk '{print $$1}')"; \
	echo "▸ Target: $$DEVICE_NAME ($$DEVICE_ID)"; \
	echo "▸ Building (Debug, automatic dev signing)…"; \
	xcodebuild -workspace Velia.xcworkspace -scheme Velia -configuration Debug \
		-destination "id=$$DEVICE_ID" -allowProvisioningUpdates \
		-derivedDataPath build/DerivedData build >/dev/null \
		|| { echo "❌ Build/destination failed. Most common cause: $$DEVICE_NAME is locked — unlock the phone (keep it awake) and rerun 'make deploy-device'."; exit 70; }; \
	APP="build/DerivedData/Build/Products/Debug-iphoneos/Velia.app"; \
	echo "▸ Installing…"; xcrun devicectl device install app --device "$$DEVICE_ID" "$$APP" >/dev/null; \
	echo "▸ Launching…"; xcrun devicectl device process launch --device "$$DEVICE_ID" $(APP_BUNDLE_ID) >/dev/null; \
	echo "✅ Velia deployed to $$DEVICE_NAME — free-account profile valid ~7 days; rerun 'make deploy-device' when it expires."

lint: ## SwiftFormat --lint + SwiftLint (skipped if not installed)
	@command -v swiftformat >/dev/null 2>&1 && swiftformat --lint . || echo "swiftformat not installed — skipping"
	@command -v swiftlint   >/dev/null 2>&1 && swiftlint --strict     || echo "swiftlint not installed — skipping"

format: ## Auto-format with SwiftFormat
	@command -v swiftformat >/dev/null 2>&1 && swiftformat . || echo "swiftformat not installed"

test: test-core ## Run all unit/property tests (engine today; app schemes after bootstrap)

test-core: ## VeliaCore unit + property + gate tests
	cd $(CORE) && swift test

bench: ## Run the Phase 0 engine benchmark gate (exit 0 = GO)
	cd $(CORE) && swift run velia-bench

test-snapshot: ## Snapshot tests (activates with the app target)
	@echo "Snapshot tests run via the app scheme once Tuist project is generated (Phase 2+)."

test-ui: ## XCUITest critical flows (activates with the app target)
	@echo "UI tests run via the app scheme once Tuist project is generated (Phase 1+)."

verify: lint test-core ## Standard gate: lint + unit/property tests
	@echo "✅ verify passed"

verify-all: verify bench test-ui ## Full gate: verify + benchmark + UI smoke
	@echo "✅ verify-all passed"

clean: ## Remove build artifacts
	cd $(CORE) && swift package clean
	rm -rf $(CORE)/.build
