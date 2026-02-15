# Error Handling

yaml-glib uses GLib's GError system for error reporting. This guide explains error domains, error codes, and best practices for handling errors.

## GError Basics

GError is GLib's standard mechanism for recoverable runtime errors. It provides:

- **Error domain**: A quark identifying the error source (e.g., parser, generator, schema)
- **Error code**: A numeric code identifying the specific error type
- **Error message**: A human-readable description

### Basic Usage Pattern

```c
void
example_parse(const gchar *filename)
{
    g_autoptr(YamlParser) parser = yaml_parser_new();
    g_autoptr(GError) error = NULL;

    if (!yaml_parser_load_from_file(parser, filename, &error))
    {
        g_printerr("Error: %s\n", error->message);
        return;
    }

    /* Success - process the data */
}
```

### GError Rules

1. **Always initialize to NULL**: `GError *error = NULL;`
2. **Check return value first**: Test the function return before checking error
3. **Error is set only on failure**: Success leaves error unchanged (NULL)
4. **Caller owns the error**: You must free it with `g_error_free()` or `g_clear_error()`
5. **Use g_autoptr for automatic cleanup**: `g_autoptr(GError) error = NULL;`

## Error Domains

yaml-glib defines three error domains:

### YAML_GLIB_PARSER_ERROR

Errors from `YamlParser` operations.

```c
#define YAML_GLIB_PARSER_ERROR (yaml_glib_parser_error_quark())
```

| Code | Constant | Description |
|------|----------|-------------|
| 0 | `YAML_GLIB_PARSER_ERROR_INVALID_DATA` | Input data is not valid YAML |
| 1 | `YAML_GLIB_PARSER_ERROR_PARSE` | General parsing error |
| 2 | `YAML_GLIB_PARSER_ERROR_SCANNER` | Lexical scanning error |
| 3 | `YAML_GLIB_PARSER_ERROR_EMPTY_DOCUMENT` | Document is empty |
| 4 | `YAML_GLIB_PARSER_ERROR_UNKNOWN` | Unknown error |

### YAML_GENERATOR_ERROR

Errors from `YamlGenerator` operations.

```c
#define YAML_GENERATOR_ERROR (yaml_generator_error_quark())
```

| Code | Constant | Description |
|------|----------|-------------|
| 0 | `YAML_GENERATOR_ERROR_EMIT` | YAML emitter error |
| 1 | `YAML_GENERATOR_ERROR_INVALID_NODE` | Node structure is invalid |
| 2 | `YAML_GENERATOR_ERROR_IO` | I/O error during output |

### YAML_SCHEMA_ERROR

Errors from `YamlSchema` validation.

```c
#define YAML_SCHEMA_ERROR (yaml_schema_error_quark())
```

| Code | Constant | Description |
|------|----------|-------------|
| 0 | `YAML_SCHEMA_ERROR_TYPE_MISMATCH` | Node type doesn't match schema |
| 1 | `YAML_SCHEMA_ERROR_MISSING_REQUIRED` | Required property missing |
| 2 | `YAML_SCHEMA_ERROR_EXTRA_FIELD` | Unexpected property found |
| 3 | `YAML_SCHEMA_ERROR_PATTERN_MISMATCH` | String doesn't match pattern |
| 4 | `YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION` | Min/max constraint violated |
| 5 | `YAML_SCHEMA_ERROR_ENUM_VIOLATION` | Value not in allowed enum |
| 6 | `YAML_SCHEMA_ERROR_INVALID_SCHEMA` | Schema definition is invalid |

## Checking Error Types

### Using g_error_matches()

Check if an error matches a specific domain and code:

```c
g_autoptr(GError) error = NULL;

if (!yaml_parser_load_from_file(parser, filename, &error))
{
    if (g_error_matches(error, YAML_GLIB_PARSER_ERROR,
                        YAML_GLIB_PARSER_ERROR_EMPTY_DOCUMENT))
    {
        g_print("File is empty, using defaults\n");
        /* Handle empty document case */
    }
    else if (g_error_matches(error, YAML_GLIB_PARSER_ERROR,
                             YAML_GLIB_PARSER_ERROR_INVALID_DATA))
    {
        g_printerr("Invalid YAML syntax: %s\n", error->message);
    }
    else
    {
        g_printerr("Parse error: %s\n", error->message);
    }
}
```

### Checking Domain Only

```c
if (error != NULL && error->domain == YAML_GLIB_PARSER_ERROR)
{
    /* Handle any parser error */
}
```

