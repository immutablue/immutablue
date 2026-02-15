# YamlNode API Reference

`YamlNode` is a generic container for YAML data. It can contain a mapping, sequence, scalar value, or null.

## Overview

```c
#include <yaml-glib/yaml-glib.h>

#define YAML_TYPE_NODE (yaml_node_get_type())
```

`YamlNode` is a reference-counted boxed type that wraps any YAML value. Use `yaml_node_ref()` and `yaml_node_unref()` to manage its lifetime.

Nodes can be made immutable (sealed) for thread-safety. Once sealed, a node and all its children cannot be modified.

## Type Definition

```c
typedef struct _YamlNode YamlNode;
```

## Construction Functions

### yaml_node_alloc

```c
YamlNode *yaml_node_alloc(void);
```

Allocates a new `YamlNode` without initializing it.

**Returns:** `(transfer full)` An uninitialized `YamlNode`.

**Notes:**
- You must call one of the `yaml_node_init_*` functions before using the node.
- For most use cases, prefer `yaml_node_new()` or the convenience constructors.

---

### yaml_node_new

```c
YamlNode *yaml_node_new(YamlNodeType type);
```

Creates a new `YamlNode` of the specified type.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| type | `YamlNodeType` | The type of node to create |

**Returns:** `(transfer full)` A new `YamlNode`.

**Example:**
```c
YamlNode *mapping_node = yaml_node_new(YAML_NODE_MAPPING);
YamlNode *sequence_node = yaml_node_new(YAML_NODE_SEQUENCE);
YamlNode *null_node = yaml_node_new(YAML_NODE_NULL);
```

---

### yaml_node_init

```c
YamlNode *yaml_node_init(YamlNode *node, YamlNodeType type);
```

Initializes a `YamlNode` with the given type.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | An uninitialized node |
| type | `YamlNodeType` | The type to initialize |

**Returns:** `(transfer none)` The initialized node.

---

### yaml_node_init_mapping

```c
YamlNode *yaml_node_init_mapping(YamlNode *node, YamlMapping *mapping);
```

Initializes a node as a mapping node.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | An uninitialized node |
| mapping | `YamlMapping *` `(nullable)` | A mapping, or `NULL` for empty |

**Returns:** `(transfer none)` The initialized node.

---

### yaml_node_init_sequence

```c
YamlNode *yaml_node_init_sequence(YamlNode *node, YamlSequence *sequence);
```

Initializes a node as a sequence node.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | An uninitialized node |
| sequence | `YamlSequence *` `(nullable)` | A sequence, or `NULL` for empty |

**Returns:** `(transfer none)` The initialized node.

---

### yaml_node_init_string

```c
YamlNode *yaml_node_init_string(YamlNode *node, const gchar *value);
```

Initializes a node as a string scalar.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | An uninitialized node |
| value | `const gchar *` | The string value |

**Returns:** `(transfer none)` The initialized node.

---

### yaml_node_init_int

```c
YamlNode *yaml_node_init_int(YamlNode *node, gint64 value);
```

Initializes a node as an integer scalar.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | An uninitialized node |
| value | `gint64` | The integer value |

**Returns:** `(transfer none)` The initialized node.

---

### yaml_node_init_double

```c
YamlNode *yaml_node_init_double(YamlNode *node, gdouble value);
```

Initializes a node as a double scalar.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | An uninitialized node |
| value | `gdouble` | The double value |

**Returns:** `(transfer none)` The initialized node.

---

### yaml_node_init_boolean

```c
YamlNode *yaml_node_init_boolean(YamlNode *node, gboolean value);
```

Initializes a node as a boolean scalar.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | An uninitialized node |
| value | `gboolean` | The boolean value |

**Returns:** `(transfer none)` The initialized node.

---

### yaml_node_init_null

```c
YamlNode *yaml_node_init_null(YamlNode *node);
```

Initializes a node as a null node.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | An uninitialized node |

**Returns:** `(transfer none)` The initialized node.

---

## Convenience Constructors

These functions combine allocation and initialization:

### yaml_node_new_mapping

```c
YamlNode *yaml_node_new_mapping(YamlMapping *mapping);
```

