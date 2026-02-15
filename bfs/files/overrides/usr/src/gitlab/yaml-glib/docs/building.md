# Building yaml-glib

This document describes how to build yaml-glib from source, its dependencies, and available build targets.

## Dependencies

yaml-glib requires the following libraries:

| Library | Package (Fedora) | Package (Debian/Ubuntu) | Purpose |
|---------|------------------|-------------------------|---------|
| GLib 2.0 | glib2-devel | libglib2.0-dev | Core utilities and data structures |
| GObject 2.0 | (included with glib2) | (included with glib) | Object system |
| GIO 2.0 | (included with glib2) | (included with glib) | I/O operations |
| libyaml | libyaml-devel | libyaml-dev | YAML parsing and emitting |
| JSON-GLib 1.0 | json-glib-devel | libjson-glib-dev | JSON interoperability |

### Installing Dependencies

**Fedora:**
```bash
sudo dnf install gcc make glib2-devel libyaml-devel json-glib-devel
```

**Debian/Ubuntu:**
```bash
sudo apt install gcc make libglib2.0-dev libyaml-dev libjson-glib-dev
```

**Arch Linux:**
```bash
sudo pacman -S gcc make glib2 libyaml json-glib
```

### Verifying Dependencies

Use pkg-config to verify all dependencies are installed:

```bash
pkg-config --exists glib-2.0 gobject-2.0 gio-2.0 yaml-0.1 json-glib-1.0 && echo "All dependencies found"
```

To see the compiler flags:
```bash
pkg-config --cflags glib-2.0 gobject-2.0 gio-2.0 yaml-0.1 json-glib-1.0
```

To see the linker flags:
```bash
pkg-config --libs glib-2.0 gobject-2.0 gio-2.0 yaml-0.1 json-glib-1.0
```

## Build Configuration

yaml-glib uses GNU Make for building. The Makefile supports several configuration variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `CC` | gcc | C compiler to use |
| `AR` | ar | Archive tool |
| `RANLIB` | ranlib | Archive index tool |
| `PKG_CONFIG` | pkg-config | pkg-config tool |
| `PREFIX` | /usr/local | Installation prefix |
| `DESTDIR` | (empty) | Staging directory for packaging |
| `WINDOWS` | 0 | Set to 1 for Windows cross-compilation |
| `CROSS` | (empty) | Cross-compiler prefix (e.g., x86_64-w64-mingw32) |

### Compiler Flags

The default CFLAGS include:
- `-std=gnu89` - GNU C89 standard
- `-Wall -Wextra` - Enable warnings
- `-g` - Debug symbols
- `-fPIC` - Position-independent code (required for shared library)
- `-I./src` - Include path for headers

## Building

### Basic Build

```bash
git clone https://gitlab.com/your-repo/yaml-glib.git
cd yaml-glib
make
```

This builds:
- `build/libyaml-glib.so.1.0.0` - Shared library
- `build/libyaml-glib.so.1` - Soname symlink
- `build/libyaml-glib.so` - Development symlink
- `build/libyaml-glib.a` - Static library

### Build Targets

| Target | Description |
|--------|-------------|
| `make` or `make all` | Build shared and static libraries |
| `make tests` | Build test executables |
| `make check` or `make run-tests` | Build and run all tests |
| `make clean` | Remove build artifacts |
| `make install` | Install to PREFIX |
| `make uninstall` | Remove installed files |

### Building Tests

```bash
make tests
```

This compiles all `test_*.c` files in the `tests/` directory into separate executables in `build/`.

### Running Tests

```bash
make check
```

Or equivalently:
```bash
make run-tests
```

This runs all test executables and reports pass/fail status:
```
Running build/test_builder...
Running build/test_generator...
Running build/test_mapping...
...
All tests passed!
```

## Installation

### System-Wide Installation

```bash
sudo make install
```

Default installation paths:
- Headers: `/usr/local/include/yaml-glib/`
- Libraries: `/usr/local/lib/`
- pkg-config: `/usr/local/lib/pkgconfig/`

After installation, run ldconfig to update the library cache:
```bash
sudo ldconfig
```

### Custom Installation Prefix

```bash
make PREFIX=/opt/yaml-glib install
```

### Staged Installation (for Packaging)

```bash
make DESTDIR=/tmp/yaml-glib-pkg install
```

This installs to `/tmp/yaml-glib-pkg/usr/local/...` which is useful for building packages.

### Uninstallation

```bash
sudo make uninstall
```

## Library Versioning

