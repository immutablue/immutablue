# YamlBuilder API Reference

`YamlBuilder` provides a fluent API for programmatically constructing YAML structures.

## Overview

```c
#include <yaml-glib/yaml-glib.h>

#define YAML_TYPE_BUILDER (yaml_builder_get_type())

G_DECLARE_DERIVABLE_TYPE(YamlBuilder, yaml_builder, YAML, BUILDER, GObject)
```

`YamlBuilder` uses a stack-based approach where you begin structures, add values, and end structures. All `begin_*` calls must be matched with corresponding `end_*` calls.

## Construction

### yaml_builder_new

```c
YamlBuilder *yaml_builder_new(void);
```

Creates a new `YamlBuilder`.

**Returns:** `(transfer full)` A new `YamlBuilder`.

---

### yaml_builder_new_immutable

```c
YamlBuilder *yaml_builder_new_immutable(void);
```

Creates a builder that produces immutable (sealed) nodes.

**Returns:** `(transfer full)` A new `YamlBuilder`.

---

### yaml_builder_get_immutable / yaml_builder_set_immutable

```c
gboolean yaml_builder_get_immutable(YamlBuilder *builder);
void yaml_builder_set_immutable(YamlBuilder *builder, gboolean immutable);
```

Get/set whether built nodes are immutable.

---

## Mapping Construction

### yaml_builder_begin_mapping

```c
YamlBuilder *yaml_builder_begin_mapping(YamlBuilder *builder);
```

Begins a new mapping. Must be matched with `yaml_builder_end_mapping()`.

**Returns:** `(transfer none)` The builder for chaining.

---

### yaml_builder_end_mapping

```c
YamlBuilder *yaml_builder_end_mapping(YamlBuilder *builder);
```

Ends the current mapping.

**Returns:** `(transfer none)` The builder for chaining.

---

### yaml_builder_set_member_name

```c
YamlBuilder *yaml_builder_set_member_name(YamlBuilder *builder, const gchar *name);
```

Sets the name for the next value in a mapping. Must be called before adding a value within a mapping context.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| builder | `YamlBuilder *` | A builder |
| name | `const gchar *` | The member name (mapping key) |

**Returns:** `(transfer none)` The builder for chaining.

---

## Sequence Construction

### yaml_builder_begin_sequence

```c
YamlBuilder *yaml_builder_begin_sequence(YamlBuilder *builder);
```

Begins a new sequence. Must be matched with `yaml_builder_end_sequence()`.

**Returns:** `(transfer none)` The builder for chaining.

---

### yaml_builder_end_sequence

```c
YamlBuilder *yaml_builder_end_sequence(YamlBuilder *builder);
```

Ends the current sequence.

**Returns:** `(transfer none)` The builder for chaining.

---

## Scalar Values

### yaml_builder_add_null_value

```c
YamlBuilder *yaml_builder_add_null_value(YamlBuilder *builder);
```

Adds a null value.

---

### yaml_builder_add_boolean_value

```c
YamlBuilder *yaml_builder_add_boolean_value(YamlBuilder *builder, gboolean value);
```

Adds a boolean value.

---

### yaml_builder_add_int_value

```c
YamlBuilder *yaml_builder_add_int_value(YamlBuilder *builder, gint64 value);
```

Adds an integer value.

---

### yaml_builder_add_double_value

```c
YamlBuilder *yaml_builder_add_double_value(YamlBuilder *builder, gdouble value);
```

Adds a double value.

---

### yaml_builder_add_string_value

```c
YamlBuilder *yaml_builder_add_string_value(YamlBuilder *builder, const gchar *value);
```

Adds a string value.

---

### yaml_builder_add_scalar_value

```c
YamlBuilder *yaml_builder_add_scalar_value(
    YamlBuilder     *builder,
    const gchar     *value,
    YamlScalarStyle  style
);
```

Adds a scalar value with explicit style.

---

### yaml_builder_add_value

```c
YamlBuilder *yaml_builder_add_value(YamlBuilder *builder, YamlNode *node);
```

Adds an existing node value.

---

## Anchor and Tag Support

### yaml_builder_set_anchor

```c
YamlBuilder *yaml_builder_set_anchor(YamlBuilder *builder, const gchar *anchor);
```

Sets the anchor for the next node. The anchor will be applied to the next mapping, sequence, or scalar.

---

### yaml_builder_set_tag

```c
YamlBuilder *yaml_builder_set_tag(YamlBuilder *builder, const gchar *tag);
```

Sets the tag for the next node.

---

### yaml_builder_add_alias

```c
YamlBuilder *yaml_builder_add_alias(YamlBuilder *builder, const gchar *anchor);
```

Adds an alias node referencing a previously anchored node.

---

## Result Retrieval

### yaml_builder_get_root

```c
YamlNode *yaml_builder_get_root(YamlBuilder *builder);
```

Gets the root node that was built. The builder must have a complete structure.

**Returns:** `(transfer none) (nullable)` The root node, or `NULL`.

---

### yaml_builder_dup_root

```c
YamlNode *yaml_builder_dup_root(YamlBuilder *builder);
```

Gets a new reference to the root node.

**Returns:** `(transfer full) (nullable)` The root node, or `NULL`.

---

### yaml_builder_steal_root

```c
YamlNode *yaml_builder_steal_root(YamlBuilder *builder);
```

Steals the root node, resetting the builder.

**Returns:** `(transfer full) (nullable)` The root node, or `NULL`.

---

### yaml_builder_get_document

```c
YamlDocument *yaml_builder_get_document(YamlBuilder *builder);
```

Gets the built structure as a document.

**Returns:** `(transfer full) (nullable)` A new document, or `NULL`.

---

### yaml_builder_reset

```c
void yaml_builder_reset(YamlBuilder *builder);
```

Resets the builder, clearing all state.

---

## Complete Example

```c
#include <yaml-glib/yaml-glib.h>

YamlNode *
build_config(void)
{
    g_autoptr(YamlBuilder) builder = yaml_builder_new();

    yaml_builder_begin_mapping(builder);
    {
        /* Application info */
        yaml_builder_set_member_name(builder, "name");
        yaml_builder_add_string_value(builder, "My Application");

        yaml_builder_set_member_name(builder, "version");
        yaml_builder_add_string_value(builder, "1.0.0");

        yaml_builder_set_member_name(builder, "debug");
        yaml_builder_add_boolean_value(builder, FALSE);

        /* Nested database config */
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

        /* Array of allowed hosts */
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

    return yaml_builder_steal_root(builder);
}
```

## Anchor Example

```c
YamlNode *
build_with_anchors(void)
{
    g_autoptr(YamlBuilder) builder = yaml_builder_new();

    yaml_builder_begin_mapping(builder);
    {
        /* Define an anchor */
        yaml_builder_set_member_name(builder, "defaults");
        yaml_builder_set_anchor(builder, "defaults");
        yaml_builder_begin_mapping(builder);
        {
            yaml_builder_set_member_name(builder, "timeout");
            yaml_builder_add_int_value(builder, 30);
        }
        yaml_builder_end_mapping(builder);

        /* Reference the anchor */
        yaml_builder_set_member_name(builder, "production");
        yaml_builder_add_alias(builder, "defaults");
    }
    yaml_builder_end_mapping(builder);

    return yaml_builder_steal_root(builder);
}
```

## See Also

- [YamlNode](node.md) - Generic container (direct construction)
- [YamlGenerator](generator.md) - Generate YAML output
- [Building YAML Guide](../guides/building-yaml.md) - Complete building guide
