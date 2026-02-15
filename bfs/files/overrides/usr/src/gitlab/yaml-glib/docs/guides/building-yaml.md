# Building YAML Guide

This guide covers programmatically building YAML structures using yaml-glib.

## Overview

yaml-glib provides two approaches for building YAML:

1. **YamlBuilder** - Fluent, stack-based API for building complex structures
2. **Direct Construction** - Creating nodes directly with constructors

## Using YamlBuilder

`YamlBuilder` uses a stack-based approach where you begin structures, add values, and end structures. All `begin_*` calls must be matched with corresponding `end_*` calls.

### Basic Mapping

```c
#include <yaml-glib/yaml-glib.h>

YamlNode *
build_simple_mapping(void)
{
    g_autoptr(YamlBuilder) builder = yaml_builder_new();

    yaml_builder_begin_mapping(builder);
    {
        yaml_builder_set_member_name(builder, "name");
        yaml_builder_add_string_value(builder, "My Application");

        yaml_builder_set_member_name(builder, "version");
        yaml_builder_add_string_value(builder, "1.0.0");

        yaml_builder_set_member_name(builder, "port");
        yaml_builder_add_int_value(builder, 8080);

        yaml_builder_set_member_name(builder, "debug");
        yaml_builder_add_boolean_value(builder, FALSE);
    }
    yaml_builder_end_mapping(builder);

    return yaml_builder_steal_root(builder);
}
```

**Output:**
```yaml
name: My Application
version: 1.0.0
port: 8080
debug: false
```

### Basic Sequence

```c
YamlNode *
build_simple_sequence(void)
{
    g_autoptr(YamlBuilder) builder = yaml_builder_new();

    yaml_builder_begin_sequence(builder);
    {
        yaml_builder_add_string_value(builder, "apple");
        yaml_builder_add_string_value(builder, "banana");
        yaml_builder_add_string_value(builder, "cherry");
    }
    yaml_builder_end_sequence(builder);

    return yaml_builder_steal_root(builder);
}
```

**Output:**
```yaml
- apple
- banana
- cherry
```

### Nested Structures

```c
YamlNode *
build_nested_config(void)
{
    g_autoptr(YamlBuilder) builder = yaml_builder_new();

    yaml_builder_begin_mapping(builder);
    {
        yaml_builder_set_member_name(builder, "application");
        yaml_builder_add_string_value(builder, "my-app");

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

        /* Nested sequence */
        yaml_builder_set_member_name(builder, "features");
        yaml_builder_begin_sequence(builder);
        {
            yaml_builder_add_string_value(builder, "logging");
            yaml_builder_add_string_value(builder, "caching");
            yaml_builder_add_string_value(builder, "metrics");
        }
        yaml_builder_end_sequence(builder);
    }
    yaml_builder_end_mapping(builder);

    return yaml_builder_steal_root(builder);
}
```

**Output:**
```yaml
application: my-app
database:
  host: localhost
  port: 5432
  name: myapp_db
features:
  - logging
  - caching
  - metrics
```

### All Scalar Types

```c
YamlNode *
build_all_types(void)
{
    g_autoptr(YamlBuilder) builder = yaml_builder_new();

    yaml_builder_begin_mapping(builder);
    {
        /* String */
        yaml_builder_set_member_name(builder, "string");
        yaml_builder_add_string_value(builder, "hello world");

        /* Integer */
        yaml_builder_set_member_name(builder, "integer");
        yaml_builder_add_int_value(builder, 42);

        /* Double */
        yaml_builder_set_member_name(builder, "double");
        yaml_builder_add_double_value(builder, 3.14159);

        /* Boolean */
        yaml_builder_set_member_name(builder, "boolean");
        yaml_builder_add_boolean_value(builder, TRUE);

        /* Null */
        yaml_builder_set_member_name(builder, "nothing");
        yaml_builder_add_null_value(builder);

        /* Scalar with explicit style */
        yaml_builder_set_member_name(builder, "multiline");
        yaml_builder_add_scalar_value(builder,
            "line one\nline two\nline three",
            YAML_SCALAR_LITERAL
        );
    }
    yaml_builder_end_mapping(builder);

    return yaml_builder_steal_root(builder);
}
```

