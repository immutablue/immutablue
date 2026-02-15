/* yaml-parser.c
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * YamlParser implementation using libyaml.
 */

#include "yaml-parser.h"
#include "yaml-document.h"
#include "yaml-node.h"
#include "yaml-mapping.h"
#include "yaml-sequence.h"
#include "yaml-private.h"
#include <yaml.h>
#include <string.h>

typedef struct
{
    GPtrArray   *documents;
    gboolean     immutable;
    guint        current_line;
    guint        current_column;
} YamlParserPrivate;

G_DEFINE_TYPE_WITH_PRIVATE(YamlParser, yaml_parser, G_TYPE_OBJECT)

enum {
    PROP_0,
    PROP_IMMUTABLE,
    N_PROPS
};

static GParamSpec *properties[N_PROPS];

enum {
    SIGNAL_PARSE_START,
    SIGNAL_DOCUMENT_START,
    SIGNAL_DOCUMENT_END,
    SIGNAL_PARSE_END,
    SIGNAL_ERROR,
    N_SIGNALS
};

static guint signals[N_SIGNALS];

static void
yaml_parser_finalize(GObject *object)
{
    YamlParser *self = YAML_PARSER(object);
    YamlParserPrivate *priv = yaml_parser_get_instance_private(self);

    g_ptr_array_free(priv->documents, TRUE);

    G_OBJECT_CLASS(yaml_parser_parent_class)->finalize(object);
}

static void
yaml_parser_get_property(
    GObject    *object,
    guint       prop_id,
    GValue     *value,
    GParamSpec *pspec
)
{
    YamlParser *self = YAML_PARSER(object);
    YamlParserPrivate *priv = yaml_parser_get_instance_private(self);

    switch (prop_id)
    {
        case PROP_IMMUTABLE:
            g_value_set_boolean(value, priv->immutable);
            break;

        default:
            G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
            break;
    }
}

static void
yaml_parser_set_property(
    GObject      *object,
    guint         prop_id,
    const GValue *value,
    GParamSpec   *pspec
)
{
    YamlParser *self = YAML_PARSER(object);
    YamlParserPrivate *priv = yaml_parser_get_instance_private(self);

    switch (prop_id)
    {
        case PROP_IMMUTABLE:
            priv->immutable = g_value_get_boolean(value);
            break;

        default:
            G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
            break;
    }
}

static void
yaml_parser_class_init(YamlParserClass *klass)
{
    GObjectClass *object_class = G_OBJECT_CLASS(klass);

    object_class->finalize = yaml_parser_finalize;
    object_class->get_property = yaml_parser_get_property;
    object_class->set_property = yaml_parser_set_property;

    /**
     * YamlParser:immutable:
     *
     * Whether parsed documents should be immutable.
     *
     * Since: 1.0
     */
    properties[PROP_IMMUTABLE] =
        g_param_spec_boolean("immutable",
                             "Immutable",
                             "Whether parsed documents are immutable",
                             FALSE,
                             G_PARAM_READWRITE |
                             G_PARAM_CONSTRUCT |
                             G_PARAM_STATIC_STRINGS);

    g_object_class_install_properties(object_class, N_PROPS, properties);

    /**
     * YamlParser::parse-start:
     * @parser: the parser
     *
     * Emitted when parsing starts.
     *
     * Since: 1.0
     */
    signals[SIGNAL_PARSE_START] =
        g_signal_new("parse-start",
                     G_TYPE_FROM_CLASS(klass),
                     G_SIGNAL_RUN_LAST,
                     G_STRUCT_OFFSET(YamlParserClass, parse_start),
                     NULL, NULL, NULL,
                     G_TYPE_NONE, 0);

    /**
     * YamlParser::document-start:
     * @parser: the parser
     *
     * Emitted when a document starts.
     *
     * Since: 1.0
     */
    signals[SIGNAL_DOCUMENT_START] =
        g_signal_new("document-start",
                     G_TYPE_FROM_CLASS(klass),
                     G_SIGNAL_RUN_LAST,
                     G_STRUCT_OFFSET(YamlParserClass, document_start),
                     NULL, NULL, NULL,
                     G_TYPE_NONE, 0);

    /**
     * YamlParser::document-end:
     * @parser: the parser
     * @document: the completed document
     *
     * Emitted when a document ends.
     *
     * Since: 1.0
     */
    signals[SIGNAL_DOCUMENT_END] =
        g_signal_new("document-end",
                     G_TYPE_FROM_CLASS(klass),
                     G_SIGNAL_RUN_LAST,
                     G_STRUCT_OFFSET(YamlParserClass, document_end),
                     NULL, NULL, NULL,
                     G_TYPE_NONE, 1, YAML_TYPE_DOCUMENT);

    /**
     * YamlParser::parse-end:
     * @parser: the parser
     *
     * Emitted when parsing ends.
     *
     * Since: 1.0
     */
    signals[SIGNAL_PARSE_END] =
        g_signal_new("parse-end",
                     G_TYPE_FROM_CLASS(klass),
                     G_SIGNAL_RUN_LAST,
                     G_STRUCT_OFFSET(YamlParserClass, parse_end),
                     NULL, NULL, NULL,
                     G_TYPE_NONE, 0);

    /**
     * YamlParser::error:
     * @parser: the parser
     * @error: the error
     *
     * Emitted when a parse error occurs.
     *
     * Since: 1.0
     */
    signals[SIGNAL_ERROR] =
        g_signal_new("error",
                     G_TYPE_FROM_CLASS(klass),
                     G_SIGNAL_RUN_LAST,
                     G_STRUCT_OFFSET(YamlParserClass, error),
                     NULL, NULL, NULL,
                     G_TYPE_NONE, 1, G_TYPE_ERROR);
}

