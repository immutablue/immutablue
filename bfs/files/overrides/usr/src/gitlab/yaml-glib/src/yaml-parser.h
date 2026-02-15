/* yaml-parser.h
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * YamlParser - Parses YAML content into YamlDocument objects.
 */

#ifndef __YAML_PARSER_H__
#define __YAML_PARSER_H__

#include <glib.h>
#include <glib-object.h>
#include <gio/gio.h>
#include "yaml-types.h"
#include "yaml-document.h"
#include "yaml-node.h"

G_BEGIN_DECLS

#define YAML_TYPE_PARSER (yaml_parser_get_type())

G_DECLARE_DERIVABLE_TYPE(YamlParser, yaml_parser, YAML, PARSER, GObject)

/**
 * YamlParserClass:
 * @parent_class: the parent class
 * @parse_start: signal emitted when parsing starts
 * @document_start: signal emitted when a document starts
 * @document_end: signal emitted when a document ends
 * @parse_end: signal emitted when parsing ends
 * @error: signal emitted on parse error
 *
 * The class structure for #YamlParser.
 *
 * Since: 1.0
 */
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

    /*< private >*/
    gpointer _reserved[8];
};

/**
 * yaml_parser_new:
 *
 * Creates a new #YamlParser.
 * Parsed documents will be mutable.
 *
 * Returns: (transfer full): a new #YamlParser
 *
 * Since: 1.0
 */
YamlParser *
yaml_parser_new(void);

/**
 * yaml_parser_new_immutable:
 *
 * Creates a new #YamlParser that produces immutable documents.
 * Immutable documents are sealed after parsing and cannot be modified.
 * This is useful for thread-safe sharing of parsed data.
 *
 * Returns: (transfer full): a new #YamlParser
 *
 * Since: 1.0
 */
YamlParser *
yaml_parser_new_immutable(void);

/**
 * yaml_parser_get_immutable:
 * @parser: a #YamlParser
 *
 * Checks whether @parser produces immutable documents.
 *
 * Returns: %TRUE if documents are immutable
 *
 * Since: 1.0
 */
gboolean
yaml_parser_get_immutable(YamlParser *parser);

/**
 * yaml_parser_set_immutable:
 * @parser: a #YamlParser
 * @immutable: whether to produce immutable documents
 *
 * Sets whether @parser should produce immutable documents.
 *
 * Since: 1.0
 */
void
yaml_parser_set_immutable(
    YamlParser *parser,
    gboolean    immutable
);

/* Synchronous loading */

/**
 * yaml_parser_load_from_file:
 * @parser: a #YamlParser
 * @filename: the path to the file to load
 * @error: (nullable): return location for a #GError
 *
 * Loads YAML content from a file.
 *
 * Returns: %TRUE on success
 *
 * Since: 1.0
 */
gboolean
yaml_parser_load_from_file(
    YamlParser   *parser,
    const gchar  *filename,
    GError      **error
);

/**
 * yaml_parser_load_from_gfile:
 * @parser: a #YamlParser
 * @file: a #GFile
 * @cancellable: (nullable): a #GCancellable
 * @error: (nullable): return location for a #GError
 *
 * Loads YAML content from a #GFile.
 *
 * Returns: %TRUE on success
 *
 * Since: 1.0
 */
gboolean
yaml_parser_load_from_gfile(
    YamlParser   *parser,
    GFile        *file,
    GCancellable *cancellable,
    GError      **error
);

/**
 * yaml_parser_load_from_data:
 * @parser: a #YamlParser
 * @data: (array length=length) (element-type guint8): the YAML data
 * @length: the length of @data, or -1 if null-terminated
 * @error: (nullable): return location for a #GError
 *
 * Loads YAML content from a string or byte array.
 *
 * Returns: %TRUE on success
 *
 * Since: 1.0
 */
gboolean
yaml_parser_load_from_data(
    YamlParser   *parser,
    const gchar  *data,
    gssize        length,
    GError      **error
);

/**
 * yaml_parser_load_from_stream:
 * @parser: a #YamlParser
 * @stream: a #GInputStream
 * @cancellable: (nullable): a #GCancellable
 * @error: (nullable): return location for a #GError
 *
 * Loads YAML content from an input stream.
 *
 * Returns: %TRUE on success
 *
 * Since: 1.0
 */
gboolean
yaml_parser_load_from_stream(
    YamlParser   *parser,
    GInputStream *stream,
    GCancellable *cancellable,
    GError      **error
);

/* Asynchronous loading */

/**
 * yaml_parser_load_from_stream_async:
 * @parser: a #YamlParser
 * @stream: a #GInputStream
 * @cancellable: (nullable): a #GCancellable
 * @callback: (scope async): callback to call when done
 * @user_data: user data for @callback
 *
 * Asynchronously loads YAML content from an input stream.
 *
 * Since: 1.0
 */
