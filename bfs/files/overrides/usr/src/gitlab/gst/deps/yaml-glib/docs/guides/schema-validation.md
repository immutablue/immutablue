# Schema Validation Guide

This guide covers validating YAML data against schemas using yaml-glib.

## Overview

`YamlSchema` provides declarative validation for YAML structures:

- **Type validation** - Ensure nodes are mappings, sequences, or scalars
- **Required properties** - Mark mandatory fields
- **Type constraints** - Validate property types
- **Value constraints** - Patterns, enums, min/max values
- **Nested schemas** - Validate complex hierarchies
- **Sequence constraints** - Element types and length limits

## Basic Schema Creation

### Mapping Schema

```c
#include <yaml-glib/yaml-glib.h>

YamlSchema *
create_person_schema(void)
{
    YamlSchema *schema = yaml_schema_new_for_mapping();

    /* Required string property */
    yaml_schema_add_property(schema, "name", YAML_NODE_SCALAR, TRUE);

    /* Optional integer property */
    yaml_schema_add_property(schema, "age", YAML_NODE_SCALAR, FALSE);

    /* Optional boolean */
    yaml_schema_add_property(schema, "active", YAML_NODE_SCALAR, FALSE);

    /* Optional sequence */
    yaml_schema_add_property(schema, "tags", YAML_NODE_SEQUENCE, FALSE);

    return schema;
}
```

### Sequence Schema

```c
YamlSchema *
create_tags_schema(void)
{
    YamlSchema *schema = yaml_schema_new_for_sequence();

    /* All elements must be scalars */
    yaml_schema_set_element_type(schema, YAML_NODE_SCALAR);

    /* At least 1, at most 10 elements */
    yaml_schema_set_min_length(schema, 1);
    yaml_schema_set_max_length(schema, 10);

    return schema;
}
```

### Scalar Schema

```c
YamlSchema *
create_email_schema(void)
{
    YamlSchema *schema = yaml_schema_new_for_scalar();

    /* Must match email pattern */
    yaml_schema_set_pattern(schema, "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$");

    return schema;
}
```

## Validating Data

### Basic Validation

```c
gboolean
validate_config(YamlNode *root)
{
    g_autoptr(YamlSchema) schema = create_person_schema();
    g_autoptr(GError) error = NULL;

    if (!yaml_schema_validate(schema, root, &error))
    {
        g_printerr("Validation failed: %s\n", error->message);
        return FALSE;
    }

    g_print("Configuration is valid!\n");
    return TRUE;
}
```

### Validation with Path Tracking

For better error messages with nested structures:

```c
gboolean
validate_with_path(YamlNode *root)
{
    g_autoptr(YamlSchema) schema = create_config_schema();
    g_autoptr(GError) error = NULL;

    if (!yaml_schema_validate_with_path(schema, root, "/", &error))
    {
        /* Error message includes path like "/database/port" */
        g_printerr("Error: %s\n", error->message);
        return FALSE;
    }

    return TRUE;
}
```

## Nested Schemas

### Property with Nested Schema

```c
YamlSchema *
create_config_schema(void)
{
    /* Database sub-schema */
    YamlSchema *db_schema = yaml_schema_new_for_mapping();
    yaml_schema_add_property(db_schema, "host", YAML_NODE_SCALAR, TRUE);
    yaml_schema_add_property(db_schema, "port", YAML_NODE_SCALAR, TRUE);
    yaml_schema_add_property(db_schema, "name", YAML_NODE_SCALAR, TRUE);
    yaml_schema_add_property(db_schema, "username", YAML_NODE_SCALAR, FALSE);
    yaml_schema_add_property(db_schema, "password", YAML_NODE_SCALAR, FALSE);

    /* Server sub-schema */
    YamlSchema *server_schema = yaml_schema_new_for_mapping();
    yaml_schema_add_property(server_schema, "host", YAML_NODE_SCALAR, FALSE);
    yaml_schema_add_property(server_schema, "port", YAML_NODE_SCALAR, TRUE);
    yaml_schema_add_property(server_schema, "ssl", YAML_NODE_SCALAR, FALSE);

    /* Main schema */
    YamlSchema *schema = yaml_schema_new_for_mapping();
    yaml_schema_add_property(schema, "name", YAML_NODE_SCALAR, TRUE);
    yaml_schema_add_property(schema, "version", YAML_NODE_SCALAR, TRUE);
    yaml_schema_add_property_with_schema(schema, "database", db_schema, TRUE);
    yaml_schema_add_property_with_schema(schema, "server", server_schema, FALSE);

    /* Clean up - schema takes ownership */
    g_object_unref(db_schema);
    g_object_unref(server_schema);

    return schema;
}
```

