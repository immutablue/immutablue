# yaml-glib Project Guide

## Project Layout

```
yaml-glib/
├── src/                    # Library source files
│   ├── yaml-glib.h         # Main umbrella header
│   ├── yaml-types.h        # Enumerations and error codes
│   ├── yaml-node.{h,c}     # YamlNode boxed type
│   ├── yaml-mapping.{h,c}  # YamlMapping boxed type
│   ├── yaml-sequence.{h,c} # YamlSequence boxed type
│   ├── yaml-document.{h,c} # YamlDocument GObject
│   ├── yaml-parser.{h,c}   # YamlParser GObject
│   ├── yaml-builder.{h,c}  # YamlBuilder GObject
│   ├── yaml-generator.{h,c}# YamlGenerator GObject
│   ├── yaml-schema.{h,c}   # YamlSchema GObject
│   ├── yaml-serializable.{h,c}  # YamlSerializable interface
│   ├── yaml-gobject.{h,c}  # GObject serialization utilities
│   └── yaml-private.h      # Internal structures (not installed)
├── tests/                  # Test files (test_*.c)
├── build/                  # Build output (created by make)
├── docs/                   # Documentation (markdown)
├── Makefile                # GNU Make build file
├── README.md               # Project overview
└── CLAUDE.md               # This file
```

## Architecture

### Type System

**Boxed Types** (reference-counted, use `_ref`/`_unref`):
- `YamlNode` - Generic container for any YAML value
- `YamlMapping` - Key-value pairs (like dict/object)
- `YamlSequence` - Ordered array of nodes

**GObject Types** (use `g_object_ref`/`g_object_unref`):
- `YamlParser` - Parses YAML from files/strings/streams
- `YamlBuilder` - Fluent API for building YAML structures
- `YamlGenerator` - Generates YAML output
- `YamlDocument` - Wraps root node with YAML directives
- `YamlSchema` - Schema validation

**Interface**:
- `YamlSerializable` - Custom GObject serialization

### Dependencies

- libyaml (yaml-0.1) - Low-level YAML parsing/emitting
- GLib/GObject/GIO - Object system, data structures, I/O
- JSON-GLib - JSON interoperability

## Code Style

### C Standard

Use `gnu89` (GNU C89 extensions).

### Formatting

- **Indentation**: 4 spaces (not tabs in source)
- **Line width**: ~80 characters preferred
- **Braces**: Opening brace on same line
- **Comments**: `/* */` only, never `//`

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Functions | `lowercase_snake_case` | `yaml_node_get_string` |
| Variables | `lowercase_snake_case` | `node_type` |
| Types | `PascalCase` | `YamlNode`, `YamlMapping` |
| Macros/Defines | `UPPERCASE_SNAKE_CASE` | `YAML_NODE_TYPE` |
| Enum values | `UPPERCASE_SNAKE_CASE` | `YAML_NODE_SCALAR` |

### Function Signature Style

Return type on separate line, parameters aligned:

```c
YamlNode *
yaml_node_new_string(const gchar *value)
{
    YamlNode *node;

    g_return_val_if_fail(value != NULL, NULL);

    node = yaml_node_alloc();
    /* ... */

    return node;
}
```

For multiple parameters:

```c
gboolean
yaml_parser_load_from_file(
    YamlParser   *parser,
    const gchar  *filename,
    GError      **error
)
{
    /* ... */
}
```

## GLib Patterns (REQUIRED)

### Automatic Cleanup

Always use `g_autoptr` and `g_autofree` for automatic cleanup:

```c
g_autoptr(YamlParser) parser = yaml_parser_new();
g_autoptr(GError) error = NULL;
g_autofree gchar *str = g_strdup("value");
```

### Ownership Transfer

Use `g_steal_pointer` when transferring ownership:

```c
YamlNode *
create_node(void)
{
    g_autoptr(YamlNode) node = yaml_node_new_string("value");
    /* ... setup ... */
    return g_steal_pointer(&node);
}
```

### Safe Cleanup

Use `g_clear_pointer` for safe cleanup in dispose/finalize:

```c
g_clear_pointer(&self->name, g_free);
g_clear_pointer(&self->node, yaml_node_unref);
```

### Precondition Checks

Use at function start:

```c
g_return_if_fail(parser != NULL);
g_return_val_if_fail(filename != NULL, FALSE);
```

### Error Handling

Always use GError pattern:

```c
gboolean
do_something(const gchar *input, GError **error)
{
    if (input == NULL)
    {
        g_set_error(error, YAML_GLIB_PARSER_ERROR,
                    YAML_GLIB_PARSER_ERROR_INVALID_DATA,
                    "Input cannot be NULL");
        return FALSE;
    }
    /* ... */
    return TRUE;
}
```

## Memory Ownership Conventions

| Prefix | Meaning | Caller Action |
|--------|---------|---------------|
| `get_*` | Borrowed reference | Do NOT free |
| `dup_*` | New reference | Must unref/free |
| `steal_*` | Takes ownership | Must unref/free |
| `set_*` | Takes/refs input | Input now owned by object |
| `take_*` | Steals from caller | Object owns, caller loses |

### Examples

```c
/* get_* - borrowed, don't free */
const gchar *name = yaml_mapping_get_string_member(mapping, "name");

/* dup_* - new reference, must unref */
YamlNode *copy = yaml_node_dup(node);
yaml_node_unref(copy);

/* steal_* - transfers ownership */
YamlNode *root = yaml_builder_steal_root(builder);
/* caller now owns root */

/* set_* - object takes/refs the value */
yaml_document_set_root(doc, node);
/* doc now holds a reference to node */
```

## Build Commands

```bash
make              # Build shared and static libraries
make tests        # Build test executables
make check        # Build and run all tests
make install      # Install to /usr/local
make clean        # Remove build artifacts
```

## Testing

Tests use GLib test framework:

```c
static void
test_node_string(void)
{
    g_autoptr(YamlNode) node = yaml_node_new_string("hello");

    g_assert_nonnull(node);
    g_assert_cmpint(yaml_node_get_node_type(node), ==, YAML_NODE_SCALAR);
    g_assert_cmpstr(yaml_node_get_string(node), ==, "hello");
}

int
main(int argc, char *argv[])
{
    g_test_init(&argc, &argv, NULL);
    g_test_add_func("/node/string", test_node_string);
    return g_test_run();
}
```

Run tests: `make check`

## Key Files to Understand

1. `src/yaml-private.h` - Internal structures for YamlNode, YamlMapping, YamlSequence
2. `src/yaml-types.h` - All enumerations and error codes
3. `src/yaml-node.h` - Core node API (50+ functions)
4. `src/yaml-parser.h` - Parsing API with signals
5. `src/yaml-builder.h` - Fluent builder API

## Error Domains

- `YAML_GLIB_PARSER_ERROR` - Parsing errors
- `YAML_GENERATOR_ERROR` - Generation errors
- `YAML_SCHEMA_ERROR` - Validation errors
