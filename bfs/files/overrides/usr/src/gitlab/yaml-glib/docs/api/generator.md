# YamlGenerator API Reference

`YamlGenerator` generates YAML output from nodes and documents.

## Overview

```c
#include <yaml-glib/yaml-glib.h>

#define YAML_TYPE_GENERATOR (yaml_generator_get_type())

G_DECLARE_DERIVABLE_TYPE(YamlGenerator, yaml_generator, YAML, GENERATOR, GObject)
```

`YamlGenerator` wraps libyaml's emitter to produce YAML output from `YamlNode` or `YamlDocument` objects.

## Construction

### yaml_generator_new

```c
YamlGenerator *yaml_generator_new(void);
```

Creates a new `YamlGenerator`.

**Returns:** `(transfer full)` A new `YamlGenerator`.

**Example:**
```c
g_autoptr(YamlGenerator) gen = yaml_generator_new();
yaml_generator_set_root(gen, node);
yaml_generator_set_indent(gen, 2);
```

---

## Configuration

### yaml_generator_set_root / yaml_generator_get_root

```c
void yaml_generator_set_root(YamlGenerator *generator, YamlNode *node);
YamlNode *yaml_generator_get_root(YamlGenerator *generator);
```

Set/get the root node to generate YAML from.

---

### yaml_generator_set_document / yaml_generator_get_document

```c
void yaml_generator_set_document(YamlGenerator *generator, YamlDocument *document);
YamlDocument *yaml_generator_get_document(YamlGenerator *generator);
```

Set/get a document to generate YAML from. Includes document directives (version, tags).

---

### yaml_generator_set_indent / yaml_generator_get_indent

```c
void yaml_generator_set_indent(YamlGenerator *generator, guint indent_spaces);
guint yaml_generator_get_indent(YamlGenerator *generator);
```

Set/get the number of spaces for indentation (1-10). Default is 2.

---

### yaml_generator_set_canonical / yaml_generator_get_canonical

```c
void yaml_generator_set_canonical(YamlGenerator *generator, gboolean canonical);
gboolean yaml_generator_get_canonical(YamlGenerator *generator);
```

Set/get whether to output canonical YAML (explicit typing and flow style).

---

### yaml_generator_set_unicode / yaml_generator_get_unicode

```c
void yaml_generator_set_unicode(YamlGenerator *generator, gboolean unicode);
gboolean yaml_generator_get_unicode(YamlGenerator *generator);
```

Set/get whether to allow unicode characters. If disabled, non-ASCII characters are escaped.

---

### yaml_generator_set_line_break / yaml_generator_get_line_break

```c
void yaml_generator_set_line_break(YamlGenerator *generator, const gchar *line_break);
const gchar *yaml_generator_get_line_break(YamlGenerator *generator);
```

Set/get the line break style:
- `"unix"`: LF (`\n`)
- `"dos"`: CRLF (`\r\n`)
- `"mac"`: CR (`\r`)

---

### yaml_generator_set_explicit_start / yaml_generator_get_explicit_start

```c
void yaml_generator_set_explicit_start(YamlGenerator *generator, gboolean explicit_start);
gboolean yaml_generator_get_explicit_start(YamlGenerator *generator);
```

Set/get whether to emit the document start marker (`---`).

---

### yaml_generator_set_explicit_end / yaml_generator_get_explicit_end

```c
void yaml_generator_set_explicit_end(YamlGenerator *generator, gboolean explicit_end);
gboolean yaml_generator_get_explicit_end(YamlGenerator *generator);
```

Set/get whether to emit the document end marker (`...`).

---

## Synchronous Output

### yaml_generator_to_data

```c
gchar *yaml_generator_to_data(
    YamlGenerator  *generator,
    gsize          *length,
    GError        **error
);
```

Generates YAML as a string.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| generator | `YamlGenerator *` | A generator |
| length | `gsize *` `(out) (optional)` | Location for output length |
| error | `GError **` `(nullable)` | Return location for error |