yaml-glib uses standard library versioning:

| Variable | Value | Description |
|----------|-------|-------------|
| `LIB_MAJOR` | 1 | Major version (ABI breaking changes) |
| `LIB_MINOR` | 0 | Minor version (new features) |
| `LIB_PATCH` | 0 | Patch version (bug fixes) |

The shared library is versioned as:
- `libyaml-glib.so.1.0.0` - Real name with full version
- `libyaml-glib.so.1` - Soname (for runtime linking)
- `libyaml-glib.so` - Linker name (for development)

## Using yaml-glib in Your Projects

### With Installed Library

**Compiler flags:**
```bash
gcc -I/usr/local/include/yaml-glib \
    `pkg-config --cflags glib-2.0 gobject-2.0 gio-2.0 yaml-0.1 json-glib-1.0` \
    -c myprogram.c
```

**Linker flags:**
```bash
gcc -o myprogram myprogram.o \
    -L/usr/local/lib -lyaml-glib \
    `pkg-config --libs glib-2.0 gobject-2.0 gio-2.0 yaml-0.1 json-glib-1.0`
```

### With Uninstalled Library (Development)

When developing against an uninstalled yaml-glib:

```bash
gcc -I/path/to/yaml-glib/src \
    `pkg-config --cflags glib-2.0 gobject-2.0 gio-2.0 yaml-0.1 json-glib-1.0` \
    -c myprogram.c

gcc -o myprogram myprogram.o \
    -L/path/to/yaml-glib/build -lyaml-glib \
    `pkg-config --libs glib-2.0 gobject-2.0 gio-2.0 yaml-0.1 json-glib-1.0`

# Set library path when running
LD_LIBRARY_PATH=/path/to/yaml-glib/build ./myprogram
```

### Example Makefile

```makefile
CC = gcc
CFLAGS = -std=gnu89 -Wall -Wextra -g \
    `pkg-config --cflags glib-2.0 gobject-2.0 gio-2.0 yaml-0.1 json-glib-1.0`
LDFLAGS = -lyaml-glib \
    `pkg-config --libs glib-2.0 gobject-2.0 gio-2.0 yaml-0.1 json-glib-1.0`

myprogram: myprogram.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)
```

## Static Linking

To link statically against yaml-glib:

```bash
gcc -o myprogram myprogram.c /usr/local/lib/libyaml-glib.a \
    `pkg-config --libs glib-2.0 gobject-2.0 gio-2.0 yaml-0.1 json-glib-1.0`
```

Note: Static linking still requires shared libraries for GLib, libyaml, and JSON-GLib unless you statically link those as well.

## Troubleshooting

### Library Not Found at Runtime

If you get "libyaml-glib.so: cannot open shared object file":

1. Ensure the library path is in the linker cache:
   ```bash
   sudo ldconfig /usr/local/lib
   ```

2. Or set LD_LIBRARY_PATH:
   ```bash
   export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
   ```

### Header Not Found

If you get "yaml-glib.h: No such file or directory":

1. Check the include path in your CFLAGS
2. Verify installation:
   ```bash
   ls /usr/local/include/yaml-glib/
   ```

### pkg-config Not Finding Packages

Ensure PKG_CONFIG_PATH includes the right directories:
```bash
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH
```

## Development Build

For development with debugging enabled:

```bash
make CFLAGS="-std=gnu89 -Wall -Wextra -g -O0 -fPIC -I./src \
    `pkg-config --cflags glib-2.0 gobject-2.0 gio-2.0 yaml-0.1 json-glib-1.0`"
```

For a release build with optimizations:

```bash
make CFLAGS="-std=gnu89 -Wall -Wextra -O2 -fPIC -I./src \
    `pkg-config --cflags glib-2.0 gobject-2.0 gio-2.0 yaml-0.1 json-glib-1.0`"
```

## Source Files

The library source files in `src/`:

| File | Description |
|------|-------------|
| yaml-types.h | Type definitions, enums, error codes |
| yaml-node.{h,c} | YamlNode boxed type |
| yaml-mapping.{h,c} | YamlMapping boxed type |
| yaml-sequence.{h,c} | YamlSequence boxed type |
| yaml-document.{h,c} | YamlDocument GObject |
| yaml-parser.{h,c} | YamlParser GObject |
| yaml-builder.{h,c} | YamlBuilder GObject |
| yaml-generator.{h,c} | YamlGenerator GObject |
| yaml-serializable.{h,c} | YamlSerializable interface |
| yaml-gobject.{h,c} | GObject serialization utilities |
| yaml-schema.{h,c} | YamlSchema validation |
| yaml-private.h | Private implementation details |
| yaml-glib.h | Main include file |

