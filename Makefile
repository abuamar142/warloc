.PHONY: run build clean analyze get

run:
	flutter run

build:
	flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/app/outputs/symbols

clean:
	flutter clean

analyze:
	dart analyze

get:
	flutter pub get
