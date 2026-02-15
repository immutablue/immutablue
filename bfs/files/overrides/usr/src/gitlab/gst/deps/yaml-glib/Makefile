# yaml-glib Makefile
#
# Copyright 2025 Zach Podbielniak
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Build libyaml-glib with cross-compilation support

#=============================================================================
# Cross-Compilation Configuration
#=============================================================================
# Usage:
#   make                      # Native Linux build (x86_64 or aarch64)
#   make WINDOWS=1            # Cross-compile for Windows x64
#   make LINUX_ARM64=1        # Cross-compile for Linux ARM64
#   make CROSS=<prefix>       # Explicit cross-compiler prefix
#
# See docs/building.md for detailed cross-compilation instructions.
#=============================================================================

WINDOWS ?= 0
LINUX_ARM64 ?= 0
CROSS ?=

# ARM64 sysroot location (Fedora's sysroot-aarch64-fc41-glibc package)
ARM64_SYSROOT ?= /usr/aarch64-redhat-linux/sys-root/fc41

# Set CROSS based on convenience variables
ifeq ($(WINDOWS),1)
    CROSS := x86_64-w64-mingw32
endif

ifeq ($(LINUX_ARM64),1)
    CROSS := aarch64-linux-gnu
endif

#=============================================================================
# Architecture Detection
#=============================================================================
# Detect target architecture (useful for info/debugging)
# For ARM64 builds, use container-based native compilation (see docs/building.md)

ifneq ($(CROSS),)
    ifeq ($(CROSS),x86_64-w64-mingw32)
        TARGET_ARCH := x86_64
    else ifeq ($(CROSS),aarch64-linux-gnu)
        TARGET_ARCH := aarch64
    else
        TARGET_ARCH := unknown
    endif
else
    TARGET_ARCH := $(shell uname -m)
endif

#=============================================================================
# Toolchain Configuration
#=============================================================================

ifneq ($(CROSS),)
    CC := $(CROSS)-gcc
    AR := $(CROSS)-ar
    RANLIB := $(CROSS)-ranlib

    ifeq ($(CROSS),x86_64-w64-mingw32)
        # Windows cross-compilation uses mingw pkg-config wrapper
        PKG_CONFIG := $(CROSS)-pkg-config
        TARGET_PLATFORM := windows
    else ifeq ($(CROSS),aarch64-linux-gnu)
        # ARM64 cross-compilation uses sysroot with native pkg-config
        PKG_CONFIG_SYSROOT_DIR := $(ARM64_SYSROOT)
        PKG_CONFIG_PATH := $(ARM64_SYSROOT)/usr/lib64/pkgconfig:$(ARM64_SYSROOT)/usr/share/pkgconfig
        PKG_CONFIG := PKG_CONFIG_SYSROOT_DIR=$(PKG_CONFIG_SYSROOT_DIR) PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) pkg-config
        SYSROOT_FLAGS := --sysroot=$(ARM64_SYSROOT)
        TARGET_PLATFORM := linux
    else
        PKG_CONFIG := pkg-config
        TARGET_PLATFORM := linux
    endif
else
    CC ?= gcc
    AR ?= ar
    RANLIB ?= ranlib
    PKG_CONFIG ?= pkg-config
    TARGET_PLATFORM := linux
    SYSROOT_FLAGS :=
endif

#=============================================================================
# Library Versioning
#=============================================================================

LIB_MAJOR = 1
LIB_MINOR = 0
LIB_PATCH = 0
LIB_VERSION = $(LIB_MAJOR).$(LIB_MINOR).$(LIB_PATCH)

#=============================================================================
# Directories
#=============================================================================

SRCDIR = src
TESTDIR = tests
EXAMPLEDIR = examples
BUILDDIR = build

#=============================================================================
# Platform-Specific Configuration
#=============================================================================

ifeq ($(TARGET_PLATFORM),windows)
    # Windows: DLL + import library
    LIB_STATIC := libyaml-glib.a
    LIB_SHARED := yaml-glib.dll
    LIB_IMPORT := libyaml-glib.dll.a
    EXE_EXT := .exe
    SHARED_LDFLAGS = -shared -Wl,--out-implib,$(BUILDDIR)/$(LIB_IMPORT)
