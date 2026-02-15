/* yaml-generator.c
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * YamlGenerator implementation - Generates YAML output from nodes and documents.
 */

#include "yaml-generator.h"
#include "yaml-node.h"
#include "yaml-mapping.h"
#include "yaml-sequence.h"
#include "yaml-private.h"
#include <yaml.h>
#include <string.h>

typedef struct
{
    YamlNode     *root;
    YamlDocument *document;
    guint         indent_spaces;
    gboolean      canonical;
    gboolean      unicode;
    gchar        *line_break;
    gboolean      explicit_start;
    gboolean      explicit_end;
} YamlGeneratorPrivate;

G_DEFINE_TYPE_WITH_PRIVATE(YamlGenerator, yaml_generator, G_TYPE_OBJECT)

enum {
    PROP_0,
    PROP_ROOT,
    PROP_INDENT,
    PROP_CANONICAL,
    PROP_UNICODE,
    N_PROPS
};

static GParamSpec *properties[N_PROPS];

static void
yaml_generator_finalize(GObject *object)
{
    YamlGenerator *self = YAML_GENERATOR(object);
    YamlGeneratorPrivate *priv = yaml_generator_get_instance_private(self);

    g_clear_pointer(&priv->root, yaml_node_unref);
    g_clear_object(&priv->document);
    g_free(priv->line_break);

    G_OBJECT_CLASS(yaml_generator_parent_class)->finalize(object);
}

static void
yaml_generator_get_property(
    GObject    *object,
    guint       prop_id,
    GValue     *value,
    GParamSpec *pspec
)
{
    YamlGenerator *self = YAML_GENERATOR(object);
    YamlGeneratorPrivate *priv = yaml_generator_get_instance_private(self);

    switch (prop_id)
    {
        case PROP_ROOT:
            g_value_set_boxed(value, priv->root);
            break;

        case PROP_INDENT:
            g_value_set_uint(value, priv->indent_spaces);
            break;

        case PROP_CANONICAL:
            g_value_set_boolean(value, priv->canonical);
            break;

        case PROP_UNICODE:
            g_value_set_boolean(value, priv->unicode);
            break;

        default:
            G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
            break;
    }
}

static void
yaml_generator_set_property(
    GObject      *object,
    guint         prop_id,
    const GValue *value,
    GParamSpec   *pspec
)
{
    YamlGenerator *self = YAML_GENERATOR(object);

    switch (prop_id)
    {
        case PROP_ROOT:
            yaml_generator_set_root(self, g_value_get_boxed(value));
            break;

        case PROP_INDENT:
            yaml_generator_set_indent(self, g_value_get_uint(value));
            break;

        case PROP_CANONICAL:
            yaml_generator_set_canonical(self, g_value_get_boolean(value));
            break;

        case PROP_UNICODE:
            yaml_generator_set_unicode(self, g_value_get_boolean(value));
            break;

        default:
            G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
            break;
    }
}

static void
yaml_generator_class_init(YamlGeneratorClass *klass)
{
    GObjectClass *object_class = G_OBJECT_CLASS(klass);

    object_class->finalize = yaml_generator_finalize;
    object_class->get_property = yaml_generator_get_property;
    object_class->set_property = yaml_generator_set_property;

    /**
     * YamlGenerator:root:
     *
     * The root node to generate YAML from.
     *
     * Since: 1.0
     */
    properties[PROP_ROOT] =
        g_param_spec_boxed("root",
                           "Root",
                           "The root node to generate YAML from",
                           YAML_TYPE_NODE,
                           G_PARAM_READWRITE |
                           G_PARAM_STATIC_STRINGS);

    /**
     * YamlGenerator:indent:
     *
     * The number of spaces to use for indentation.
     *
     * Since: 1.0
     */
    properties[PROP_INDENT] =
        g_param_spec_uint("indent",
                          "Indent",
                          "Number of spaces for indentation",
                          1, 10, 2,
                          G_PARAM_READWRITE |
                          G_PARAM_STATIC_STRINGS);

    /**
     * YamlGenerator:canonical:
     *
     * Whether to use canonical YAML format.
     *
     * Since: 1.0
     */
    properties[PROP_CANONICAL] =
        g_param_spec_boolean("canonical",
                             "Canonical",
                             "Whether to use canonical format",
                             FALSE,
                             G_PARAM_READWRITE |
                             G_PARAM_STATIC_STRINGS);

    /**
     * YamlGenerator:unicode:
     *
     * Whether to allow unicode characters in output.
     *
     * Since: 1.0
     */
    properties[PROP_UNICODE] =
        g_param_spec_boolean("unicode",
                             "Unicode",
                             "Whether to allow unicode in output",
                             TRUE,
                             G_PARAM_READWRITE |
                             G_PARAM_STATIC_STRINGS);

    g_object_class_install_properties(object_class, N_PROPS, properties);
}

