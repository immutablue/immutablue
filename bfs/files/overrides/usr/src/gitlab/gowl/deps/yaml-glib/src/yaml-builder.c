/* yaml-builder.c
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * YamlBuilder implementation - Fluent API for building YAML documents.
 */

#include "yaml-builder.h"
#include "yaml-node.h"
#include "yaml-mapping.h"
#include "yaml-sequence.h"
#include "yaml-private.h"

/*
 * BuilderState:
 *
 * Represents the current state of the builder stack.
 * Each nested mapping or sequence pushes a new state.
 */
typedef enum
{
    BUILDER_STATE_MAPPING,
    BUILDER_STATE_SEQUENCE
} BuilderState;

/*
 * BuilderFrame:
 *
 * A stack frame representing a nested mapping or sequence
 * being constructed.
 */
typedef struct
{
    BuilderState  state;
    YamlNode     *node;         /* The mapping or sequence node being built */
    gchar        *member_name;  /* For mappings: the pending key name */
} BuilderFrame;

typedef struct
{
    GQueue      *stack;         /* Stack of BuilderFrame */
    YamlNode    *root;          /* The completed root node */
    gboolean     immutable;     /* Whether to seal nodes */
    gchar       *pending_anchor;
    gchar       *pending_tag;
    GHashTable  *anchors;       /* anchor name -> YamlNode for aliases */
} YamlBuilderPrivate;

G_DEFINE_TYPE_WITH_PRIVATE(YamlBuilder, yaml_builder, G_TYPE_OBJECT)

enum {
    PROP_0,
    PROP_IMMUTABLE,
    N_PROPS
};

static GParamSpec *properties[N_PROPS];

static void
builder_frame_free(BuilderFrame *frame)
{
    if (frame == NULL)
        return;

    g_clear_pointer(&frame->node, yaml_node_unref);
    g_free(frame->member_name);
    g_free(frame);
}

static BuilderFrame *
builder_frame_new(
    BuilderState  state,
    YamlNode     *node
)
{
    BuilderFrame *frame;

    frame = g_new0(BuilderFrame, 1);
    frame->state = state;
    frame->node = yaml_node_ref(node);
    frame->member_name = NULL;

    return frame;
}

static void
yaml_builder_finalize(GObject *object)
{
    YamlBuilder *self = YAML_BUILDER(object);
    YamlBuilderPrivate *priv = yaml_builder_get_instance_private(self);

    g_queue_free_full(priv->stack, (GDestroyNotify)builder_frame_free);
    g_clear_pointer(&priv->root, yaml_node_unref);
    g_free(priv->pending_anchor);
    g_free(priv->pending_tag);
    g_clear_pointer(&priv->anchors, g_hash_table_destroy);

    G_OBJECT_CLASS(yaml_builder_parent_class)->finalize(object);
}