### Switch on Error Codes

```c
if (!yaml_schema_validate(schema, node, &error))
{
    switch (error->code)
    {
    case YAML_SCHEMA_ERROR_TYPE_MISMATCH:
        g_printerr("Wrong type at %s\n", error->message);
        break;

    case YAML_SCHEMA_ERROR_MISSING_REQUIRED:
        g_printerr("Missing field: %s\n", error->message);
        break;

    case YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION:
        g_printerr("Value out of range: %s\n", error->message);
        break;

    default:
        g_printerr("Validation error: %s\n", error->message);
        break;
    }
}
```

## Error Propagation

### Propagating Errors Up

When writing functions that can fail, propagate errors to callers:

```c
gboolean
load_config(
    const gchar  *filename,
    YamlNode    **out_node,
    GError      **error
)
{
    g_autoptr(YamlParser) parser = yaml_parser_new();

    /* Pass error pointer through - it gets set on failure */
    if (!yaml_parser_load_from_file(parser, filename, error))
    {
        return FALSE;
    }

    *out_node = yaml_parser_steal_root(parser);
    return TRUE;
}
```

### Using g_propagate_error()

When you have a local error to propagate:

```c
gboolean
process_yaml(
    const gchar  *data,
    GError      **error
)
{
    g_autoptr(GError) local_error = NULL;
    g_autoptr(YamlParser) parser = yaml_parser_new();

    if (!yaml_parser_load_from_data(parser, data, -1, &local_error))
    {
        g_propagate_error(error, g_steal_pointer(&local_error));
        return FALSE;
    }

    /* Continue processing... */
    return TRUE;
}
```

### Creating Custom Errors

Use `g_set_error()` or `g_set_error_literal()`:

```c
gboolean
validate_config(
    YamlNode  *config,
    GError   **error
)
{
    YamlMapping *mapping;
    const gchar *name;

    if (yaml_node_get_node_type(config) != YAML_NODE_MAPPING)
    {
        g_set_error(error,
                    YAML_GLIB_PARSER_ERROR,
                    YAML_GLIB_PARSER_ERROR_INVALID_DATA,
                    "Config must be a mapping, got %d",
                    yaml_node_get_node_type(config));
        return FALSE;
    }

    mapping = yaml_node_get_mapping(config);
    name = yaml_mapping_get_string_member(mapping, "name");

    if (name == NULL)
    {
        g_set_error_literal(error,
                            YAML_SCHEMA_ERROR,
                            YAML_SCHEMA_ERROR_MISSING_REQUIRED,
                            "Config missing required 'name' field");
        return FALSE;
    }

    return TRUE;
}
```

### Adding Prefix to Errors

Add context to errors as they propagate:

```c
gboolean
load_all_configs(
    const gchar  *directory,
    GError      **error
)
{
    g_autoptr(GError) local_error = NULL;

    if (!load_config("app.yaml", &app_config, &local_error))
    {
        g_propagate_prefixed_error(error, g_steal_pointer(&local_error),
                                   "Failed to load app config: ");
        return FALSE;
    }

    /* ... */
    return TRUE;
}
```

## Common Error Handling Patterns

### Try-Parse Pattern

```c
YamlNode *
try_parse_yaml(
    const gchar *data,
    GError     **error
)
{
    g_autoptr(YamlParser) parser = yaml_parser_new();

    if (!yaml_parser_load_from_data(parser, data, -1, error))
    {
        return NULL;
    }

    return yaml_parser_steal_root(parser);
}

/* Usage */
g_autoptr(GError) error = NULL;
g_autoptr(YamlNode) config = try_parse_yaml(yaml_str, &error);

if (config == NULL)
{
    g_printerr("Parse failed: %s\n", error->message);
}
```

### Multiple Operations

```c
gboolean
process_file(
    const gchar  *input_file,
    const gchar  *output_file,
    GError      **error
)
{
    g_autoptr(YamlParser) parser = yaml_parser_new();
    g_autoptr(YamlGenerator) generator = yaml_generator_new();
    g_autoptr(YamlSchema) schema = yaml_schema_new_for_mapping();
    YamlNode *root;

    /* Step 1: Parse */
    if (!yaml_parser_load_from_file(parser, input_file, error))
    {
        return FALSE;
    }

    /* Step 2: Validate */
    root = yaml_parser_get_root(parser);
    yaml_schema_add_property(schema, "name", YAML_NODE_SCALAR, TRUE);

    if (!yaml_schema_validate(schema, root, error))
    {
        return FALSE;
    }

    /* Step 3: Generate */
    yaml_generator_set_root(generator, root);
    if (!yaml_generator_to_file(generator, output_file, error))
    {
        return FALSE;
    }

    return TRUE;
}
```