else
    # Linux: SO with versioning
    LIB_STATIC := libyaml-glib.a
    LIB_SHARED := libyaml-glib.so
    LIB_SHARED_VERSION := libyaml-glib.so.$(LIB_VERSION)
    LIB_SHARED_SONAME := libyaml-glib.so.$(LIB_MAJOR)
    EXE_EXT :=
    SHARED_LDFLAGS = -shared -Wl,-soname,$(LIB_SHARED_SONAME)
endif

#=============================================================================
# Compiler/Linker Flags
#=============================================================================

PKG_CFLAGS := $(shell $(PKG_CONFIG) --cflags glib-2.0 gobject-2.0 gio-2.0 yaml-0.1 json-glib-1.0)
PKG_LIBS := $(shell $(PKG_CONFIG) --libs glib-2.0 gobject-2.0 gio-2.0 yaml-0.1 json-glib-1.0)

CFLAGS = -std=gnu89 -Wall -Wextra -g -fPIC -I./$(SRCDIR) $(SYSROOT_FLAGS) $(PKG_CFLAGS)
LDFLAGS = $(SYSROOT_FLAGS) $(PKG_LIBS)

#=============================================================================
# Source Files
#=============================================================================

SOURCES = \
	$(SRCDIR)/yaml-node.c \
	$(SRCDIR)/yaml-mapping.c \
	$(SRCDIR)/yaml-sequence.c \
	$(SRCDIR)/yaml-document.c \
	$(SRCDIR)/yaml-parser.c \
	$(SRCDIR)/yaml-builder.c \
	$(SRCDIR)/yaml-generator.c \
	$(SRCDIR)/yaml-serializable.c \
	$(SRCDIR)/yaml-gobject.c \
	$(SRCDIR)/yaml-schema.c

HEADERS = \
	$(SRCDIR)/yaml-glib.h \
	$(SRCDIR)/yaml-types.h \
	$(SRCDIR)/yaml-node.h \
	$(SRCDIR)/yaml-mapping.h \
	$(SRCDIR)/yaml-sequence.h \
	$(SRCDIR)/yaml-document.h \
	$(SRCDIR)/yaml-parser.h \
	$(SRCDIR)/yaml-builder.h \
	$(SRCDIR)/yaml-generator.h \
	$(SRCDIR)/yaml-serializable.h \
	$(SRCDIR)/yaml-gobject.h \
	$(SRCDIR)/yaml-schema.h \
	$(SRCDIR)/yaml-private.h

OBJECTS = \
	$(BUILDDIR)/yaml-node.o \
	$(BUILDDIR)/yaml-mapping.o \
	$(BUILDDIR)/yaml-sequence.o \
	$(BUILDDIR)/yaml-document.o \
	$(BUILDDIR)/yaml-parser.o \
	$(BUILDDIR)/yaml-builder.o \
	$(BUILDDIR)/yaml-generator.o \
	$(BUILDDIR)/yaml-serializable.o \
	$(BUILDDIR)/yaml-gobject.o \
	$(BUILDDIR)/yaml-schema.o

#=============================================================================
# Platform Marker (Auto-Clean on Platform Switch)
#=============================================================================

PLATFORM_MARKER := $(BUILDDIR)/.platform

#=============================================================================
# Test Configuration
#=============================================================================

TEST_SOURCES = $(wildcard $(TESTDIR)/test_*.c)
TEST_BINARIES = $(patsubst $(TESTDIR)/%.c,$(BUILDDIR)/%$(EXE_EXT),$(TEST_SOURCES))

#=============================================================================
# Example Configuration
#=============================================================================

EXAMPLE_BINARIES = \
	$(BUILDDIR)/examples/yaml-print$(EXE_EXT) \
	$(BUILDDIR)/examples/yaml-to-json$(EXE_EXT) \
	$(BUILDDIR)/examples/json-to-yaml$(EXE_EXT)

#=============================================================================
# Install Configuration
#=============================================================================

PREFIX ?= /usr/local
INCLUDEDIR = $(PREFIX)/include/yaml-glib
LIBDIR = $(PREFIX)/lib
PKGCONFIGDIR = $(LIBDIR)/pkgconfig

#=============================================================================
# Default Target
#=============================================================================

all: platform-check $(BUILDDIR) libs

#=============================================================================
# Platform Check (Auto-Clean on Platform Switch)
#=============================================================================

