# ChmViewerRe — rebuild of the reversed CHM reader core + UI
SDK := $(shell xcrun --show-sdk-path)
APP := build/ChmViewerRe.app
CC := clang
CFLAGS := -O2 -Wall -arch arm64 -fobjc-arc -std=gnu11
OBJCFLAGS := $(CFLAGS) -mmacosx-version-min=11.0
FRAMEWORKS := -framework Cocoa -framework WebKit -lxml2
INCS := -Ivendor/chmlib/src -I$(SDK)/usr/include/libxml2

CORE_SRC := vendor/chmlib/src/chm_lib.c vendor/chmlib/src/lzx.c
APP_SRC := src/main.m src/CHMApplicationDelegate.m src/CHMDocument.m \
           src/CHMFileHandle.m src/CHMTopicNode.m src/ABCHMContent.m \
           src/ItssSchemeHandler.m src/CHMWindowController.m
TEST_SRC := tools/chmtest.m src/CHMFileHandle.m src/CHMTopicNode.m src/ABCHMContent.m

.PHONY: all app test clean

all: app test

app: $(APP)

$(APP): $(CORE_SRC) $(APP_SRC) resources/Info.plist resources/AppIcon.icns
	@mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp resources/Info.plist $(APP)/Contents/Info.plist
	cp resources/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	$(CC) $(OBJCFLAGS) $(INCS) $(CORE_SRC) $(APP_SRC) $(FRAMEWORKS) \
		-o $(APP)/Contents/MacOS/ChmViewerRe
	codesign --force --sign - $(APP) 2>/dev/null || true
	@echo "Built $(APP)"

test: build/chmtest
	@echo "Built build/chmtest"

build/chmtest: $(CORE_SRC) $(TEST_SRC)
	@mkdir -p build
	$(CC) $(CFLAGS) $(INCS) $(CORE_SRC) $(TEST_SRC) $(FRAMEWORKS) -o $@

clean:
	rm -rf build
