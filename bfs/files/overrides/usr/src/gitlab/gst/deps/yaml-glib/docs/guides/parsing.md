# Parsing YAML Guide

This guide covers parsing YAML content from various sources using yaml-glib.

## Overview

yaml-glib provides multiple ways to parse YAML:
- From file paths (synchronous)
- From GFile objects (synchronous and asynchronous)
- From strings/data
- From input streams (synchronous and asynchronous)

All parsing uses `YamlParser`, which produces `YamlDocument` objects containing `YamlNode` trees.

## Basic Parsing

### Parsing from a File

```c
#include <yaml-glib/yaml-glib.h>

gboolean
load_config_file(const gchar *filename)
{
    g_autoptr(YamlParser) parser = yaml_parser_new();
    g_autoptr(GError) error = NULL;

    if (!yaml_parser_load_from_file(parser, filename, &error))
    {
        g_printerr("Failed to load %s: %s\n", filename, error->message);
        return FALSE;
    }

    /* Get the root node of the first document */
    YamlNode *root = yaml_parser_get_root(parser);
    if (root == NULL)
    {
        g_printerr("Empty YAML file\n");
        return FALSE;
    }

    /* Process the root node */
    g_print("Loaded %s, root type: %d\n",
            filename, yaml_node_get_node_type(root));

    return TRUE;
}
```

### Parsing from a String

```c
gboolean
parse_yaml_string(const gchar *yaml_content)
{
    g_autoptr(YamlParser) parser = yaml_parser_new();
    g_autoptr(GError) error = NULL;

    /* Parse the string (-1 means null-terminated) */
    if (!yaml_parser_load_from_data(parser, yaml_content, -1, &error))
    {
        g_printerr("Parse error: %s\n", error->message);
        return FALSE;
    }

    YamlNode *root = yaml_parser_get_root(parser);
    return (root != NULL);
}

/* Example usage */
void
example(void)
{
    const gchar *yaml =
        "name: My Application\n"
        "version: 1.0.0\n"
        "features:\n"
        "  - logging\n"
        "  - caching\n";

    parse_yaml_string(yaml);
}
```

## Working with Parsed Data

### Accessing Mapping Properties

```c
void
process_config(YamlNode *root)
{
    /* Verify it's a mapping */
    if (yaml_node_get_node_type(root) != YAML_NODE_MAPPING)
    {
        g_printerr("Expected a mapping at root\n");
        return;
    }

    YamlMapping *config = yaml_node_get_mapping(root);

    /* Get string property */
    const gchar *name = yaml_mapping_get_string_member(config, "name");
    g_print("Name: %s\n", name ? name : "(not set)");

    /* Get integer property with default */
    gint64 port = yaml_mapping_get_int_member_with_default(config, "port", 8080);
    g_print("Port: %" G_GINT64_FORMAT "\n", port);

    /* Get boolean property */
    gboolean debug = yaml_mapping_get_boolean_member(config, "debug");
    g_print("Debug: %s\n", debug ? "yes" : "no");

    /* Check if property exists */
    if (yaml_mapping_has_member(config, "database"))
    {
        YamlNode *db_node = yaml_mapping_get_member(config, "database");
        /* Process nested database config */
    }
}
```

### Iterating Over Sequences

```c
void
process_features(YamlNode *root)
{
    YamlMapping *config = yaml_node_get_mapping(root);
    YamlNode *features_node = yaml_mapping_get_member(config, "features");

    if (features_node == NULL)
    {
        g_print("No features defined\n");
        return;
    }

    if (yaml_node_get_node_type(features_node) != YAML_NODE_SEQUENCE)
    {
        g_printerr("Expected 'features' to be a sequence\n");
        return;
    }

    YamlSequence *features = yaml_node_get_sequence(features_node);
    guint n_features = yaml_sequence_get_length(features);

    g_print("Found %u features:\n", n_features);

    for (guint i = 0; i < n_features; i++)
    {
        /* Get as string directly */
        const gchar *feature = yaml_sequence_get_string_element(features, i);
        g_print("  - %s\n", feature);
    }
}
```

### Using Iterators

```c
void
iterate_mapping(YamlMapping *mapping)
{
    YamlMappingIter iter;

    yaml_mapping_iter_init(&iter, mapping);

    const gchar *key;
    YamlNode *value;

    while (yaml_mapping_iter_next(&iter, &key, &value))
    {
        YamlNodeType type = yaml_node_get_node_type(value);
        g_print("Key: %s, Type: %d\n", key, type);

        if (type == YAML_NODE_SCALAR)
        {
            g_print("  Value: %s\n", yaml_node_get_string(value));
        }
    }
}

void
iterate_sequence(YamlSequence *sequence)
{
    YamlSequenceIter iter;

    yaml_sequence_iter_init(&iter, sequence);

    YamlNode *element;

    while (yaml_sequence_iter_next(&iter, &element))
    {
        g_print("Element type: %d\n", yaml_node_get_node_type(element));
    }
}
```

## Multi-Document Parsing

YAML supports multiple documents in a single stream, separated by `---`.

