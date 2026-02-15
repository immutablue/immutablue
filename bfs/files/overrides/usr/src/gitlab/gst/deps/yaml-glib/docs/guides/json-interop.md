# JSON-GLib Interoperability Guide

This guide covers converting between yaml-glib and JSON-GLib data structures.

## Overview

yaml-glib provides bidirectional conversion with JSON-GLib:

- Convert `YamlNode` to `JsonNode`
- Convert `JsonNode` to `YamlNode`
- Convert `YamlDocument` to/from JSON

This enables workflows where you parse YAML, convert to JSON for processing with JSON-based APIs, or vice versa.

## Node Conversion

### YAML to JSON

```c
#include <yaml-glib/yaml-glib.h>
#include <json-glib/json-glib.h>

JsonNode *
yaml_to_json(YamlNode *yaml_node)
{
    return yaml_node_to_json_node(yaml_node);
}

void
example_yaml_to_json(void)
{
    const gchar *yaml_str =
        "name: John Doe\n"
        "age: 30\n"
        "active: true\n"
        "tags:\n"
        "  - developer\n"
        "  - admin\n";

    /* Parse YAML */
    g_autoptr(YamlParser) parser = yaml_parser_new();
    yaml_parser_load_from_data(parser, yaml_str, -1, NULL);
    YamlNode *yaml_root = yaml_parser_get_root(parser);

    /* Convert to JSON */
    g_autoptr(JsonNode) json_root = yaml_node_to_json_node(yaml_root);

    /* Use with JSON-GLib APIs */
    g_autoptr(JsonGenerator) gen = json_generator_new();
    json_generator_set_root(gen, json_root);
    json_generator_set_pretty(gen, TRUE);

    g_autofree gchar *json_str = json_generator_to_data(gen, NULL);
    g_print("JSON:\n%s\n", json_str);
}
```

**Output:**
```json
{
  "name": "John Doe",
  "age": 30,
  "active": true,
  "tags": [
    "developer",
    "admin"
  ]
}
```

### JSON to YAML

```c
YamlNode *
json_to_yaml(JsonNode *json_node)
{
    return yaml_node_from_json_node(json_node);
}

void
example_json_to_yaml(void)
{
    const gchar *json_str =
        "{"
        "  \"name\": \"Jane Smith\","
        "  \"scores\": [95, 87, 92],"
        "  \"metadata\": {"
        "    \"created\": \"2024-01-15\""
        "  }"
        "}";

    /* Parse JSON */
    g_autoptr(JsonParser) json_parser = json_parser_new();
    json_parser_load_from_data(json_parser, json_str, -1, NULL);
    JsonNode *json_root = json_parser_get_root(json_parser);

    /* Convert to YAML */
    g_autoptr(YamlNode) yaml_root = yaml_node_from_json_node(json_root);

    /* Generate YAML output */
    g_autoptr(YamlGenerator) gen = yaml_generator_new();
    yaml_generator_set_root(gen, yaml_root);
    yaml_generator_set_indent(gen, 2);

    g_autofree gchar *yaml_str = yaml_generator_to_data(gen, NULL, NULL);
    g_print("YAML:\n%s\n", yaml_str);
}
```

**Output:**
```yaml
name: Jane Smith
scores:
  - 95
  - 87
  - 92
metadata:
  created: '2024-01-15'
```

## Document Conversion

### YamlDocument to JSON

```c
void
document_to_json(void)
{
    /* Parse YAML document */
    g_autoptr(YamlParser) parser = yaml_parser_new();
    yaml_parser_load_from_file(parser, "config.yaml", NULL);
    YamlDocument *doc = yaml_parser_get_document(parser, 0);

    /* Convert entire document to JSON */
    g_autoptr(JsonNode) json = yaml_document_to_json_node(doc);

    /* Process with JSON-GLib... */
}
```

### JSON to YamlDocument

