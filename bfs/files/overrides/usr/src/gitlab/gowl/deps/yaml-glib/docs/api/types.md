# Types Reference

This page documents the type definitions, enumerations, and error codes used throughout yaml-glib.

## Type Definitions

yaml-glib uses several boxed and GObject types:

| Type | Header | Description |
|------|--------|-------------|
| `YamlNode` | yaml-node.h | Generic container for YAML data |
| `YamlMapping` | yaml-mapping.h | Key-value pairs (like JSON object) |
| `YamlSequence` | yaml-sequence.h | Ordered array (like JSON array) |
| `YamlDocument` | yaml-document.h | Document with root node and directives |
| `YamlParser` | yaml-parser.h | YAML parser |
| `YamlBuilder` | yaml-builder.h | Fluent API for building YAML |
| `YamlGenerator` | yaml-generator.h | YAML output generator |
| `YamlSchema` | yaml-schema.h | Schema validation |

## Enumerations

### YamlNodeType

Indicates the type of content stored in a `YamlNode`.

```c
typedef enum {
    YAML_NODE_MAPPING,
    YAML_NODE_SEQUENCE,
    YAML_NODE_SCALAR,
    YAML_NODE_NULL
} YamlNodeType;
```

| Value | Description |
|-------|-------------|
| `YAML_NODE_MAPPING` | The node contains a YAML mapping (key-value pairs) |
| `YAML_NODE_SEQUENCE` | The node contains a YAML sequence (ordered array) |
| `YAML_NODE_SCALAR` | The node contains a scalar value (string, int, etc.) |
| `YAML_NODE_NULL` | The node contains a null value |

**Example:**
```c
YamlNode *node = yaml_parser_get_root(parser);
switch (yaml_node_get_node_type(node))
{
case YAML_NODE_MAPPING:
    g_print("Root is a mapping\n");
    break;
case YAML_NODE_SEQUENCE:
    g_print("Root is a sequence\n");
    break;
case YAML_NODE_SCALAR:
    g_print("Root is a scalar: %s\n", yaml_node_get_string(node));
    break;
case YAML_NODE_NULL:
    g_print("Root is null\n");
    break;
}
```

---

### YamlScalarStyle

Style hint for scalar serialization in YAML output. The generator may override this hint if the content requires a different style (e.g., special characters requiring quoting).

```c
typedef enum {
    YAML_SCALAR_STYLE_ANY,
    YAML_SCALAR_STYLE_PLAIN,
    YAML_SCALAR_STYLE_SINGLE_QUOTED,
    YAML_SCALAR_STYLE_DOUBLE_QUOTED,
    YAML_SCALAR_STYLE_LITERAL,
    YAML_SCALAR_STYLE_FOLDED
} YamlScalarStyle;
```

| Value | Description | YAML Output |
|-------|-------------|-------------|
| `YAML_SCALAR_STYLE_ANY` | Let the emitter choose the best style | (varies) |
| `YAML_SCALAR_STYLE_PLAIN` | Plain unquoted scalar | `value` |
| `YAML_SCALAR_STYLE_SINGLE_QUOTED` | Single-quoted scalar | `'value'` |
| `YAML_SCALAR_STYLE_DOUBLE_QUOTED` | Double-quoted scalar | `"value"` |
| `YAML_SCALAR_STYLE_LITERAL` | Literal block scalar (preserves newlines) | `\|` |
| `YAML_SCALAR_STYLE_FOLDED` | Folded block scalar (joins lines) | `>` |

**Example:**
```c
/* Create a literal block scalar for multi-line content */
YamlNode *node = yaml_node_new_scalar(
    "Line 1\nLine 2\nLine 3",
    YAML_SCALAR_STYLE_LITERAL
);

/* Output:
 * |
 *   Line 1
 *   Line 2
 *   Line 3
 */
```

**Literal vs Folded:**
```yaml
# Literal block (|) - preserves newlines
description: |
  Line 1
  Line 2

# Folded block (>) - joins lines with spaces
description: >
  This is a long
  sentence that wraps.
```

---

### YamlMappingStyle

Style hint for mapping serialization in YAML output.

```c
typedef enum {
    YAML_MAPPING_STYLE_ANY,
    YAML_MAPPING_STYLE_BLOCK,
    YAML_MAPPING_STYLE_FLOW
} YamlMappingStyle;
```