### Using Anchors and Aliases

```c
YamlNode *
build_with_anchors(void)
{
    g_autoptr(YamlBuilder) builder = yaml_builder_new();

    yaml_builder_begin_mapping(builder);
    {
        /* Define defaults with anchor */
        yaml_builder_set_member_name(builder, "defaults");
        yaml_builder_set_anchor(builder, "defaults");
        yaml_builder_begin_mapping(builder);
        {
            yaml_builder_set_member_name(builder, "timeout");
            yaml_builder_add_int_value(builder, 30);

            yaml_builder_set_member_name(builder, "retries");
            yaml_builder_add_int_value(builder, 3);
        }
        yaml_builder_end_mapping(builder);

        /* Reference with alias */
        yaml_builder_set_member_name(builder, "production");
        yaml_builder_add_alias(builder, "defaults");

        yaml_builder_set_member_name(builder, "staging");
        yaml_builder_add_alias(builder, "defaults");
    }
    yaml_builder_end_mapping(builder);

    return yaml_builder_steal_root(builder);
}
```

**Output:**
```yaml
defaults: &defaults
  timeout: 30
  retries: 3
production: *defaults
staging: *defaults
```

### Using Tags

```c
YamlNode *
build_with_tags(void)
{
    g_autoptr(YamlBuilder) builder = yaml_builder_new();

    yaml_builder_begin_mapping(builder);
    {
        /* Add a tagged value */
        yaml_builder_set_member_name(builder, "timestamp");
        yaml_builder_set_tag(builder, "!timestamp");
        yaml_builder_add_string_value(builder, "2024-01-15T10:30:00Z");

        /* Custom application tag */
        yaml_builder_set_member_name(builder, "user");
        yaml_builder_set_tag(builder, "!app/user");
        yaml_builder_begin_mapping(builder);
        {
            yaml_builder_set_member_name(builder, "id");
            yaml_builder_add_int_value(builder, 123);
        }
        yaml_builder_end_mapping(builder);
    }
    yaml_builder_end_mapping(builder);

    return yaml_builder_steal_root(builder);
}
```

## Direct Construction

For simpler cases, create nodes directly:

### Simple Scalars

```c
void
create_scalars(void)
{
    /* String */
    g_autoptr(YamlNode) str = yaml_node_new_string("hello");

    /* Integer */
    g_autoptr(YamlNode) num = yaml_node_new_int(42);

    /* Double */
    g_autoptr(YamlNode) dbl = yaml_node_new_double(3.14);

    /* Boolean */
    g_autoptr(YamlNode) flag = yaml_node_new_boolean(TRUE);

    /* Null */
    g_autoptr(YamlNode) null = yaml_node_new_null();
}
```

### Building Mappings Directly

```c
YamlNode *
build_mapping_direct(void)
{
    g_autoptr(YamlMapping) mapping = yaml_mapping_new();

    /* Set various member types */
    yaml_mapping_set_string_member(mapping, "name", "Direct Build");
    yaml_mapping_set_int_member(mapping, "count", 100);
    yaml_mapping_set_double_member(mapping, "ratio", 0.75);
    yaml_mapping_set_boolean_member(mapping, "active", TRUE);
    yaml_mapping_set_null_member(mapping, "optional");

    /* Nested mapping */
    g_autoptr(YamlMapping) nested = yaml_mapping_new();
    yaml_mapping_set_string_member(nested, "key", "value");
    yaml_mapping_set_mapping_member(mapping, "nested", nested);

    /* Nested sequence */
    g_autoptr(YamlSequence) list = yaml_sequence_new();
    yaml_sequence_add_string_element(list, "item1");
    yaml_sequence_add_string_element(list, "item2");
    yaml_mapping_set_sequence_member(mapping, "items", list);

    return yaml_node_new_mapping(mapping);
}
```