```c
void
json_to_document(void)
{
    /* Parse JSON */
    g_autoptr(JsonParser) json_parser = json_parser_new();
    json_parser_load_from_file(json_parser, "data.json", NULL);
    JsonNode *json_root = json_parser_get_root(json_parser);

    /* Create YAML document from JSON */
    g_autoptr(YamlDocument) doc = yaml_document_from_json_node(json_root);

    /* Add YAML-specific features */
    yaml_document_set_version(doc, 1, 2);
    yaml_document_add_tag_directive(doc, "!app!", "tag:myapp.com,2024:");

    /* Generate YAML with directives */
    g_autoptr(YamlGenerator) gen = yaml_generator_new();
    yaml_generator_set_document(gen, doc);
    yaml_generator_set_explicit_start(gen, TRUE);

    g_autofree gchar *yaml = yaml_generator_to_data(gen, NULL, NULL);
    g_print("%s\n", yaml);
}
```

## Type Mappings

| YAML Type | JSON Type |
|-----------|-----------|
| Scalar (string) | String |
| Scalar (integer) | Number (integer) |
| Scalar (float) | Number (double) |
| Scalar (boolean) | Boolean |
| Scalar (null) | Null |
| Mapping | Object |
| Sequence | Array |

### Notes on Conversion

- **YAML anchors/aliases** are resolved during conversion
- **YAML tags** are not preserved in JSON (JSON has no tag concept)
- **YAML comments** are not preserved (neither format preserves comments in the tree)
- **Multi-document YAML** requires converting each document separately
- **Binary data** in YAML is converted to base64 strings

## Practical Use Cases

### Configuration Migration

Convert JSON configs to YAML:

```c
gboolean
migrate_json_to_yaml(const gchar *json_file, const gchar *yaml_file)
{
    g_autoptr(JsonParser) json_parser = json_parser_new();
    g_autoptr(GError) error = NULL;

    if (!json_parser_load_from_file(json_parser, json_file, &error))
    {
        g_printerr("Error loading JSON: %s\n", error->message);
        return FALSE;
    }

    JsonNode *json_root = json_parser_get_root(json_parser);
    g_autoptr(YamlNode) yaml_root = yaml_node_from_json_node(json_root);

    g_autoptr(YamlGenerator) gen = yaml_generator_new();
    yaml_generator_set_root(gen, yaml_root);
    yaml_generator_set_indent(gen, 2);
    yaml_generator_set_explicit_start(gen, TRUE);

    if (!yaml_generator_to_file(gen, yaml_file, &error))
    {
        g_printerr("Error writing YAML: %s\n", error->message);
        return FALSE;
    }

    return TRUE;
}
```

### API Response Handling

Parse JSON API responses, convert to YAML for configuration:

```c
YamlNode *
process_api_response(const gchar *json_response)
{
    g_autoptr(JsonParser) parser = json_parser_new();

    if (!json_parser_load_from_data(parser, json_response, -1, NULL))
    {
        return NULL;
    }

    JsonNode *root = json_parser_get_root(parser);
    return yaml_node_from_json_node(root);
}
```

### Schema Conversion

```c
void
convert_json_schema_to_yaml(void)
{
    const gchar *json_schema =
        "{"
        "  \"type\": \"object\","
        "  \"properties\": {"
        "    \"name\": { \"type\": \"string\" },"
        "    \"port\": { \"type\": \"integer\", \"minimum\": 1 }"
        "  },"
        "  \"required\": [\"name\"]"
        "}";

    g_autoptr(JsonParser) parser = json_parser_new();
    json_parser_load_from_data(parser, json_schema, -1, NULL);

    g_autoptr(YamlNode) yaml = yaml_node_from_json_node(
        json_parser_get_root(parser)
    );

    g_autoptr(YamlGenerator) gen = yaml_generator_new();
    yaml_generator_set_root(gen, yaml);
    yaml_generator_set_indent(gen, 2);

    g_autofree gchar *output = yaml_generator_to_data(gen, NULL, NULL);
    g_print("%s\n", output);
}
```

**Output:**
```yaml
type: object
properties:
  name:
    type: string
  port:
    type: integer
    minimum: 1
required:
  - name
```

## Working with JSON-GLib Objects

### Converting JsonObject to YamlMapping