static void
yaml_generator_init(YamlGenerator *self)
{
    YamlGeneratorPrivate *priv = yaml_generator_get_instance_private(self);

    priv->root = NULL;
    priv->document = NULL;
    priv->indent_spaces = 2;
    priv->canonical = FALSE;
    priv->unicode = TRUE;
    priv->line_break = g_strdup("unix");
    priv->explicit_start = FALSE;
    priv->explicit_end = FALSE;
}

YamlGenerator *
yaml_generator_new(void)
{
    return g_object_new(YAML_TYPE_GENERATOR, NULL);
}

void
yaml_generator_set_root(
    YamlGenerator *generator,
    YamlNode      *node
)
{
    YamlGeneratorPrivate *priv;

    g_return_if_fail(YAML_IS_GENERATOR(generator));

    priv = yaml_generator_get_instance_private(generator);

    if (priv->root == node)
        return;

    g_clear_pointer(&priv->root, yaml_node_unref);

    if (node != NULL)
        priv->root = yaml_node_ref(node);

    g_object_notify_by_pspec(G_OBJECT(generator), properties[PROP_ROOT]);
}

YamlNode *
yaml_generator_get_root(YamlGenerator *generator)
{
    YamlGeneratorPrivate *priv;

    g_return_val_if_fail(YAML_IS_GENERATOR(generator), NULL);

    priv = yaml_generator_get_instance_private(generator);

    return priv->root;
}

void
yaml_generator_set_document(
    YamlGenerator *generator,
    YamlDocument  *document
)
{
    YamlGeneratorPrivate *priv;

    g_return_if_fail(YAML_IS_GENERATOR(generator));

    priv = yaml_generator_get_instance_private(generator);

    g_clear_object(&priv->document);

    if (document != NULL)
        priv->document = g_object_ref(document);
}

YamlDocument *
yaml_generator_get_document(YamlGenerator *generator)
{
    YamlGeneratorPrivate *priv;

    g_return_val_if_fail(YAML_IS_GENERATOR(generator), NULL);

    priv = yaml_generator_get_instance_private(generator);

    return priv->document;
}

void
yaml_generator_set_indent(
    YamlGenerator *generator,
    guint          indent_spaces
)
{
    YamlGeneratorPrivate *priv;

    g_return_if_fail(YAML_IS_GENERATOR(generator));
    g_return_if_fail(indent_spaces >= 1 && indent_spaces <= 10);

    priv = yaml_generator_get_instance_private(generator);
    priv->indent_spaces = indent_spaces;

    g_object_notify_by_pspec(G_OBJECT(generator), properties[PROP_INDENT]);
}

guint
yaml_generator_get_indent(YamlGenerator *generator)
{
    YamlGeneratorPrivate *priv;

    g_return_val_if_fail(YAML_IS_GENERATOR(generator), 2);

    priv = yaml_generator_get_instance_private(generator);

    return priv->indent_spaces;
}

void
yaml_generator_set_canonical(
    YamlGenerator *generator,
    gboolean       canonical
)
{
    YamlGeneratorPrivate *priv;

    g_return_if_fail(YAML_IS_GENERATOR(generator));

    priv = yaml_generator_get_instance_private(generator);
    priv->canonical = canonical;

    g_object_notify_by_pspec(G_OBJECT(generator), properties[PROP_CANONICAL]);
}

gboolean
yaml_generator_get_canonical(YamlGenerator *generator)
{
    YamlGeneratorPrivate *priv;

    g_return_val_if_fail(YAML_IS_GENERATOR(generator), FALSE);

    priv = yaml_generator_get_instance_private(generator);

    return priv->canonical;
}