| Value | Description | YAML Output |
|-------|-------------|-------------|
| `YAML_MAPPING_STYLE_ANY` | Let the emitter choose | (varies) |
| `YAML_MAPPING_STYLE_BLOCK` | Block style (one key per line) | See below |
| `YAML_MAPPING_STYLE_FLOW` | Flow style (JSON-like) | `{key: value}` |

**Block style:**
```yaml
key1: value1
key2: value2
```

**Flow style:**
```yaml
{key1: value1, key2: value2}
```

---

### YamlSequenceStyle

Style hint for sequence serialization in YAML output.

```c
typedef enum {
    YAML_SEQUENCE_STYLE_ANY,
    YAML_SEQUENCE_STYLE_BLOCK,
    YAML_SEQUENCE_STYLE_FLOW
} YamlSequenceStyle;
```

| Value | Description | YAML Output |
|-------|-------------|-------------|
| `YAML_SEQUENCE_STYLE_ANY` | Let the emitter choose | (varies) |
| `YAML_SEQUENCE_STYLE_BLOCK` | Block style (one item per line) | See below |
| `YAML_SEQUENCE_STYLE_FLOW` | Flow style (JSON-like) | `[item1, item2]` |

**Block style:**
```yaml
- item1
- item2
- item3
```

**Flow style:**
```yaml
[item1, item2, item3]
```

---

## Error Codes

yaml-glib defines three error domains with associated error codes.

### YAML_GLIB_PARSER_ERROR

Error domain for `YamlParser` operations.

```c
#define YAML_GLIB_PARSER_ERROR (yaml_glib_parser_error_quark())
GQuark yaml_glib_parser_error_quark(void);
```

```c
typedef enum {
    YAML_GLIB_PARSER_ERROR_INVALID_DATA,
    YAML_GLIB_PARSER_ERROR_PARSE,
    YAML_GLIB_PARSER_ERROR_SCANNER,
    YAML_GLIB_PARSER_ERROR_EMPTY_DOCUMENT,
    YAML_GLIB_PARSER_ERROR_UNKNOWN
} YamlGlibParserError;
```

| Code | Constant | Description |
|------|----------|-------------|
| 0 | `YAML_GLIB_PARSER_ERROR_INVALID_DATA` | The input data is not valid YAML |
| 1 | `YAML_GLIB_PARSER_ERROR_PARSE` | A parsing error occurred |
| 2 | `YAML_GLIB_PARSER_ERROR_SCANNER` | A lexical scanning error occurred |
| 3 | `YAML_GLIB_PARSER_ERROR_EMPTY_DOCUMENT` | The document is empty |
| 4 | `YAML_GLIB_PARSER_ERROR_UNKNOWN` | An unknown error occurred |

**Example:**
```c
g_autoptr(GError) error = NULL;
if (!yaml_parser_load_from_data(parser, data, -1, &error))
{
    if (g_error_matches(error, YAML_GLIB_PARSER_ERROR,
                        YAML_GLIB_PARSER_ERROR_INVALID_DATA))
    {
        g_printerr("Invalid YAML syntax\n");
    }
    else if (g_error_matches(error, YAML_GLIB_PARSER_ERROR,
                             YAML_GLIB_PARSER_ERROR_EMPTY_DOCUMENT))
    {
        g_printerr("Document is empty\n");
    }
}
```

---

### YAML_GENERATOR_ERROR

Error domain for `YamlGenerator` operations.

```c
#define YAML_GENERATOR_ERROR (yaml_generator_error_quark())
GQuark yaml_generator_error_quark(void);
```

```c
typedef enum {
    YAML_GENERATOR_ERROR_EMIT,
    YAML_GENERATOR_ERROR_INVALID_NODE,
    YAML_GENERATOR_ERROR_IO
} YamlGeneratorError;
```

| Code | Constant | Description |
|------|----------|-------------|
| 0 | `YAML_GENERATOR_ERROR_EMIT` | A YAML emitter error occurred |
| 1 | `YAML_GENERATOR_ERROR_INVALID_NODE` | The node structure is invalid |
| 2 | `YAML_GENERATOR_ERROR_IO` | An I/O error occurred during output |

**Example:**
```c
g_autoptr(GError) error = NULL;
gchar *output = yaml_generator_to_data(generator, NULL, &error);
if (output == NULL)
{
    if (g_error_matches(error, YAML_GENERATOR_ERROR,
                        YAML_GENERATOR_ERROR_INVALID_NODE))
    {
        g_printerr("Node structure is invalid\n");
    }
}
```

---

### YAML_SCHEMA_ERROR

Error domain for `YamlSchema` validation.

