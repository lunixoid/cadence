.DEFAULT_GOAL := help
.PHONY: help macos macos-dev macos-deploy ios ios-dev ios-deploy check install-hooks clean

PROJECT        := Cadence.xcodeproj
MACOS_SCHEME   := Cadence
IOS_SCHEME     := CadenceiOS
BUILD_DIR      := .build
APP_NAME       := Cadence.app
APPLICATIONS_DIR := /Applications

help: ## Show available build roles
	@echo "Cadence build roles:"
	@echo "  make macos          Release build for macOS"
	@echo "  make macos-dev      Debug build for macOS"
	@echo "  make macos-deploy   Release build, install to /Applications, launch"
	@echo "  make ios            Release build for iOS (device, generic)"
	@echo "  make ios-dev        Debug build for iOS Simulator"
	@echo "  make ios-deploy     Debug build, install on paired physical device, launch"
	@echo "  make check          Compiler diagnostics check (warnings as errors)"
	@echo "  make install-hooks  Install the pre-commit git hook"
	@echo "  make clean          Remove local derived data (${BUILD_DIR})"

## --- macOS ---------------------------------------------------------------

macos: ## Release build for macOS
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(MACOS_SCHEME) \
		-configuration Release \
		-destination 'platform=macOS' \
		-derivedDataPath $(BUILD_DIR)/DerivedData-macos-release \
		build

macos-dev: ## Debug build for macOS
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(MACOS_SCHEME) \
		-configuration Debug \
		-destination 'platform=macOS' \
		-derivedDataPath $(BUILD_DIR)/DerivedData-macos-debug \
		build

macos-deploy: macos ## Release build, install to /Applications, launch
	@app="$(BUILD_DIR)/DerivedData-macos-release/Build/Products/Release/$(APP_NAME)"; \
	if [ ! -d "$$app" ]; then \
		echo "error: app bundle not found at $$app" >&2; \
		exit 1; \
	fi; \
	echo "macos-deploy: stopping running instance…"; \
	pkill -x "Cadence" 2>/dev/null || true; \
	echo "macos-deploy: installing to $(APPLICATIONS_DIR)…"; \
	rm -rf "$(APPLICATIONS_DIR)/$(APP_NAME)"; \
	cp -R "$$app" "$(APPLICATIONS_DIR)/$(APP_NAME)"; \
	echo "macos-deploy: launching…"; \
	open "$(APPLICATIONS_DIR)/$(APP_NAME)"; \
	echo "macos-deploy: OK"

## --- iOS -------------------------------------------------------------------

ios: ## Release build for iOS (generic device)
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(IOS_SCHEME) \
		-configuration Release \
		-destination 'generic/platform=iOS' \
		-derivedDataPath $(BUILD_DIR)/DerivedData-ios-release \
		-allowProvisioningUpdates \
		build

ios-dev: ## Debug build for iOS Simulator
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(IOS_SCHEME) \
		-configuration Debug \
		-destination 'generic/platform=iOS Simulator' \
		-derivedDataPath $(BUILD_DIR)/DerivedData-ios-debug \
		CODE_SIGNING_ALLOWED=NO \
		build

ios-deploy: ## Debug build, install on paired physical device, launch
	./scripts/deploy-ios-device.sh

## --- Shared ----------------------------------------------------------------

check: ## Compiler diagnostics check (warnings as errors)
	./scripts/swift-xcode-check.sh

install-hooks: ## Install the pre-commit git hook
	./scripts/install-git-hooks.sh

clean: ## Remove local derived data
	rm -rf $(BUILD_DIR)
