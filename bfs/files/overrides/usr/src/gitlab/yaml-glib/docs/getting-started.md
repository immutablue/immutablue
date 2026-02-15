# Getting Started with yaml-glib

This guide walks you through installing yaml-glib, understanding the basic concepts, and writing your first program.

## Prerequisites

Before using yaml-glib, ensure you have the following installed:

- GCC compiler
- GLib 2.0 development files
- GObject 2.0 development files
- GIO 2.0 development files
- libyaml development files
- JSON-GLib 1.0 development files

On Fedora:
```bash
sudo dnf install gcc glib2-devel libyaml-devel json-glib-devel
```

On Debian/Ubuntu:
```bash
sudo apt install gcc libglib2.0-dev libyaml-dev libjson-glib-dev
```

## Installation

### Building from Source

```bash
git clone https://gitlab.com/your-repo/yaml-glib.git
cd yaml-glib
make
sudo make install
```

This installs:
- Headers to `/usr/local/include/yaml-glib/`
- Shared library (`libyaml-glib.so.1.0.0`) to `/usr/local/lib/`
- Static library (`libyaml-glib.a`) to `/usr/local/lib/`

### Verifying Installation

```bash
pkg-config --cflags --libs glib-2.0 gobject-2.0 gio-2.0 yaml-0.1 json-glib-1.0
```

## Core Concepts

### Types Overview

yaml-glib provides several key types:

| Type | Kind | Purpose |
|------|------|---------|
| `YamlNode` | Boxed (ref-counted) | Generic container for any YAML value |
| `YamlMapping` | Boxed (ref-counted) | Key-value pairs (like JSON object or Python dict) |
| `YamlSequence` | Boxed (ref-counted) | Ordered array (like JSON array or Python list) |
| `YamlDocument` | GObject | Document with root node and directives |
| `YamlParser` | GObject | Parses YAML from various sources |
| `YamlBuilder` | GObject | Fluent API for constructing YAML |
| `YamlGenerator` | GObject | Generates YAML output |

### Node Types

Every YAML value is wrapped in a `YamlNode`. The node type is determined by `YamlNodeType`:

- `YAML_NODE_MAPPING` - Contains a `YamlMapping`
- `YAML_NODE_SEQUENCE` - Contains a `YamlSequence`
- `YAML_NODE_SCALAR` - Contains a scalar value (string, int, double, boolean)
- `YAML_NODE_NULL` - Represents null/nil

### Memory Management

yaml-glib uses reference counting for memory management:

- **GObjects** (YamlParser, YamlBuilder, YamlGenerator, YamlDocument): Use `g_object_unref()` to release
- **Boxed types** (YamlNode, YamlMapping, YamlSequence): Use type-specific `*_unref()` functions

