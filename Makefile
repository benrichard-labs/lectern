# Lectern build helpers.
#
#   make mac         Generate the Xcode project and build the menu bar app
#   make mac-run     Build and launch the menu bar app
#   make garmin      Build the watch app (DEVICE=fenix7 by default)
#   make garmin-key  Create the Connect IQ developer signing key

DEVICE ?= fenix7
KEY ?= garmin/developer_key.der

# Use the SDK selected in Garmin's SDK Manager, falling back to PATH.
SDK_HOME := $(shell cat "$(HOME)/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg" 2>/dev/null)
MONKEYC := $(if $(SDK_HOME),$(SDK_HOME)/bin/monkeyc,monkeyc)

MAC_APP := build/mac/Build/Products/Debug/Lectern.app
WATCH_PRG := build/garmin/Lectern-$(DEVICE).prg

.PHONY: mac mac-project mac-run garmin garmin-key clean

mac-project:
	cd mac && xcodegen generate

mac: mac-project
	xcodebuild -project mac/Lectern.xcodeproj -scheme Lectern -configuration Debug -derivedDataPath build/mac build

mac-run: mac
	open "$(MAC_APP)"

garmin-key: $(KEY)

$(KEY):
	openssl genrsa -out garmin/developer_key.pem 4096
	openssl pkcs8 -topk8 -inform PEM -outform DER -in garmin/developer_key.pem -out $(KEY) -nocrypt

garmin: $(KEY)
	mkdir -p build/garmin
	"$(MONKEYC)" -d $(DEVICE) -f garmin/monkey.jungle -o $(WATCH_PRG) -y $(KEY)
	@echo "Copy $(WATCH_PRG) to GARMIN/APPS on the watch."

clean:
	rm -rf build mac/Lectern.xcodeproj