```c
void
parse_multi_document(const gchar *filename)
{
    g_autoptr(YamlParser) parser = yaml_parser_new();
    g_autoptr(GError) error = NULL;

    if (!yaml_parser_load_from_file(parser, filename, &error))
    {
        g_printerr("Error: %s\n", error->message);
        return;
    }

    guint n_docs = yaml_parser_get_n_documents(parser);
    g_print("Parsed %u documents\n", n_docs);

    for (guint i = 0; i < n_docs; i++)
    {
        YamlDocument *doc = yaml_parser_get_document(parser, i);
        YamlNode *root = yaml_document_get_root(doc);

        g_print("Document %u:\n", i);
        g_print("  Root type: %d\n", yaml_node_get_node_type(root));

        /* Check for version directive */
        guint major, minor;
        yaml_document_get_version(doc, &major, &minor);
        if (major > 0)
        {
            g_print("  YAML version: %u.%u\n", major, minor);
        }
    }
}
```

## Parsing from GFile

For integration with GIO:

```c
void
parse_from_gfile(GFile *file)
{
    g_autoptr(YamlParser) parser = yaml_parser_new();
    g_autoptr(GError) error = NULL;

    if (!yaml_parser_load_from_gfile(parser, file, NULL, &error))
    {
        g_printerr("Error: %s\n", error->message);
        return;
    }

    YamlNode *root = yaml_parser_get_root(parser);
    /* Process root... */
}

/* From a URI */
void
parse_from_uri(const gchar *uri)
{
    g_autoptr(GFile) file = g_file_new_for_uri(uri);
    parse_from_gfile(file);
}
```

## Parsing from Streams

```c
void
parse_from_stream(GInputStream *stream)
{
    g_autoptr(YamlParser) parser = yaml_parser_new();
    g_autoptr(GError) error = NULL;

    if (!yaml_parser_load_from_stream(parser, stream, NULL, &error))
    {
        g_printerr("Error: %s\n", error->message);
        return;
    }

    YamlNode *root = yaml_parser_get_root(parser);
    /* Process root... */
}

/* Example: parse from memory stream */
void
example_memory_stream(void)
{
    const gchar *data = "key: value\n";
    g_autoptr(GInputStream) stream = g_memory_input_stream_new_from_data(
        data, -1, NULL
    );

    parse_from_stream(stream);
}
```

## Immutable Parsing

For thread-safe sharing of parsed data:

```c
YamlNode *
parse_immutable(const gchar *filename)
{
    /* Create immutable parser */
    g_autoptr(YamlParser) parser = yaml_parser_new_immutable();
    g_autoptr(GError) error = NULL;

    if (!yaml_parser_load_from_file(parser, filename, &error))
    {
        g_printerr("Error: %s\n", error->message);
        return NULL;
    }

    /* Steal root - it's sealed and safe to share between threads */
    YamlNode *root = yaml_parser_steal_root(parser);

    /* Verify it's immutable */
    g_assert(yaml_node_is_immutable(root));

    return root;
}

/* Or set immutability on existing parser */
void
example_set_immutable(void)
{
    g_autoptr(YamlParser) parser = yaml_parser_new();
    yaml_parser_set_immutable(parser, TRUE);

    /* Now parsed documents will be sealed */
}
```

## Error Handling

```c
void
robust_parsing(const gchar *filename)
{
    g_autoptr(YamlParser) parser = yaml_parser_new();
    g_autoptr(GError) error = NULL;

    if (!yaml_parser_load_from_file(parser, filename, &error))
    {
        /* Check error domain and code */
        if (g_error_matches(error, G_FILE_ERROR, G_FILE_ERROR_NOENT))
        {
            g_printerr("File not found: %s\n", filename);
        }
        else if (error->domain == YAML_GLIB_PARSER_ERROR)
        {
            /* Get position information */
            guint line = yaml_parser_get_current_line(parser);
            guint col = yaml_parser_get_current_column(parser);

            g_printerr("YAML syntax error at line %u, column %u: %s\n",
                       line, col, error->message);
        }
        else
        {
            g_printerr("Error: %s\n", error->message);
        }
        return;
    }

    /* Success */
}
```

## Type-Safe Access Pattern

A pattern for safely extracting expected structures:

```c
typedef struct {
    gchar *name;
    gint   port;
    gchar *host;
} ServerConfig;

gboolean
parse_server_config(YamlNode      *node,
                    ServerConfig  *config,
                    GError       **error)
{
    if (yaml_node_get_node_type(node) != YAML_NODE_MAPPING)
    {
        g_set_error(error, YAML_SCHEMA_ERROR,
                    YAML_SCHEMA_ERROR_TYPE_MISMATCH,
                    "Expected mapping for server config");
        return FALSE;
    }

    YamlMapping *mapping = yaml_node_get_mapping(node);

    /* Required field */
    const gchar *name = yaml_mapping_get_string_member(mapping, "name");
    if (name == NULL)
    {
        g_set_error(error, YAML_SCHEMA_ERROR,
                    YAML_SCHEMA_ERROR_MISSING_REQUIRED,
                    "Missing required field 'name'");
        return FALSE;
    }
    config->name = g_strdup(name);

    /* Optional fields with defaults */
    const gchar *host = yaml_mapping_get_string_member(mapping, "host");
    config->host = g_strdup(host ? host : "localhost");

    config->port = (gint)yaml_mapping_get_int_member_with_default(
        mapping, "port", 8080
    );

    return TRUE;
}

void
free_server_config(ServerConfig *config)
{
    g_free(config->name);
    g_free(config->host);
}
```

