.PHONY: run build install clean analyze get

run:
	flutter run

build:
	flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/app/outputs/symbols

install:
	flutter install

clean:
	flutter clean

analyze:
	dart analyze

get:
	flutter pub get