.PHONY: platform-check
platform-check:
	@mkdir -p $(BUILDDIR)
	@if [ -f "$(PLATFORM_MARKER)" ] && \
	   [ "$$(cat $(PLATFORM_MARKER))" != "$(TARGET_PLATFORM)" ]; then \
		echo "Platform changed from $$(cat $(PLATFORM_MARKER)) to $(TARGET_PLATFORM), cleaning..."; \
		rm -rf $(BUILDDIR)/*; \
		mkdir -p $(BUILDDIR); \
	fi
	@echo "$(TARGET_PLATFORM)" > $(PLATFORM_MARKER)

#=============================================================================
# Directory Creation
#=============================================================================

$(BUILDDIR):
	mkdir -p $(BUILDDIR)

$(BUILDDIR)/examples:
	mkdir -p $(BUILDDIR)/examples

#=============================================================================
# Library Targets
#=============================================================================

.PHONY: libs lib-static lib-shared
libs: lib-static lib-shared

lib-static: $(BUILDDIR)/$(LIB_STATIC)

lib-shared: $(BUILDDIR)/$(LIB_SHARED)

# Static library
$(BUILDDIR)/$(LIB_STATIC): $(OBJECTS)
	$(AR) rcs $@ $^
	$(RANLIB) $@

# Shared library (platform-specific)
ifeq ($(TARGET_PLATFORM),windows)
$(BUILDDIR)/$(LIB_SHARED): $(OBJECTS)
	$(CC) $(SHARED_LDFLAGS) -o $@ $^ $(LDFLAGS)
	@echo "Built: $(LIB_SHARED) and $(LIB_IMPORT)"
else
$(BUILDDIR)/$(LIB_SHARED): $(OBJECTS)
	$(CC) $(SHARED_LDFLAGS) -o $(BUILDDIR)/$(LIB_SHARED_VERSION) $^ $(LDFLAGS)
	ln -sf $(LIB_SHARED_VERSION) $(BUILDDIR)/$(LIB_SHARED_SONAME)
	ln -sf $(LIB_SHARED_SONAME) $(BUILDDIR)/$(LIB_SHARED)
	@echo "Built: $(LIB_SHARED_VERSION) with symlinks"
endif

#=============================================================================
# Object File Rules
#=============================================================================

$(BUILDDIR)/%.o: $(SRCDIR)/%.c $(HEADERS)
	$(CC) $(CFLAGS) -c $< -o $@

#=============================================================================
# Test Targets
#=============================================================================

.PHONY: tests
tests: platform-check $(BUILDDIR) $(BUILDDIR)/$(LIB_STATIC) $(TEST_BINARIES)

$(BUILDDIR)/test_%$(EXE_EXT): $(TESTDIR)/test_%.c $(BUILDDIR)/$(LIB_STATIC)
	$(CC) $(CFLAGS) -o $@ $< $(BUILDDIR)/$(LIB_STATIC) $(LDFLAGS)

.PHONY: check run-tests
check: tests
ifeq ($(TARGET_PLATFORM),windows)
	@echo "Cross-compiled tests cannot be run on Linux. Use Wine or copy to Windows."
	@echo "Test binaries built in $(BUILDDIR)/"
else ifeq ($(CROSS),aarch64-linux-gnu)
	@echo "Running ARM64 tests via QEMU (requires qemu-user-static)..."
	@for test in $(BUILDDIR)/test_*; do \
		if [ -x "$$test" ]; then \
			echo "Running $$test..."; \
			qemu-aarch64 -L $(ARM64_SYSROOT) $$test || exit 1; \
		fi \
	done
	@echo "All tests passed!"
else
	@for test in $(BUILDDIR)/test_*; do \
		if [ -x "$$test" ]; then \
			echo "Running $$test..."; \
			$$test || exit 1; \
		fi \
	done
	@echo "All tests passed!"
endif

run-tests: check

#=============================================================================
# Example Targets
#=============================================================================

.PHONY: examples
examples: platform-check $(BUILDDIR)/examples $(BUILDDIR)/$(LIB_STATIC) $(EXAMPLE_BINARIES)

$(BUILDDIR)/examples/%$(EXE_EXT): $(EXAMPLEDIR)/%.c $(BUILDDIR)/$(LIB_STATIC)
	$(CC) $(CFLAGS) -o $@ $< $(BUILDDIR)/$(LIB_STATIC) $(LDFLAGS)

#=============================================================================
# Install Targets
#=============================================================================

.PHONY: install
install: libs
ifeq ($(TARGET_PLATFORM),windows)
	@echo "Install target is for native Linux builds only."
	@echo "For Windows, copy the DLL and headers manually."
else
	install -d $(DESTDIR)$(INCLUDEDIR)
	install -d $(DESTDIR)$(LIBDIR)
	install -d $(DESTDIR)$(PKGCONFIGDIR)
	install -m 644 $(SRCDIR)/yaml-glib.h $(DESTDIR)$(INCLUDEDIR)/
	install -m 644 $(SRCDIR)/yaml-types.h $(DESTDIR)$(INCLUDEDIR)/
	install -m 644 $(SRCDIR)/yaml-node.h $(DESTDIR)$(INCLUDEDIR)/
	install -m 644 $(SRCDIR)/yaml-mapping.h $(DESTDIR)$(INCLUDEDIR)/
	install -m 644 $(SRCDIR)/yaml-sequence.h $(DESTDIR)$(INCLUDEDIR)/
	install -m 644 $(SRCDIR)/yaml-document.h $(DESTDIR)$(INCLUDEDIR)/
	install -m 644 $(SRCDIR)/yaml-parser.h $(DESTDIR)$(INCLUDEDIR)/
	install -m 644 $(SRCDIR)/yaml-builder.h $(DESTDIR)$(INCLUDEDIR)/
	install -m 644 $(SRCDIR)/yaml-generator.h $(DESTDIR)$(INCLUDEDIR)/
	install -m 644 $(SRCDIR)/yaml-serializable.h $(DESTDIR)$(INCLUDEDIR)/
	install -m 644 $(SRCDIR)/yaml-gobject.h $(DESTDIR)$(INCLUDEDIR)/
	install -m 644 $(SRCDIR)/yaml-schema.h $(DESTDIR)$(INCLUDEDIR)/
	install -m 755 $(BUILDDIR)/$(LIB_SHARED_VERSION) $(DESTDIR)$(LIBDIR)/
	install -m 644 $(BUILDDIR)/$(LIB_STATIC) $(DESTDIR)$(LIBDIR)/
	ln -sf $(LIB_SHARED_VERSION) $(DESTDIR)$(LIBDIR)/$(LIB_SHARED_SONAME)
	ln -sf $(LIB_SHARED_SONAME) $(DESTDIR)$(LIBDIR)/$(LIB_SHARED)
	ldconfig -n $(DESTDIR)$(LIBDIR) || true
endif

.PHONY: uninstall
uninstall:
	rm -rf $(DESTDIR)$(INCLUDEDIR)
	rm -f $(DESTDIR)$(LIBDIR)/$(LIB_SHARED)*
	rm -f $(DESTDIR)$(LIBDIR)/$(LIB_STATIC)
	rm -f $(DESTDIR)$(PKGCONFIGDIR)/yaml-glib.pc

#=============================================================================
# Clean Target
#=============================================================================

.PHONY: clean
clean:
	rm -rf $(BUILDDIR)

#=============================================================================
# Info Target (Debug)
#=============================================================================

.PHONY: info
info:
	@echo "=== Build Configuration ==="
	@echo "TARGET_PLATFORM: $(TARGET_PLATFORM)"
	@echo "TARGET_ARCH:     $(TARGET_ARCH)"
	@echo "CROSS:           $(CROSS)"
	@echo "CC:              $(CC)"
	@echo "AR:              $(AR)"
	@echo "PKG_CONFIG:      $(PKG_CONFIG)"
ifeq ($(CROSS),aarch64-linux-gnu)
	@echo "ARM64_SYSROOT:   $(ARM64_SYSROOT)"
endif
	@echo ""
	@echo "=== Output Files ==="
	@echo "LIB_STATIC:      $(LIB_STATIC)"
	@echo "LIB_SHARED:      $(LIB_SHARED)"
ifeq ($(TARGET_PLATFORM),windows)
	@echo "LIB_IMPORT:      $(LIB_IMPORT)"
endif
	@echo "EXE_EXT:         '$(EXE_EXT)'"
	@echo ""
	@echo "=== Directories ==="
	@echo "BUILDDIR:        $(BUILDDIR)"
	@echo "PREFIX:          $(PREFIX)"

#=============================================================================
# Header Dependencies
#=============================================================================

$(OBJECTS): $(HEADERS)

.PHONY: all libs lib-static lib-shared tests check run-tests examples install uninstall clean info