static void
yaml_parser_init(YamlParser *self)
{
    YamlParserPrivate *priv = yaml_parser_get_instance_private(self);

    priv->documents = g_ptr_array_new_with_free_func(g_object_unref);
    priv->immutable = FALSE;
    priv->current_line = 0;
    priv->current_column = 0;
}

YamlParser *
yaml_parser_new(void)
{
    return g_object_new(YAML_TYPE_PARSER, NULL);
}

YamlParser *
yaml_parser_new_immutable(void)
{
    return g_object_new(YAML_TYPE_PARSER,
                        "immutable", TRUE,
                        NULL);
}

gboolean
yaml_parser_get_immutable(YamlParser *parser)
{
    YamlParserPrivate *priv;

    g_return_val_if_fail(YAML_IS_PARSER(parser), FALSE);

    priv = yaml_parser_get_instance_private(parser);

    return priv->immutable;
}

void
yaml_parser_set_immutable(
    YamlParser *parser,
    gboolean    immutable
)
{
    YamlParserPrivate *priv;

    g_return_if_fail(YAML_IS_PARSER(parser));

    priv = yaml_parser_get_instance_private(parser);
    priv->immutable = immutable;
}

/*
 * Internal: Convert a libyaml node to a YamlNode.
 * Recursively processes all children.
 */
static YamlNode *
convert_yaml_node(
    yaml_document_t *doc,
    yaml_node_t     *ynode,
    GHashTable      *anchors
)
{
    YamlNode *node;

    if (ynode == NULL)
        return NULL;

    node = yaml_node_alloc();

    /* Handle tag */
    if (ynode->tag != NULL)
    {
        const gchar *tag = (const gchar *)ynode->tag;
        /* Skip default tags */
        if (!g_str_has_prefix(tag, "tag:yaml.org,2002:"))
        {
            yaml_node_set_tag(node, tag);
        }
    }

    switch (ynode->type)
    {
        case YAML_SCALAR_NODE:
        {
            const gchar *scalar_value = (const gchar *)ynode->data.scalar.value;

            /* Check for null values */
            if (scalar_value == NULL || scalar_value[0] == '\0' ||
                g_strcmp0(scalar_value, "~") == 0 ||
                g_ascii_strcasecmp(scalar_value, "null") == 0)
            {
                yaml_node_init_null(node);
            }
            else
            {
                yaml_node_init_string(node, scalar_value);
            }
            break;
        }

        case YAML_SEQUENCE_NODE:
        {
            yaml_node_item_t *item;

            yaml_node_init(node, YAML_NODE_SEQUENCE);

            for (item = ynode->data.sequence.items.start;
                 item < ynode->data.sequence.items.top;
                 item++)
            {
                yaml_node_t *child_ynode = yaml_document_get_node(doc, *item);
                YamlNode *child = convert_yaml_node(doc, child_ynode, anchors);

                if (child != NULL)
                {
                    yaml_sequence_add_element(
                        yaml_node_get_sequence(node),
                        child
                    );
                    yaml_node_unref(child);
                }
            }
            break;
        }

        case YAML_MAPPING_NODE:
        {
            yaml_node_pair_t *pair;

            yaml_node_init(node, YAML_NODE_MAPPING);

            for (pair = ynode->data.mapping.pairs.start;
                 pair < ynode->data.mapping.pairs.top;
                 pair++)
            {
                yaml_node_t *key_ynode = yaml_document_get_node(doc, pair->key);
                yaml_node_t *value_ynode = yaml_document_get_node(doc, pair->value);
                const gchar *key = NULL;

                if (key_ynode != NULL && key_ynode->type == YAML_SCALAR_NODE)
                {
                    key = (const gchar *)key_ynode->data.scalar.value;
                }

                if (key != NULL)
                {
                    YamlNode *value = convert_yaml_node(doc, value_ynode, anchors);

                    if (value != NULL)
                    {
                        yaml_mapping_set_member(
                            yaml_node_get_mapping(node),
                            key,
                            value
                        );
                        yaml_node_unref(value);
                    }
                }
            }
            break;
        }

        default:
            yaml_node_init_null(node);
            break;
    }

    return node;
}