**Ownership conventions:**
- `get_*` functions return borrowed references (don't free)
- `dup_*` functions return new references (you must free)
- `steal_*` functions transfer ownership (you own the result)
- `set_*` functions take a reference (caller keeps their reference)
- `take_*` functions steal the reference (caller loses their reference)

### Automatic Cleanup

Use `g_autoptr()` for automatic cleanup:

```c
g_autoptr(YamlParser) parser = yaml_parser_new();
g_autoptr(YamlNode) node = yaml_node_new_mapping(NULL);
g_autoptr(YamlMapping) mapping = yaml_mapping_new();
```

## Complete Example Program

Here's a complete program that demonstrates parsing, modifying, and generating YAML.

### example.c

```c
/* example.c
 *
 * Complete yaml-glib example demonstrating:
 * - Parsing YAML from a file
 * - Reading values from the parsed data
 * - Modifying the data structure
 * - Building new YAML programmatically
 * - Generating YAML output
 */

#include <stdio.h>
#include <stdlib.h>
#include <yaml-glib/yaml-glib.h>

/*
 * print_person:
 * @mapping: a YamlMapping containing person data
 *
 * Prints the details of a person from a mapping.
 */
static void
print_person(YamlMapping *mapping)
{
    const gchar *name;
    gint64 age;
    const gchar *city;
    YamlMapping *address;

    name = yaml_mapping_get_string_member(mapping, "name");
    age = yaml_mapping_get_int_member(mapping, "age");

    g_print("Name: %s\n", name ? name : "(unknown)");
    g_print("Age: %ld\n", (long)age);

    /* Access nested mapping */
    address = yaml_mapping_get_mapping_member(mapping, "address");
    if (address != NULL)
    {
        city = yaml_mapping_get_string_member(address, "city");
        g_print("City: %s\n", city ? city : "(unknown)");
    }
}

/*
 * print_hobbies:
 * @sequence: a YamlSequence containing hobby strings
 *
 * Prints all hobbies from a sequence.
 */
static void
print_hobbies(YamlSequence *sequence)
{
    guint i;
    guint count;

    count = yaml_sequence_get_length(sequence);
    g_print("Hobbies (%u):\n", count);

    for (i = 0; i < count; i++)
    {
        YamlNode *item;
        const gchar *hobby;

        item = yaml_sequence_get_element(sequence, i);
        hobby = yaml_node_get_string(item);
        g_print("  - %s\n", hobby ? hobby : "(null)");
    }
}

/*
 * demo_parsing:
 *
 * Demonstrates parsing YAML from a file and reading values.
 */
static gboolean
demo_parsing(void)
{
    g_autoptr(YamlParser) parser = NULL;
    g_autoptr(GError) error = NULL;
    YamlNode *root;
    YamlMapping *root_mapping;
    YamlSequence *hobbies;

    g_print("=== Parsing Demo ===\n\n");

    /* Create parser and load file */
    parser = yaml_parser_new();
    if (!yaml_parser_load_from_file(parser, "sample.yaml", &error))
    {
        g_printerr("Failed to parse file: %s\n", error->message);
        return FALSE;
    }

    /* Get root node */
    root = yaml_parser_get_root(parser);
    if (root == NULL)
    {
        g_printerr("No root node found\n");
        return FALSE;
    }

    /* Verify it's a mapping */
    if (yaml_node_get_node_type(root) != YAML_NODE_MAPPING)
    {
        g_printerr("Root is not a mapping\n");
        return FALSE;
    }

    /* Access the mapping */
    root_mapping = yaml_node_get_mapping(root);
    print_person(root_mapping);

    /* Access hobbies sequence */
    hobbies = yaml_mapping_get_sequence_member(root_mapping, "hobbies");
    if (hobbies != NULL)
    {
        g_print("\n");
        print_hobbies(hobbies);
    }

    return TRUE;
}

/*
 * demo_modification:
 *
 * Demonstrates modifying parsed YAML data.
 */
static gboolean
demo_modification(void)
{
    g_autoptr(YamlParser) parser = NULL;
    g_autoptr(YamlGenerator) generator = NULL;
    g_autoptr(GError) error = NULL;
    g_autofree gchar *output = NULL;
    YamlNode *root;
    YamlMapping *root_mapping;
    YamlSequence *hobbies;

    g_print("\n=== Modification Demo ===\n\n");

    /* Parse the file */
    parser = yaml_parser_new();
    if (!yaml_parser_load_from_file(parser, "sample.yaml", &error))
    {
        g_printerr("Failed to parse file: %s\n", error->message);
        return FALSE;
    }

    root = yaml_parser_get_root(parser);
    root_mapping = yaml_node_get_mapping(root);

    /* Modify a value */
    yaml_mapping_set_int_member(root_mapping, "age", 35);
    g_print("Updated age to 35\n");

    /* Add a new member */
    yaml_mapping_set_string_member(root_mapping, "email", "john@example.com");
    g_print("Added email field\n");

    /* Add to the hobbies sequence */
    hobbies = yaml_mapping_get_sequence_member(root_mapping, "hobbies");
    if (hobbies != NULL)
    {
        g_autoptr(YamlNode) new_hobby = yaml_node_new_string("cooking");
        yaml_sequence_add_element(hobbies, new_hobby);
        g_print("Added 'cooking' to hobbies\n");
    }

    /* Generate output */
    generator = yaml_generator_new();
    yaml_generator_set_root(generator, root);
    yaml_generator_set_indent(generator, 2);

    output = yaml_generator_to_data(generator, NULL, &error);
    if (output == NULL)
    {
        g_printerr("Failed to generate YAML: %s\n", error->message);
        return FALSE;
    }

    g_print("\nModified YAML:\n%s", output);

    return TRUE;
}

/*
 * demo_building:
 *
 * Demonstrates building YAML programmatically using YamlBuilder.
 */
static gboolean
demo_building(void)
{
    g_autoptr(YamlBuilder) builder = NULL;
    g_autoptr(YamlGenerator) generator = NULL;
    g_autoptr(GError) error = NULL;
    g_autofree gchar *output = NULL;
    YamlNode *root;

    g_print("\n=== Building Demo ===\n\n");

    /* Create builder */
    builder = yaml_builder_new();

    /* Build structure using fluent API */
    yaml_builder_begin_mapping(builder);
    {
        /* Simple values */
        yaml_builder_set_member_name(builder, "title");
        yaml_builder_add_string_value(builder, "Server Configuration");

        yaml_builder_set_member_name(builder, "version");
        yaml_builder_add_double_value(builder, 1.5);

        yaml_builder_set_member_name(builder, "enabled");
        yaml_builder_add_boolean_value(builder, TRUE);

        /* Nested mapping */
        yaml_builder_set_member_name(builder, "database");
        yaml_builder_begin_mapping(builder);
        {
            yaml_builder_set_member_name(builder, "host");
            yaml_builder_add_string_value(builder, "localhost");

            yaml_builder_set_member_name(builder, "port");
            yaml_builder_add_int_value(builder, 5432);

            yaml_builder_set_member_name(builder, "name");
            yaml_builder_add_string_value(builder, "myapp_db");
        }
        yaml_builder_end_mapping(builder);

        /* Sequence */
        yaml_builder_set_member_name(builder, "allowed_hosts");
        yaml_builder_begin_sequence(builder);
        {
            yaml_builder_add_string_value(builder, "localhost");
            yaml_builder_add_string_value(builder, "127.0.0.1");
            yaml_builder_add_string_value(builder, "*.example.com");
        }
        yaml_builder_end_sequence(builder);

        /* Null value */
        yaml_builder_set_member_name(builder, "cache_server");
        yaml_builder_add_null_value(builder);
    }
    yaml_builder_end_mapping(builder);

    /* Get the built structure */
    root = yaml_builder_get_root(builder);
    if (root == NULL)
    {
        g_printerr("Builder produced no root node\n");
        return FALSE;
    }

    /* Generate output */
    generator = yaml_generator_new();
    yaml_generator_set_root(generator, root);
    yaml_generator_set_indent(generator, 2);

    output = yaml_generator_to_data(generator, NULL, &error);
    if (output == NULL)
    {
        g_printerr("Failed to generate YAML: %s\n", error->message);
        return FALSE;
    }

    g_print("Built YAML:\n%s", output);

    return TRUE;
}

/*
 * demo_direct_construction:
 *
 * Demonstrates building YAML by directly creating nodes.
 */
static gboolean
demo_direct_construction(void)
{
    g_autoptr(YamlMapping) mapping = NULL;
    g_autoptr(YamlSequence) tags = NULL;
    g_autoptr(YamlNode) root = NULL;
    g_autoptr(YamlNode) tag1 = NULL;
    g_autoptr(YamlNode) tag2 = NULL;
    g_autoptr(YamlGenerator) generator = NULL;
    g_autoptr(GError) error = NULL;
    g_autofree gchar *output = NULL;

    g_print("\n=== Direct Construction Demo ===\n\n");

    /* Create mapping directly */
    mapping = yaml_mapping_new();
    yaml_mapping_set_string_member(mapping, "id", "item-001");
    yaml_mapping_set_string_member(mapping, "name", "Widget");
    yaml_mapping_set_double_member(mapping, "price", 19.99);
    yaml_mapping_set_int_member(mapping, "quantity", 100);
    yaml_mapping_set_boolean_member(mapping, "in_stock", TRUE);

    /* Create sequence for tags */
    tags = yaml_sequence_new();
    tag1 = yaml_node_new_string("electronics");
    tag2 = yaml_node_new_string("sale");
    yaml_sequence_add_element(tags, tag1);
    yaml_sequence_add_element(tags, tag2);

    /* Add sequence to mapping */
    yaml_mapping_set_sequence_member(mapping, "tags", tags);

    /* Wrap in a node for the generator */
    root = yaml_node_new_mapping(mapping);

    /* Generate output */
    generator = yaml_generator_new();
    yaml_generator_set_root(generator, root);
    yaml_generator_set_indent(generator, 2);

    output = yaml_generator_to_data(generator, NULL, &error);
    if (output == NULL)
    {
        g_printerr("Failed to generate YAML: %s\n", error->message);
        return FALSE;
    }

    g_print("Directly constructed YAML:\n%s", output);

    return TRUE;
}

int
main(
    int   argc,
    char *argv[]
)
{
    gboolean success;

    (void)argc;
    (void)argv;

    success = TRUE;

    if (!demo_parsing())
    {
        success = FALSE;
    }

    if (!demo_modification())
    {
        success = FALSE;
    }

    if (!demo_building())
    {
        success = FALSE;
    }

    if (!demo_direct_construction())
    {
        success = FALSE;
    }

    return success ? EXIT_SUCCESS : EXIT_FAILURE;
}
```

### sample.yaml

Create this file in the same directory as your compiled program:

```yaml
name: John Doe
age: 30
active: true
address:
  street: 123 Main St
  city: Springfield
  zip: "12345"
hobbies:
  - reading
  - hiking
  - photography
notes: |
  This is a multi-line
  note about the person.
```

### Makefile

```makefile
# Makefile for yaml-glib example
#
# Usage:
#   make          - Build the example
#   make run      - Build and run the example
#   make clean    - Remove build artifacts

CC = gcc
CFLAGS = -std=gnu89 -Wall -Wextra -g \
	`pkg-config --cflags glib-2.0 gobject-2.0 gio-2.0 yaml-0.1 json-glib-1.0`

# Link against yaml-glib and its dependencies
LDFLAGS = -L/usr/local/lib -lyaml-glib \
	`pkg-config --libs glib-2.0 gobject-2.0 gio-2.0 yaml-0.1 json-glib-1.0`

# For development against uninstalled library
# CFLAGS += -I../src
# LDFLAGS = -L../build -lyaml-glib ...

TARGET = example

all: $(TARGET)

$(TARGET): example.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

run: $(TARGET)
	LD_LIBRARY_PATH=/usr/local/lib:$$LD_LIBRARY_PATH ./$(TARGET)

clean:
	rm -f $(TARGET)

.PHONY: all run clean
```

### Building and Running

```bash
# Build the example
make

# Create sample.yaml (shown above)
# Then run the example
make run
```

### Expected Output

```
=== Parsing Demo ===

Name: John Doe
Age: 30
City: Springfield

Hobbies (3):
  - reading
  - hiking
  - photography

=== Modification Demo ===

Updated age to 35
Added email field
Added 'cooking' to hobbies

Modified YAML:
name: John Doe
age: 35
active: true
address:
  street: 123 Main St
  city: Springfield
  zip: '12345'
hobbies:
  - reading
  - hiking
  - photography
  - cooking
email: john@example.com
notes: |
  This is a multi-line
  note about the person.

=== Building Demo ===

Built YAML:
title: Server Configuration
version: 1.5
enabled: true
database:
  host: localhost
  port: 5432
  name: myapp_db
allowed_hosts:
  - localhost
  - 127.0.0.1
  - '*.example.com'
cache_server: ~

=== Direct Construction Demo ===

Directly constructed YAML:
id: item-001
name: Widget
price: 19.99
quantity: 100
in_stock: true
tags:
  - electronics
  - sale
```

## Quick Reference

### Parsing YAML

```c
/* From string */
YamlParser *parser = yaml_parser_new();
yaml_parser_load_from_data(parser, "key: value\n", -1, &error);
YamlNode *root = yaml_parser_get_root(parser);

/* From file */
yaml_parser_load_from_file(parser, "config.yaml", &error);

/* From GFile (for GIO integration) */
GFile *file = g_file_new_for_path("config.yaml");
yaml_parser_load_from_gfile(parser, file, NULL, &error);
```

### Reading Values

```c
/* Get mapping from node */
YamlMapping *mapping = yaml_node_get_mapping(node);

/* Read scalar values */
const gchar *str = yaml_mapping_get_string_member(mapping, "name");
gint64 num = yaml_mapping_get_int_member(mapping, "count");
gdouble dbl = yaml_mapping_get_double_member(mapping, "price");
gboolean flag = yaml_mapping_get_boolean_member(mapping, "enabled");

/* Check for null */
if (yaml_mapping_get_null_member(mapping, "optional"))
    g_print("Value is null\n");

/* Get nested structures */
YamlMapping *nested = yaml_mapping_get_mapping_member(mapping, "config");
YamlSequence *list = yaml_mapping_get_sequence_member(mapping, "items");

/* Iterate sequences */
guint len = yaml_sequence_get_length(sequence);
for (guint i = 0; i < len; i++) {
    YamlNode *item = yaml_sequence_get_element(sequence, i);
    /* process item */
}
```

### Building YAML

```c
/* Using YamlBuilder (recommended for complex structures) */
YamlBuilder *builder = yaml_builder_new();
yaml_builder_begin_mapping(builder);
yaml_builder_set_member_name(builder, "key");
yaml_builder_add_string_value(builder, "value");
yaml_builder_end_mapping(builder);
YamlNode *root = yaml_builder_get_root(builder);

/* Using direct construction (simpler for basic structures) */
YamlMapping *mapping = yaml_mapping_new();
yaml_mapping_set_string_member(mapping, "key", "value");
YamlNode *root = yaml_node_new_mapping(mapping);
```

### Generating Output

```c
YamlGenerator *gen = yaml_generator_new();
yaml_generator_set_root(gen, root);
yaml_generator_set_indent(gen, 2);

/* To string */
gchar *yaml = yaml_generator_to_data(gen, NULL, &error);

/* To file */
yaml_generator_to_file(gen, "output.yaml", &error);
```

## Next Steps

- [Memory Management](memory-management.md) - Detailed guide on reference counting
- [Error Handling](error-handling.md) - Error domains and GError usage
- [Parsing Guide](guides/parsing.md) - Complete parsing documentation
- [API Reference](api/node.md) - Full API documentation