void
yaml_parser_load_from_stream_async(
    YamlParser          *parser,
    GInputStream        *stream,
    GCancellable        *cancellable,
    GAsyncReadyCallback  callback,
    gpointer             user_data
);

/**
 * yaml_parser_load_from_stream_finish:
 * @parser: a #YamlParser
 * @result: a #GAsyncResult
 * @error: (nullable): return location for a #GError
 *
 * Finishes an asynchronous load operation.
 *
 * Returns: %TRUE on success
 *
 * Since: 1.0
 */
gboolean
yaml_parser_load_from_stream_finish(
    YamlParser    *parser,
    GAsyncResult  *result,
    GError       **error
);

/**
 * yaml_parser_load_from_gfile_async:
 * @parser: a #YamlParser
 * @file: a #GFile
 * @cancellable: (nullable): a #GCancellable
 * @callback: (scope async): callback to call when done
 * @user_data: user data for @callback
 *
 * Asynchronously loads YAML content from a #GFile.
 *
 * Since: 1.0
 */
void
yaml_parser_load_from_gfile_async(
    YamlParser          *parser,
    GFile               *file,
    GCancellable        *cancellable,
    GAsyncReadyCallback  callback,
    gpointer             user_data
);

/**
 * yaml_parser_load_from_gfile_finish:
 * @parser: a #YamlParser
 * @result: a #GAsyncResult
 * @error: (nullable): return location for a #GError
 *
 * Finishes an asynchronous file load operation.
 *
 * Returns: %TRUE on success
 *
 * Since: 1.0
 */
gboolean
yaml_parser_load_from_gfile_finish(
    YamlParser    *parser,
    GAsyncResult  *result,
    GError       **error
);

/* Document access */

/**
 * yaml_parser_get_n_documents:
 * @parser: a #YamlParser
 *
 * Gets the number of documents parsed.
 *
 * Returns: the number of documents
 *
 * Since: 1.0
 */
guint
yaml_parser_get_n_documents(YamlParser *parser);

/**
 * yaml_parser_get_document:
 * @parser: a #YamlParser
 * @index: the document index
 *
 * Gets a document by index.
 *
 * Returns: (transfer none) (nullable): the document, or %NULL
 *
 * Since: 1.0
 */
YamlDocument *
yaml_parser_get_document(
    YamlParser *parser,
    guint       index
);

/**
 * yaml_parser_dup_document:
 * @parser: a #YamlParser
 * @index: the document index
 *
 * Gets a reference to a document by index.
 *
 * Returns: (transfer full) (nullable): the document, or %NULL
 *
 * Since: 1.0
 */
YamlDocument *
yaml_parser_dup_document(
    YamlParser *parser,
    guint       index
);

/**
 * yaml_parser_steal_document:
 * @parser: a #YamlParser
 * @index: the document index
 *
 * Steals a document from the parser.
 * The document is removed from the parser's list.
 *
 * Returns: (transfer full) (nullable): the document, or %NULL
 *
 * Since: 1.0
 */
YamlDocument *
yaml_parser_steal_document(
    YamlParser *parser,
    guint       index
);

/* Convenience for single-document YAML */

/**
 * yaml_parser_get_root:
 * @parser: a #YamlParser
 *
 * Gets the root node of the first document.
 * This is a convenience for single-document YAML files.
 *
 * Returns: (transfer none) (nullable): the root node, or %NULL
 *
 * Since: 1.0
 */
YamlNode *
yaml_parser_get_root(YamlParser *parser);

/**
 * yaml_parser_dup_root:
 * @parser: a #YamlParser
 *
 * Gets a reference to the root node of the first document.
 *
 * Returns: (transfer full) (nullable): the root node, or %NULL
 *
 * Since: 1.0
 */
YamlNode *
yaml_parser_dup_root(YamlParser *parser);

/**
 * yaml_parser_steal_root:
 * @parser: a #YamlParser
 *
 * Steals the root node from the first document.
 *
 * Returns: (transfer full) (nullable): the root node, or %NULL
 *
 * Since: 1.0
 */
YamlNode *
yaml_parser_steal_root(YamlParser *parser);

/* Position information */

/**
 * yaml_parser_get_current_line:
 * @parser: a #YamlParser
 *
 * Gets the current line number during or after parsing.
 *
 * Returns: the line number (1-based)
 *
 * Since: 1.0
 */
guint
yaml_parser_get_current_line(YamlParser *parser);

/**
 * yaml_parser_get_current_column:
 * @parser: a #YamlParser
 *
 * Gets the current column number during or after parsing.
 *
 * Returns: the column number (1-based)
 *
 * Since: 1.0
 */
guint
yaml_parser_get_current_column(YamlParser *parser);

/**
 * yaml_parser_reset:
 * @parser: a #YamlParser
 *
 * Resets the parser, clearing all parsed documents.
 *
 * Since: 1.0
 */
void
yaml_parser_reset(YamlParser *parser);

G_END_DECLS

#endif /* __YAML_PARSER_H__ */