void
yaml_generator_set_unicode(
    YamlGenerator *generator,
    gboolean       unicode
)
{
    YamlGeneratorPrivate *priv;

    g_return_if_fail(YAML_IS_GENERATOR(generator));

    priv = yaml_generator_get_instance_private(generator);
    priv->unicode = unicode;

    g_object_notify_by_pspec(G_OBJECT(generator), properties[PROP_UNICODE]);
}

gboolean
yaml_generator_get_unicode(YamlGenerator *generator)
{
    YamlGeneratorPrivate *priv;

    g_return_val_if_fail(YAML_IS_GENERATOR(generator), TRUE);

    priv = yaml_generator_get_instance_private(generator);

    return priv->unicode;
}

void
yaml_generator_set_line_break(
    YamlGenerator *generator,
    const gchar   *line_break
)
{
    YamlGeneratorPrivate *priv;

    g_return_if_fail(YAML_IS_GENERATOR(generator));
    g_return_if_fail(line_break != NULL);

    priv = yaml_generator_get_instance_private(generator);

    g_free(priv->line_break);
    priv->line_break = g_strdup(line_break);
}

const gchar *
yaml_generator_get_line_break(YamlGenerator *generator)
{
    YamlGeneratorPrivate *priv;

    g_return_val_if_fail(YAML_IS_GENERATOR(generator), "unix");

    priv = yaml_generator_get_instance_private(generator);

    return priv->line_break;
}

void
yaml_generator_set_explicit_start(
    YamlGenerator *generator,
    gboolean       explicit_start
)
{
    YamlGeneratorPrivate *priv;

    g_return_if_fail(YAML_IS_GENERATOR(generator));

    priv = yaml_generator_get_instance_private(generator);
    priv->explicit_start = explicit_start;
}

gboolean
yaml_generator_get_explicit_start(YamlGenerator *generator)
{
    YamlGeneratorPrivate *priv;

    g_return_val_if_fail(YAML_IS_GENERATOR(generator), FALSE);

    priv = yaml_generator_get_instance_private(generator);

    return priv->explicit_start;
}

void
yaml_generator_set_explicit_end(
    YamlGenerator *generator,
    gboolean       explicit_end
)
{
    YamlGeneratorPrivate *priv;

    g_return_if_fail(YAML_IS_GENERATOR(generator));

    priv = yaml_generator_get_instance_private(generator);
    priv->explicit_end = explicit_end;
}

gboolean
yaml_generator_get_explicit_end(YamlGenerator *generator)
{
    YamlGeneratorPrivate *priv;

    g_return_val_if_fail(YAML_IS_GENERATOR(generator), FALSE);

    priv = yaml_generator_get_instance_private(generator);

    return priv->explicit_end;
}

/*
 * get_yaml_line_break:
 * @line_break: the line break string ("unix", "dos", "mac")
 *
 * Converts our line break string to libyaml's enum.
 *
 * Returns: the yaml_break_t value
 */
static yaml_break_t
get_yaml_line_break(const gchar *line_break)
{
    if (g_strcmp0(line_break, "dos") == 0)
        return YAML_CRLN_BREAK;
    else if (g_strcmp0(line_break, "mac") == 0)
        return YAML_CR_BREAK;
    else
        return YAML_LN_BREAK;
}

/*
 * get_yaml_scalar_style:
 * @style: our YamlScalarStyle
 *
 * Converts our scalar style to libyaml's enum.
 *
 * Returns: the yaml_scalar_style_t value
 */
static yaml_scalar_style_t
get_yaml_scalar_style(YamlScalarStyle style)
{
    switch (style)
    {
        case YAML_SCALAR_STYLE_PLAIN:
            return YAML_PLAIN_SCALAR_STYLE;
        case YAML_SCALAR_STYLE_SINGLE_QUOTED:
            return YAML_SINGLE_QUOTED_SCALAR_STYLE;
        case YAML_SCALAR_STYLE_DOUBLE_QUOTED:
            return YAML_DOUBLE_QUOTED_SCALAR_STYLE;
        case YAML_SCALAR_STYLE_LITERAL:
            return YAML_LITERAL_SCALAR_STYLE;
        case YAML_SCALAR_STYLE_FOLDED:
            return YAML_FOLDED_SCALAR_STYLE;
        default:
            return YAML_ANY_SCALAR_STYLE;
    }
}