```c
YamlMapping *
json_object_to_yaml_mapping(JsonObject *obj)
{
    g_autoptr(JsonNode) node = json_node_new(JSON_NODE_OBJECT);
    json_node_set_object(node, obj);

    g_autoptr(YamlNode) yaml = yaml_node_from_json_node(node);
    return yaml_node_dup_mapping(yaml);
}
```

### Converting JsonArray to YamlSequence

```c
YamlSequence *
json_array_to_yaml_sequence(JsonArray *arr)
{
    g_autoptr(JsonNode) node = json_node_new(JSON_NODE_ARRAY);
    json_node_set_array(node, arr);

    g_autoptr(YamlNode) yaml = yaml_node_from_json_node(node);
    return yaml_node_dup_sequence(yaml);
}
```

## Complete Example

```c
#include <yaml-glib/yaml-glib.h>
#include <json-glib/json-glib.h>

/* Convert a JSON API response to a YAML config file */
gboolean
api_to_config(const gchar *api_response,
              const gchar *config_file)
{
    g_autoptr(GError) error = NULL;

    /* Parse JSON response */
    g_autoptr(JsonParser) json_parser = json_parser_new();
    if (!json_parser_load_from_data(json_parser, api_response, -1, &error))
    {
        g_printerr("JSON parse error: %s\n", error->message);
        return FALSE;
    }

    JsonNode *json_root = json_parser_get_root(json_parser);

    /* Convert to YAML */
    g_autoptr(YamlNode) yaml_root = yaml_node_from_json_node(json_root);
    if (yaml_root == NULL)
    {
        g_printerr("Conversion failed\n");
        return FALSE;
    }

    /* Create document with YAML features */
    g_autoptr(YamlDocument) doc = yaml_document_new_with_root(yaml_root);
    yaml_document_set_version(doc, 1, 2);

    /* Generate YAML file */
    g_autoptr(YamlGenerator) gen = yaml_generator_new();
    yaml_generator_set_document(gen, doc);
    yaml_generator_set_indent(gen, 2);
    yaml_generator_set_explicit_start(gen, TRUE);
    yaml_generator_set_unicode(gen, TRUE);

    if (!yaml_generator_to_file(gen, config_file, &error))
    {
        g_printerr("Write error: %s\n", error->message);
        return FALSE;
    }

    g_print("Converted API response to %s\n", config_file);
    return TRUE;
}

/* Convert YAML config to JSON for an API request */
gchar *
config_to_api_request(const gchar *config_file)
{
    g_autoptr(GError) error = NULL;

    /* Parse YAML config */
    g_autoptr(YamlParser) yaml_parser = yaml_parser_new();
    if (!yaml_parser_load_from_file(yaml_parser, config_file, &error))
    {
        g_printerr("YAML parse error: %s\n", error->message);
        return NULL;
    }

    YamlNode *yaml_root = yaml_parser_get_root(yaml_parser);

    /* Convert to JSON */
    g_autoptr(JsonNode) json_root = yaml_node_to_json_node(yaml_root);

    /* Generate JSON string */
    g_autoptr(JsonGenerator) gen = json_generator_new();
    json_generator_set_root(gen, json_root);

    return json_generator_to_data(gen, NULL);
}

int
main(int argc, char *argv[])
{
    /* Example: JSON API response */
    const gchar *api_response =
        "{"
        "  \"server\": {"
        "    \"host\": \"api.example.com\","
        "    \"port\": 443,"
        "    \"ssl\": true"
        "  },"
        "  \"endpoints\": ["
        "    \"/users\","
        "    \"/posts\","
        "    \"/comments\""
        "  ]"
        "}";

    /* Convert to YAML config */
    api_to_config(api_response, "/tmp/config.yaml");

    /* Read it back as JSON */
    g_autofree gchar *json = config_to_api_request("/tmp/config.yaml");
    g_print("JSON:\n%s\n", json);

    return 0;
}
```

## See Also

- [YamlNode API](../api/node.md) - Node conversion functions
- [YamlDocument API](../api/document.md) - Document conversion
- [JSON-GLib Documentation](https://gnome.pages.gitlab.gnome.org/json-glib/)
