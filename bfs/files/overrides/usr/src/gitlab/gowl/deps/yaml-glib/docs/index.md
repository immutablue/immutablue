# yaml-glib Documentation

**yaml-glib** is a GObject-based YAML library for C that provides comprehensive YAML parsing, generation, and manipulation capabilities with full GLib/GObject integration.

## Features

- **Full YAML 1.1 Support** - Parse and generate compliant YAML documents using libyaml
- **GObject Integration** - Proper GObject types with properties, signals, and introspection support
- **Reference-Counted Types** - YamlNode, YamlMapping, and YamlSequence use reference counting for safe memory management
- **JSON-GLib Interoperability** - Bidirectional conversion between YAML and JSON-GLib types
- **GObject Serialization** - Serialize and deserialize GObjects to/from YAML
- **Schema Validation** - Validate YAML documents against schemas with detailed error reporting
- **Async I/O** - Full async support using GIO patterns (GTask, GAsyncResult)
- **Immutability Support** - Seal nodes for thread-safe sharing
- **Multi-Document Support** - Parse and generate YAML streams with multiple documents

## Quick Example

```c
#include <yaml-glib.h>

int main(void)
{
    YamlParser *parser;
    YamlNode *root;
    YamlMapping *mapping;
    GError *error = NULL;

    /* Parse YAML from a string */
    parser = yaml_parser_new();
    if (!yaml_parser_load_from_data(parser, "name: John\nage: 30\n", -1, &error))
    {
        g_printerr("Parse error: %s\n", error->message);
        g_error_free(error);
        return 1;
    }

    /* Access the data */
    root = yaml_parser_get_root(parser);
    mapping = yaml_node_get_mapping(root);

    g_print("Name: %s\n", yaml_mapping_get_string_member(mapping, "name"));
    g_print("Age: %ld\n", yaml_mapping_get_int_member(mapping, "age"));

    g_object_unref(parser);
    return 0;
}
```

## Documentation Structure

### Getting Started

- [Getting Started](getting-started.md) - Installation, first program, basic concepts
- [Building](building.md) - Build instructions and dependencies
- [Memory Management](memory-management.md) - Reference counting and ownership patterns
- [Error Handling](error-handling.md) - Error domains and GError usage

### API Reference

Core types and containers:

- [Types](api/types.md) - Enumerations, error codes, and type definitions
- [YamlNode](api/node.md) - Generic container for YAML data
- [YamlMapping](api/mapping.md) - Key-value pair container (like JSON object)
- [YamlSequence](api/sequence.md) - Ordered array container (like JSON array)
- [YamlDocument](api/document.md) - Top-level document with directives

Parsing and generation:

- [YamlParser](api/parser.md) - Parse YAML from files, strings, or streams
- [YamlBuilder](api/builder.md) - Fluent API for building YAML structures
- [YamlGenerator](api/generator.md) - Generate YAML output

Advanced features:

- [YamlSerializable](api/serializable.md) - Interface for custom GObject serialization
- [GObject Utilities](api/gobject.md) - GObject and boxed type serialization
- [YamlSchema](api/schema.md) - Schema validation

### Guides

- [Parsing YAML](guides/parsing.md) - Complete guide to parsing YAML data
- [Building YAML](guides/building-yaml.md) - Programmatically constructing YAML
- [JSON Interoperability](guides/json-interop.md) - Converting between YAML and JSON-GLib
- [GObject Serialization](guides/gobject-serialization.md) - Serializing GObjects to YAML
- [Schema Validation](guides/schema-validation.md) - Validating YAML with schemas
- [Async I/O](guides/async-io.md) - Asynchronous parsing and generation

## Type Overview

| Type | Kind | Description |
|------|------|-------------|
| `YamlNode` | Boxed (ref-counted) | Generic container for any YAML value |
| `YamlMapping` | Boxed (ref-counted) | Key-value pairs with string keys |
| `YamlSequence` | Boxed (ref-counted) | Ordered array of nodes |
| `YamlDocument` | GObject | Document with root node and directives |
| `YamlParser` | GObject | Parses YAML from various sources |
| `YamlBuilder` | GObject | Fluent API for constructing YAML |
| `YamlGenerator` | GObject | Generates YAML output |
| `YamlSchema` | GObject | Schema for validation |
| `YamlSerializable` | GInterface | Custom serialization interface |

## License

yaml-glib is licensed under the AGPL-3.0-or-later license.

## See Also

- [libyaml](https://pyyaml.org/wiki/LibYAML) - The underlying YAML parser/emitter
- [JSON-GLib](https://gnome.pages.gitlab.gnome.org/json-glib/) - Similar library for JSON
- [GLib Reference](https://docs.gtk.org/glib/) - GLib documentation
- [GObject Reference](https://docs.gtk.org/gobject/) - GObject documentation