Creates a new mapping node.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` `(nullable)` | A mapping, or `NULL` for empty |

**Returns:** `(transfer full)` A new `YamlNode`.

**Example:**
```c
g_autoptr(YamlMapping) mapping = yaml_mapping_new();
yaml_mapping_set_string_member(mapping, "name", "John");
g_autoptr(YamlNode) node = yaml_node_new_mapping(mapping);
```

---

### yaml_node_new_sequence

```c
YamlNode *yaml_node_new_sequence(YamlSequence *sequence);
```

Creates a new sequence node.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` `(nullable)` | A sequence, or `NULL` for empty |

**Returns:** `(transfer full)` A new `YamlNode`.

---

### yaml_node_new_string

```c
YamlNode *yaml_node_new_string(const gchar *value);
```

Creates a new string scalar node.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| value | `const gchar *` | The string value |

**Returns:** `(transfer full)` A new `YamlNode`.

**Example:**
```c
g_autoptr(YamlNode) node = yaml_node_new_string("Hello, World!");
```

---

### yaml_node_new_int

```c
YamlNode *yaml_node_new_int(gint64 value);
```

Creates a new integer scalar node.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| value | `gint64` | The integer value |

**Returns:** `(transfer full)` A new `YamlNode`.

---

### yaml_node_new_double

```c
YamlNode *yaml_node_new_double(gdouble value);
```

Creates a new double scalar node.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| value | `gdouble` | The double value |

**Returns:** `(transfer full)` A new `YamlNode`.

---

### yaml_node_new_boolean

```c
YamlNode *yaml_node_new_boolean(gboolean value);
```

Creates a new boolean scalar node.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| value | `gboolean` | The boolean value |

**Returns:** `(transfer full)` A new `YamlNode`.

---

### yaml_node_new_null

```c
YamlNode *yaml_node_new_null(void);
```

Creates a new null node.

**Returns:** `(transfer full)` A new `YamlNode`.

---

### yaml_node_new_scalar

```c
YamlNode *yaml_node_new_scalar(const gchar *value, YamlScalarStyle style);
```

Creates a new scalar node with the specified style.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| value | `const gchar *` | The scalar string value |
| style | `YamlScalarStyle` | The preferred scalar style |

**Returns:** `(transfer full)` A new `YamlNode`.

**Example:**
```c
/* Create a literal block scalar */
g_autoptr(YamlNode) node = yaml_node_new_scalar(
    "Line 1\nLine 2\nLine 3",
    YAML_SCALAR_STYLE_LITERAL
);
```

---

## Reference Counting

### yaml_node_ref

```c
YamlNode *yaml_node_ref(YamlNode *node);
```

Increases the reference count by one.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |

**Returns:** `(transfer full)` The same node.

---

### yaml_node_unref

```c
void yaml_node_unref(YamlNode *node);
```

Decreases the reference count by one. When the reference count reaches zero, the node is freed.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |

---

### yaml_node_copy

```c
YamlNode *yaml_node_copy(YamlNode *node);
```

Creates a deep copy of the node.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |

**Returns:** `(transfer full)` A new `YamlNode` with copied content.

---

## Type Queries

### yaml_node_get_node_type

```c
YamlNodeType yaml_node_get_node_type(YamlNode *node);
```

Gets the type of content stored in the node.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |

**Returns:** The `YamlNodeType`.

**Example:**
```c
if (yaml_node_get_node_type(node) == YAML_NODE_MAPPING)
{
    YamlMapping *mapping = yaml_node_get_mapping(node);
    /* ... */
}
```

---

### yaml_node_is_null

```c
gboolean yaml_node_is_null(YamlNode *node);
```

Checks whether the node contains a null value.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |

**Returns:** `TRUE` if the node is null.

---

## Immutability

### yaml_node_seal

```c
void yaml_node_seal(YamlNode *node);
```

Makes the node and all its children immutable. After sealing, modification attempts are silently ignored.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |

**Example:**
```c
YamlNode *config = load_config();
yaml_node_seal(config);  /* Make immutable */

/* Safe to share between threads */
```

---

### yaml_node_is_immutable

```c
gboolean yaml_node_is_immutable(YamlNode *node);
```

Checks whether the node is immutable (sealed).

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |

**Returns:** `TRUE` if the node is immutable.

---

## Mapping Accessors

### yaml_node_set_mapping

```c
void yaml_node_set_mapping(YamlNode *node, YamlMapping *mapping);
```

Sets the mapping content. Takes a reference on the mapping.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |
| mapping | `YamlMapping *` | The mapping to set |

---

### yaml_node_take_mapping

