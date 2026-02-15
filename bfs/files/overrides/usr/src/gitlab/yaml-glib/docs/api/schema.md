# YamlSchema API Reference

`YamlSchema` provides schema validation for YAML nodes.

## Overview

```c
#include <yaml-glib/yaml-glib.h>

#define YAML_TYPE_SCHEMA (yaml_schema_get_type())

G_DECLARE_DERIVABLE_TYPE(YamlSchema, yaml_schema, YAML, SCHEMA, GObject)
```

`YamlSchema` allows you to define expected structure, required fields, type constraints, and value constraints for YAML data.

## Construction

### yaml_schema_new

```c
YamlSchema *yaml_schema_new(void);
```

Creates a new empty `YamlSchema`.

**Returns:** `(transfer full)` A new `YamlSchema`.

---

### yaml_schema_new_for_mapping

```c
YamlSchema *yaml_schema_new_for_mapping(void);
```

Creates a schema that expects a mapping root.

**Returns:** `(transfer full)` A new `YamlSchema`.

**Example:**
```c
g_autoptr(YamlSchema) schema = yaml_schema_new_for_mapping();
yaml_schema_add_property(schema, "name", YAML_NODE_SCALAR, TRUE);
yaml_schema_add_property(schema, "age", YAML_NODE_SCALAR, FALSE);
```

---

### yaml_schema_new_for_sequence

```c
YamlSchema *yaml_schema_new_for_sequence(void);
```

Creates a schema that expects a sequence root.

**Returns:** `(transfer full)` A new `YamlSchema`.

---

### yaml_schema_new_for_scalar

```c
YamlSchema *yaml_schema_new_for_scalar(void);
```

Creates a schema that expects a scalar root.

**Returns:** `(transfer full)` A new `YamlSchema`.

---

## Type Configuration

### yaml_schema_set_expected_type / yaml_schema_get_expected_type

```c
void yaml_schema_set_expected_type(YamlSchema *schema, YamlNodeType type);
YamlNodeType yaml_schema_get_expected_type(YamlSchema *schema);
```

Set/get the expected root node type.

---

## Mapping Property Definitions

### yaml_schema_add_property

```c
void yaml_schema_add_property(
    YamlSchema   *schema,
    const gchar  *name,
    YamlNodeType  type,
    gboolean      required
);
```

Adds a property definition to a mapping schema.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| schema | `YamlSchema *` | A schema |
| name | `const gchar *` | The property name |
| type | `YamlNodeType` | Expected property type |
| required | `gboolean` | Whether the property is required |

**Example:**
```c
g_autoptr(YamlSchema) schema = yaml_schema_new_for_mapping();
yaml_schema_add_property(schema, "name", YAML_NODE_SCALAR, TRUE);
yaml_schema_add_property(schema, "email", YAML_NODE_SCALAR, FALSE);
yaml_schema_add_property(schema, "tags", YAML_NODE_SEQUENCE, FALSE);
```

---

### yaml_schema_add_property_with_schema

```c
void yaml_schema_add_property_with_schema(
    YamlSchema  *schema,
    const gchar *name,
    YamlSchema  *property_schema,
    gboolean     required
);
```

Adds a property with a nested schema for validation.

**Example:**
```c
/* Address schema */
g_autoptr(YamlSchema) address_schema = yaml_schema_new_for_mapping();
yaml_schema_add_property(address_schema, "city", YAML_NODE_SCALAR, TRUE);
yaml_schema_add_property(address_schema, "zip", YAML_NODE_SCALAR, TRUE);

/* Person schema with nested address */
g_autoptr(YamlSchema) person_schema = yaml_schema_new_for_mapping();
yaml_schema_add_property(person_schema, "name", YAML_NODE_SCALAR, TRUE);
yaml_schema_add_property_with_schema(person_schema, "address", address_schema, TRUE);
```

---

### yaml_schema_set_allow_additional_properties / yaml_schema_get_allow_additional_properties

```c
void yaml_schema_set_allow_additional_properties(YamlSchema *schema, gboolean allow);
gboolean yaml_schema_get_allow_additional_properties(YamlSchema *schema);
```

Set/get whether unmapped properties are allowed. Default is `TRUE`.

**Example:**
```c
yaml_schema_set_allow_additional_properties(schema, FALSE);
/* Now extra properties will cause validation to fail */
```

---

## Sequence Constraints

### yaml_schema_set_element_type

```c
void yaml_schema_set_element_type(YamlSchema *schema, YamlNodeType type);
```

Sets the expected type for sequence elements.

---

### yaml_schema_set_element_schema

```c
void yaml_schema_set_element_schema(YamlSchema *schema, YamlSchema *element_schema);
```

Sets a schema for validating sequence elements.

---

### yaml_schema_set_min_length / yaml_schema_set_max_length

```c
void yaml_schema_set_min_length(YamlSchema *schema, guint min_length);
void yaml_schema_set_max_length(YamlSchema *schema, guint max_length);
```

Set minimum/maximum sequence length.

**Example:**
```c
g_autoptr(YamlSchema) schema = yaml_schema_new_for_sequence();
yaml_schema_set_min_length(schema, 1);  /* At least 1 element */
yaml_schema_set_max_length(schema, 10); /* At most 10 elements */
```

---

## Scalar Constraints

### yaml_schema_set_pattern

```c
void yaml_schema_set_pattern(YamlSchema *schema, const gchar *pattern);
```

Sets a regex pattern for scalar validation.