/*
 * emit_node:
 * @emitter: the libyaml emitter
 * @node: the node to emit
 * @error: return location for error
 *
 * Recursively emits a node and all its children.
 *
 * Returns: TRUE on success
 */
static gboolean
emit_node(
    yaml_emitter_t *emitter,
    YamlNode       *node,
    GError        **error
)
{
    yaml_event_t event;
    YamlNodeType type;
    const gchar *anchor;
    const gchar *tag;

    type = yaml_node_get_node_type(node);
    anchor = yaml_node_get_anchor(node);
    tag = yaml_node_get_tag(node);

    switch (type)
    {
        case YAML_NODE_MAPPING:
        {
            YamlMapping *mapping;
            guint n_members;
            guint i;

            mapping = yaml_node_get_mapping(node);
            n_members = yaml_mapping_get_size(mapping);

            yaml_mapping_start_event_initialize(
                &event,
                (yaml_char_t *)anchor,
                (yaml_char_t *)tag,
                tag == NULL ? 1 : 0,
                YAML_ANY_MAPPING_STYLE
            );

            if (!yaml_emitter_emit(emitter, &event))
            {
                g_set_error(error,
                            YAML_GENERATOR_ERROR,
                            YAML_GENERATOR_ERROR_EMIT,
                            "Failed to emit mapping start");
                return FALSE;
            }

            for (i = 0; i < n_members; i++)
            {
                const gchar *key;
                YamlNode *value;

                key = yaml_mapping_get_key(mapping, i);
                value = yaml_mapping_get_member(mapping, key);

                /* Emit key as scalar */
                yaml_scalar_event_initialize(
                    &event,
                    NULL,
                    NULL,
                    (yaml_char_t *)key,
                    (int)strlen(key),
                    1, 1,
                    YAML_PLAIN_SCALAR_STYLE
                );

                if (!yaml_emitter_emit(emitter, &event))
                {
                    g_set_error(error,
                                YAML_GENERATOR_ERROR,
                                YAML_GENERATOR_ERROR_EMIT,
                                "Failed to emit mapping key");
                    return FALSE;
                }

                /* Emit value */
                if (!emit_node(emitter, value, error))
                    return FALSE;
            }

            yaml_mapping_end_event_initialize(&event);

            if (!yaml_emitter_emit(emitter, &event))
            {
                g_set_error(error,
                            YAML_GENERATOR_ERROR,
                            YAML_GENERATOR_ERROR_EMIT,
                            "Failed to emit mapping end");
                return FALSE;
            }

            break;
        }

        case YAML_NODE_SEQUENCE:
        {
            YamlSequence *sequence;
            guint n_elements;
            guint i;

            sequence = yaml_node_get_sequence(node);
            n_elements = yaml_sequence_get_length(sequence);

            yaml_sequence_start_event_initialize(
                &event,
                (yaml_char_t *)anchor,
                (yaml_char_t *)tag,
                tag == NULL ? 1 : 0,
                YAML_ANY_SEQUENCE_STYLE
            );

            if (!yaml_emitter_emit(emitter, &event))
            {
                g_set_error(error,
                            YAML_GENERATOR_ERROR,
                            YAML_GENERATOR_ERROR_EMIT,
                            "Failed to emit sequence start");
                return FALSE;
            }

            for (i = 0; i < n_elements; i++)
            {
                YamlNode *element;

                element = yaml_sequence_get_element(sequence, i);

                if (!emit_node(emitter, element, error))
                    return FALSE;
            }

            yaml_sequence_end_event_initialize(&event);

            if (!yaml_emitter_emit(emitter, &event))
            {
                g_set_error(error,
                            YAML_GENERATOR_ERROR,
                            YAML_GENERATOR_ERROR_EMIT,
                            "Failed to emit sequence end");
                return FALSE;
            }

            break;
        }

        case YAML_NODE_SCALAR:
        {
            const gchar *value;
            YamlScalarStyle style;

            value = yaml_node_get_scalar(node);
            style = yaml_node_get_scalar_style(node);

            if (value == NULL)
                value = "";

            yaml_scalar_event_initialize(
                &event,
                (yaml_char_t *)anchor,
                (yaml_char_t *)tag,
                (yaml_char_t *)value,
                (int)strlen(value),
                tag == NULL ? 1 : 0,
                tag == NULL ? 1 : 0,
                get_yaml_scalar_style(style)
            );

            if (!yaml_emitter_emit(emitter, &event))
            {
                g_set_error(error,
                            YAML_GENERATOR_ERROR,
                            YAML_GENERATOR_ERROR_EMIT,
                            "Failed to emit scalar");
                return FALSE;
            }

            break;
        }

        case YAML_NODE_NULL:
        {
            yaml_scalar_event_initialize(
                &event,
                (yaml_char_t *)anchor,
                (yaml_char_t *)tag,
                (yaml_char_t *)"null",
                4,
                1, 1,
                YAML_PLAIN_SCALAR_STYLE
            );

            if (!yaml_emitter_emit(emitter, &event))
            {
                g_set_error(error,
                            YAML_GENERATOR_ERROR,
                            YAML_GENERATOR_ERROR_EMIT,
                            "Failed to emit null");
                return FALSE;
            }

            break;
        }
    }

    return TRUE;
}