```c
void yaml_node_take_mapping(YamlNode *node, YamlMapping *mapping);
```

Sets the mapping content, taking ownership of the mapping.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |
| mapping | `YamlMapping *` `(transfer full)` | The mapping to take |

---

### yaml_node_get_mapping

```c
YamlMapping *yaml_node_get_mapping(YamlNode *node);
```

Gets the mapping content.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |

**Returns:** `(transfer none) (nullable)` The mapping, or `NULL` if not a mapping node.

**Example:**
```c
YamlMapping *mapping = yaml_node_get_mapping(node);
if (mapping != NULL)
{
    const gchar *name = yaml_mapping_get_string_member(mapping, "name");
    g_print("Name: %s\n", name);
}
```

---

### yaml_node_dup_mapping

```c
YamlMapping *yaml_node_dup_mapping(YamlNode *node);
```

Gets a new reference to the mapping content.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |

**Returns:** `(transfer full) (nullable)` A new reference to the mapping, or `NULL`. Free with `yaml_mapping_unref()`.

---

## Sequence Accessors

### yaml_node_set_sequence

```c
void yaml_node_set_sequence(YamlNode *node, YamlSequence *sequence);
```

Sets the sequence content. Takes a reference on the sequence.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |
| sequence | `YamlSequence *` | The sequence to set |

---

### yaml_node_take_sequence

```c
void yaml_node_take_sequence(YamlNode *node, YamlSequence *sequence);
```

Sets the sequence content, taking ownership.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |
| sequence | `YamlSequence *` `(transfer full)` | The sequence to take |

---

### yaml_node_get_sequence

```c
YamlSequence *yaml_node_get_sequence(YamlNode *node);
```

Gets the sequence content.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |

**Returns:** `(transfer none) (nullable)` The sequence, or `NULL` if not a sequence node.

---

### yaml_node_dup_sequence

```c
YamlSequence *yaml_node_dup_sequence(YamlNode *node);
```

Gets a new reference to the sequence content.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |

**Returns:** `(transfer full) (nullable)` A new reference to the sequence, or `NULL`. Free with `yaml_sequence_unref()`.

---

## Scalar Accessors

### yaml_node_set_string

```c
void yaml_node_set_string(YamlNode *node, const gchar *value);
```

Sets the node to a string scalar.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |
| value | `const gchar *` | The string value |

---

### yaml_node_get_string

```c
const gchar *yaml_node_get_string(YamlNode *node);
```

Gets the string value of a scalar node.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |

**Returns:** `(transfer none) (nullable)` The string value, or `NULL`.

---

### yaml_node_get_scalar

```c
const gchar *yaml_node_get_scalar(YamlNode *node);
```

Gets the raw scalar value as a string. This is the underlying string representation regardless of type.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |

**Returns:** `(transfer none) (nullable)` The scalar string, or `NULL`.

---

### yaml_node_dup_string

```c
gchar *yaml_node_dup_string(YamlNode *node);
```

Gets a copy of the string value.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |

**Returns:** `(transfer full) (nullable)` A newly allocated string, or `NULL`. Free with `g_free()`.

---

### yaml_node_set_int

```c
void yaml_node_set_int(YamlNode *node, gint64 value);
```

Sets the node to an integer scalar.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |
| value | `gint64` | The integer value |

---

### yaml_node_get_int

```c
gint64 yaml_node_get_int(YamlNode *node);
```

Gets the integer value of a scalar node.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |

**Returns:** The integer value, or 0 if not an integer.

---

### yaml_node_set_double

```c
void yaml_node_set_double(YamlNode *node, gdouble value);
```

Sets the node to a double scalar.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |
| value | `gdouble` | The double value |

---

### yaml_node_get_double

```c
gdouble yaml_node_get_double(YamlNode *node);
```

Gets the double value of a scalar node.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |

**Returns:** The double value, or 0.0 if not a number.

---

### yaml_node_set_boolean

```c
void yaml_node_set_boolean(YamlNode *node, gboolean value);
```

Sets the node to a boolean scalar.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |
| value | `gboolean` | The boolean value |

---

### yaml_node_get_boolean

```c
gboolean yaml_node_get_boolean(YamlNode *node);
```

Gets the boolean value of a scalar node.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |

**Returns:** The boolean value, or `FALSE` if not a boolean.

---

## YAML Metadata

### yaml_node_set_tag