### Sequence with Element Schema

```c
YamlSchema *
create_users_list_schema(void)
{
    /* Schema for each user element */
    YamlSchema *user_schema = yaml_schema_new_for_mapping();
    yaml_schema_add_property(user_schema, "id", YAML_NODE_SCALAR, TRUE);
    yaml_schema_add_property(user_schema, "name", YAML_NODE_SCALAR, TRUE);
    yaml_schema_add_property(user_schema, "email", YAML_NODE_SCALAR, FALSE);

    /* Users list schema */
    YamlSchema *schema = yaml_schema_new_for_sequence();
    yaml_schema_set_element_schema(schema, user_schema);
    yaml_schema_set_min_length(schema, 1);

    g_object_unref(user_schema);

    return schema;
}
```

## Value Constraints

### Enum Values

```c
YamlSchema *
create_status_schema(void)
{
    YamlSchema *schema = yaml_schema_new_for_scalar();

    /* Only allow specific values */
    yaml_schema_add_enum_value(schema, "pending");
    yaml_schema_add_enum_value(schema, "active");
    yaml_schema_add_enum_value(schema, "suspended");
    yaml_schema_add_enum_value(schema, "deleted");

    return schema;
}
```

### Numeric Ranges

```c
YamlSchema *
create_port_schema(void)
{
    YamlSchema *schema = yaml_schema_new_for_scalar();

    yaml_schema_set_min_value(schema, 1);
    yaml_schema_set_max_value(schema, 65535);

    return schema;
}

YamlSchema *
create_age_schema(void)
{
    YamlSchema *schema = yaml_schema_new_for_scalar();

    yaml_schema_set_min_value(schema, 0);
    yaml_schema_set_max_value(schema, 150);

    return schema;
}
```

### String Length

```c
YamlSchema *
create_username_schema(void)
{
    YamlSchema *schema = yaml_schema_new_for_scalar();

    yaml_schema_set_min_string_length(schema, 3);
    yaml_schema_set_max_string_length(schema, 32);

    /* Also enforce pattern */
    yaml_schema_set_pattern(schema, "^[a-z][a-z0-9_]*$");

    return schema;
}
```

### Regex Patterns

```c
YamlSchema *
create_semantic_version_schema(void)
{
    YamlSchema *schema = yaml_schema_new_for_scalar();

    /* Semantic versioning pattern */
    yaml_schema_set_pattern(schema,
        "^(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)"
        "(-[a-zA-Z0-9-]+(\\.[a-zA-Z0-9-]+)*)?"
        "(\\+[a-zA-Z0-9-]+(\\.[a-zA-Z0-9-]+)*)?$"
    );

    return schema;
}
```

## Additional Properties

Control whether unmapped properties are allowed:

```c
YamlSchema *
create_strict_schema(void)
{
    YamlSchema *schema = yaml_schema_new_for_mapping();

    yaml_schema_add_property(schema, "name", YAML_NODE_SCALAR, TRUE);
    yaml_schema_add_property(schema, "value", YAML_NODE_SCALAR, TRUE);

    /* Reject any properties not in the schema */
    yaml_schema_set_allow_additional_properties(schema, FALSE);

    return schema;
}
```

## Error Handling

### Error Codes

```c
void
handle_validation_error(GError *error)
{
    if (error->domain != YAML_SCHEMA_ERROR)
    {
        g_printerr("Unknown error: %s\n", error->message);
        return;
    }

    switch (error->code)
    {
    case YAML_SCHEMA_ERROR_TYPE_MISMATCH:
        g_printerr("Type error: %s\n", error->message);
        break;

    case YAML_SCHEMA_ERROR_MISSING_REQUIRED:
        g_printerr("Missing required field: %s\n", error->message);
        break;

    case YAML_SCHEMA_ERROR_EXTRA_FIELD:
        g_printerr("Unknown field: %s\n", error->message);
        break;

    case YAML_SCHEMA_ERROR_PATTERN_MISMATCH:
        g_printerr("Pattern mismatch: %s\n", error->message);
        break;

    case YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION:
        g_printerr("Constraint violated: %s\n", error->message);
        break;

    case YAML_SCHEMA_ERROR_ENUM_VIOLATION:
        g_printerr("Invalid value: %s\n", error->message);
        break;

    case YAML_SCHEMA_ERROR_INVALID_SCHEMA:
        g_printerr("Schema error: %s\n", error->message);
        break;

    default:
        g_printerr("Validation error: %s\n", error->message);
    }
}
```

