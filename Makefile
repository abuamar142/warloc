SHELL := /bin/bash

.PHONY: run build install clean analyze get

run:
	flutter run

build:
	flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/app/outputs/symbols

install:
	@echo "Checking connected devices..."
	@mapfile -t DEVICES < <(adb devices | grep -w "device" | cut -f1); \
	NUM_DEVICES=$${#DEVICES[@]}; \
	if [ "$$NUM_DEVICES" -eq 0 ]; then \
		echo "Error: No connected device found via adb. Make sure USB debugging is enabled."; \
		exit 1; \
	elif [ "$$NUM_DEVICES" -eq 1 ]; then \
		DEVICE_ID=$${DEVICES[0]}; \
	else \
		echo "Multiple devices found. Please select one:"; \
		PS3="Select device number: "; \
		select DEV in "$${DEVICES[@]}"; do \
			if [ -n "$$DEV" ]; then \
				DEVICE_ID=$$DEV; \
				break; \
			fi; \
			echo "Invalid selection. Try again."; \
		done; \
	fi; \
	echo "Selected device: $$DEVICE_ID"; \
	ABI=$$(adb -s "$$DEVICE_ID" shell getprop ro.product.cpu.abi | tr -d '\r' 2>/dev/null); \
	APK_PATH="build/app/outputs/flutter-apk/app-$$ABI-release.apk"; \
	if [ -f "$$APK_PATH" ]; then \
		echo "Installing/Updating APK for ABI $$ABI: $$APK_PATH on $$DEVICE_ID..."; \
		adb -s "$$DEVICE_ID" install -r -d "$$APK_PATH"; \
	else \
		FALLBACK_APK="build/app/outputs/flutter-apk/app-release.apk"; \
		if [ -f "$$FALLBACK_APK" ]; then \
			echo "APK for ABI $$ABI not found. Installing default release APK: $$FALLBACK_APK on $$DEVICE_ID..."; \
			adb -s "$$DEVICE_ID" install -r -d "$$FALLBACK_APK"; \
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
