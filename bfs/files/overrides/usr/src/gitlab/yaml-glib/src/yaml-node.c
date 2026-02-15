/* yaml-node.c
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * YamlNode implementation.
 */

#include "yaml-node.h"
#include "yaml-mapping.h"
#include "yaml-sequence.h"
#include "yaml-private.h"
#include <string.h>
#include <stdlib.h>

G_DEFINE_BOXED_TYPE(YamlNode, yaml_node,
                    yaml_node_ref, yaml_node_unref)

/*
 * Internal helper to clear node contents without freeing the node.
 */
void
yaml_node_clear_internal(YamlNode *node)
{
    g_return_if_fail(node != NULL);

    g_clear_pointer(&node->tag, g_free);
    g_clear_pointer(&node->anchor, g_free);

    switch (node->type)
    {
        case YAML_NODE_MAPPING:
            g_clear_pointer(&node->data.mapping, yaml_mapping_unref);
            break;

        case YAML_NODE_SEQUENCE:
            g_clear_pointer(&node->data.sequence, yaml_sequence_unref);
            break;

        case YAML_NODE_SCALAR:
            g_clear_pointer(&node->data.scalar.value, g_free);
            break;

        case YAML_NODE_NULL:
        default:
            break;
    }
}

/*
 * Internal helper to parse scalar string to typed values.
 */
void
yaml_node_parse_scalar_internal(YamlNode *node)
{
    const gchar *value;
    gchar *endptr;

    g_return_if_fail(node != NULL);
    g_return_if_fail(node->type == YAML_NODE_SCALAR);

    value = node->data.scalar.value;
    if (value == NULL)
        return;

    /* Reset cached values */
    node->data.scalar.has_int = FALSE;
    node->data.scalar.has_double = FALSE;
    node->data.scalar.has_boolean = FALSE;

    /* Try boolean */
    if (g_str_equal(value, "true") || g_str_equal(value, "True") ||
        g_str_equal(value, "TRUE") || g_str_equal(value, "yes") ||
        g_str_equal(value, "Yes") || g_str_equal(value, "YES") ||
        g_str_equal(value, "on") || g_str_equal(value, "On") ||
        g_str_equal(value, "ON"))
    {
        node->data.scalar.has_boolean = TRUE;
        node->data.scalar.boolean_value = TRUE;
        return;
    }

    if (g_str_equal(value, "false") || g_str_equal(value, "False") ||
        g_str_equal(value, "FALSE") || g_str_equal(value, "no") ||
        g_str_equal(value, "No") || g_str_equal(value, "NO") ||
        g_str_equal(value, "off") || g_str_equal(value, "Off") ||
        g_str_equal(value, "OFF"))
    {
        node->data.scalar.has_boolean = TRUE;
        node->data.scalar.boolean_value = FALSE;
        return;
    }

    /* Try integer */
    node->data.scalar.int_value = g_ascii_strtoll(value, &endptr, 10);
    if (endptr != value && *endptr == '\0')
    {
        node->data.scalar.has_int = TRUE;
        node->data.scalar.has_double = TRUE;
        node->data.scalar.double_value = (gdouble)node->data.scalar.int_value;
        return;
    }

    /* Try double */
    node->data.scalar.double_value = g_ascii_strtod(value, &endptr);
    if (endptr != value && *endptr == '\0')
    {
        node->data.scalar.has_double = TRUE;
        return;
    }
}

YamlNode *
yaml_node_alloc(void)
{
    YamlNode *node;

    node = g_slice_new0(YamlNode);
    node->ref_count = 1;
    node->type = YAML_NODE_NULL;
    node->immutable = FALSE;
    node->parent = NULL;
    node->tag = NULL;
    node->anchor = NULL;

    return node;
}

YamlNode *
yaml_node_new(YamlNodeType type)
{
    YamlNode *node;

    node = yaml_node_alloc();
    yaml_node_init(node, type);

    return node;
}