/*
 * Internal: Parse YAML from data buffer.
 */
static gboolean
yaml_parser_parse_internal(
    YamlParser   *self,
    const gchar  *data,
    gsize         length,
    GError      **error
)
{
    YamlParserPrivate *priv = yaml_parser_get_instance_private(self);
    yaml_parser_t parser;
    yaml_document_t doc;
    gboolean success = TRUE;
    GHashTable *anchors;

    if (!yaml_parser_initialize(&parser))
    {
        g_set_error(error,
                    YAML_GLIB_PARSER_ERROR,
                    YAML_GLIB_PARSER_ERROR_UNKNOWN,
                    "Failed to initialize YAML parser");
        return FALSE;
    }

    yaml_parser_set_input_string(&parser,
                                  (const unsigned char *)data,
                                  length);

    g_signal_emit(self, signals[SIGNAL_PARSE_START], 0);

    anchors = g_hash_table_new_full(g_str_hash, g_str_equal,
                                    g_free, (GDestroyNotify)yaml_node_unref);

    while (TRUE)
    {
        YamlDocument *yaml_doc;
        yaml_node_t *root;
        YamlNode *root_node;

        if (!yaml_parser_load(&parser, &doc))
        {
            if (parser.error != YAML_NO_ERROR)
            {
                priv->current_line = parser.problem_mark.line + 1;
                priv->current_column = parser.problem_mark.column + 1;

                g_set_error(error,
                            YAML_GLIB_PARSER_ERROR,
                            YAML_GLIB_PARSER_ERROR_PARSE,
                            "Parse error at line %u, column %u: %s",
                            priv->current_line,
                            priv->current_column,
                            parser.problem ? parser.problem : "unknown error");

                g_signal_emit(self, signals[SIGNAL_ERROR], 0, *error);
                success = FALSE;
            }
            break;
        }

        root = yaml_document_get_root_node(&doc);
        if (root == NULL)
        {
            yaml_document_delete(&doc);
            break;
        }

        g_signal_emit(self, signals[SIGNAL_DOCUMENT_START], 0);

        root_node = convert_yaml_node(&doc, root, anchors);

        yaml_doc = yaml_document_new();
        yaml_document_set_root(yaml_doc, root_node);
        yaml_node_unref(root_node);

        if (priv->immutable)
            yaml_document_seal(yaml_doc);

        g_ptr_array_add(priv->documents, yaml_doc);

        g_signal_emit(self, signals[SIGNAL_DOCUMENT_END], 0, yaml_doc);

        yaml_document_delete(&doc);
    }

    g_hash_table_destroy(anchors);
    yaml_parser_delete(&parser);

    g_signal_emit(self, signals[SIGNAL_PARSE_END], 0);

    return success;
}

gboolean
yaml_parser_load_from_file(
    YamlParser   *parser,
    const gchar  *filename,
    GError      **error
)
{
    g_autofree gchar *contents = NULL;
    gsize length;

    g_return_val_if_fail(YAML_IS_PARSER(parser), FALSE);
    g_return_val_if_fail(filename != NULL, FALSE);

    if (!g_file_get_contents(filename, &contents, &length, error))
        return FALSE;

    return yaml_parser_parse_internal(parser, contents, length, error);
}

gboolean
yaml_parser_load_from_gfile(
    YamlParser   *parser,
    GFile        *file,
    GCancellable *cancellable,
    GError      **error
)
{
    g_autofree gchar *contents = NULL;
    gsize length;

    g_return_val_if_fail(YAML_IS_PARSER(parser), FALSE);
    g_return_val_if_fail(G_IS_FILE(file), FALSE);

    if (!g_file_load_contents(file, cancellable, &contents, &length, NULL, error))
        return FALSE;

    return yaml_parser_parse_internal(parser, contents, length, error);
}