## Reusing the Parser

```c
void
parse_multiple_files(gchar **filenames, guint n_files)
{
    g_autoptr(YamlParser) parser = yaml_parser_new();
    g_autoptr(GError) error = NULL;

    for (guint i = 0; i < n_files; i++)
    {
        /* Reset clears previous documents */
        yaml_parser_reset(parser);

        if (!yaml_parser_load_from_file(parser, filenames[i], &error))
        {
            g_printerr("Error in %s: %s\n", filenames[i], error->message);
            g_clear_error(&error);
            continue;
        }

        YamlNode *root = yaml_parser_get_root(parser);
        g_print("Parsed %s: root type %d\n",
                filenames[i], yaml_node_get_node_type(root));
    }
}
```

## Complete Example

```c
#include <yaml-glib/yaml-glib.h>

typedef struct {
    gchar    *name;
    gchar    *version;
    gboolean  debug;
    gint      port;
    GPtrArray *features;
} AppConfig;

static void
app_config_free(AppConfig *config)
{
    g_free(config->name);
    g_free(config->version);
    g_ptr_array_unref(config->features);
    g_free(config);
}

G_DEFINE_AUTOPTR_CLEANUP_FUNC(AppConfig, app_config_free)

static AppConfig *
parse_app_config(const gchar *filename, GError **error)
{
    g_autoptr(YamlParser) parser = yaml_parser_new();

    if (!yaml_parser_load_from_file(parser, filename, error))
    {
        return NULL;
    }

    YamlNode *root = yaml_parser_get_root(parser);
    if (root == NULL || yaml_node_get_node_type(root) != YAML_NODE_MAPPING)
    {
        g_set_error(error, YAML_SCHEMA_ERROR,
                    YAML_SCHEMA_ERROR_TYPE_MISMATCH,
                    "Expected root to be a mapping");
        return NULL;
    }

    YamlMapping *mapping = yaml_node_get_mapping(root);

    /* Allocate config */
    AppConfig *config = g_new0(AppConfig, 1);
    config->features = g_ptr_array_new_with_free_func(g_free);

    /* Parse fields */
    const gchar *name = yaml_mapping_get_string_member(mapping, "name");
    if (name == NULL)
    {
        g_set_error(error, YAML_SCHEMA_ERROR,
                    YAML_SCHEMA_ERROR_MISSING_REQUIRED,
                    "Missing required field 'name'");
        app_config_free(config);
        return NULL;
    }
    config->name = g_strdup(name);

    const gchar *version = yaml_mapping_get_string_member(mapping, "version");
    config->version = g_strdup(version ? version : "1.0.0");

    config->debug = yaml_mapping_get_boolean_member(mapping, "debug");
    config->port = (gint)yaml_mapping_get_int_member_with_default(
        mapping, "port", 8080
    );

    /* Parse features array */
    YamlNode *features_node = yaml_mapping_get_member(mapping, "features");
    if (features_node != NULL &&
        yaml_node_get_node_type(features_node) == YAML_NODE_SEQUENCE)
    {
        YamlSequence *features = yaml_node_get_sequence(features_node);
        guint n = yaml_sequence_get_length(features);

        for (guint i = 0; i < n; i++)
        {
            const gchar *feature = yaml_sequence_get_string_element(features, i);
            if (feature != NULL)
            {
                g_ptr_array_add(config->features, g_strdup(feature));
            }
        }
    }

    return config;
}

int
main(int argc, char *argv[])
{
    if (argc < 2)
    {
        g_printerr("Usage: %s <config.yaml>\n", argv[0]);
        return 1;
    }

    g_autoptr(GError) error = NULL;
    g_autoptr(AppConfig) config = parse_app_config(argv[1], &error);

    if (config == NULL)
    {
        g_printerr("Error: %s\n", error->message);
        return 1;
    }

    g_print("Configuration:\n");
    g_print("  Name: %s\n", config->name);
    g_print("  Version: %s\n", config->version);
    g_print("  Debug: %s\n", config->debug ? "yes" : "no");
    g_print("  Port: %d\n", config->port);
    g_print("  Features (%u):\n", config->features->len);

    for (guint i = 0; i < config->features->len; i++)
    {
        g_print("    - %s\n", (gchar *)g_ptr_array_index(config->features, i));
    }

    return 0;
}
```

## See Also

- [YamlParser API](../api/parser.md) - Complete API reference
- [Async I/O Guide](async-io.md) - Asynchronous parsing
- [Schema Validation Guide](schema-validation.md) - Validating parsed content
- [Error Handling](../error-handling.md) - Error handling patterns