YamlNode *
yaml_node_init(
    YamlNode    *node,
    YamlNodeType type
)
{
    g_return_val_if_fail(node != NULL, NULL);

    node->type = type;

    switch (type)
    {
        case YAML_NODE_MAPPING:
            node->data.mapping = yaml_mapping_new();
            break;

        case YAML_NODE_SEQUENCE:
            node->data.sequence = yaml_sequence_new();
            break;

        case YAML_NODE_SCALAR:
            node->data.scalar.value = NULL;
            node->data.scalar.style = YAML_SCALAR_STYLE_ANY;
            node->data.scalar.has_int = FALSE;
            node->data.scalar.has_double = FALSE;
            node->data.scalar.has_boolean = FALSE;
            break;

        case YAML_NODE_NULL:
        default:
            break;
    }

    return node;
}

YamlNode *
yaml_node_init_mapping(
    YamlNode    *node,
    YamlMapping *mapping
)
{
    g_return_val_if_fail(node != NULL, NULL);

    node->type = YAML_NODE_MAPPING;

    if (mapping != NULL)
        node->data.mapping = yaml_mapping_ref(mapping);
    else
        node->data.mapping = yaml_mapping_new();

    return node;
}

YamlNode *
yaml_node_init_sequence(
    YamlNode     *node,
    YamlSequence *sequence
)
{
    g_return_val_if_fail(node != NULL, NULL);

    node->type = YAML_NODE_SEQUENCE;

    if (sequence != NULL)
        node->data.sequence = yaml_sequence_ref(sequence);
    else
        node->data.sequence = yaml_sequence_new();

    return node;
}

YamlNode *
yaml_node_init_string(
    YamlNode    *node,
    const gchar *value
)
{
    g_return_val_if_fail(node != NULL, NULL);

    node->type = YAML_NODE_SCALAR;
    node->data.scalar.value = g_strdup(value);
    node->data.scalar.style = YAML_SCALAR_STYLE_ANY;
    yaml_node_parse_scalar_internal(node);

    return node;
}

YamlNode *
yaml_node_init_int(
    YamlNode *node,
    gint64    value
)
{
    g_return_val_if_fail(node != NULL, NULL);

    node->type = YAML_NODE_SCALAR;
    node->data.scalar.value = g_strdup_printf("%" G_GINT64_FORMAT, value);
    node->data.scalar.style = YAML_SCALAR_STYLE_PLAIN;
    node->data.scalar.has_int = TRUE;
    node->data.scalar.int_value = value;
    node->data.scalar.has_double = TRUE;
    node->data.scalar.double_value = (gdouble)value;
    node->data.scalar.has_boolean = FALSE;

    return node;
}

YamlNode *
yaml_node_init_double(
    YamlNode *node,
    gdouble   value
)
{
    g_return_val_if_fail(node != NULL, NULL);

    node->type = YAML_NODE_SCALAR;
    node->data.scalar.value = g_strdup_printf("%g", value);
    node->data.scalar.style = YAML_SCALAR_STYLE_PLAIN;
    node->data.scalar.has_int = FALSE;
    node->data.scalar.has_double = TRUE;
    node->data.scalar.double_value = value;
    node->data.scalar.has_boolean = FALSE;

    return node;
}

YamlNode *
yaml_node_init_boolean(
    YamlNode *node,
    gboolean  value
)
{
    g_return_val_if_fail(node != NULL, NULL);

    node->type = YAML_NODE_SCALAR;
    node->data.scalar.value = g_strdup(value ? "true" : "false");
    node->data.scalar.style = YAML_SCALAR_STYLE_PLAIN;
    node->data.scalar.has_int = FALSE;
    node->data.scalar.has_double = FALSE;
    node->data.scalar.has_boolean = TRUE;
    node->data.scalar.boolean_value = value;

    return node;
}

YamlNode *
yaml_node_init_null(YamlNode *node)
{
    g_return_val_if_fail(node != NULL, NULL);

    node->type = YAML_NODE_NULL;

    return node;
}

YamlNode *
yaml_node_ref(YamlNode *node)
{
    g_return_val_if_fail(node != NULL, NULL);
    g_return_val_if_fail(node->ref_count > 0, NULL);

    g_atomic_int_inc(&node->ref_count);

    return node;
}

