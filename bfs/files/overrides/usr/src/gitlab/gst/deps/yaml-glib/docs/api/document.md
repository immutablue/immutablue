# YamlDocument API Reference

`YamlDocument` represents a single YAML document with its root node and directives.

## Overview

```c
#include <yaml-glib/yaml-glib.h>

#define YAML_TYPE_DOCUMENT (yaml_document_get_type())

G_DECLARE_DERIVABLE_TYPE(YamlDocument, yaml_document, YAML, DOCUMENT, GObject)
```

`YamlDocument` is a GObject that wraps a root node and optional YAML directives (version, tags). Use `g_object_unref()` to free.

## Type Definition

```c
typedef struct _YamlDocument YamlDocument;

struct _YamlDocumentClass
{
    GObjectClass parent_class;
    gpointer _reserved[8];
};
```

## Construction

### yaml_document_new

```c
YamlDocument *yaml_document_new(void);
```

Creates a new empty `YamlDocument`.

**Returns:** `(transfer full)` A new `YamlDocument`.

**Example:**
```c
g_autoptr(YamlDocument) doc = yaml_document_new();
g_autoptr(YamlNode) root = yaml_node_new_mapping(NULL);
yaml_document_set_root(doc, root);
```

---

### yaml_document_new_with_root

```c
YamlDocument *yaml_document_new_with_root(YamlNode *root);
```

Creates a new `YamlDocument` with the specified root node.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| root | `YamlNode *` | The root node |

**Returns:** `(transfer full)` A new `YamlDocument`.

**Example:**
```c
g_autoptr(YamlNode) root = yaml_node_new_string("Hello");
g_autoptr(YamlDocument) doc = yaml_document_new_with_root(root);
```

---

## Root Node Access

### yaml_document_set_root

```c
void yaml_document_set_root(YamlDocument *document, YamlNode *root);
```

Sets the root node.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| document | `YamlDocument *` | A document |
| root | `YamlNode *` `(nullable)` | The root node, or `NULL` |

---

### yaml_document_get_root

```c
YamlNode *yaml_document_get_root(YamlDocument *document);
```

Gets the root node.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| document | `YamlDocument *` | A document |

**Returns:** `(transfer none) (nullable)` The root node, or `NULL`.

---

### yaml_document_dup_root

```c
YamlNode *yaml_document_dup_root(YamlDocument *document);
```

Gets a new reference to the root node.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| document | `YamlDocument *` | A document |

**Returns:** `(transfer full) (nullable)` A new reference to the root, or `NULL`. Free with `yaml_node_unref()`.

---

### yaml_document_steal_root

```c
YamlNode *yaml_document_steal_root(YamlDocument *document);
```

Steals the root node, leaving the document empty.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| document | `YamlDocument *` | A document |

**Returns:** `(transfer full) (nullable)` The root node, or `NULL`.

---

## Immutability

### yaml_document_seal

```c
void yaml_document_seal(YamlDocument *document);
```

Makes the document and its root node immutable.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| document | `YamlDocument *` | A document |

---

### yaml_document_is_immutable

```c
gboolean yaml_document_is_immutable(YamlDocument *document);
```

Checks whether the document is immutable.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| document | `YamlDocument *` | A document |

**Returns:** `TRUE` if the document is immutable.

---

## Version Directives

### yaml_document_set_version

```c
void yaml_document_set_version(YamlDocument *document, guint major, guint minor);
```

Sets the YAML version directive. Common values are (1, 1) for YAML 1.1 and (1, 2) for YAML 1.2.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| document | `YamlDocument *` | A document |
| major | `guint` | The major version |
| minor | `guint` | The minor version |

**Example:**
```c
yaml_document_set_version(doc, 1, 2);  /* YAML 1.2 */
```

---

### yaml_document_get_version

```c
void yaml_document_get_version(YamlDocument *document, guint *major, guint *minor);
```

Gets the YAML version directive.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| document | `YamlDocument *` | A document |
| major | `guint *` `(out) (optional)` | Location for major version |
| minor | `guint *` `(out) (optional)` | Location for minor version |

---

## Tag Directives

### yaml_document_add_tag_directive

```c
void yaml_document_add_tag_directive(
    YamlDocument *document,
    const gchar  *handle,
    const gchar  *prefix
);
```

Adds a tag directive.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| document | `YamlDocument *` | A document |
| handle | `const gchar *` | The tag handle (e.g., "!e!") |
| prefix | `const gchar *` | The tag prefix (e.g., "tag:example.com,2024:") |

**Example:**
```c
yaml_document_add_tag_directive(doc, "!app!", "tag:myapp.example.com,2024:");
/* Now you can use !app!type instead of !<tag:myapp.example.com,2024:type> */
```

---

### yaml_document_get_tag_directives

```c
GHashTable *yaml_document_get_tag_directives(YamlDocument *document);
```

Gets all tag directives.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| document | `YamlDocument *` | A document |

**Returns:** `(transfer none) (element-type utf8 utf8)` A hash table mapping handles to prefixes. Do not modify.

---

## JSON Interoperability

### yaml_document_from_json_node

```c
YamlDocument *yaml_document_from_json_node(JsonNode *json_node);
```

Creates a `YamlDocument` from a `JsonNode`.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| json_node | `JsonNode *` | A JSON-GLib node |

**Returns:** `(transfer full)` A new `YamlDocument`.

---

### yaml_document_to_json_node

```c
JsonNode *yaml_document_to_json_node(YamlDocument *document);
```

Converts the document to a `JsonNode`.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| document | `YamlDocument *` | A document |

**Returns:** `(transfer full) (nullable)` A new `JsonNode`, or `NULL`.

---

## Complete Example

```c
#include <yaml-glib/yaml-glib.h>

int main(void)
{
    g_autoptr(YamlDocument) doc = NULL;
    g_autoptr(YamlMapping) mapping = NULL;
    g_autoptr(YamlNode) root = NULL;
    g_autoptr(YamlGenerator) gen = NULL;
    g_autoptr(GError) error = NULL;
    g_autofree gchar *output = NULL;

    /* Create document with version directive */
    doc = yaml_document_new();
    yaml_document_set_version(doc, 1, 2);
    yaml_document_add_tag_directive(doc, "!app!", "tag:myapp.com,2024:");

    /* Create root node */
    mapping = yaml_mapping_new();
    yaml_mapping_set_string_member(mapping, "name", "My Application");
    yaml_mapping_set_string_member(mapping, "version", "1.0.0");

    root = yaml_node_new_mapping(mapping);
    yaml_document_set_root(doc, root);

    /* Generate YAML */
    gen = yaml_generator_new();
    yaml_generator_set_document(gen, doc);

    output = yaml_generator_to_data(gen, NULL, &error);
    if (output != NULL)
    {
        g_print("%s", output);
    }

    return 0;
}
```

## See Also

- [YamlParser](parser.md) - Parse documents from files/strings
- [YamlGenerator](generator.md) - Generate YAML output
- [YamlNode](node.md) - Generic container
