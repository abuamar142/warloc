.PHONY: run build install clean analyze get

run:
	flutter run

build:
	flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/app/outputs/symbols

install:
	@echo "Detecting connected device ABI..."
	@ABI=$$(adb shell getprop ro.product.cpu.abi | tr -d '\r' 2>/dev/null); \
	if [ -z "$$ABI" ]; then \
		echo "Error: No connected device found via adb. Make sure USB debugging is enabled."; \
		exit 1; \
	fi; \
	APK_PATH="build/app/outputs/flutter-apk/app-$$ABI-release.apk"; \
	if [ -f "$$APK_PATH" ]; then \
		echo "Installing/Updating APK for ABI $$ABI: $$APK_PATH..."; \
		adb install -r -d "$$APK_PATH"; \
	else \
		FALLBACK_APK="build/app/outputs/flutter-apk/app-release.apk"; \
		if [ -f "$$FALLBACK_APK" ]; then \
			echo "APK for ABI $$ABI not found. Installing default release APK: $$FALLBACK_APK..."; \
			adb install -r -d "$$FALLBACK_APK"; \
		else \
			echo "Error: No APK found. Please run 'make build' first."; \
			exit 1; \
		fi \
	fi


clean:
	flutter clean

analyze:
	dart analyze

get:
	flutter pub get