void
yaml_node_unref(YamlNode *node)
{
    g_return_if_fail(node != NULL);
    g_return_if_fail(node->ref_count > 0);

    if (g_atomic_int_dec_and_test(&node->ref_count))
    {
        yaml_node_clear_internal(node);
        g_slice_free(YamlNode, node);
    }
}

YamlNode *
yaml_node_copy(YamlNode *node)
{
    YamlNode *copy;

    g_return_val_if_fail(node != NULL, NULL);

    copy = yaml_node_alloc();
    copy->type = node->type;
    copy->tag = g_strdup(node->tag);
    copy->anchor = g_strdup(node->anchor);

    switch (node->type)
    {
        case YAML_NODE_MAPPING:
            /* Deep copy mapping */
            copy->data.mapping = yaml_mapping_new();
            {
                GList *members = yaml_mapping_get_members(node->data.mapping);
                GList *l;
                for (l = members; l != NULL; l = l->next)
                {
                    const gchar *key = l->data;
                    YamlNode *value = yaml_mapping_get_member(node->data.mapping, key);
                    YamlNode *value_copy = yaml_node_copy(value);
                    yaml_mapping_set_member(copy->data.mapping, key, value_copy);
                    yaml_node_unref(value_copy);
                }
                g_list_free(members);
            }
            break;

        case YAML_NODE_SEQUENCE:
            /* Deep copy sequence */
            copy->data.sequence = yaml_sequence_sized_new(
                yaml_sequence_get_length(node->data.sequence)
            );
            {
                guint i;
                guint len = yaml_sequence_get_length(node->data.sequence);
                for (i = 0; i < len; i++)
                {
                    YamlNode *elem = yaml_sequence_get_element(node->data.sequence, i);
                    YamlNode *elem_copy = yaml_node_copy(elem);
                    yaml_sequence_add_element(copy->data.sequence, elem_copy);
                    yaml_node_unref(elem_copy);
                }
            }
            break;

        case YAML_NODE_SCALAR:
            copy->data.scalar.value = g_strdup(node->data.scalar.value);
            copy->data.scalar.style = node->data.scalar.style;
            copy->data.scalar.has_int = node->data.scalar.has_int;
            copy->data.scalar.int_value = node->data.scalar.int_value;
            copy->data.scalar.has_double = node->data.scalar.has_double;
            copy->data.scalar.double_value = node->data.scalar.double_value;
            copy->data.scalar.has_boolean = node->data.scalar.has_boolean;
            copy->data.scalar.boolean_value = node->data.scalar.boolean_value;
            break;

        case YAML_NODE_NULL:
        default:
            break;
    }

    return copy;
}

YamlNodeType
yaml_node_get_node_type(YamlNode *node)
{
    g_return_val_if_fail(node != NULL, YAML_NODE_NULL);

    return node->type;
}

gboolean
yaml_node_is_null(YamlNode *node)
{
    g_return_val_if_fail(node != NULL, TRUE);

    return node->type == YAML_NODE_NULL;
}

void
yaml_node_seal(YamlNode *node)
{
    g_return_if_fail(node != NULL);

    if (node->immutable)
        return;

    node->immutable = TRUE;

    switch (node->type)
    {
        case YAML_NODE_MAPPING:
            if (node->data.mapping != NULL)
                yaml_mapping_seal(node->data.mapping);
            break;

        case YAML_NODE_SEQUENCE:
            if (node->data.sequence != NULL)
                yaml_sequence_seal(node->data.sequence);
            break;

        default:
            break;
    }
}

gboolean
yaml_node_is_immutable(YamlNode *node)
{
    g_return_val_if_fail(node != NULL, TRUE);

    return node->immutable;
}

/* Mapping accessors */

void
yaml_node_set_mapping(
    YamlNode    *node,
    YamlMapping *mapping
)
{
    g_return_if_fail(node != NULL);
    g_return_if_fail(mapping != NULL);

    if (node->immutable)
    {
        g_warning("yaml_node_set_mapping: node is immutable");
        return;
    }

    yaml_node_clear_internal(node);
    node->type = YAML_NODE_MAPPING;
    node->data.mapping = yaml_mapping_ref(mapping);
}