### Building Sequences Directly

```c
YamlNode *
build_sequence_direct(void)
{
    g_autoptr(YamlSequence) sequence = yaml_sequence_new();

    /* Add various element types */
    yaml_sequence_add_string_element(sequence, "first");
    yaml_sequence_add_int_element(sequence, 42);
    yaml_sequence_add_double_element(sequence, 3.14);
    yaml_sequence_add_boolean_element(sequence, TRUE);
    yaml_sequence_add_null_element(sequence);

    /* Add a nested mapping */
    g_autoptr(YamlMapping) item = yaml_mapping_new();
    yaml_mapping_set_string_member(item, "type", "special");
    yaml_sequence_add_mapping_element(sequence, item);

    return yaml_node_new_sequence(sequence);
}
```

## Building Immutable Structures

For thread-safe sharing:

```c
YamlNode *
build_immutable_config(void)
{
    /* Create immutable builder */
    g_autoptr(YamlBuilder) builder = yaml_builder_new_immutable();

    yaml_builder_begin_mapping(builder);
    {
        yaml_builder_set_member_name(builder, "shared");
        yaml_builder_add_string_value(builder, "config");
    }
    yaml_builder_end_mapping(builder);

    YamlNode *root = yaml_builder_steal_root(builder);

    /* Verify immutability */
    g_assert(yaml_node_is_immutable(root));

    return root;
}

/* Or seal after building */
YamlNode *
build_then_seal(void)
{
    g_autoptr(YamlBuilder) builder = yaml_builder_new();

    yaml_builder_begin_mapping(builder);
    {
        yaml_builder_set_member_name(builder, "data");
        yaml_builder_add_string_value(builder, "value");
    }
    yaml_builder_end_mapping(builder);

    YamlNode *root = yaml_builder_steal_root(builder);

    /* Seal the entire tree */
    yaml_node_seal(root);

    return root;
}
```

## Generating Output

Convert built structures to YAML text:

```c
gchar *
generate_yaml(YamlNode *root)
{
    g_autoptr(YamlGenerator) gen = yaml_generator_new();
    g_autoptr(GError) error = NULL;

    yaml_generator_set_root(gen, root);
    yaml_generator_set_indent(gen, 2);

    gchar *output = yaml_generator_to_data(gen, NULL, &error);
    if (output == NULL)
    {
        g_printerr("Error: %s\n", error->message);
        return NULL;
    }

    return output;
}

void
write_yaml_file(YamlNode *root, const gchar *filename)
{
    g_autoptr(YamlGenerator) gen = yaml_generator_new();
    g_autoptr(GError) error = NULL;

    yaml_generator_set_root(gen, root);
    yaml_generator_set_indent(gen, 4);
    yaml_generator_set_explicit_start(gen, TRUE);

    if (!yaml_generator_to_file(gen, filename, &error))
    {
        g_printerr("Error: %s\n", error->message);
    }
}
```

## Building from Data Structures

### From GList

```c
YamlNode *
build_from_string_list(GList *strings)
{
    g_autoptr(YamlBuilder) builder = yaml_builder_new();

    yaml_builder_begin_sequence(builder);
    for (GList *l = strings; l != NULL; l = l->next)
    {
        yaml_builder_add_string_value(builder, (const gchar *)l->data);
    }
    yaml_builder_end_sequence(builder);

    return yaml_builder_steal_root(builder);
}
```

### From GPtrArray

```c
YamlNode *
build_from_array(GPtrArray *items)
{
    g_autoptr(YamlSequence) seq = yaml_sequence_new();

    for (guint i = 0; i < items->len; i++)
    {
        const gchar *item = g_ptr_array_index(items, i);
        yaml_sequence_add_string_element(seq, item);
    }

    return yaml_node_new_sequence(seq);
}
```

### From GHashTable

