/* yaml-sequence.c
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * YamlSequence implementation.
 */

#include "yaml-sequence.h"
#include "yaml-node.h"
#include "yaml-mapping.h"
#include "yaml-private.h"

G_DEFINE_BOXED_TYPE(YamlSequence, yaml_sequence,
                    yaml_sequence_ref, yaml_sequence_unref)

YamlSequence *
yaml_sequence_new(void)
{
    return yaml_sequence_sized_new(8);
}

YamlSequence *
yaml_sequence_sized_new(guint n_elements)
{
    YamlSequence *sequence;

    sequence = g_slice_new0(YamlSequence);
    sequence->ref_count = 1;
    sequence->immutable = FALSE;
    sequence->elements = g_ptr_array_new_full(
        n_elements,
        (GDestroyNotify)yaml_node_unref
    );

    return sequence;
}

YamlSequence *
yaml_sequence_ref(YamlSequence *sequence)
{
    g_return_val_if_fail(sequence != NULL, NULL);
    g_return_val_if_fail(sequence->ref_count > 0, NULL);

    g_atomic_int_inc(&sequence->ref_count);

    return sequence;
}

void
yaml_sequence_unref(YamlSequence *sequence)
{
    g_return_if_fail(sequence != NULL);
    g_return_if_fail(sequence->ref_count > 0);

    if (g_atomic_int_dec_and_test(&sequence->ref_count))
    {
        g_ptr_array_free(sequence->elements, TRUE);
        g_slice_free(YamlSequence, sequence);
    }
}

void
yaml_sequence_seal(YamlSequence *sequence)
{
    guint i;

    g_return_if_fail(sequence != NULL);

    if (sequence->immutable)
        return;

    sequence->immutable = TRUE;

    /* Seal all contained nodes */
    for (i = 0; i < sequence->elements->len; i++)
    {
        YamlNode *node = g_ptr_array_index(sequence->elements, i);
        yaml_node_seal(node);
    }
}

gboolean
yaml_sequence_is_immutable(YamlSequence *sequence)
{
    g_return_val_if_fail(sequence != NULL, TRUE);

    return sequence->immutable;
}

guint
yaml_sequence_get_length(YamlSequence *sequence)
{
    g_return_val_if_fail(sequence != NULL, 0);

    return sequence->elements->len;
}

void
yaml_sequence_add_element(
    YamlSequence *sequence,
    YamlNode     *node
)
{
    g_return_if_fail(sequence != NULL);
    g_return_if_fail(node != NULL);

    if (sequence->immutable)
    {
        g_warning("yaml_sequence_add_element: sequence is immutable");
        return;
    }

    g_ptr_array_add(sequence->elements, yaml_node_ref(node));
}

YamlNode *
yaml_sequence_get_element(
    YamlSequence *sequence,
    guint         index_
)
{
    g_return_val_if_fail(sequence != NULL, NULL);

    if (index_ >= sequence->elements->len)
        return NULL;

    return g_ptr_array_index(sequence->elements, index_);
}

YamlNode *
yaml_sequence_dup_element(
    YamlSequence *sequence,
    guint         index_
)
{
    YamlNode *node;

    g_return_val_if_fail(sequence != NULL, NULL);

    if (index_ >= sequence->elements->len)
        return NULL;

    node = g_ptr_array_index(sequence->elements, index_);
    return yaml_node_ref(node);
}

void
yaml_sequence_remove_element(
    YamlSequence *sequence,
    guint         index_
)
{
    g_return_if_fail(sequence != NULL);

    if (sequence->immutable)
    {
        g_warning("yaml_sequence_remove_element: sequence is immutable");
        return;
    }

    if (index_ < sequence->elements->len)
    {
        g_ptr_array_remove_index(sequence->elements, index_);
    }
}

/* Convenience adders */

void
yaml_sequence_add_string_element(
    YamlSequence *sequence,
    const gchar  *value
)
{
    g_autoptr(YamlNode) node = NULL;

    g_return_if_fail(sequence != NULL);

    node = yaml_node_alloc();
    yaml_node_init_string(node, value);
    yaml_sequence_add_element(sequence, node);
}

void
yaml_sequence_add_int_element(
    YamlSequence *sequence,
    gint64        value
)
{
    g_autoptr(YamlNode) node = NULL;

    g_return_if_fail(sequence != NULL);

    node = yaml_node_alloc();
    yaml_node_init_int(node, value);
    yaml_sequence_add_element(sequence, node);
}

void
yaml_sequence_add_double_element(
    YamlSequence *sequence,
    gdouble       value
)
{
    g_autoptr(YamlNode) node = NULL;

    g_return_if_fail(sequence != NULL);

    node = yaml_node_alloc();
    yaml_node_init_double(node, value);
    yaml_sequence_add_element(sequence, node);
}

void
yaml_sequence_add_boolean_element(
    YamlSequence *sequence,
    gboolean      value
)
{
    g_autoptr(YamlNode) node = NULL;

    g_return_if_fail(sequence != NULL);

    node = yaml_node_alloc();
    yaml_node_init_boolean(node, value);
    yaml_sequence_add_element(sequence, node);
}

void
yaml_sequence_add_null_element(YamlSequence *sequence)
{
    g_autoptr(YamlNode) node = NULL;

    g_return_if_fail(sequence != NULL);

    node = yaml_node_alloc();
    yaml_node_init_null(node);
    yaml_sequence_add_element(sequence, node);
}