static void
yaml_builder_get_property(
    GObject    *object,
    guint       prop_id,
    GValue     *value,
    GParamSpec *pspec
)
{
    YamlBuilder *self = YAML_BUILDER(object);
    YamlBuilderPrivate *priv = yaml_builder_get_instance_private(self);

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
yaml_builder_set_property(
    GObject      *object,
    guint         prop_id,
    const GValue *value,
    GParamSpec   *pspec
)
{
    YamlBuilder *self = YAML_BUILDER(object);
    YamlBuilderPrivate *priv = yaml_builder_get_instance_private(self);

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
yaml_builder_class_init(YamlBuilderClass *klass)
{
    GObjectClass *object_class = G_OBJECT_CLASS(klass);

    object_class->finalize = yaml_builder_finalize;
    object_class->get_property = yaml_builder_get_property;
    object_class->set_property = yaml_builder_set_property;

    /**
     * YamlBuilder:immutable:
     *
     * Whether the builder produces immutable nodes.
     *
     * Since: 1.0
     */
    properties[PROP_IMMUTABLE] =
        g_param_spec_boolean("immutable",
                             "Immutable",
                             "Whether to produce immutable nodes",
                             FALSE,
                             G_PARAM_READWRITE |
                             G_PARAM_CONSTRUCT |
                             G_PARAM_STATIC_STRINGS);

    g_object_class_install_properties(object_class, N_PROPS, properties);
}

static void
yaml_builder_init(YamlBuilder *self)
{
    YamlBuilderPrivate *priv = yaml_builder_get_instance_private(self);

    priv->stack = g_queue_new();
    priv->root = NULL;
    priv->immutable = FALSE;
    priv->pending_anchor = NULL;
    priv->pending_tag = NULL;
    priv->anchors = g_hash_table_new_full(
        g_str_hash,
        g_str_equal,
        g_free,
        (GDestroyNotify)yaml_node_unref
    );
}

YamlBuilder *
yaml_builder_new(void)
{
    return g_object_new(YAML_TYPE_BUILDER, NULL);
}

YamlBuilder *
yaml_builder_new_immutable(void)
{
    return g_object_new(YAML_TYPE_BUILDER,
                        "immutable", TRUE,
                        NULL);
}

gboolean
yaml_builder_get_immutable(YamlBuilder *builder)
{
    YamlBuilderPrivate *priv;

    g_return_val_if_fail(YAML_IS_BUILDER(builder), FALSE);

    priv = yaml_builder_get_instance_private(builder);

    return priv->immutable;
}

void
yaml_builder_set_immutable(
    YamlBuilder *builder,
    gboolean     immutable
)
{
    YamlBuilderPrivate *priv;

    g_return_if_fail(YAML_IS_BUILDER(builder));

    priv = yaml_builder_get_instance_private(builder);
    priv->immutable = immutable;

    g_object_notify_by_pspec(G_OBJECT(builder), properties[PROP_IMMUTABLE]);
}

/*
 * apply_pending_metadata:
 * @builder: the builder
 * @node: the node to apply metadata to
 *
 * Applies any pending anchor or tag to the node and clears the pending state.
 */
static void
apply_pending_metadata(
    YamlBuilder *builder,
    YamlNode    *node
)
{
    YamlBuilderPrivate *priv = yaml_builder_get_instance_private(builder);

    if (priv->pending_anchor != NULL)
    {
        yaml_node_set_anchor(node, priv->pending_anchor);
        /* Store in anchors table for alias resolution */
        g_hash_table_insert(
            priv->anchors,
            g_strdup(priv->pending_anchor),
            yaml_node_ref(node)
        );
        g_clear_pointer(&priv->pending_anchor, g_free);
    }

    if (priv->pending_tag != NULL)
    {
        yaml_node_set_tag(node, priv->pending_tag);
        g_clear_pointer(&priv->pending_tag, g_free);
    }
}

/*
 * add_value_to_context:
 * @builder: the builder
 * @node: the node to add
 *
 * Adds a node to the current context (mapping or sequence).
 * If there's no context, the node becomes the root.
 */
static void
add_value_to_context(
    YamlBuilder *builder,
    YamlNode    *node
)
{
    YamlBuilderPrivate *priv = yaml_builder_get_instance_private(builder);
    BuilderFrame *frame;
    YamlMapping *mapping;
    YamlSequence *sequence;

    apply_pending_metadata(builder, node);

    if (g_queue_is_empty(priv->stack))
    {
        /* No context - this becomes the root */
        g_clear_pointer(&priv->root, yaml_node_unref);
        priv->root = yaml_node_ref(node);
        return;
    }

    frame = g_queue_peek_head(priv->stack);

    switch (frame->state)
    {
        case BUILDER_STATE_MAPPING:
            if (frame->member_name == NULL)
            {
                g_warning("yaml_builder: value added to mapping without member name");
                return;
            }
            mapping = yaml_node_get_mapping(frame->node);
            yaml_mapping_set_member(mapping, frame->member_name, node);
            g_clear_pointer(&frame->member_name, g_free);
            break;

        case BUILDER_STATE_SEQUENCE:
            sequence = yaml_node_get_sequence(frame->node);
            yaml_sequence_add_element(sequence, node);
            break;
    }
}

YamlBuilder *
yaml_builder_begin_mapping(YamlBuilder *builder)
{
    YamlBuilderPrivate *priv;
    YamlNode *node;
    YamlMapping *mapping;
    BuilderFrame *frame;

    g_return_val_if_fail(YAML_IS_BUILDER(builder), NULL);

    priv = yaml_builder_get_instance_private(builder);

    mapping = yaml_mapping_new();
    node = yaml_node_new_mapping(mapping);
    yaml_mapping_unref(mapping);

    apply_pending_metadata(builder, node);

    frame = builder_frame_new(BUILDER_STATE_MAPPING, node);
    g_queue_push_head(priv->stack, frame);

    yaml_node_unref(node);

    return builder;
}

YamlBuilder *
yaml_builder_end_mapping(YamlBuilder *builder)
{
    YamlBuilderPrivate *priv;
    BuilderFrame *frame;
    YamlNode *node;

    g_return_val_if_fail(YAML_IS_BUILDER(builder), NULL);

    priv = yaml_builder_get_instance_private(builder);

    if (g_queue_is_empty(priv->stack))
    {
        g_warning("yaml_builder_end_mapping: no mapping to end");
        return builder;
    }

    frame = g_queue_peek_head(priv->stack);

    if (frame->state != BUILDER_STATE_MAPPING)
    {
        g_warning("yaml_builder_end_mapping: current context is not a mapping");
        return builder;
    }

    frame = g_queue_pop_head(priv->stack);
    node = yaml_node_ref(frame->node);

    if (priv->immutable)
        yaml_node_seal(node);

    builder_frame_free(frame);

    /* Add completed mapping to parent context */
    add_value_to_context(builder, node);
    yaml_node_unref(node);

    return builder;
}

YamlBuilder *
yaml_builder_set_member_name(
    YamlBuilder *builder,
    const gchar *name
)
{
    YamlBuilderPrivate *priv;
    BuilderFrame *frame;

    g_return_val_if_fail(YAML_IS_BUILDER(builder), NULL);
    g_return_val_if_fail(name != NULL, builder);

    priv = yaml_builder_get_instance_private(builder);

    if (g_queue_is_empty(priv->stack))
    {
        g_warning("yaml_builder_set_member_name: not inside a mapping");
        return builder;
    }

    frame = g_queue_peek_head(priv->stack);

    if (frame->state != BUILDER_STATE_MAPPING)
    {
        g_warning("yaml_builder_set_member_name: current context is not a mapping");
        return builder;
    }

    g_free(frame->member_name);
    frame->member_name = g_strdup(name);

    return builder;
}

YamlBuilder *
yaml_builder_begin_sequence(YamlBuilder *builder)
{
    YamlBuilderPrivate *priv;
    YamlNode *node;
    YamlSequence *sequence;
    BuilderFrame *frame;

    g_return_val_if_fail(YAML_IS_BUILDER(builder), NULL);

    priv = yaml_builder_get_instance_private(builder);

    sequence = yaml_sequence_new();
    node = yaml_node_new_sequence(sequence);
    yaml_sequence_unref(sequence);

    apply_pending_metadata(builder, node);

    frame = builder_frame_new(BUILDER_STATE_SEQUENCE, node);
    g_queue_push_head(priv->stack, frame);

    yaml_node_unref(node);

    return builder;
}

YamlBuilder *
yaml_builder_end_sequence(YamlBuilder *builder)
{
    YamlBuilderPrivate *priv;
    BuilderFrame *frame;
    YamlNode *node;

    g_return_val_if_fail(YAML_IS_BUILDER(builder), NULL);

    priv = yaml_builder_get_instance_private(builder);

    if (g_queue_is_empty(priv->stack))
    {
        g_warning("yaml_builder_end_sequence: no sequence to end");
        return builder;
    }

    frame = g_queue_peek_head(priv->stack);

    if (frame->state != BUILDER_STATE_SEQUENCE)
    {
        g_warning("yaml_builder_end_sequence: current context is not a sequence");
        return builder;
    }

    frame = g_queue_pop_head(priv->stack);
    node = yaml_node_ref(frame->node);

    if (priv->immutable)
        yaml_node_seal(node);

    builder_frame_free(frame);

    /* Add completed sequence to parent context */
    add_value_to_context(builder, node);
    yaml_node_unref(node);

    return builder;
}

YamlBuilder *
yaml_builder_add_null_value(YamlBuilder *builder)
{
    YamlNode *node;

    g_return_val_if_fail(YAML_IS_BUILDER(builder), NULL);

    node = yaml_node_new_null();
    add_value_to_context(builder, node);
    yaml_node_unref(node);

    return builder;
}

YamlBuilder *
yaml_builder_add_boolean_value(
    YamlBuilder *builder,
    gboolean     value
)
{
    YamlNode *node;

    g_return_val_if_fail(YAML_IS_BUILDER(builder), NULL);

    node = yaml_node_new_boolean(value);
    add_value_to_context(builder, node);
    yaml_node_unref(node);

    return builder;
}

YamlBuilder *
yaml_builder_add_int_value(
    YamlBuilder *builder,
    gint64       value
)
{
    YamlNode *node;

    g_return_val_if_fail(YAML_IS_BUILDER(builder), NULL);

    node = yaml_node_new_int(value);
    add_value_to_context(builder, node);
    yaml_node_unref(node);

    return builder;
}

YamlBuilder *
yaml_builder_add_double_value(
    YamlBuilder *builder,
    gdouble      value
)
{
    YamlNode *node;

    g_return_val_if_fail(YAML_IS_BUILDER(builder), NULL);

    node = yaml_node_new_double(value);
    add_value_to_context(builder, node);
    yaml_node_unref(node);

    return builder;
}

YamlBuilder *
yaml_builder_add_string_value(
    YamlBuilder *builder,
    const gchar *value
)
{
    YamlNode *node;

    g_return_val_if_fail(YAML_IS_BUILDER(builder), NULL);

    node = yaml_node_new_string(value);
    add_value_to_context(builder, node);
    yaml_node_unref(node);

    return builder;
}

YamlBuilder *
yaml_builder_add_scalar_value(
    YamlBuilder     *builder,
    const gchar     *value,
    YamlScalarStyle  style
)
{
    YamlNode *node;

    g_return_val_if_fail(YAML_IS_BUILDER(builder), NULL);

    node = yaml_node_new_scalar(value, style);
    add_value_to_context(builder, node);
    yaml_node_unref(node);

    return builder;
}

YamlBuilder *
yaml_builder_add_value(
    YamlBuilder *builder,
    YamlNode    *node
)
{
    g_return_val_if_fail(YAML_IS_BUILDER(builder), NULL);
    g_return_val_if_fail(node != NULL, builder);

    add_value_to_context(builder, node);

    return builder;
}

YamlBuilder *
yaml_builder_set_anchor(
    YamlBuilder *builder,
    const gchar *anchor
)
{
    YamlBuilderPrivate *priv;

    g_return_val_if_fail(YAML_IS_BUILDER(builder), NULL);
    g_return_val_if_fail(anchor != NULL, builder);

    priv = yaml_builder_get_instance_private(builder);

    g_free(priv->pending_anchor);
    priv->pending_anchor = g_strdup(anchor);

    return builder;
}

YamlBuilder *
yaml_builder_set_tag(
    YamlBuilder *builder,
    const gchar *tag
)
{
    YamlBuilderPrivate *priv;

    g_return_val_if_fail(YAML_IS_BUILDER(builder), NULL);
    g_return_val_if_fail(tag != NULL, builder);

    priv = yaml_builder_get_instance_private(builder);

    g_free(priv->pending_tag);
    priv->pending_tag = g_strdup(tag);

    return builder;
}

YamlBuilder *
yaml_builder_add_alias(
    YamlBuilder *builder,
    const gchar *anchor
)
{
    YamlBuilderPrivate *priv;
    YamlNode *referenced_node;

    g_return_val_if_fail(YAML_IS_BUILDER(builder), NULL);
    g_return_val_if_fail(anchor != NULL, builder);

    priv = yaml_builder_get_instance_private(builder);

    referenced_node = g_hash_table_lookup(priv->anchors, anchor);
    if (referenced_node == NULL)
    {
        g_warning("yaml_builder_add_alias: unknown anchor '%s'", anchor);
        return builder;
    }

    /*
     * For aliases, we add the same node reference.
     * This creates shared structure in the built tree.
     */
    add_value_to_context(builder, referenced_node);

    return builder;
}

YamlNode *
yaml_builder_get_root(YamlBuilder *builder)
{
    YamlBuilderPrivate *priv;

    g_return_val_if_fail(YAML_IS_BUILDER(builder), NULL);

    priv = yaml_builder_get_instance_private(builder);

    if (!g_queue_is_empty(priv->stack))
    {
        g_warning("yaml_builder_get_root: builder has unclosed structures");
        return NULL;
    }

    return priv->root;
}

YamlNode *
yaml_builder_dup_root(YamlBuilder *builder)
{
    YamlBuilderPrivate *priv;

    g_return_val_if_fail(YAML_IS_BUILDER(builder), NULL);

    priv = yaml_builder_get_instance_private(builder);

    if (!g_queue_is_empty(priv->stack))
    {
        g_warning("yaml_builder_dup_root: builder has unclosed structures");
        return NULL;
    }

    if (priv->root != NULL)
        return yaml_node_ref(priv->root);

    return NULL;
}

YamlNode *
yaml_builder_steal_root(YamlBuilder *builder)
{
    YamlBuilderPrivate *priv;
    YamlNode *root;

    g_return_val_if_fail(YAML_IS_BUILDER(builder), NULL);

    priv = yaml_builder_get_instance_private(builder);

    if (!g_queue_is_empty(priv->stack))
    {
        g_warning("yaml_builder_steal_root: builder has unclosed structures");
        return NULL;
    }

    root = priv->root;
    priv->root = NULL;

    /* Clear anchors since they reference nodes we may not own anymore */
    g_hash_table_remove_all(priv->anchors);

    return root;
}

YamlDocument *
yaml_builder_get_document(YamlBuilder *builder)
{
    YamlBuilderPrivate *priv;
    YamlDocument *doc;

    g_return_val_if_fail(YAML_IS_BUILDER(builder), NULL);

    priv = yaml_builder_get_instance_private(builder);

    if (!g_queue_is_empty(priv->stack))
    {
        g_warning("yaml_builder_get_document: builder has unclosed structures");
        return NULL;
    }

    doc = yaml_document_new_with_root(priv->root);

    if (priv->immutable)
        yaml_document_seal(doc);

    return doc;
}

void
yaml_builder_reset(YamlBuilder *builder)
{
    YamlBuilderPrivate *priv;

    g_return_if_fail(YAML_IS_BUILDER(builder));

    priv = yaml_builder_get_instance_private(builder);

    g_queue_free_full(priv->stack, (GDestroyNotify)builder_frame_free);
    priv->stack = g_queue_new();

    g_clear_pointer(&priv->root, yaml_node_unref);
    g_clear_pointer(&priv->pending_anchor, g_free);
    g_clear_pointer(&priv->pending_tag, g_free);
    g_hash_table_remove_all(priv->anchors);
}