gboolean
yaml_parser_load_from_data(
    YamlParser   *parser,
    const gchar  *data,
    gssize        length,
    GError      **error
)
{
    g_return_val_if_fail(YAML_IS_PARSER(parser), FALSE);
    g_return_val_if_fail(data != NULL, FALSE);

    if (length < 0)
        length = strlen(data);

    return yaml_parser_parse_internal(parser, data, length, error);
}

gboolean
yaml_parser_load_from_stream(
    YamlParser   *parser,
    GInputStream *stream,
    GCancellable *cancellable,
    GError      **error
)
{
    g_autoptr(GByteArray) data = NULL;
    guchar buffer[4096];
    gssize bytes_read;

    g_return_val_if_fail(YAML_IS_PARSER(parser), FALSE);
    g_return_val_if_fail(G_IS_INPUT_STREAM(stream), FALSE);

    data = g_byte_array_new();

    while ((bytes_read = g_input_stream_read(stream, buffer, sizeof(buffer),
                                              cancellable, error)) > 0)
    {
        g_byte_array_append(data, buffer, bytes_read);
    }

    if (bytes_read < 0)
        return FALSE;

    return yaml_parser_parse_internal(parser,
                                       (const gchar *)data->data,
                                       data->len,
                                       error);
}

/* Async loading */

typedef struct
{
    YamlParser   *parser;
    GInputStream *stream;
    GByteArray   *data;
} AsyncLoadData;

static void
async_load_data_free(AsyncLoadData *data)
{
    g_clear_object(&data->parser);
    g_clear_object(&data->stream);
    if (data->data != NULL)
        g_byte_array_free(data->data, TRUE);
    g_slice_free(AsyncLoadData, data);
}

static void
async_read_cb(GObject      *source,
              GAsyncResult *result,
              gpointer      user_data)
{
    GTask *task = G_TASK(user_data);
    AsyncLoadData *load_data = g_task_get_task_data(task);
    GError *error = NULL;
    gssize bytes_read;
    guchar buffer[4096];

    bytes_read = g_input_stream_read_finish(G_INPUT_STREAM(source),
                                            result, &error);

    if (bytes_read < 0)
    {
        g_task_return_error(task, error);
        g_object_unref(task);
        return;
    }

    if (bytes_read > 0)
    {
        g_byte_array_append(load_data->data, buffer, bytes_read);

        /* Continue reading */
        g_input_stream_read_async(load_data->stream,
                                   buffer, sizeof(buffer),
                                   g_task_get_priority(task),
                                   g_task_get_cancellable(task),
                                   async_read_cb,
                                   task);
        return;
    }

    /* Done reading, parse the data */
    if (!yaml_parser_parse_internal(load_data->parser,
                                    (const gchar *)load_data->data->data,
                                    load_data->data->len,
                                    &error))
    {
        g_task_return_error(task, error);
    }
    else
    {
        g_task_return_boolean(task, TRUE);
    }

    g_object_unref(task);
}

void
yaml_parser_load_from_stream_async(
    YamlParser          *parser,
    GInputStream        *stream,
    GCancellable        *cancellable,
    GAsyncReadyCallback  callback,
    gpointer             user_data
)
{
    GTask *task;
    AsyncLoadData *load_data;
    guchar buffer[4096];

    g_return_if_fail(YAML_IS_PARSER(parser));
    g_return_if_fail(G_IS_INPUT_STREAM(stream));

    task = g_task_new(parser, cancellable, callback, user_data);
    g_task_set_source_tag(task, yaml_parser_load_from_stream_async);

    load_data = g_slice_new0(AsyncLoadData);
    load_data->parser = g_object_ref(parser);
    load_data->stream = g_object_ref(stream);
    load_data->data = g_byte_array_new();

    g_task_set_task_data(task, load_data, (GDestroyNotify)async_load_data_free);

    g_input_stream_read_async(stream,
                               buffer, sizeof(buffer),
                               G_PRIORITY_DEFAULT,
                               cancellable,
                               async_read_cb,
                               task);
}

gboolean
yaml_parser_load_from_stream_finish(
    YamlParser    *parser,
    GAsyncResult  *result,
    GError       **error
)
{
    g_return_val_if_fail(YAML_IS_PARSER(parser), FALSE);
    g_return_val_if_fail(g_task_is_valid(result, parser), FALSE);

    return g_task_propagate_boolean(G_TASK(result), error);
}

