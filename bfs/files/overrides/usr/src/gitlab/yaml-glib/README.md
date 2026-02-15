# yaml-glib

A GLib/GObject-based YAML library for C, providing a high-level API for parsing, building, and generating YAML documents.

## Features

- **Parse** YAML from files, strings, or streams (sync and async)
- **Build** YAML programmatically with a fluent builder API
- **Generate** YAML output with configurable formatting
- **Validate** YAML against schemas with type and constraint checking
- **Convert** bidirectionally between YAML and JSON-GLib
- **Serialize** GObjects to/from YAML with custom serialization support
- **Reference-counted** boxed types with GLib memory management patterns
- **Multi-document** YAML stream support
- **Anchors and aliases** for YAML references

## Requirements

### Fedora

```bash
sudo dnf install gcc make glib2-devel libyaml-devel json-glib-devel
```

### Debian/Ubuntu

```bash
sudo apt install gcc make libglib2.0-dev libyaml-dev libjson-glib-dev
```

### Arch Linux

```bash
sudo pacman -S gcc make glib2 libyaml json-glib
```

### Cross-Compilation for Windows (from Fedora)

```bash
sudo dnf install mingw64-gcc mingw64-glib2 mingw64-json-glib mingw64-libyaml
```

### Cross-Compilation for Linux ARM64 (from Fedora x86_64)

```bash
sudo dnf install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu \
    sysroot-aarch64-fc41-glibc qemu-user-static cpio
sudo ./scripts/setup-arm64-sysroot.sh  # Adds glib2, libyaml, json-glib to sysroot
```

## Quick Start

### Build

```bash
git clone <repository-url>
cd yaml-glib
make
```

### Cross-Compile for Windows

```bash
make WINDOWS=1
make WINDOWS=1 tests examples
```

### Run Windows Tests with Wine

```bash
cd build
WINEPATH="/usr/x86_64-w64-mingw32/sys-root/mingw/bin" wine test_node.exe
```

### Cross-Compile for Linux ARM64

```bash
make LINUX_ARM64=1
make LINUX_ARM64=1 tests examples
```

### Run ARM64 Tests with QEMU

```bash
make LINUX_ARM64=1 check
```

### Run Tests

```bash
make check
```

### Install

```bash
sudo make install
sudo ldconfig
```

## Quick Example

Parse a YAML file and read values:

```c
#include <yaml-glib/yaml-glib.h>

int
main(int argc, char *argv[])
{
    g_autoptr(YamlParser) parser = yaml_parser_new();
    g_autoptr(GError) error = NULL;

    if (!yaml_parser_load_from_file(parser, "config.yaml", &error))
    {
        g_printerr("Error: %s\n", error->message);
        return 1;
    }

    YamlNode *root = yaml_parser_get_root(parser);
    YamlMapping *config = yaml_node_get_mapping(root);

    const gchar *name = yaml_mapping_get_string_member(config, "name");
    gint64 port = yaml_mapping_get_int_member_with_default(config, "port", 8080);
    gboolean debug = yaml_mapping_get_boolean_member(config, "debug");

    g_print("Name: %s\n", name);
    g_print("Port: %" G_GINT64_FORMAT "\n", port);
    g_print("Debug: %s\n", debug ? "yes" : "no");

    return 0;
}
```

### Compile

```bash
gcc -o example example.c \
    `pkg-config --cflags --libs glib-2.0 gobject-2.0 gio-2.0 yaml-0.1 json-glib-1.0` \
    -lyaml-glib
```

## Documentation

Full documentation is available in the `docs/` directory:

- [Getting Started](docs/getting-started.md) - Complete tutorial with working example
- [Building](docs/building.md) - Build instructions and configuration
- [API Reference](docs/api/) - Complete API documentation
- [Guides](docs/guides/) - How-to guides for common tasks

## License

AGPL-3.0-or-later

## Author

Zach Podbielniak