/*
 * OutputBuffer:
 *
 * Simple buffer for collecting emitter output.
 */
typedef struct
{
    gchar *data;
    gsize  len;
    gsize  allocated;
} OutputBuffer;

/*
 * write_handler:
 *
 * libyaml write handler that appends to our buffer.
 */
static int
write_handler(
    void          *data,
    unsigned char *buffer,
    size_t         size
)
{
    OutputBuffer *output = data;
    gsize new_len;

    new_len = output->len + size;

    if (new_len >= output->allocated)
    {
        output->allocated = MAX(output->allocated * 2, new_len + 1);
        output->data = g_realloc(output->data, output->allocated);
    }

    memcpy(output->data + output->len, buffer, size);
    output->len = new_len;
    output->data[output->len] = '\0';

    return 1;
}

gchar *
yaml_generator_to_data(
    YamlGenerator  *generator,
    gsize          *length,
    GError        **error
)
{
    YamlGeneratorPrivate *priv;
    yaml_emitter_t emitter;
    yaml_event_t event;
    OutputBuffer output = { NULL, 0, 0 };
    YamlNode *root;
    gchar *result;

    g_return_val_if_fail(YAML_IS_GENERATOR(generator), NULL);

    priv = yaml_generator_get_instance_private(generator);

    /* Get root node from document or directly */
    if (priv->document != NULL)
        root = yaml_document_get_root(priv->document);
    else
        root = priv->root;

    if (root == NULL)
    {
        g_set_error(error,
                    YAML_GENERATOR_ERROR,
                    YAML_GENERATOR_ERROR_INVALID_NODE,
                    "No root node to generate");
        return NULL;
    }

    /* Initialize emitter */
    if (!yaml_emitter_initialize(&emitter))
    {
        g_set_error(error,
                    YAML_GENERATOR_ERROR,
                    YAML_GENERATOR_ERROR_EMIT,
                    "Failed to initialize YAML emitter");
        return NULL;
    }

    /* Configure emitter */
    yaml_emitter_set_output(&emitter, write_handler, &output);
    yaml_emitter_set_encoding(&emitter, YAML_UTF8_ENCODING);
    yaml_emitter_set_canonical(&emitter, priv->canonical);
    yaml_emitter_set_indent(&emitter, priv->indent_spaces);
    yaml_emitter_set_unicode(&emitter, priv->unicode);
    yaml_emitter_set_break(&emitter, get_yaml_line_break(priv->line_break));

    /* Emit stream start */
    yaml_stream_start_event_initialize(&event, YAML_UTF8_ENCODING);
    if (!yaml_emitter_emit(&emitter, &event))
    {
        g_set_error(error,
                    YAML_GENERATOR_ERROR,
                    YAML_GENERATOR_ERROR_EMIT,
                    "Failed to emit stream start");
        yaml_emitter_delete(&emitter);
        g_free(output.data);
        return NULL;
    }

    /* Emit document start */
    yaml_document_start_event_initialize(
        &event,
        NULL,  /* version directive */
        NULL,  /* tag directives start */
        NULL,  /* tag directives end */
        priv->explicit_start ? 0 : 1
    );
    if (!yaml_emitter_emit(&emitter, &event))
    {
        g_set_error(error,
                    YAML_GENERATOR_ERROR,
                    YAML_GENERATOR_ERROR_EMIT,
                    "Failed to emit document start");
        yaml_emitter_delete(&emitter);
        g_free(output.data);
        return NULL;
    }

    /* Emit the node tree */
    if (!emit_node(&emitter, root, error))
    {
        yaml_emitter_delete(&emitter);
        g_free(output.data);
        return NULL;
    }

    /* Emit document end */
    yaml_document_end_event_initialize(&event, priv->explicit_end ? 0 : 1);
    if (!yaml_emitter_emit(&emitter, &event))
    {
        g_set_error(error,
                    YAML_GENERATOR_ERROR,
                    YAML_GENERATOR_ERROR_EMIT,
                    "Failed to emit document end");
        yaml_emitter_delete(&emitter);
        g_free(output.data);
        return NULL;
    }

    /* Emit stream end */
    yaml_stream_end_event_initialize(&event);
    if (!yaml_emitter_emit(&emitter, &event))
    {
        g_set_error(error,
                    YAML_GENERATOR_ERROR,
                    YAML_GENERATOR_ERROR_EMIT,
                    "Failed to emit stream end");
        yaml_emitter_delete(&emitter);
        g_free(output.data);
        return NULL;
    }

    yaml_emitter_delete(&emitter);

    result = output.data;

    if (length != NULL)
        *length = output.len;

    return result;
}

