/* yaml-generator.h
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * YamlGenerator - Generates YAML output from nodes and documents.
 */

#ifndef __YAML_GENERATOR_H__
#define __YAML_GENERATOR_H__

#include <glib.h>
#include <glib-object.h>
#include <gio/gio.h>
#include "yaml-types.h"
#include "yaml-node.h"
#include "yaml-document.h"

G_BEGIN_DECLS

#define YAML_TYPE_GENERATOR (yaml_generator_get_type())

G_DECLARE_DERIVABLE_TYPE(YamlGenerator, yaml_generator, YAML, GENERATOR, GObject)

/**
 * YamlGeneratorClass:
 * @parent_class: the parent class
 *
 * The class structure for #YamlGenerator.
 *
 * Since: 1.0
 */
struct _YamlGeneratorClass
{
    GObjectClass parent_class;

    /*< private >*/
    gpointer _reserved[8];
};

/**
 * yaml_generator_new:
 *
 * Creates a new #YamlGenerator.
 *
 * Returns: (transfer full): a new #YamlGenerator
 *
 * Since: 1.0
 */
YamlGenerator *
yaml_generator_new(void);

/* Configuration */

/**
 * yaml_generator_set_root:
 * @generator: a #YamlGenerator
 * @node: (transfer none): the root node
 *
 * Sets the root node to generate YAML from.
 *
 * Since: 1.0
 */
void
yaml_generator_set_root(
    YamlGenerator *generator,
    YamlNode      *node
);

/**
 * yaml_generator_get_root:
 * @generator: a #YamlGenerator
 *
 * Gets the root node.
 *
 * Returns: (transfer none) (nullable): the root node, or %NULL
 *
 * Since: 1.0
 */
YamlNode *
yaml_generator_get_root(YamlGenerator *generator);

/**
 * yaml_generator_set_document:
 * @generator: a #YamlGenerator
 * @document: (transfer none): the document to generate
 *
 * Sets a document to generate YAML from.
 * This includes document directives (version, tags).
 *
 * Since: 1.0
 */
void
yaml_generator_set_document(
    YamlGenerator *generator,
    YamlDocument  *document
);

/**
 * yaml_generator_get_document:
 * @generator: a #YamlGenerator
 *
 * Gets the document.
 *
 * Returns: (transfer none) (nullable): the document, or %NULL
 *
 * Since: 1.0
 */
YamlDocument *
yaml_generator_get_document(YamlGenerator *generator);

/**
 * yaml_generator_set_indent:
 * @generator: a #YamlGenerator
 * @indent_spaces: number of spaces for indentation (1-10)
 *
 * Sets the number of spaces to use for indentation.
 * Default is 2.
 *
 * Since: 1.0
 */
void
yaml_generator_set_indent(
    YamlGenerator *generator,
    guint          indent_spaces
);

/**
 * yaml_generator_get_indent:
 * @generator: a #YamlGenerator
 *
 * Gets the indentation setting.
 *
 * Returns: the number of spaces used for indentation
 *
 * Since: 1.0
 */
guint
yaml_generator_get_indent(YamlGenerator *generator);

/**
 * yaml_generator_set_canonical:
 * @generator: a #YamlGenerator
 * @canonical: whether to use canonical YAML format
 *
 * Sets whether to output canonical YAML.
 * Canonical format uses explicit typing and flow style.
 *
 * Since: 1.0
 */
void
yaml_generator_set_canonical(
    YamlGenerator *generator,
    gboolean       canonical
);

/**
 * yaml_generator_get_canonical:
 * @generator: a #YamlGenerator
 *
 * Checks whether canonical mode is enabled.
 *
 * Returns: %TRUE if canonical mode is enabled
 *
 * Since: 1.0
 */
gboolean
yaml_generator_get_canonical(YamlGenerator *generator);

/**
 * yaml_generator_set_unicode:
 * @generator: a #YamlGenerator
 * @unicode: whether to allow unicode characters
 *
 * Sets whether to allow unicode characters in output.
 * If disabled, non-ASCII characters are escaped.
 *
 * Since: 1.0
 */
void
yaml_generator_set_unicode(
    YamlGenerator *generator,
    gboolean       unicode
);

/**
 * yaml_generator_get_unicode:
 * @generator: a #YamlGenerator
 *
 * Checks whether unicode output is enabled.
 *
 * Returns: %TRUE if unicode is enabled
 *
 * Since: 1.0
 */
gboolean
yaml_generator_get_unicode(YamlGenerator *generator);

/**
 * yaml_generator_set_line_break:
 * @generator: a #YamlGenerator
 * @line_break: the line break style ("unix", "dos", "mac")
 *
 * Sets the line break style for output.
 * - "unix": LF (\n)
 * - "dos": CRLF (\r\n)
 * - "mac": CR (\r)
 *
 * Since: 1.0
 */
void
yaml_generator_set_line_break(
    YamlGenerator *generator,
    const gchar   *line_break
);

/**
 * yaml_generator_get_line_break:
 * @generator: a #YamlGenerator
 *
 * Gets the line break style.
 *
 * Returns: the line break style
 *
 * Since: 1.0
 */
const gchar *
yaml_generator_get_line_break(YamlGenerator *generator);

/**
 * yaml_generator_set_explicit_start:
 * @generator: a #YamlGenerator
 * @explicit_start: whether to emit document start marker
 *
 * Sets whether to emit the document start marker (---).
 *
 * Since: 1.0
 */
