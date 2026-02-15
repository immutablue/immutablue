# YamlParser API Reference

`YamlParser` parses YAML content from files, strings, or streams into document objects.

## Overview

```c
#include <yaml-glib/yaml-glib.h>

#define YAML_TYPE_PARSER (yaml_parser_get_type())

G_DECLARE_DERIVABLE_TYPE(YamlParser, yaml_parser, YAML, PARSER, GObject)
```

`YamlParser` is a GObject that wraps libyaml's parser. It supports:
- Parsing from files, strings, and streams
- Synchronous and asynchronous operations
- Multi-document YAML streams
- Immutable document generation

## Class Structure

```c
struct _YamlParserClass
{
    GObjectClass parent_class;

    /* Signals */
    void (* parse_start)    (YamlParser   *parser);
    void (* document_start) (YamlParser   *parser);
    void (* document_end)   (YamlParser   *parser,
                             YamlDocument *document);
    void (* parse_end)      (YamlParser   *parser);
    void (* error)          (YamlParser   *parser,
                             const GError *error);

    gpointer _reserved[8];
};
```

## Construction

### yaml_parser_new

```c
YamlParser *yaml_parser_new(void);
```

Creates a new `YamlParser`. Parsed documents are mutable.

**Returns:** `(transfer full)` A new `YamlParser`.

**Example:**
```c
g_autoptr(YamlParser) parser = yaml_parser_new();
```

---

### yaml_parser_new_immutable

```c
YamlParser *yaml_parser_new_immutable(void);
```

Creates a parser that produces immutable documents. Immutable documents are sealed after parsing.

**Returns:** `(transfer full)` A new `YamlParser`.

**Example:**
```c
/* For thread-safe sharing of parsed data */
g_autoptr(YamlParser) parser = yaml_parser_new_immutable();
```

---

## Immutability Settings

### yaml_parser_get_immutable

```c
gboolean yaml_parser_get_immutable(YamlParser *parser);
```

Checks whether the parser produces immutable documents.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| parser | `YamlParser *` | A parser |

**Returns:** `TRUE` if documents are immutable.

---

### yaml_parser_set_immutable

```c
void yaml_parser_set_immutable(YamlParser *parser, gboolean immutable);
```

Sets whether to produce immutable documents.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| parser | `YamlParser *` | A parser |
| immutable | `gboolean` | Whether to produce immutable documents |

---

## Synchronous Loading

### yaml_parser_load_from_file

```c
gboolean yaml_parser_load_from_file(
    YamlParser   *parser,
    const gchar  *filename,
    GError      **error
);
```

Loads YAML content from a file path.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| parser | `YamlParser *` | A parser |
| filename | `const gchar *` | Path to the file |
| error | `GError **` `(nullable)` | Return location for error |

**Returns:** `TRUE` on success.

**Example:**
```c
g_autoptr(YamlParser) parser = yaml_parser_new();
g_autoptr(GError) error = NULL;

if (!yaml_parser_load_from_file(parser, "config.yaml", &error))
{
    g_printerr("Error: %s\n", error->message);
    return;
}

YamlNode *root = yaml_parser_get_root(parser);
```

---

### yaml_parser_load_from_gfile

```c
gboolean yaml_parser_load_from_gfile(
    YamlParser   *parser,
    GFile        *file,
    GCancellable *cancellable,
    GError      **error
);
```

Loads YAML content from a `GFile`.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| parser | `YamlParser *` | A parser |
| file | `GFile *` | A GFile |
| cancellable | `GCancellable *` `(nullable)` | A cancellable |
| error | `GError **` `(nullable)` | Return location for error |

**Returns:** `TRUE` on success.

---

### yaml_parser_load_from_data

```c
gboolean yaml_parser_load_from_data(
    YamlParser   *parser,
    const gchar  *data,
    gssize        length,
    GError      **error
);
```