**Returns:** `(transfer full) (nullable)` The generated YAML string. Free with `g_free()`.

**Example:**
```c
g_autoptr(YamlGenerator) gen = yaml_generator_new();
g_autoptr(GError) error = NULL;
g_autofree gchar *output = NULL;

yaml_generator_set_root(gen, root);
output = yaml_generator_to_data(gen, NULL, &error);

if (output != NULL)
{
    g_print("%s", output);
}
```

---

### yaml_generator_to_file

```c
gboolean yaml_generator_to_file(
    YamlGenerator  *generator,
    const gchar    *filename,
    GError        **error
);
```

Generates YAML and writes it to a file.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| generator | `YamlGenerator *` | A generator |
| filename | `const gchar *` | The output file path |
| error | `GError **` `(nullable)` | Return location for error |

**Returns:** `TRUE` on success.

---

### yaml_generator_to_gfile

```c
gboolean yaml_generator_to_gfile(
    YamlGenerator  *generator,
    GFile          *file,
    GCancellable   *cancellable,
    GError        **error
);
```

Generates YAML and writes it to a `GFile`.

---

### yaml_generator_to_stream

```c
gboolean yaml_generator_to_stream(
    YamlGenerator  *generator,
    GOutputStream  *stream,
    GCancellable   *cancellable,
    GError        **error
);
```

Generates YAML and writes it to an output stream.

---

## Asynchronous Output

### yaml_generator_to_stream_async

```c
void yaml_generator_to_stream_async(
    YamlGenerator       *generator,
    GOutputStream       *stream,
    GCancellable        *cancellable,
    GAsyncReadyCallback  callback,
    gpointer             user_data
);
```

Asynchronously generates YAML and writes it to an output stream.

---

### yaml_generator_to_stream_finish

```c
gboolean yaml_generator_to_stream_finish(
    YamlGenerator  *generator,
    GAsyncResult   *result,
    GError        **error
);
```

Finishes an async stream generation.

---

### yaml_generator_to_gfile_async

```c
void yaml_generator_to_gfile_async(
    YamlGenerator       *generator,
    GFile               *file,
    GCancellable        *cancellable,
    GAsyncReadyCallback  callback,
    gpointer             user_data
);
```

Asynchronously generates YAML and writes it to a GFile.

---

### yaml_generator_to_gfile_finish

```c
gboolean yaml_generator_to_gfile_finish(
    YamlGenerator  *generator,
    GAsyncResult   *result,
    GError        **error
);
```

Finishes an async file generation.

---

## Complete Example

```c
#include <yaml-glib/yaml-glib.h>

gboolean
save_config(YamlNode *config, const gchar *filename)
{
    g_autoptr(YamlGenerator) gen = yaml_generator_new();
    g_autoptr(GError) error = NULL;

    /* Configure output format */
    yaml_generator_set_root(gen, config);
    yaml_generator_set_indent(gen, 4);
    yaml_generator_set_unicode(gen, TRUE);
    yaml_generator_set_explicit_start(gen, TRUE);

    /* Write to file */
    if (!yaml_generator_to_file(gen, filename, &error))
    {
        g_printerr("Failed to save: %s\n", error->message);
        return FALSE;
    }

    return TRUE;
}
```

## Output Comparison

```c
/* Default output */
yaml_generator_set_indent(gen, 2);
/*
name: John
address:
  city: Springfield
  zip: '12345'
*/

/* 4-space indent with document markers */
yaml_generator_set_indent(gen, 4);
yaml_generator_set_explicit_start(gen, TRUE);
yaml_generator_set_explicit_end(gen, TRUE);
/*
---
name: John
address:
    city: Springfield
    zip: '12345'
...
*/

/* Canonical output */
yaml_generator_set_canonical(gen, TRUE);
/*
---
!!map {
  ? !!str "name"
  : !!str "John",
  ...
}
...
*/
```

## See Also

- [YamlParser](parser.md) - Parse YAML input
- [YamlBuilder](builder.md) - Build YAML structures
- [YamlDocument](document.md) - Document with directives