void
yaml_sequence_add_mapping_element(
    YamlSequence *sequence,
    YamlMapping  *value
)
{
    g_autoptr(YamlNode) node = NULL;

    g_return_if_fail(sequence != NULL);
    g_return_if_fail(value != NULL);

    node = yaml_node_alloc();
    yaml_node_init_mapping(node, value);
    yaml_sequence_add_element(sequence, node);
}

void
yaml_sequence_add_sequence_element(
    YamlSequence *sequence,
    YamlSequence *value
)
{
    g_autoptr(YamlNode) node = NULL;

    g_return_if_fail(sequence != NULL);
    g_return_if_fail(value != NULL);

    node = yaml_node_alloc();
    yaml_node_init_sequence(node, value);
    yaml_sequence_add_element(sequence, node);
}

/* Convenience getters */

const gchar *
yaml_sequence_get_string_element(
    YamlSequence *sequence,
    guint         index_
)
{
    YamlNode *node;

    g_return_val_if_fail(sequence != NULL, NULL);

    node = yaml_sequence_get_element(sequence, index_);
    if (node == NULL)
        return NULL;

    return yaml_node_get_string(node);
}

gint64
yaml_sequence_get_int_element(
    YamlSequence *sequence,
    guint         index_
)
{
    YamlNode *node;

    g_return_val_if_fail(sequence != NULL, 0);

    node = yaml_sequence_get_element(sequence, index_);
    if (node == NULL)
        return 0;

    return yaml_node_get_int(node);
}

gdouble
yaml_sequence_get_double_element(
    YamlSequence *sequence,
    guint         index_
)
{
    YamlNode *node;

    g_return_val_if_fail(sequence != NULL, 0.0);

    node = yaml_sequence_get_element(sequence, index_);
    if (node == NULL)
        return 0.0;

    return yaml_node_get_double(node);
}

gboolean
yaml_sequence_get_boolean_element(
    YamlSequence *sequence,
    guint         index_
)
{
    YamlNode *node;

    g_return_val_if_fail(sequence != NULL, FALSE);

    node = yaml_sequence_get_element(sequence, index_);
    if (node == NULL)
        return FALSE;

    return yaml_node_get_boolean(node);
}

gboolean
yaml_sequence_get_null_element(
    YamlSequence *sequence,
    guint         index_
)
{
    YamlNode *node;

    g_return_val_if_fail(sequence != NULL, FALSE);

    node = yaml_sequence_get_element(sequence, index_);
    if (node == NULL)
        return FALSE;

    return yaml_node_is_null(node);
}

YamlMapping *
yaml_sequence_get_mapping_element(
    YamlSequence *sequence,
    guint         index_
)
{
    YamlNode *node;

    g_return_val_if_fail(sequence != NULL, NULL);

    node = yaml_sequence_get_element(sequence, index_);
    if (node == NULL)
        return NULL;

    return yaml_node_get_mapping(node);
}

YamlSequence *
yaml_sequence_get_sequence_element(
    YamlSequence *sequence,
    guint         index_
)
{
    YamlNode *node;

    g_return_val_if_fail(sequence != NULL, NULL);

    node = yaml_sequence_get_element(sequence, index_);
    if (node == NULL)
        return NULL;

    return yaml_node_get_sequence(node);
}

GList *
yaml_sequence_get_elements(YamlSequence *sequence)
{
    GList *list;
    guint i;

    g_return_val_if_fail(sequence != NULL, NULL);

    list = NULL;
    for (i = 0; i < sequence->elements->len; i++)
    {
        YamlNode *node = g_ptr_array_index(sequence->elements, i);
        list = g_list_append(list, node);
    }

    return list;
}

void
yaml_sequence_foreach_element(
    YamlSequence        *sequence,
    YamlSequenceForeach  func,
    gpointer             user_data
)
{
    guint i;

    g_return_if_fail(sequence != NULL);
    g_return_if_fail(func != NULL);

    for (i = 0; i < sequence->elements->len; i++)
    {
        YamlNode *node = g_ptr_array_index(sequence->elements, i);
        func(sequence, i, node, user_data);
    }
}

guint
yaml_sequence_hash(gconstpointer key)
{
    YamlSequence *sequence = (YamlSequence *)key;
    guint hash = 0;
    guint i;

    if (sequence == NULL)
        return 0;

    /* Hash based on length and first few elements */
    hash = g_direct_hash(GUINT_TO_POINTER(sequence->elements->len));

    for (i = 0; i < sequence->elements->len && i < 5; i++)
    {
        YamlNode *node = g_ptr_array_index(sequence->elements, i);
        hash ^= yaml_node_hash(node);
    }

    return hash;
}

gboolean
yaml_sequence_equal(
    gconstpointer a,
    gconstpointer b
)
{
    YamlSequence *sa = (YamlSequence *)a;
    YamlSequence *sb = (YamlSequence *)b;
    guint i;

    if (sa == sb)
        return TRUE;

    if (sa == NULL || sb == NULL)
        return FALSE;

    if (sa->elements->len != sb->elements->len)
        return FALSE;

    for (i = 0; i < sa->elements->len; i++)
    {
        YamlNode *node_a = g_ptr_array_index(sa->elements, i);
        YamlNode *node_b = g_ptr_array_index(sb->elements, i);

        if (!yaml_node_equal(node_a, node_b))
            return FALSE;
    }

    return TRUE;
}