Loads YAML content from a string.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| parser | `YamlParser *` | A parser |
| data | `const gchar *` | The YAML data |
| length | `gssize` | Length of data, or -1 if null-terminated |
| error | `GError **` `(nullable)` | Return location for error |

**Returns:** `TRUE` on success.

**Example:**
```c
const gchar *yaml_str = "name: John\nage: 30\n";

g_autoptr(YamlParser) parser = yaml_parser_new();
yaml_parser_load_from_data(parser, yaml_str, -1, NULL);

YamlNode *root = yaml_parser_get_root(parser);
YamlMapping *mapping = yaml_node_get_mapping(root);
g_print("Name: %s\n", yaml_mapping_get_string_member(mapping, "name"));
```

---

### yaml_parser_load_from_stream

```c
gboolean yaml_parser_load_from_stream(
    YamlParser   *parser,
    GInputStream *stream,
    GCancellable *cancellable,
    GError      **error
);
```

Loads YAML content from an input stream.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| parser | `YamlParser *` | A parser |
| stream | `GInputStream *` | An input stream |
| cancellable | `GCancellable *` `(nullable)` | A cancellable |
| error | `GError **` `(nullable)` | Return location for error |

**Returns:** `TRUE` on success.

---

## Asynchronous Loading

### yaml_parser_load_from_stream_async

```c
void yaml_parser_load_from_stream_async(
    YamlParser          *parser,
    GInputStream        *stream,
    GCancellable        *cancellable,
    GAsyncReadyCallback  callback,
    gpointer             user_data
);
```

Asynchronously loads YAML from an input stream.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| parser | `YamlParser *` | A parser |
| stream | `GInputStream *` | An input stream |
| cancellable | `GCancellable *` `(nullable)` | A cancellable |
| callback | `GAsyncReadyCallback` | Completion callback |
| user_data | `gpointer` | User data for callback |

---

### yaml_parser_load_from_stream_finish

```c
gboolean yaml_parser_load_from_stream_finish(
    YamlParser    *parser,
    GAsyncResult  *result,
    GError       **error
);
```

Finishes an async stream load operation.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| parser | `YamlParser *` | A parser |
| result | `GAsyncResult *` | The async result |
| error | `GError **` `(nullable)` | Return location for error |

**Returns:** `TRUE` on success.

---

### yaml_parser_load_from_gfile_async

```c
void yaml_parser_load_from_gfile_async(
    YamlParser          *parser,
    GFile               *file,
    GCancellable        *cancellable,
    GAsyncReadyCallback  callback,
    gpointer             user_data
);
```

Asynchronously loads YAML from a GFile.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| parser | `YamlParser *` | A parser |
| file | `GFile *` | A GFile |
| cancellable | `GCancellable *` `(nullable)` | A cancellable |
| callback | `GAsyncReadyCallback` | Completion callback |
| user_data | `gpointer` | User data for callback |

---

### yaml_parser_load_from_gfile_finish

```c
gboolean yaml_parser_load_from_gfile_finish(
    YamlParser    *parser,
    GAsyncResult  *result,
    GError       **error
);
```

Finishes an async file load operation.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| parser | `YamlParser *` | A parser |
| result | `GAsyncResult *` | The async result |
| error | `GError **` `(nullable)` | Return location for error |

**Returns:** `TRUE` on success.

---

## Document Access

### yaml_parser_get_n_documents

```c
guint yaml_parser_get_n_documents(YamlParser *parser);
```

Gets the number of documents parsed.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| parser | `YamlParser *` | A parser |

**Returns:** The number of documents.

---

### yaml_parser_get_document

```c
YamlDocument *yaml_parser_get_document(YamlParser *parser, guint index);
```

Gets a document by index.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| parser | `YamlParser *` | A parser |
| index | `guint` | The document index |

**Returns:** `(transfer none) (nullable)` The document, or `NULL`.

---

### yaml_parser_dup_document

```c
YamlDocument *yaml_parser_dup_document(YamlParser *parser, guint index);
```