```c
YamlNode *
build_from_hash_table(GHashTable *table)
{
    g_autoptr(YamlMapping) mapping = yaml_mapping_new();

    GHashTableIter iter;
    gpointer key, value;

    g_hash_table_iter_init(&iter, table);
    while (g_hash_table_iter_next(&iter, &key, &value))
    {
        yaml_mapping_set_string_member(mapping,
                                       (const gchar *)key,
                                       (const gchar *)value);
    }

    return yaml_node_new_mapping(mapping);
}
```

## Complete Example

```c
#include <yaml-glib/yaml-glib.h>

typedef struct {
    const gchar *name;
    gint         port;
    gboolean     ssl;
} ServerConfig;

typedef struct {
    const gchar  *app_name;
    const gchar  *version;
    gboolean      debug;
    ServerConfig  server;
    gchar       **features;
} AppConfig;

YamlNode *
build_app_config(const AppConfig *config)
{
    g_autoptr(YamlBuilder) builder = yaml_builder_new();

    yaml_builder_begin_mapping(builder);
    {
        /* Basic properties */
        yaml_builder_set_member_name(builder, "name");
        yaml_builder_add_string_value(builder, config->app_name);

        yaml_builder_set_member_name(builder, "version");
        yaml_builder_add_string_value(builder, config->version);

        yaml_builder_set_member_name(builder, "debug");
        yaml_builder_add_boolean_value(builder, config->debug);

        /* Nested server config */
        yaml_builder_set_member_name(builder, "server");
        yaml_builder_begin_mapping(builder);
        {
            yaml_builder_set_member_name(builder, "name");
            yaml_builder_add_string_value(builder, config->server.name);

            yaml_builder_set_member_name(builder, "port");
            yaml_builder_add_int_value(builder, config->server.port);

            yaml_builder_set_member_name(builder, "ssl");
            yaml_builder_add_boolean_value(builder, config->server.ssl);
        }
        yaml_builder_end_mapping(builder);

        /* Features array */
        if (config->features != NULL)
        {
            yaml_builder_set_member_name(builder, "features");
            yaml_builder_begin_sequence(builder);
            for (gchar **f = config->features; *f != NULL; f++)
            {
                yaml_builder_add_string_value(builder, *f);
            }
            yaml_builder_end_sequence(builder);
        }
    }
    yaml_builder_end_mapping(builder);

    return yaml_builder_steal_root(builder);
}

int
main(void)
{
    gchar *features[] = { "logging", "metrics", "caching", NULL };

    AppConfig config = {
        .app_name = "MyApp",
        .version = "2.0.0",
        .debug = FALSE,
        .server = {
            .name = "production",
            .port = 443,
            .ssl = TRUE
        },
        .features = features
    };

    g_autoptr(YamlNode) root = build_app_config(&config);

    /* Generate YAML */
    g_autoptr(YamlGenerator) gen = yaml_generator_new();
    yaml_generator_set_root(gen, root);
    yaml_generator_set_indent(gen, 2);
    yaml_generator_set_explicit_start(gen, TRUE);

    g_autofree gchar *yaml = yaml_generator_to_data(gen, NULL, NULL);
    g_print("%s", yaml);

    return 0;
}
```

**Output:**
```yaml
---
name: MyApp
version: 2.0.0
debug: false
server:
  name: production
  port: 443
  ssl: true
features:
  - logging
  - metrics
  - caching
```

## Best Practices

1. **Use g_autoptr** - Let automatic cleanup handle memory management
2. **Match begin/end** - Every `begin_*` needs a corresponding `end_*`
3. **Set member name first** - In mappings, always call `set_member_name` before adding a value
4. **Steal the root** - Use `steal_root` to take ownership of the built structure
5. **Reset for reuse** - Call `yaml_builder_reset` to reuse a builder

## See Also

- [YamlBuilder API](../api/builder.md) - Complete API reference
- [YamlGenerator API](../api/generator.md) - Output generation
- [YamlMapping API](../api/mapping.md) - Mapping operations
- [YamlSequence API](../api/sequence.md) - Sequence operations