void
yaml_node_take_mapping(
    YamlNode    *node,
    YamlMapping *mapping
)
{
    g_return_if_fail(node != NULL);
    g_return_if_fail(mapping != NULL);

    if (node->immutable)
    {
        g_warning("yaml_node_take_mapping: node is immutable");
        yaml_mapping_unref(mapping);
        return;
    }

    yaml_node_clear_internal(node);
    node->type = YAML_NODE_MAPPING;
    node->data.mapping = mapping;  /* Take ownership */
}

YamlMapping *
yaml_node_get_mapping(YamlNode *node)
{
    g_return_val_if_fail(node != NULL, NULL);

    if (node->type != YAML_NODE_MAPPING)
        return NULL;

    return node->data.mapping;
}

YamlMapping *
yaml_node_dup_mapping(YamlNode *node)
{
    g_return_val_if_fail(node != NULL, NULL);

    if (node->type != YAML_NODE_MAPPING || node->data.mapping == NULL)
        return NULL;

    return yaml_mapping_ref(node->data.mapping);
}

/* Sequence accessors */

void
yaml_node_set_sequence(
    YamlNode     *node,
    YamlSequence *sequence
)
{
    g_return_if_fail(node != NULL);
    g_return_if_fail(sequence != NULL);

    if (node->immutable)
    {
        g_warning("yaml_node_set_sequence: node is immutable");
        return;
    }

    yaml_node_clear_internal(node);
    node->type = YAML_NODE_SEQUENCE;
    node->data.sequence = yaml_sequence_ref(sequence);
}

void
yaml_node_take_sequence(
    YamlNode     *node,
    YamlSequence *sequence
)
{
    g_return_if_fail(node != NULL);
    g_return_if_fail(sequence != NULL);

    if (node->immutable)
    {
        g_warning("yaml_node_take_sequence: node is immutable");
        yaml_sequence_unref(sequence);
        return;
    }

    yaml_node_clear_internal(node);
    node->type = YAML_NODE_SEQUENCE;
    node->data.sequence = sequence;  /* Take ownership */
}

YamlSequence *
yaml_node_get_sequence(YamlNode *node)
{
    g_return_val_if_fail(node != NULL, NULL);

    if (node->type != YAML_NODE_SEQUENCE)
        return NULL;

    return node->data.sequence;
}

YamlSequence *
yaml_node_dup_sequence(YamlNode *node)
{
    g_return_val_if_fail(node != NULL, NULL);

    if (node->type != YAML_NODE_SEQUENCE || node->data.sequence == NULL)
        return NULL;

    return yaml_sequence_ref(node->data.sequence);
}

/* Scalar accessors */

void
yaml_node_set_string(
    YamlNode    *node,
    const gchar *value
)
{
    g_return_if_fail(node != NULL);

    if (node->immutable)
    {
        g_warning("yaml_node_set_string: node is immutable");
        return;
    }

    yaml_node_clear_internal(node);
    node->type = YAML_NODE_SCALAR;
    node->data.scalar.value = g_strdup(value);
    node->data.scalar.style = YAML_SCALAR_STYLE_ANY;
    yaml_node_parse_scalar_internal(node);
}

const gchar *
yaml_node_get_string(YamlNode *node)
{
    g_return_val_if_fail(node != NULL, NULL);

    if (node->type != YAML_NODE_SCALAR)
        return NULL;

    return node->data.scalar.value;
}

gchar *
yaml_node_dup_string(YamlNode *node)
{
    g_return_val_if_fail(node != NULL, NULL);

    if (node->type != YAML_NODE_SCALAR)
        return NULL;

    return g_strdup(node->data.scalar.value);
}

void
yaml_node_set_int(
    YamlNode *node,
    gint64    value
)
{
    g_return_if_fail(node != NULL);

    if (node->immutable)
    {
        g_warning("yaml_node_set_int: node is immutable");
        return;
    }

    yaml_node_clear_internal(node);
    yaml_node_init_int(node, value);
}