**Example:**
```c
g_autoptr(YamlSchema) email_schema = yaml_schema_new_for_scalar();
yaml_schema_set_pattern(email_schema, "^[a-z]+@[a-z]+\\.[a-z]+$");
```

---

### yaml_schema_add_enum_value

```c
void yaml_schema_add_enum_value(YamlSchema *schema, const gchar *value);
```

Adds an allowed value for enum validation.

**Example:**
```c
g_autoptr(YamlSchema) status_schema = yaml_schema_new_for_scalar();
yaml_schema_add_enum_value(status_schema, "pending");
yaml_schema_add_enum_value(status_schema, "active");
yaml_schema_add_enum_value(status_schema, "completed");
```

---

### yaml_schema_set_min_value / yaml_schema_set_max_value

```c
void yaml_schema_set_min_value(YamlSchema *schema, gdouble min_value);
void yaml_schema_set_max_value(YamlSchema *schema, gdouble max_value);
```

Set minimum/maximum numeric value for scalars.

**Example:**
```c
g_autoptr(YamlSchema) age_schema = yaml_schema_new_for_scalar();
yaml_schema_set_min_value(age_schema, 0);
yaml_schema_set_max_value(age_schema, 150);
```

---

### yaml_schema_set_min_string_length / yaml_schema_set_max_string_length

```c
void yaml_schema_set_min_string_length(YamlSchema *schema, guint min_length);
void yaml_schema_set_max_string_length(YamlSchema *schema, guint max_length);
```

Set minimum/maximum string length for scalars.

---

## Validation

### yaml_schema_validate

```c
gboolean yaml_schema_validate(
    YamlSchema  *schema,
    YamlNode    *node,
    GError     **error
);
```

Validates a node against the schema.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| schema | `YamlSchema *` | A schema |
| node | `YamlNode *` | The node to validate |
| error | `GError **` `(nullable)` | Return location for error |

**Returns:** `TRUE` if valid.

**Example:**
```c
g_autoptr(GError) error = NULL;
if (!yaml_schema_validate(schema, root, &error))
{
    g_printerr("Validation failed: %s\n", error->message);
}
```

---

### yaml_schema_validate_with_path

```c
gboolean yaml_schema_validate_with_path(
    YamlSchema  *schema,
    YamlNode    *node,
    const gchar *path,
    GError     **error
);
```

Validates with path tracking for better error messages.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| schema | `YamlSchema *` | A schema |
| node | `YamlNode *` | The node to validate |
| path | `const gchar *` | Current path (e.g., "/users/0") |
| error | `GError **` `(nullable)` | Return location for error |

**Returns:** `TRUE` if valid.

---

## Complete Example

```c
#include <yaml-glib/yaml-glib.h>

YamlSchema *
create_config_schema(void)
{
    YamlSchema *schema;
    YamlSchema *db_schema;
    YamlSchema *hosts_schema;

    /* Database nested schema */
    db_schema = yaml_schema_new_for_mapping();
    yaml_schema_add_property(db_schema, "host", YAML_NODE_SCALAR, TRUE);
    yaml_schema_add_property(db_schema, "port", YAML_NODE_SCALAR, TRUE);
    yaml_schema_add_property(db_schema, "name", YAML_NODE_SCALAR, TRUE);

    /* Hosts sequence schema */
    hosts_schema = yaml_schema_new_for_sequence();
    yaml_schema_set_element_type(hosts_schema, YAML_NODE_SCALAR);
    yaml_schema_set_min_length(hosts_schema, 1);

    /* Main config schema */
    schema = yaml_schema_new_for_mapping();
    yaml_schema_add_property(schema, "name", YAML_NODE_SCALAR, TRUE);
    yaml_schema_add_property(schema, "version", YAML_NODE_SCALAR, TRUE);
    yaml_schema_add_property(schema, "debug", YAML_NODE_SCALAR, FALSE);
    yaml_schema_add_property_with_schema(schema, "database", db_schema, TRUE);
    yaml_schema_add_property_with_schema(schema, "allowed_hosts", hosts_schema, FALSE);
    yaml_schema_set_allow_additional_properties(schema, FALSE);

    g_object_unref(db_schema);
    g_object_unref(hosts_schema);

    return schema;
}

gboolean
validate_config(const gchar *filename)
{
    g_autoptr(YamlParser) parser = yaml_parser_new();
    g_autoptr(YamlSchema) schema = create_config_schema();
    g_autoptr(GError) error = NULL;

    if (!yaml_parser_load_from_file(parser, filename, &error))
    {
        g_printerr("Parse error: %s\n", error->message);
        return FALSE;
    }

    YamlNode *root = yaml_parser_get_root(parser);
    if (!yaml_schema_validate(schema, root, &error))
    {
        g_printerr("Validation error: %s\n", error->message);
        return FALSE;
    }

    g_print("Configuration is valid!\n");
    return TRUE;
}
```

## Error Codes

See [Types Reference](types.md#yaml_schema_error) for error codes:
- `YAML_SCHEMA_ERROR_TYPE_MISMATCH`
- `YAML_SCHEMA_ERROR_MISSING_REQUIRED`
- `YAML_SCHEMA_ERROR_EXTRA_FIELD`
- `YAML_SCHEMA_ERROR_PATTERN_MISMATCH`
- `YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION`
- `YAML_SCHEMA_ERROR_ENUM_VIOLATION`
- `YAML_SCHEMA_ERROR_INVALID_SCHEMA`

## See Also

- [Schema Validation Guide](../guides/schema-validation.md) - Complete guide
- [Error Handling](../error-handling.md) - GError usage