gboolean
yaml_generator_to_file(
    YamlGenerator  *generator,
    const gchar    *filename,
    GError        **error
)
{
    gchar *data;
    gsize length;
    gboolean result;

    g_return_val_if_fail(YAML_IS_GENERATOR(generator), FALSE);
    g_return_val_if_fail(filename != NULL, FALSE);

    data = yaml_generator_to_data(generator, &length, error);
    if (data == NULL)
        return FALSE;

    result = g_file_set_contents(filename, data, length, error);
    g_free(data);

    return result;
}

gboolean
yaml_generator_to_gfile(
    YamlGenerator  *generator,
    GFile          *file,
    GCancellable   *cancellable,
    GError        **error
)
{
    gchar *data;
    gsize length;
    gboolean result;

    g_return_val_if_fail(YAML_IS_GENERATOR(generator), FALSE);
    g_return_val_if_fail(G_IS_FILE(file), FALSE);

    data = yaml_generator_to_data(generator, &length, error);
    if (data == NULL)
        return FALSE;

    result = g_file_replace_contents(
        file,
        data,
        length,
        NULL,      /* etag */
        FALSE,     /* make_backup */
        G_FILE_CREATE_NONE,
        NULL,      /* new_etag */
        cancellable,
        error
    );

    g_free(data);

    return result;
}

gboolean
yaml_generator_to_stream(
    YamlGenerator  *generator,
    GOutputStream  *stream,
    GCancellable   *cancellable,
    GError        **error
)
{
    gchar *data;
    gsize length;
    gsize bytes_written;
    gboolean result;

    g_return_val_if_fail(YAML_IS_GENERATOR(generator), FALSE);
    g_return_val_if_fail(G_IS_OUTPUT_STREAM(stream), FALSE);

    data = yaml_generator_to_data(generator, &length, error);
    if (data == NULL)
        return FALSE;

    result = g_output_stream_write_all(
        stream,
        data,
        length,
        &bytes_written,
        cancellable,
        error
    );

    g_free(data);

    return result;
}

/*
 * Async context for stream writing
 */
typedef struct
{
    YamlGenerator *generator;
    gchar         *data;
    gsize          length;
} AsyncStreamContext;

static void
async_stream_context_free(AsyncStreamContext *ctx)
{
    g_object_unref(ctx->generator);
    g_free(ctx->data);
    g_free(ctx);
}