void
yaml_generator_set_explicit_start(
    YamlGenerator *generator,
    gboolean       explicit_start
);

/**
 * yaml_generator_get_explicit_start:
 * @generator: a #YamlGenerator
 *
 * Checks whether explicit start marker is enabled.
 *
 * Returns: %TRUE if explicit start is enabled
 *
 * Since: 1.0
 */
gboolean
yaml_generator_get_explicit_start(YamlGenerator *generator);

/**
 * yaml_generator_set_explicit_end:
 * @generator: a #YamlGenerator
 * @explicit_end: whether to emit document end marker
 *
 * Sets whether to emit the document end marker (...).
 *
 * Since: 1.0
 */
void
yaml_generator_set_explicit_end(
    YamlGenerator *generator,
    gboolean       explicit_end
);

/**
 * yaml_generator_get_explicit_end:
 * @generator: a #YamlGenerator
 *
 * Checks whether explicit end marker is enabled.
 *
 * Returns: %TRUE if explicit end is enabled
 *
 * Since: 1.0
 */
gboolean
yaml_generator_get_explicit_end(YamlGenerator *generator);

/* Synchronous output */

/**
 * yaml_generator_to_data:
 * @generator: a #YamlGenerator
 * @length: (out) (optional): location for output length
 * @error: (nullable): return location for a #GError
 *
 * Generates YAML as a string.
 *
 * Returns: (transfer full) (nullable): the generated YAML string,
 *          or %NULL on error. Free with g_free().
 *
 * Since: 1.0
 */
gchar *
yaml_generator_to_data(
    YamlGenerator  *generator,
    gsize          *length,
    GError        **error
);

/**
 * yaml_generator_to_file:
 * @generator: a #YamlGenerator
 * @filename: the output file path
 * @error: (nullable): return location for a #GError
 *
 * Generates YAML and writes it to a file.
 *
 * Returns: %TRUE on success
 *
 * Since: 1.0
 */
gboolean
yaml_generator_to_file(
    YamlGenerator  *generator,
    const gchar    *filename,
    GError        **error
);

/**
 * yaml_generator_to_gfile:
 * @generator: a #YamlGenerator
 * @file: a #GFile
 * @cancellable: (nullable): a #GCancellable
 * @error: (nullable): return location for a #GError
 *
 * Generates YAML and writes it to a #GFile.
 *
 * Returns: %TRUE on success
 *
 * Since: 1.0
 */
gboolean
yaml_generator_to_gfile(
    YamlGenerator  *generator,
    GFile          *file,
    GCancellable   *cancellable,
    GError        **error
);

/**
 * yaml_generator_to_stream:
 * @generator: a #YamlGenerator
 * @stream: a #GOutputStream
 * @cancellable: (nullable): a #GCancellable
 * @error: (nullable): return location for a #GError
 *
 * Generates YAML and writes it to an output stream.
 *
 * Returns: %TRUE on success
 *
 * Since: 1.0
 */
gboolean
yaml_generator_to_stream(
    YamlGenerator  *generator,
    GOutputStream  *stream,
    GCancellable   *cancellable,
    GError        **error
);

/* Asynchronous output */

/**
 * yaml_generator_to_stream_async:
 * @generator: a #YamlGenerator
 * @stream: a #GOutputStream
 * @cancellable: (nullable): a #GCancellable
 * @callback: (scope async): callback to call when done
 * @user_data: user data for @callback
 *
 * Asynchronously generates YAML and writes it to an output stream.
 *
 * Since: 1.0
 */
void
yaml_generator_to_stream_async(
    YamlGenerator       *generator,
    GOutputStream       *stream,
    GCancellable        *cancellable,
    GAsyncReadyCallback  callback,
    gpointer             user_data
);

/**
 * yaml_generator_to_stream_finish:
 * @generator: a #YamlGenerator
 * @result: a #GAsyncResult
 * @error: (nullable): return location for a #GError
 *
 * Finishes an asynchronous generation operation.
 *
 * Returns: %TRUE on success
 *
 * Since: 1.0
 */
gboolean
yaml_generator_to_stream_finish(
    YamlGenerator  *generator,
    GAsyncResult   *result,
    GError        **error
);

/**
 * yaml_generator_to_gfile_async:
 * @generator: a #YamlGenerator
 * @file: a #GFile
 * @cancellable: (nullable): a #GCancellable
 * @callback: (scope async): callback to call when done
 * @user_data: user data for @callback
 *
 * Asynchronously generates YAML and writes it to a #GFile.
 *
 * Since: 1.0
 */
void
yaml_generator_to_gfile_async(
    YamlGenerator       *generator,
    GFile               *file,
    GCancellable        *cancellable,
    GAsyncReadyCallback  callback,
    gpointer             user_data
);

/**
 * yaml_generator_to_gfile_finish:
 * @generator: a #YamlGenerator
 * @result: a #GAsyncResult
 * @error: (nullable): return location for a #GError
 *
 * Finishes an asynchronous file generation operation.
 *
 * Returns: %TRUE on success
 *
 * Since: 1.0
 */
gboolean
yaml_generator_to_gfile_finish(
    YamlGenerator  *generator,
    GAsyncResult   *result,
    GError        **error
);

G_END_DECLS

#endif /* __YAML_GENERATOR_H__ */