### Ignoring Errors

When you don't care about errors, pass NULL:

```c
/* Parse, but ignore errors */
yaml_parser_load_from_data(parser, data, -1, NULL);

/* Check if it worked */
YamlNode *root = yaml_parser_get_root(parser);
if (root != NULL)
{
    /* Success */
}
```

### Collecting Multiple Errors

For validation scenarios where you want all errors:

```c
typedef struct {
    GPtrArray *errors;
} ValidationContext;

static void
add_validation_error(
    ValidationContext *ctx,
    const gchar       *path,
    const gchar       *message
)
{
    gchar *full_message = g_strdup_printf("%s: %s", path, message);
    g_ptr_array_add(ctx->errors, full_message);
}

GPtrArray *
validate_all(YamlNode *root)
{
    ValidationContext ctx = { g_ptr_array_new_with_free_func(g_free) };

    /* Validate multiple fields, collecting all errors */
    YamlMapping *mapping = yaml_node_get_mapping(root);

    if (!yaml_mapping_has_member(mapping, "name"))
    {
        add_validation_error(&ctx, "/name", "required field missing");
    }

    if (!yaml_mapping_has_member(mapping, "version"))
    {
        add_validation_error(&ctx, "/version", "required field missing");
    }

    return ctx.errors;
}
```

## Parser Error Messages

Parser errors include position information when available:

```c
if (!yaml_parser_load_from_data(parser, data, -1, &error))
{
    guint line = yaml_parser_get_current_line(parser);
    guint column = yaml_parser_get_current_column(parser);

    g_printerr("Parse error at line %u, column %u: %s\n",
               line, column, error->message);
}
```

## Async Error Handling

For async operations, errors are retrieved in the finish function:

```c
static void
load_complete(
    GObject      *source,
    GAsyncResult *result,
    gpointer      user_data
)
{
    YamlParser *parser = YAML_PARSER(source);
    g_autoptr(GError) error = NULL;

    if (!yaml_parser_load_from_stream_finish(parser, result, &error))
    {
        g_printerr("Async load failed: %s\n", error->message);
        return;
    }

    /* Success - process the data */
    YamlNode *root = yaml_parser_get_root(parser);
    /* ... */
}
```

## GIO Errors

File and stream operations may return GIO errors:

```c
if (!yaml_parser_load_from_file(parser, filename, &error))
{
    if (error->domain == G_FILE_ERROR)
    {
        /* File system error */
        if (error->code == G_FILE_ERROR_NOENT)
        {
            g_printerr("File not found: %s\n", filename);
        }
        else if (error->code == G_FILE_ERROR_PERM)
        {
            g_printerr("Permission denied: %s\n", filename);
        }
    }
    else if (error->domain == YAML_GLIB_PARSER_ERROR)
    {
        /* YAML parsing error */
        g_printerr("YAML syntax error: %s\n", error->message);
    }
}
```

## Best Practices

1. **Always check return values** - Don't rely on error alone
2. **Use g_autoptr(GError)** - Prevents memory leaks
3. **Log with context** - Include file names, line numbers when available
4. **Propagate errors** - Don't silently swallow errors
5. **Add prefixes** - Provide context at each level
6. **Document error conditions** - Note which errors your functions can return
7. **Handle or propagate** - Either handle an error or pass it up, never both
8. **Use g_error_matches()** - More readable than manual domain/code checks

## Quick Reference

| Function | Purpose |
|----------|---------|
| `g_error_new()` | Create new error with formatted message |
| `g_set_error()` | Set error with formatted message |
| `g_set_error_literal()` | Set error with literal message |
| `g_propagate_error()` | Pass error to caller |
| `g_propagate_prefixed_error()` | Pass error with added prefix |
| `g_error_matches()` | Check domain and code |
| `g_error_free()` | Free an error |
| `g_clear_error()` | Free and set to NULL |

## See Also

- [Memory Management](memory-management.md) - g_autoptr patterns
- [API Reference](api/types.md) - Error code definitions
- [GLib Error Reporting](https://docs.gtk.org/glib/error-reporting.html) - GLib documentation