gint64
yaml_node_get_int(YamlNode *node)
{
    g_return_val_if_fail(node != NULL, 0);

    if (node->type != YAML_NODE_SCALAR)
        return 0;

    if (node->data.scalar.has_int)
        return node->data.scalar.int_value;

    if (node->data.scalar.value != NULL)
        return g_ascii_strtoll(node->data.scalar.value, NULL, 10);

    return 0;
}

void
yaml_node_set_double(
    YamlNode *node,
    gdouble   value
)
{
    g_return_if_fail(node != NULL);

    if (node->immutable)
    {
        g_warning("yaml_node_set_double: node is immutable");
        return;
    }

    yaml_node_clear_internal(node);
    yaml_node_init_double(node, value);
}

gdouble
yaml_node_get_double(YamlNode *node)
{
    g_return_val_if_fail(node != NULL, 0.0);

    if (node->type != YAML_NODE_SCALAR)
        return 0.0;

    if (node->data.scalar.has_double)
        return node->data.scalar.double_value;

    if (node->data.scalar.value != NULL)
        return g_ascii_strtod(node->data.scalar.value, NULL);

    return 0.0;
}

void
yaml_node_set_boolean(
    YamlNode *node,
    gboolean  value
)
{
    g_return_if_fail(node != NULL);

    if (node->immutable)
    {
        g_warning("yaml_node_set_boolean: node is immutable");
        return;
    }

    yaml_node_clear_internal(node);
    yaml_node_init_boolean(node, value);
}

gboolean
yaml_node_get_boolean(YamlNode *node)
{
    g_return_val_if_fail(node != NULL, FALSE);

    if (node->type != YAML_NODE_SCALAR)
        return FALSE;

    if (node->data.scalar.has_boolean)
        return node->data.scalar.boolean_value;

    return FALSE;
}

/* YAML-specific metadata */

void
yaml_node_set_tag(
    YamlNode    *node,
    const gchar *tag
)
{
    g_return_if_fail(node != NULL);

    if (node->immutable)
    {
        g_warning("yaml_node_set_tag: node is immutable");
        return;
    }

    g_free(node->tag);
    node->tag = g_strdup(tag);
}

const gchar *
yaml_node_get_tag(YamlNode *node)
{
    g_return_val_if_fail(node != NULL, NULL);

    return node->tag;
}

void
yaml_node_set_anchor(
    YamlNode    *node,
    const gchar *anchor
)
{
    g_return_if_fail(node != NULL);

    if (node->immutable)
    {
        g_warning("yaml_node_set_anchor: node is immutable");
        return;
    }

    g_free(node->anchor);
    node->anchor = g_strdup(anchor);
}

const gchar *
yaml_node_get_anchor(YamlNode *node)
{
    g_return_val_if_fail(node != NULL, NULL);

    return node->anchor;
}

void
yaml_node_set_scalar_style(
    YamlNode       *node,
    YamlScalarStyle style
)
{
    g_return_if_fail(node != NULL);

    if (node->immutable)
    {
        g_warning("yaml_node_set_scalar_style: node is immutable");
        return;
    }

    if (node->type == YAML_NODE_SCALAR)
        node->data.scalar.style = style;
}

YamlScalarStyle
yaml_node_get_scalar_style(YamlNode *node)
{
    g_return_val_if_fail(node != NULL, YAML_SCALAR_STYLE_ANY);

    if (node->type != YAML_NODE_SCALAR)
        return YAML_SCALAR_STYLE_ANY;

    return node->data.scalar.style;
}

/* Parent relationship */

void
yaml_node_set_parent(
    YamlNode *node,
    YamlNode *parent
)
{
    g_return_if_fail(node != NULL);

    /* Parent is a weak reference to avoid cycles */
    node->parent = parent;
}

YamlNode *
yaml_node_get_parent(YamlNode *node)
{
    g_return_val_if_fail(node != NULL, NULL);

    return node->parent;
}

/* Equality and hashing */