## Cross-Compilation

yaml-glib supports cross-compilation for Windows using MinGW-w64. The build system automatically detects platform changes and cleans the build directory when switching between native and cross-compilation.

### Cross-Compilation Dependencies

**Fedora:**

```bash
sudo dnf install mingw64-gcc mingw64-glib2 mingw64-json-glib mingw64-libyaml
```

| Package | Description |
|---------|-------------|
| mingw64-gcc | MinGW-w64 GCC cross-compiler |
| mingw64-glib2 | GLib 2.0 for Windows |
| mingw64-json-glib | JSON-GLib for Windows |
| mingw64-libyaml | libyaml for Windows |

### Cross-Compilation Usage

**Simple Windows build:**

```bash
make WINDOWS=1
```

**With explicit cross-compiler prefix:**

```bash
make CROSS=x86_64-w64-mingw32
```

**Build specific targets:**

```bash
make WINDOWS=1 tests      # Build test executables
make WINDOWS=1 examples   # Build example programs
make WINDOWS=1 lib-static # Build static library only
make WINDOWS=1 lib-shared # Build DLL only
```

**View build configuration:**

```bash
make WINDOWS=1 info
```

### Cross-Compilation Output Files

When cross-compiling for Windows, the following files are produced:

| File | Description |
|------|-------------|
| `build/yaml-glib.dll` | Runtime DLL (ship with application) |
| `build/libyaml-glib.dll.a` | Import library (for linking) |
| `build/libyaml-glib.a` | Static library |
| `build/test_*.exe` | Test executables |
| `build/examples/*.exe` | Example programs |

### Platform Auto-Detection

The build system tracks the current build platform in `build/.platform`. When you switch between native and cross-compilation, the build directory is automatically cleaned to prevent mixing incompatible object files:

```bash
make                # Native Linux build
make WINDOWS=1      # Auto-cleans and rebuilds for Windows
make                # Auto-cleans and rebuilds for Linux
```

To force a clean build:

```bash
make clean && make WINDOWS=1
```

### Running Cross-Compiled Tests

Cross-compiled test binaries cannot run directly on Linux. Options:

1. **Use Wine** (recommended for quick testing):

   ```bash
   cd build
   WINEPATH="/usr/x86_64-w64-mingw32/sys-root/mingw/bin" wine test_node.exe
   ```

   The `WINEPATH` environment variable tells Wine where to find the MinGW runtime DLLs (`libglib-2.0-0.dll`, `libyaml-0-2.dll`, etc.).

   Run all tests:

   ```bash
   cd build
   for exe in test_*.exe; do
       echo "Running $exe..."
       WINEPATH="/usr/x86_64-w64-mingw32/sys-root/mingw/bin" wine "$exe" 2>/dev/null
   done
   ```

2. **Copy to Windows**: Transfer `build/*.exe`, `build/yaml-glib.dll`, and the required DLLs to a Windows machine

3. **Use a Windows VM**: Share the build directory with a Windows VM

### Notes on Cross-Compilation

- The `install` target is disabled for cross-compilation (use manual file copying)
- GObject Introspection is not supported for cross-compilation
- All dependencies must be available for the MinGW-w64 toolchain

## Cross-Compiling for Linux ARM64

yaml-glib supports cross-compilation for Linux ARM64 (aarch64) targets. Unlike Windows cross-compilation (which uses pre-built `mingw64-*` packages), ARM64 cross-compilation requires setting up a sysroot with ARM64 libraries.

### Cross-Compilation Dependencies

**Fedora:**

```bash
sudo dnf install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu \
    sysroot-aarch64-fc41-glibc qemu-user-static cpio
```

| Package | Description |
|---------|-------------|
| gcc-aarch64-linux-gnu | ARM64 cross-compiler |
| binutils-aarch64-linux-gnu | ARM64 cross binutils (ar, ranlib, ld) |
| sysroot-aarch64-fc41-glibc | Base ARM64 glibc sysroot with headers and runtime |
| qemu-user-static | Run ARM64 binaries on x86_64 via QEMU |
| cpio | Required to extract RPM packages |

The `sysroot-aarch64-fc41-glibc` package installs the base sysroot to `/usr/aarch64-redhat-linux/sys-root/fc41`.

### Setting Up the ARM64 Sysroot

