# hs._dfzf, the native backend of Dfzf.spoon. Derived from asmagill/hammerspoon_asm's
# Makefile_universal_template, with every source linked into a single library.

HS_APPLICATION ?= /Applications
SPOON_DIR ?= ../Dfzf.spoon
# Lua's C loader resolves require("hs._dfzf") to hs/_dfzf.so on package.cpath.
LIB := _dfzf.so
MACOS_MIN := 11.0

SOURCES := $(wildcard src/*.m)
HEADERS := $(wildcard src/*.h) $(wildcard test/*.h)
# The test runner lives outside Hammerspoon: no LuaSkin glue, no Accessibility.
CORE_SOURCES := $(filter-out src/DFZLua.m src/DFZAXSource.m,$(SOURCES))
TEST_SOURCES := $(wildcard test/*.m)

CC := clang
WARNINGS ?= -Wall -Wextra -Wno-unused-parameter -Werror-implicit-function-declaration
CFLAGS += -g -fobjc-arc $(WARNINGS)
LIB_CFLAGS := -fmodules -DHS_EXTERNAL_MODULE -F$(HS_APPLICATION)/Hammerspoon.app/Contents/Frameworks
# LuaSkin and Lua symbols resolve against the running Hammerspoon at load time.
LIB_LDFLAGS := -dynamiclib -undefined dynamic_lookup -framework Cocoa -framework ApplicationServices

ARCH_LIBS := obj_x86_64/$(LIB) obj_arm64/$(LIB)

all: $(shell uname -m)

x86_64: obj_x86_64/$(LIB)

arm64: obj_arm64/$(LIB)

universal: obj_universal/$(LIB)

$(ARCH_LIBS): obj_%/$(LIB): $(SOURCES) $(HEADERS)
	@mkdir -p $(@D)
	$(CC) $(SOURCES) $(CFLAGS) $(LIB_CFLAGS) -target $*-apple-macos$(MACOS_MIN) $(LIB_LDFLAGS) -o $@

obj_universal/$(LIB): $(ARCH_LIBS)
	@mkdir -p $(@D)
	lipo -create -output $@ $^

# Drops the universal library where Dfzf.spoon looks for it.
spoon: obj_universal/$(LIB)
	install -d $(SPOON_DIR)/hs
	install -m 0644 $< $(SPOON_DIR)/hs/$(LIB)

obj_test/dfzf-test: $(CORE_SOURCES) $(TEST_SOURCES) $(HEADERS)
	@mkdir -p $(@D)
	$(CC) $(CORE_SOURCES) $(TEST_SOURCES) -Isrc $(CFLAGS) -framework Foundation -o $@

test: obj_test/dfzf-test
	$< ../../tests/macos/fixtures/tree.json

clean:
	rm -rf obj_x86_64 obj_arm64 obj_universal obj_test

.PHONY: all x86_64 arm64 universal spoon test clean