```c
void yaml_node_set_tag(YamlNode *node, const gchar *tag);
```

Sets the YAML tag. Common tags include `!!str`, `!!int`, `!!bool`, etc.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |
| tag | `const gchar *` `(nullable)` | The YAML tag, or `NULL` |

---

### yaml_node_get_tag

```c
const gchar *yaml_node_get_tag(YamlNode *node);
```

Gets the YAML tag.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |

**Returns:** `(transfer none) (nullable)` The tag, or `NULL`.

---

### yaml_node_set_anchor

```c
void yaml_node_set_anchor(YamlNode *node, const gchar *anchor);
```

Sets the anchor name. Anchors can be referenced elsewhere using aliases.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |
| anchor | `const gchar *` `(nullable)` | The anchor name, or `NULL` |

---

### yaml_node_get_anchor

```c
const gchar *yaml_node_get_anchor(YamlNode *node);
```

Gets the anchor name.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |

**Returns:** `(transfer none) (nullable)` The anchor, or `NULL`.

---

### yaml_node_set_scalar_style

```c
void yaml_node_set_scalar_style(YamlNode *node, YamlScalarStyle style);
```

Sets the preferred output style for a scalar node.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |
| style | `YamlScalarStyle` | The scalar style |

---

### yaml_node_get_scalar_style

```c
YamlScalarStyle yaml_node_get_scalar_style(YamlNode *node);
```

Gets the preferred output style.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |

**Returns:** The `YamlScalarStyle`.

---

## Parent Relationship

### yaml_node_set_parent

```c
void yaml_node_set_parent(YamlNode *node, YamlNode *parent);
```

Sets the parent of the node. This is typically managed automatically.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |
| parent | `YamlNode *` `(nullable)` | The parent node, or `NULL` |

---

### yaml_node_get_parent

```c
YamlNode *yaml_node_get_parent(YamlNode *node);
```

Gets the parent of the node.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A node |

**Returns:** `(transfer none) (nullable)` The parent node, or `NULL`.

---

## Equality and Hashing

### yaml_node_hash

```c
guint yaml_node_hash(gconstpointer key);
```

Computes a hash value for the node.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| key | `gconstpointer` | A `YamlNode` |

**Returns:** A hash value.

---

### yaml_node_equal

```c
gboolean yaml_node_equal(gconstpointer a, gconstpointer b);
```

Checks if two nodes have equal content.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| a | `gconstpointer` | A `YamlNode` |
| b | `gconstpointer` | Another `YamlNode` |

**Returns:** `TRUE` if the nodes are equal.

**Example:**
```c
/* Use as GHashTable key functions */
GHashTable *table = g_hash_table_new_full(
    yaml_node_hash,
    yaml_node_equal,
    (GDestroyNotify)yaml_node_unref,
    NULL
);
```

---

## JSON Interoperability

### yaml_node_from_json_node

```c
YamlNode *yaml_node_from_json_node(JsonNode *json_node);
```

Creates a `YamlNode` from a `JsonNode`. Performs a deep conversion.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| json_node | `JsonNode *` | A JSON-GLib node |

**Returns:** `(transfer full)` A new `YamlNode`.

**Example:**
```c
JsonParser *json_parser = json_parser_new();
json_parser_load_from_data(json_parser, "{\"key\": \"value\"}", -1, NULL);
JsonNode *json_root = json_parser_get_root(json_parser);

g_autoptr(YamlNode) yaml_node = yaml_node_from_json_node(json_root);
```

---

### yaml_node_to_json_node

```c
JsonNode *yaml_node_to_json_node(YamlNode *node);
```

Creates a `JsonNode` from a `YamlNode`. Performs a deep conversion.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | A YAML node |

**Returns:** `(transfer full)` A new `JsonNode`.

---

## Autoptr Support

```c
G_DEFINE_AUTOPTR_CLEANUP_FUNC(YamlNode, yaml_node_unref)
```

Use `g_autoptr(YamlNode)` for automatic cleanup:

```c
void example(void)
{
    g_autoptr(YamlNode) node = yaml_node_new_string("hello");
    /* node automatically freed when leaving scope */
}
```

## See Also

- [YamlMapping](mapping.md) - Key-value pairs
- [YamlSequence](sequence.md) - Ordered arrays
- [Types Reference](types.md) - Type definitions
- [Memory Management](../memory-management.md) - Ownership patterns