```c
#define YAML_SCHEMA_ERROR (yaml_schema_error_quark())
GQuark yaml_schema_error_quark(void);
```

```c
typedef enum {
    YAML_SCHEMA_ERROR_TYPE_MISMATCH,
    YAML_SCHEMA_ERROR_MISSING_REQUIRED,
    YAML_SCHEMA_ERROR_EXTRA_FIELD,
    YAML_SCHEMA_ERROR_PATTERN_MISMATCH,
    YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION,
    YAML_SCHEMA_ERROR_ENUM_VIOLATION,
    YAML_SCHEMA_ERROR_INVALID_SCHEMA
} YamlSchemaError;
```

| Code | Constant | Description |
|------|----------|-------------|
| 0 | `YAML_SCHEMA_ERROR_TYPE_MISMATCH` | Node type doesn't match schema expectation |
| 1 | `YAML_SCHEMA_ERROR_MISSING_REQUIRED` | A required property is missing |
| 2 | `YAML_SCHEMA_ERROR_EXTRA_FIELD` | An unexpected property was found |
| 3 | `YAML_SCHEMA_ERROR_PATTERN_MISMATCH` | String doesn't match required pattern |
| 4 | `YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION` | Min/max constraint was violated |
| 5 | `YAML_SCHEMA_ERROR_ENUM_VIOLATION` | Value not in allowed enum values |
| 6 | `YAML_SCHEMA_ERROR_INVALID_SCHEMA` | The schema definition itself is invalid |

**Example:**
```c
g_autoptr(YamlSchema) schema = yaml_schema_new_for_mapping();
yaml_schema_add_property(schema, "name", YAML_NODE_SCALAR, TRUE);
yaml_schema_add_property(schema, "age", YAML_NODE_SCALAR, TRUE);

g_autoptr(GError) error = NULL;
if (!yaml_schema_validate(schema, root, &error))
{
    switch (error->code)
    {
    case YAML_SCHEMA_ERROR_TYPE_MISMATCH:
        g_printerr("Wrong type: %s\n", error->message);
        break;
    case YAML_SCHEMA_ERROR_MISSING_REQUIRED:
        g_printerr("Missing field: %s\n", error->message);
        break;
    case YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION:
        g_printerr("Constraint violation: %s\n", error->message);
        break;
    default:
        g_printerr("Validation error: %s\n", error->message);
        break;
    }
}
```

---

## GType Registration

All yaml-glib types are registered with the GType system:

```c
/* Get GType for each type */
GType yaml_node_get_type(void);
GType yaml_mapping_get_type(void);
GType yaml_sequence_get_type(void);
GType yaml_document_get_type(void);
GType yaml_parser_get_type(void);
GType yaml_builder_get_type(void);
GType yaml_generator_get_type(void);
GType yaml_schema_get_type(void);
```

**Type macros:**
```c
#define YAML_TYPE_NODE      (yaml_node_get_type())
#define YAML_TYPE_MAPPING   (yaml_mapping_get_type())
#define YAML_TYPE_SEQUENCE  (yaml_sequence_get_type())
#define YAML_TYPE_DOCUMENT  (yaml_document_get_type())
#define YAML_TYPE_PARSER    (yaml_parser_get_type())
#define YAML_TYPE_BUILDER   (yaml_builder_get_type())
#define YAML_TYPE_GENERATOR (yaml_generator_get_type())
#define YAML_TYPE_SCHEMA    (yaml_schema_get_type())
```

---

## Autoptr Support

All types support `g_autoptr()` for automatic cleanup:

```c
void example(void)
{
    g_autoptr(YamlParser) parser = yaml_parser_new();
    g_autoptr(YamlBuilder) builder = yaml_builder_new();
    g_autoptr(YamlGenerator) generator = yaml_generator_new();
    g_autoptr(YamlDocument) document = yaml_document_new();
    g_autoptr(YamlSchema) schema = yaml_schema_new_for_mapping();
    g_autoptr(YamlNode) node = yaml_node_new_string("hello");
    g_autoptr(YamlMapping) mapping = yaml_mapping_new();
    g_autoptr(YamlSequence) sequence = yaml_sequence_new();

    /* All automatically freed when leaving scope */
}
```

## See Also

- [YamlNode](node.md) - Generic container for YAML data
- [YamlMapping](mapping.md) - Key-value pairs
- [YamlSequence](sequence.md) - Ordered arrays
- [Error Handling](../error-handling.md) - GError usage