static void
async_file_read_cb(GObject      *source,
                   GAsyncResult *result,
                   gpointer      user_data)
{
    GTask *task = G_TASK(user_data);
    YamlParser *parser = g_task_get_source_object(task);
    GError *error = NULL;
    g_autofree gchar *contents = NULL;
    gsize length;

    if (!g_file_load_contents_finish(G_FILE(source), result,
                                      &contents, &length, NULL, &error))
    {
        g_task_return_error(task, error);
        g_object_unref(task);
        return;
    }

    if (!yaml_parser_parse_internal(parser, contents, length, &error))
    {
        g_task_return_error(task, error);
    }
    else
    {
        g_task_return_boolean(task, TRUE);
    }

    g_object_unref(task);
}

void
yaml_parser_load_from_gfile_async(
    YamlParser          *parser,
    GFile               *file,
    GCancellable        *cancellable,
    GAsyncReadyCallback  callback,
    gpointer             user_data
)
{
    GTask *task;

    g_return_if_fail(YAML_IS_PARSER(parser));
    g_return_if_fail(G_IS_FILE(file));

    task = g_task_new(parser, cancellable, callback, user_data);
    g_task_set_source_tag(task, yaml_parser_load_from_gfile_async);

    g_file_load_contents_async(file, cancellable,
                                async_file_read_cb, task);
}

gboolean
yaml_parser_load_from_gfile_finish(
    YamlParser    *parser,
    GAsyncResult  *result,
    GError       **error
)
{
    g_return_val_if_fail(YAML_IS_PARSER(parser), FALSE);
    g_return_val_if_fail(g_task_is_valid(result, parser), FALSE);

    return g_task_propagate_boolean(G_TASK(result), error);
}

/* Document access */

guint
yaml_parser_get_n_documents(YamlParser *parser)
{
    YamlParserPrivate *priv;

    g_return_val_if_fail(YAML_IS_PARSER(parser), 0);

    priv = yaml_parser_get_instance_private(parser);

    return priv->documents->len;
}

YamlDocument *
yaml_parser_get_document(
    YamlParser *parser,
    guint       index
)
{
    YamlParserPrivate *priv;

    g_return_val_if_fail(YAML_IS_PARSER(parser), NULL);

    priv = yaml_parser_get_instance_private(parser);

    if (index >= priv->documents->len)
        return NULL;

    return g_ptr_array_index(priv->documents, index);
}

YamlDocument *
yaml_parser_dup_document(
    YamlParser *parser,
    guint       index
)
{
    YamlDocument *doc;

    doc = yaml_parser_get_document(parser, index);
    if (doc != NULL)
        return g_object_ref(doc);

    return NULL;
}

YamlDocument *
yaml_parser_steal_document(
    YamlParser *parser,
    guint       index
)
{
    YamlParserPrivate *priv;
    YamlDocument *doc;

    g_return_val_if_fail(YAML_IS_PARSER(parser), NULL);

    priv = yaml_parser_get_instance_private(parser);

    if (index >= priv->documents->len)
        return NULL;

    doc = g_ptr_array_index(priv->documents, index);
    g_ptr_array_remove_index(priv->documents, index);

    return doc;
}

YamlNode *
yaml_parser_get_root(YamlParser *parser)
{
    YamlDocument *doc;

    doc = yaml_parser_get_document(parser, 0);
    if (doc == NULL)
        return NULL;

    return yaml_document_get_root(doc);
}

YamlNode *
yaml_parser_dup_root(YamlParser *parser)
{
    YamlDocument *doc;

    doc = yaml_parser_get_document(parser, 0);
    if (doc == NULL)
        return NULL;

    return yaml_document_dup_root(doc);
}

YamlNode *
yaml_parser_steal_root(YamlParser *parser)
{
    YamlDocument *doc;

    doc = yaml_parser_get_document(parser, 0);
    if (doc == NULL)
        return NULL;

    return yaml_document_steal_root(doc);
}

guint
yaml_parser_get_current_line(YamlParser *parser)
{
    YamlParserPrivate *priv;

    g_return_val_if_fail(YAML_IS_PARSER(parser), 0);

    priv = yaml_parser_get_instance_private(parser);

    return priv->current_line;
}

guint
yaml_parser_get_current_column(YamlParser *parser)
{
    YamlParserPrivate *priv;

    g_return_val_if_fail(YAML_IS_PARSER(parser), 0);

    priv = yaml_parser_get_instance_private(parser);

    return priv->current_column;
}

void
yaml_parser_reset(YamlParser *parser)
{
    YamlParserPrivate *priv;

    g_return_if_fail(YAML_IS_PARSER(parser));

    priv = yaml_parser_get_instance_private(parser);

    g_ptr_array_set_size(priv->documents, 0);
    priv->current_line = 0;
    priv->current_column = 0;
}