The base glibc sysroot doesn't include glib2, libyaml, or json-glib. Use the provided script to download and extract ARM64 versions of these libraries:

```bash
sudo ./scripts/setup-arm64-sysroot.sh
```

This downloads ARM64 packages from Fedora repositories and extracts them into the Fedora sysroot at `/usr/aarch64-redhat-linux/sys-root/fc41`.

**Custom sysroot location:**

```bash
./scripts/setup-arm64-sysroot.sh ~/arm64-sysroot
```

**Manual setup:**

If you prefer to set up the sysroot manually:

```bash
SYSROOT=/usr/aarch64-redhat-linux/sys-root/fc41
TMPDIR=$(mktemp -d)

# Download ARM64 packages
dnf download --destdir="$TMPDIR" --forcearch=aarch64 \
    glib2 glib2-devel libyaml libyaml-devel json-glib json-glib-devel \
    libffi libffi-devel pcre2 pcre2-devel zlib zlib-devel \
    libmount libmount-devel libblkid libblkid-devel \
    libselinux libselinux-devel libsepol libsepol-devel

# Extract to sysroot
for rpm in "$TMPDIR"/*.rpm; do
    rpm2cpio "$rpm" | sudo cpio -idm -D "$SYSROOT"
done
```

### Cross-Compilation Usage

**Simple ARM64 build:**

```bash
make LINUX_ARM64=1
```

**With custom sysroot:**

```bash
make LINUX_ARM64=1 ARM64_SYSROOT=~/arm64-sysroot
```

**Build specific targets:**

```bash
make LINUX_ARM64=1 tests      # Build test executables
make LINUX_ARM64=1 examples   # Build example programs
make LINUX_ARM64=1 lib-static # Build static library only
make LINUX_ARM64=1 lib-shared # Build shared library only
```

**View build configuration:**

```bash
make LINUX_ARM64=1 info
```

### ARM64 Output Files

When cross-compiling for ARM64, the following files are produced:

| File | Description |
|------|-------------|
| `build/libyaml-glib.so.1.0.0` | Shared library (ELF aarch64) |
| `build/libyaml-glib.so.1` | Soname symlink |
| `build/libyaml-glib.so` | Development symlink |
| `build/libyaml-glib.a` | Static library |
| `build/test_*` | Test executables (ELF aarch64) |
| `build/examples/*` | Example programs (ELF aarch64) |

Verify the architecture:

```bash
file build/libyaml-glib.so.1.0.0
# Output: ELF 64-bit LSB shared object, ARM aarch64, ...
```

### Running ARM64 Tests

Cross-compiled tests can be run using QEMU user-mode emulation:

```bash
make LINUX_ARM64=1 check
```

This automatically uses `qemu-aarch64` with the sysroot as the library path.

**Manual test execution:**

```bash
qemu-aarch64 -L /usr/aarch64-redhat-linux/sys-root/fc41 ./build/test_node
```

**Run all tests manually:**

```bash
SYSROOT=/usr/aarch64-redhat-linux/sys-root/fc41
for test in build/test_*; do
    echo "Running $test..."
    qemu-aarch64 -L "$SYSROOT" "$test" || exit 1
done
```

### Troubleshooting

**pkg-config errors during build:**

Ensure the sysroot has .pc files:

```bash
ls /usr/aarch64-redhat-linux/sys-root/fc41/usr/lib64/pkgconfig/
```

If missing, run the sysroot setup script again:

```bash
sudo ./scripts/setup-arm64-sysroot.sh
```

**QEMU fails with "Exec format error":**

Ensure `qemu-user-static` is installed and binfmt_misc is configured:

```bash
sudo dnf install qemu-user-static
sudo systemctl restart systemd-binfmt
```

**Library not found at runtime:**

QEMU needs the sysroot path. Either use `make check` (which sets it automatically) or specify manually:

```bash
qemu-aarch64 -L /usr/aarch64-redhat-linux/sys-root/fc41 ./build/test_node
```

**Missing dependencies in sysroot:**

The setup script downloads common dependencies. If you get linker errors about missing libraries, you may need to download additional packages:

```bash
SYSROOT=/usr/aarch64-redhat-linux/sys-root/fc41
dnf download --destdir=/tmp/arm64 --forcearch=aarch64 <missing-package>
rpm2cpio /tmp/arm64/<package>.rpm | sudo cpio -idm -D "$SYSROOT"
```

## See Also

- [Getting Started](getting-started.md) - Quick start guide
- [API Reference](api/types.md) - Full API documentation