static void
write_all_async_cb(
    GObject      *source_object,
    GAsyncResult *result,
    gpointer      user_data
)
{
    GOutputStream *stream = G_OUTPUT_STREAM(source_object);
    GTask *task = G_TASK(user_data);
    GError *error = NULL;
    gsize bytes_written;

    if (!g_output_stream_write_all_finish(stream, result, &bytes_written, &error))
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
yaml_generator_to_stream_async(
    YamlGenerator       *generator,
    GOutputStream       *stream,
    GCancellable        *cancellable,
    GAsyncReadyCallback  callback,
    gpointer             user_data
)
{
    GTask *task;
    AsyncStreamContext *ctx;
    GError *error = NULL;

    g_return_if_fail(YAML_IS_GENERATOR(generator));
    g_return_if_fail(G_IS_OUTPUT_STREAM(stream));

    task = g_task_new(generator, cancellable, callback, user_data);
    g_task_set_source_tag(task, yaml_generator_to_stream_async);

    ctx = g_new0(AsyncStreamContext, 1);
    ctx->generator = g_object_ref(generator);
    ctx->data = yaml_generator_to_data(generator, &ctx->length, &error);

    if (ctx->data == NULL)
    {
        g_task_return_error(task, error);
        async_stream_context_free(ctx);
        g_object_unref(task);
        return;
    }

    g_task_set_task_data(task, ctx, (GDestroyNotify)async_stream_context_free);

    g_output_stream_write_all_async(
        stream,
        ctx->data,
        ctx->length,
        G_PRIORITY_DEFAULT,
        cancellable,
        write_all_async_cb,
        task
    );
}

gboolean
yaml_generator_to_stream_finish(
    YamlGenerator  *generator,
    GAsyncResult   *result,
    GError        **error
)
{
    g_return_val_if_fail(YAML_IS_GENERATOR(generator), FALSE);
    g_return_val_if_fail(g_task_is_valid(result, generator), FALSE);

    return g_task_propagate_boolean(G_TASK(result), error);
}

/*
 * Async context for GFile writing
 */
typedef struct
{
    YamlGenerator *generator;
    GFile         *file;
    gchar         *data;
    gsize          length;
} AsyncGFileContext;

static void
async_gfile_context_free(AsyncGFileContext *ctx)
{
    g_object_unref(ctx->generator);
    g_object_unref(ctx->file);
    g_free(ctx->data);
    g_free(ctx);
}

static void
replace_contents_async_cb(
    GObject      *source_object,
    GAsyncResult *result,
    gpointer      user_data
)
{
    GFile *file = G_FILE(source_object);
    GTask *task = G_TASK(user_data);
    GError *error = NULL;

    if (!g_file_replace_contents_finish(file, result, NULL, &error))
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
yaml_generator_to_gfile_async(
    YamlGenerator       *generator,
    GFile               *file,
    GCancellable        *cancellable,
    GAsyncReadyCallback  callback,
    gpointer             user_data
)
{
    GTask *task;
    AsyncGFileContext *ctx;
    GError *error = NULL;

    g_return_if_fail(YAML_IS_GENERATOR(generator));
    g_return_if_fail(G_IS_FILE(file));

    task = g_task_new(generator, cancellable, callback, user_data);
    g_task_set_source_tag(task, yaml_generator_to_gfile_async);

    ctx = g_new0(AsyncGFileContext, 1);
    ctx->generator = g_object_ref(generator);
    ctx->file = g_object_ref(file);
    ctx->data = yaml_generator_to_data(generator, &ctx->length, &error);

    if (ctx->data == NULL)
    {
        g_task_return_error(task, error);
        async_gfile_context_free(ctx);
        g_object_unref(task);
        return;
    }

    g_task_set_task_data(task, ctx, (GDestroyNotify)async_gfile_context_free);

    g_file_replace_contents_async(
        file,
        ctx->data,
        ctx->length,
        NULL,      /* etag */
        FALSE,     /* make_backup */
        G_FILE_CREATE_NONE,
        cancellable,
        replace_contents_async_cb,
        task
    );
}

gboolean
yaml_generator_to_gfile_finish(
    YamlGenerator  *generator,
    GAsyncResult   *result,
    GError        **error
)
{
    g_return_val_if_fail(YAML_IS_GENERATOR(generator), FALSE);
    g_return_val_if_fail(g_task_is_valid(result, generator), FALSE);

    return g_task_propagate_boolean(G_TASK(result), error);
}
