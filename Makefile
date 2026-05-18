SCHEME    = ChordTyper
BUILD_DIR = .build
APP_PATH  = $(BUILD_DIR)/Build/Products/Release/$(SCHEME).app

.PHONY: generate build run test dmg clean

generate:
	xcodegen generate

build: generate
	xcodebuild -scheme $(SCHEME) -configuration Release \
	  -derivedDataPath $(BUILD_DIR) build

run: build
	open "$(APP_PATH)"

test: generate
	xcodebuild -scheme $(SCHEME)Tests -configuration Debug \
	  -derivedDataPath $(BUILD_DIR) test

dmg: build
	codesign --force --deep -s - "$(APP_PATH)"
	hdiutil create -volname $(SCHEME) -srcfolder "$(APP_PATH)" \
	  -ov -format UDZO $(BUILD_DIR)/$(SCHEME).dmg

clean:
	rm -rf $(BUILD_DIR) *.xcodeproj