Gets a new reference to a document by index.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| parser | `YamlParser *` | A parser |
| index | `guint` | The document index |

**Returns:** `(transfer full) (nullable)` The document, or `NULL`.

---

### yaml_parser_steal_document

```c
YamlDocument *yaml_parser_steal_document(YamlParser *parser, guint index);
```

Steals a document from the parser (removes it from the list).

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| parser | `YamlParser *` | A parser |
| index | `guint` | The document index |

**Returns:** `(transfer full) (nullable)` The document, or `NULL`.

---

## Convenience Accessors

### yaml_parser_get_root

```c
YamlNode *yaml_parser_get_root(YamlParser *parser);
```

Gets the root node of the first document. Convenience for single-document files.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| parser | `YamlParser *` | A parser |

**Returns:** `(transfer none) (nullable)` The root node, or `NULL`.

**Example:**
```c
YamlNode *root = yaml_parser_get_root(parser);
if (root != NULL && yaml_node_get_node_type(root) == YAML_NODE_MAPPING)
{
    YamlMapping *config = yaml_node_get_mapping(root);
    /* ... */
}
```

---

### yaml_parser_dup_root

```c
YamlNode *yaml_parser_dup_root(YamlParser *parser);
```

Gets a new reference to the root node of the first document.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| parser | `YamlParser *` | A parser |

**Returns:** `(transfer full) (nullable)` The root node, or `NULL`.

---

### yaml_parser_steal_root

```c
YamlNode *yaml_parser_steal_root(YamlParser *parser);
```

Steals the root node from the first document.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| parser | `YamlParser *` | A parser |

**Returns:** `(transfer full) (nullable)` The root node, or `NULL`.

**Example:**
```c
/* Keep root after parser is freed */
g_autoptr(YamlNode) config = yaml_parser_steal_root(parser);
g_object_unref(parser);
/* config is still valid */
```

---

## Position Information

### yaml_parser_get_current_line

```c
guint yaml_parser_get_current_line(YamlParser *parser);
```

Gets the current line number (1-based). Useful for error messages.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| parser | `YamlParser *` | A parser |

**Returns:** The line number.

---

### yaml_parser_get_current_column

```c
guint yaml_parser_get_current_column(YamlParser *parser);
```

Gets the current column number (1-based).

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| parser | `YamlParser *` | A parser |

**Returns:** The column number.

---

### yaml_parser_reset

```c
void yaml_parser_reset(YamlParser *parser);
```

Resets the parser, clearing all parsed documents.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| parser | `YamlParser *` | A parser |

---

## Multi-Document Example

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
    g_print("Found %u documents\n", n_docs);

    for (guint i = 0; i < n_docs; i++)
    {
        YamlDocument *doc = yaml_parser_get_document(parser, i);
        YamlNode *root = yaml_document_get_root(doc);
        g_print("Document %u type: %d\n", i, yaml_node_get_node_type(root));
    }
}
```

## Async Example

```c
static void
load_complete(GObject *source, GAsyncResult *result, gpointer user_data)
{
    YamlParser *parser = YAML_PARSER(source);
    g_autoptr(GError) error = NULL;

    if (!yaml_parser_load_from_gfile_finish(parser, result, &error))
    {
        g_printerr("Async load failed: %s\n", error->message);
        return;
    }

    YamlNode *root = yaml_parser_get_root(parser);
    /* Process the parsed data */
}

void
load_config_async(const gchar *path)
{
    g_autoptr(YamlParser) parser = yaml_parser_new();
    g_autoptr(GFile) file = g_file_new_for_path(path);

    yaml_parser_load_from_gfile_async(parser, file, NULL, load_complete, NULL);
}
```

## See Also

- [YamlDocument](document.md) - Document container
- [YamlNode](node.md) - Generic container
- [Parsing Guide](../guides/parsing.md) - Complete parsing guide
- [Async I/O Guide](../guides/async-io.md) - Async patterns