guint
yaml_node_hash(gconstpointer key)
{
    YamlNode *node = (YamlNode *)key;
    guint hash;

    if (node == NULL)
        return 0;

    hash = g_direct_hash(GINT_TO_POINTER(node->type));

    switch (node->type)
    {
        case YAML_NODE_MAPPING:
            if (node->data.mapping != NULL)
                hash ^= yaml_mapping_hash(node->data.mapping);
            break;

        case YAML_NODE_SEQUENCE:
            if (node->data.sequence != NULL)
                hash ^= yaml_sequence_hash(node->data.sequence);
            break;

        case YAML_NODE_SCALAR:
            if (node->data.scalar.value != NULL)
                hash ^= g_str_hash(node->data.scalar.value);
            break;

        default:
            break;
    }

    return hash;
}

gboolean
yaml_node_equal(
    gconstpointer a,
    gconstpointer b
)
{
    YamlNode *na = (YamlNode *)a;
    YamlNode *nb = (YamlNode *)b;

    if (na == nb)
        return TRUE;

    if (na == NULL || nb == NULL)
        return FALSE;

    if (na->type != nb->type)
        return FALSE;

    switch (na->type)
    {
        case YAML_NODE_MAPPING:
            return yaml_mapping_equal(na->data.mapping, nb->data.mapping);

        case YAML_NODE_SEQUENCE:
            return yaml_sequence_equal(na->data.sequence, nb->data.sequence);

        case YAML_NODE_SCALAR:
            return g_strcmp0(na->data.scalar.value, nb->data.scalar.value) == 0;

        case YAML_NODE_NULL:
            return TRUE;

        default:
            return FALSE;
    }
}

/* JSON-GLib interoperability */

YamlNode *
yaml_node_from_json_node(JsonNode *json_node)
{
    YamlNode *node;

    g_return_val_if_fail(json_node != NULL, NULL);

    node = yaml_node_alloc();

    switch (json_node_get_node_type(json_node))
    {
        case JSON_NODE_OBJECT:
        {
            JsonObject *object = json_node_get_object(json_node);
            GList *members;
            GList *l;

            yaml_node_init(node, YAML_NODE_MAPPING);
            members = json_object_get_members(object);

            for (l = members; l != NULL; l = l->next)
            {
                const gchar *name = l->data;
                JsonNode *child = json_object_get_member(object, name);
                YamlNode *yaml_child = yaml_node_from_json_node(child);

                yaml_mapping_set_member(node->data.mapping, name, yaml_child);
                yaml_node_unref(yaml_child);
            }

            g_list_free(members);
            break;
        }

        case JSON_NODE_ARRAY:
        {
            JsonArray *array = json_node_get_array(json_node);
            guint len = json_array_get_length(array);
            guint i;

            yaml_node_init(node, YAML_NODE_SEQUENCE);

            for (i = 0; i < len; i++)
            {
                JsonNode *child = json_array_get_element(array, i);
                YamlNode *yaml_child = yaml_node_from_json_node(child);

                yaml_sequence_add_element(node->data.sequence, yaml_child);
                yaml_node_unref(yaml_child);
            }
            break;
        }

        case JSON_NODE_VALUE:
        {
            GType value_type = json_node_get_value_type(json_node);

            if (value_type == G_TYPE_STRING)
            {
                yaml_node_init_string(node, json_node_get_string(json_node));
            }
            else if (value_type == G_TYPE_INT64)
            {
                yaml_node_init_int(node, json_node_get_int(json_node));
            }
            else if (value_type == G_TYPE_DOUBLE)
            {
                yaml_node_init_double(node, json_node_get_double(json_node));
            }
            else if (value_type == G_TYPE_BOOLEAN)
            {
                yaml_node_init_boolean(node, json_node_get_boolean(json_node));
            }
            else
            {
                yaml_node_init_null(node);
            }
            break;
        }

        case JSON_NODE_NULL:
        default:
            yaml_node_init_null(node);
            break;
    }

    return node;
}

