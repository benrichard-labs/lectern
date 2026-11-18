# Lectern build helpers.
#
#   make mac         Generate the Xcode project and build the menu bar app
#   make mac-run     Build and launch the menu bar app
#   make garmin      Build the watch app (DEVICE=fenix7 by default)
#   make garmin-key  Create the Connect IQ developer signing key
#   make icons       Regenerate the app and watch icons from design/make_glyph.py
#   make release     Signed Mac DMG plus watch .iq and per-device .prg files

DEVICE ?= fenix7
KEY ?= garmin/developer_key.der

# Use the SDK selected in Garmin's SDK Manager, falling back to PATH.
SDK_HOME := $(shell cat "$(HOME)/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg" 2>/dev/null)
MONKEYC := $(if $(SDK_HOME),$(SDK_HOME)/bin/monkeyc,monkeyc)

# monkeyc runs `java` from PATH. Homebrew's JDK is keg-only, so look for a
# system JDK first, then `brew install openjdk@21`.
JAVA_HOME ?= $(shell /usr/libexec/java_home 2>/dev/null || brew --prefix openjdk@21 2>/dev/null)
export PATH := $(JAVA_HOME)/bin:$(PATH)

MAC_APP := build/mac/Build/Products/Debug/Lectern.app
WATCH_PRG := build/garmin/Lectern-$(DEVICE).prg
RELEASE_GARMIN := build/release/garmin
GARMIN_DEVICES := $(shell sed -n 's/.*<iq:product id="\([^"]*\)".*/\1/p' garmin/manifest.xml)

ICTOOL := $(shell xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool
APP_ICON := mac/Lectern/AppIcon.icon

.PHONY: mac mac-project mac-run garmin garmin-key icons release mac-release garmin-release clean

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

icons:
	python3 -I design/make_glyph.py > $(APP_ICON)/Assets/lectern.svg
	"$(ICTOOL)" $(APP_ICON) --export-image --output-file garmin/resources/drawables/launcher_icon.png \
		--platform watchOS --rendition Default --width 40 --height 40 --scale 1

release: mac-release garmin-release

mac-release:
	scripts/release-mac.sh

# Lectern.iq is the store/distribution package covering every device in the
# manifest; the .prg files can be sideloaded directly.
garmin-release: $(KEY)
	rm -rf $(RELEASE_GARMIN)
	mkdir -p $(RELEASE_GARMIN)
	"$(MONKEYC)" -e -r -f garmin/monkey.jungle -o $(RELEASE_GARMIN)/Lectern.iq -y $(KEY)
	for device in $(GARMIN_DEVICES); do \
		"$(MONKEYC)" -r -d $$device -f garmin/monkey.jungle -o $(RELEASE_GARMIN)/Lectern-$$device.prg -y $(KEY) || exit 1; \
	done
	rm -rf $(RELEASE_GARMIN)/*.debug.xml $(RELEASE_GARMIN)/gen $(RELEASE_GARMIN)/mir $(RELEASE_GARMIN)/internal-mir

clean:
	rm -rf build mac/Lectern.xcodeproj