## Practical Examples

### Configuration File Validation

```c
YamlSchema *
create_app_config_schema(void)
{
    YamlSchema *schema = yaml_schema_new_for_mapping();

    /* Application info */
    yaml_schema_add_property(schema, "name", YAML_NODE_SCALAR, TRUE);

    YamlSchema *version_schema = yaml_schema_new_for_scalar();
    yaml_schema_set_pattern(version_schema, "^\\d+\\.\\d+\\.\\d+$");
    yaml_schema_add_property_with_schema(schema, "version", version_schema, TRUE);
    g_object_unref(version_schema);

    yaml_schema_add_property(schema, "debug", YAML_NODE_SCALAR, FALSE);

    /* Database config */
    YamlSchema *db = yaml_schema_new_for_mapping();
    yaml_schema_add_property(db, "host", YAML_NODE_SCALAR, TRUE);

    YamlSchema *port = yaml_schema_new_for_scalar();
    yaml_schema_set_min_value(port, 1);
    yaml_schema_set_max_value(port, 65535);
    yaml_schema_add_property_with_schema(db, "port", port, TRUE);
    g_object_unref(port);

    yaml_schema_add_property(db, "name", YAML_NODE_SCALAR, TRUE);
    yaml_schema_add_property(db, "username", YAML_NODE_SCALAR, FALSE);
    yaml_schema_add_property(db, "password", YAML_NODE_SCALAR, FALSE);
    yaml_schema_set_allow_additional_properties(db, FALSE);

    yaml_schema_add_property_with_schema(schema, "database", db, TRUE);
    g_object_unref(db);

    /* Logging config */
    YamlSchema *logging = yaml_schema_new_for_mapping();

    YamlSchema *level = yaml_schema_new_for_scalar();
    yaml_schema_add_enum_value(level, "debug");
    yaml_schema_add_enum_value(level, "info");
    yaml_schema_add_enum_value(level, "warning");
    yaml_schema_add_enum_value(level, "error");
    yaml_schema_add_property_with_schema(logging, "level", level, FALSE);
    g_object_unref(level);

    yaml_schema_add_property(logging, "file", YAML_NODE_SCALAR, FALSE);
    yaml_schema_add_property_with_schema(schema, "logging", logging, FALSE);
    g_object_unref(logging);

    /* Features list */
    YamlSchema *features = yaml_schema_new_for_sequence();
    yaml_schema_set_element_type(features, YAML_NODE_SCALAR);
    yaml_schema_add_property_with_schema(schema, "features", features, FALSE);
    g_object_unref(features);

    yaml_schema_set_allow_additional_properties(schema, FALSE);

    return schema;
}

gboolean
validate_config_file(const gchar *filename)
{
    g_autoptr(YamlParser) parser = yaml_parser_new();
    g_autoptr(GError) error = NULL;

    if (!yaml_parser_load_from_file(parser, filename, &error))
    {
        g_printerr("Parse error: %s\n", error->message);
        return FALSE;
    }

    YamlNode *root = yaml_parser_get_root(parser);
    g_autoptr(YamlSchema) schema = create_app_config_schema();

    if (!yaml_schema_validate_with_path(schema, root, "/", &error))
    {
        g_printerr("Validation error: %s\n", error->message);
        return FALSE;
    }

    return TRUE;
}
```

### API Request Validation