JsonNode *
yaml_node_to_json_node(YamlNode *node)
{
    JsonNode *json_node;

    g_return_val_if_fail(node != NULL, NULL);

    switch (node->type)
    {
        case YAML_NODE_MAPPING:
        {
            JsonObject *object = json_object_new();
            GList *members;
            GList *l;

            members = yaml_mapping_get_members(node->data.mapping);

            for (l = members; l != NULL; l = l->next)
            {
                const gchar *name = l->data;
                YamlNode *child = yaml_mapping_get_member(node->data.mapping, name);
                JsonNode *json_child = yaml_node_to_json_node(child);

                json_object_set_member(object, name, json_child);
            }

            g_list_free(members);

            json_node = json_node_new(JSON_NODE_OBJECT);
            json_node_take_object(json_node, object);
            break;
        }

        case YAML_NODE_SEQUENCE:
        {
            JsonArray *array = json_array_new();
            guint len = yaml_sequence_get_length(node->data.sequence);
            guint i;

            for (i = 0; i < len; i++)
            {
                YamlNode *child = yaml_sequence_get_element(node->data.sequence, i);
                JsonNode *json_child = yaml_node_to_json_node(child);

                json_array_add_element(array, json_child);
            }

            json_node = json_node_new(JSON_NODE_ARRAY);
            json_node_take_array(json_node, array);
            break;
        }

        case YAML_NODE_SCALAR:
        {
            json_node = json_node_new(JSON_NODE_VALUE);

            if (node->data.scalar.has_boolean)
            {
                json_node_set_boolean(json_node, node->data.scalar.boolean_value);
            }
            else if (node->data.scalar.has_int)
            {
                json_node_set_int(json_node, node->data.scalar.int_value);
            }
            else if (node->data.scalar.has_double)
            {
                json_node_set_double(json_node, node->data.scalar.double_value);
            }
            else
            {
                json_node_set_string(json_node, node->data.scalar.value);
            }
            break;
        }

        case YAML_NODE_NULL:
        default:
            json_node = json_node_new(JSON_NODE_NULL);
            break;
    }

    return json_node;
}

/* Convenience constructors */

YamlNode *
yaml_node_new_mapping(YamlMapping *mapping)
{
    YamlNode *node = yaml_node_alloc();
    return yaml_node_init_mapping(node, mapping);
}

YamlNode *
yaml_node_new_sequence(YamlSequence *sequence)
{
    YamlNode *node = yaml_node_alloc();
    return yaml_node_init_sequence(node, sequence);
}

YamlNode *
yaml_node_new_string(const gchar *value)
{
    YamlNode *node = yaml_node_alloc();
    return yaml_node_init_string(node, value);
}

YamlNode *
yaml_node_new_int(gint64 value)
{
    YamlNode *node = yaml_node_alloc();
    return yaml_node_init_int(node, value);
}

YamlNode *
yaml_node_new_double(gdouble value)
{
    YamlNode *node = yaml_node_alloc();
    return yaml_node_init_double(node, value);
}

YamlNode *
yaml_node_new_boolean(gboolean value)
{
    YamlNode *node = yaml_node_alloc();
    return yaml_node_init_boolean(node, value);
}

YamlNode *
yaml_node_new_null(void)
{
    YamlNode *node = yaml_node_alloc();
    return yaml_node_init_null(node);
}

YamlNode *
yaml_node_new_scalar(
    const gchar    *value,
    YamlScalarStyle style
)
{
    YamlNode *node = yaml_node_alloc();
    yaml_node_init_string(node, value);
    yaml_node_set_scalar_style(node, style);
    return node;
}

const gchar *
yaml_node_get_scalar(YamlNode *node)
{
    g_return_val_if_fail(node != NULL, NULL);

    if (node->type != YAML_NODE_SCALAR)
        return NULL;

    return node->data.scalar.value;
}

/* Error domain quark implementations */

GQuark
yaml_glib_parser_error_quark(void)
{
    return g_quark_from_static_string("yaml-glib-parser-error-quark");
}

GQuark
yaml_generator_error_quark(void)
{
    return g_quark_from_static_string("yaml-generator-error-quark");
}

GQuark
yaml_schema_error_quark(void)
{
    return g_quark_from_static_string("yaml-schema-error-quark");
}