```c
YamlSchema *
create_user_request_schema(void)
{
    YamlSchema *schema = yaml_schema_new_for_mapping();

    /* Username: 3-20 alphanumeric characters */
    YamlSchema *username = yaml_schema_new_for_scalar();
    yaml_schema_set_min_string_length(username, 3);
    yaml_schema_set_max_string_length(username, 20);
    yaml_schema_set_pattern(username, "^[a-zA-Z0-9_]+$");
    yaml_schema_add_property_with_schema(schema, "username", username, TRUE);
    g_object_unref(username);

    /* Email: valid email format */
    YamlSchema *email = yaml_schema_new_for_scalar();
    yaml_schema_set_pattern(email, "^[^@]+@[^@]+\\.[^@]+$");
    yaml_schema_add_property_with_schema(schema, "email", email, TRUE);
    g_object_unref(email);

    /* Age: 13-120 */
    YamlSchema *age = yaml_schema_new_for_scalar();
    yaml_schema_set_min_value(age, 13);
    yaml_schema_set_max_value(age, 120);
    yaml_schema_add_property_with_schema(schema, "age", age, FALSE);
    g_object_unref(age);

    /* Role: enum */
    YamlSchema *role = yaml_schema_new_for_scalar();
    yaml_schema_add_enum_value(role, "user");
    yaml_schema_add_enum_value(role, "moderator");
    yaml_schema_add_enum_value(role, "admin");
    yaml_schema_add_property_with_schema(schema, "role", role, FALSE);
    g_object_unref(role);

    yaml_schema_set_allow_additional_properties(schema, FALSE);

    return schema;
}
```

## Complete Example

```c
#include <yaml-glib/yaml-glib.h>

static YamlSchema *
create_server_config_schema(void)
{
    /* TLS settings */
    YamlSchema *tls = yaml_schema_new_for_mapping();
    yaml_schema_add_property(tls, "enabled", YAML_NODE_SCALAR, FALSE);
    yaml_schema_add_property(tls, "cert_file", YAML_NODE_SCALAR, FALSE);
    yaml_schema_add_property(tls, "key_file", YAML_NODE_SCALAR, FALSE);

    /* Listener */
    YamlSchema *listener = yaml_schema_new_for_mapping();
    yaml_schema_add_property(listener, "host", YAML_NODE_SCALAR, FALSE);

    YamlSchema *port = yaml_schema_new_for_scalar();
    yaml_schema_set_min_value(port, 1);
    yaml_schema_set_max_value(port, 65535);
    yaml_schema_add_property_with_schema(listener, "port", port, TRUE);
    g_object_unref(port);

    yaml_schema_add_property_with_schema(listener, "tls", tls, FALSE);
    g_object_unref(tls);

    /* Listeners array */
    YamlSchema *listeners = yaml_schema_new_for_sequence();
    yaml_schema_set_element_schema(listeners, listener);
    yaml_schema_set_min_length(listeners, 1);
    g_object_unref(listener);

    /* Main schema */
    YamlSchema *schema = yaml_schema_new_for_mapping();
    yaml_schema_add_property(schema, "name", YAML_NODE_SCALAR, TRUE);
    yaml_schema_add_property_with_schema(schema, "listeners", listeners, TRUE);
    g_object_unref(listeners);

    yaml_schema_set_allow_additional_properties(schema, FALSE);

    return schema;
}

int
main(int argc, char *argv[])
{
    if (argc < 2)
    {
        g_printerr("Usage: %s <config.yaml>\n", argv[0]);
        return 1;
    }

    g_autoptr(YamlParser) parser = yaml_parser_new();
    g_autoptr(GError) error = NULL;

    if (!yaml_parser_load_from_file(parser, argv[1], &error))
    {
        g_printerr("Parse error: %s\n", error->message);
        return 1;
    }

    YamlNode *root = yaml_parser_get_root(parser);
    g_autoptr(YamlSchema) schema = create_server_config_schema();

    if (!yaml_schema_validate_with_path(schema, root, "/", &error))
    {
        g_printerr("Validation failed: %s\n", error->message);
        return 1;
    }

    g_print("Configuration is valid!\n");
    return 0;
}
```

**Valid config.yaml:**
```yaml
name: my-server
listeners:
  - port: 8080
  - port: 8443
    host: 0.0.0.0
    tls:
      enabled: true
      cert_file: /etc/ssl/cert.pem
      key_file: /etc/ssl/key.pem
```

## See Also

- [YamlSchema API](../api/schema.md) - Complete API reference
- [Error Handling](../error-handling.md) - Error handling patterns
- [Parsing Guide](parsing.md) - Loading YAML to validate
