/* yaml-mapping.c
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * YamlMapping implementation.
 */

#include "yaml-mapping.h"
#include "yaml-node.h"
#include "yaml-sequence.h"
#include "yaml-private.h"
#include <string.h>

G_DEFINE_BOXED_TYPE(YamlMapping, yaml_mapping,
                    yaml_mapping_ref, yaml_mapping_unref)

YamlMapping *
yaml_mapping_new(void)
{
    YamlMapping *mapping;

    mapping = g_slice_new0(YamlMapping);
    mapping->ref_count = 1;
    mapping->immutable = FALSE;
    mapping->members = g_hash_table_new_full(
        g_str_hash,
        g_str_equal,
        g_free,
        (GDestroyNotify)yaml_node_unref
    );
    mapping->keys_order = g_ptr_array_new_with_free_func(g_free);

    return mapping;
}

YamlMapping *
yaml_mapping_ref(YamlMapping *mapping)
{
    g_return_val_if_fail(mapping != NULL, NULL);
    g_return_val_if_fail(mapping->ref_count > 0, NULL);

    g_atomic_int_inc(&mapping->ref_count);

    return mapping;
}

void
yaml_mapping_unref(YamlMapping *mapping)
{
    g_return_if_fail(mapping != NULL);
    g_return_if_fail(mapping->ref_count > 0);

    if (g_atomic_int_dec_and_test(&mapping->ref_count))
    {
        g_hash_table_destroy(mapping->members);
        g_ptr_array_free(mapping->keys_order, TRUE);
        g_slice_free(YamlMapping, mapping);
    }
}

void
yaml_mapping_seal(YamlMapping *mapping)
{
    GHashTableIter iter;
    gpointer value;

    g_return_if_fail(mapping != NULL);

    if (mapping->immutable)
        return;

    mapping->immutable = TRUE;

    /* Seal all contained nodes */
    g_hash_table_iter_init(&iter, mapping->members);
    while (g_hash_table_iter_next(&iter, NULL, &value))
    {
        yaml_node_seal((YamlNode *)value);
    }
}

gboolean
yaml_mapping_is_immutable(YamlMapping *mapping)
{
    g_return_val_if_fail(mapping != NULL, TRUE);

    return mapping->immutable;
}

guint
yaml_mapping_get_size(YamlMapping *mapping)
{
    g_return_val_if_fail(mapping != NULL, 0);

    return g_hash_table_size(mapping->members);
}

const gchar *
yaml_mapping_get_key(
    YamlMapping *mapping,
    guint        index
)
{
    g_return_val_if_fail(mapping != NULL, NULL);

    if (index >= mapping->keys_order->len)
        return NULL;

    return g_ptr_array_index(mapping->keys_order, index);
}

YamlNode *
yaml_mapping_get_value(
    YamlMapping *mapping,
    guint        index
)
{
    const gchar *key;

    g_return_val_if_fail(mapping != NULL, NULL);

    key = yaml_mapping_get_key(mapping, index);
    if (key == NULL)
        return NULL;

    return g_hash_table_lookup(mapping->members, key);
}

gboolean
yaml_mapping_has_member(
    YamlMapping *mapping,
    const gchar *member_name
)
{
    g_return_val_if_fail(mapping != NULL, FALSE);
    g_return_val_if_fail(member_name != NULL, FALSE);

    return g_hash_table_contains(mapping->members, member_name);
}

GList *
yaml_mapping_get_members(YamlMapping *mapping)
{
    GList *list;
    guint i;

    g_return_val_if_fail(mapping != NULL, NULL);

    list = NULL;
    /* Return in insertion order */
    for (i = 0; i < mapping->keys_order->len; i++)
    {
        const gchar *key = g_ptr_array_index(mapping->keys_order, i);
        list = g_list_append(list, (gpointer)key);
    }

    return list;
}

void
yaml_mapping_set_member(
    YamlMapping *mapping,
    const gchar *member_name,
    YamlNode    *node
)
{
    g_return_if_fail(mapping != NULL);
    g_return_if_fail(member_name != NULL);
    g_return_if_fail(node != NULL);

    if (mapping->immutable)
    {
        g_warning("yaml_mapping_set_member: mapping is immutable");
        return;
    }

    /* Track key order for new keys */
    if (!g_hash_table_contains(mapping->members, member_name))
    {
        g_ptr_array_add(mapping->keys_order, g_strdup(member_name));
    }

    g_hash_table_insert(
        mapping->members,
        g_strdup(member_name),
        yaml_node_ref(node)
    );
}

YamlNode *
yaml_mapping_get_member(
    YamlMapping *mapping,
    const gchar *member_name
)
{
    g_return_val_if_fail(mapping != NULL, NULL);
    g_return_val_if_fail(member_name != NULL, NULL);

    return g_hash_table_lookup(mapping->members, member_name);
}

YamlNode *
yaml_mapping_dup_member(
    YamlMapping *mapping,
    const gchar *member_name
)
{
    YamlNode *node;

    g_return_val_if_fail(mapping != NULL, NULL);
    g_return_val_if_fail(member_name != NULL, NULL);

    node = g_hash_table_lookup(mapping->members, member_name);
    if (node != NULL)
        return yaml_node_ref(node);

    return NULL;
}

gboolean
yaml_mapping_remove_member(
    YamlMapping *mapping,
    const gchar *member_name
)
{
    guint i;

    g_return_val_if_fail(mapping != NULL, FALSE);
    g_return_val_if_fail(member_name != NULL, FALSE);

    if (mapping->immutable)
    {
        g_warning("yaml_mapping_remove_member: mapping is immutable");
        return FALSE;
    }

    /* Remove from ordered keys list */
    for (i = 0; i < mapping->keys_order->len; i++)
    {
        const gchar *key = g_ptr_array_index(mapping->keys_order, i);
        if (g_str_equal(key, member_name))
        {
            g_ptr_array_remove_index(mapping->keys_order, i);
            break;
        }
    }

    return g_hash_table_remove(mapping->members, member_name);
}

/* Convenience setters */

void
yaml_mapping_set_string_member(
    YamlMapping *mapping,
    const gchar *member_name,
    const gchar *value
)
{
    g_autoptr(YamlNode) node = NULL;

    g_return_if_fail(mapping != NULL);
    g_return_if_fail(member_name != NULL);

    node = yaml_node_alloc();
    yaml_node_init_string(node, value);
    yaml_mapping_set_member(mapping, member_name, node);
}

void
yaml_mapping_set_int_member(
    YamlMapping *mapping,
    const gchar *member_name,
    gint64       value
)
{
    g_autoptr(YamlNode) node = NULL;

    g_return_if_fail(mapping != NULL);
    g_return_if_fail(member_name != NULL);

    node = yaml_node_alloc();
    yaml_node_init_int(node, value);
    yaml_mapping_set_member(mapping, member_name, node);
}

void
yaml_mapping_set_double_member(
    YamlMapping *mapping,
    const gchar *member_name,
    gdouble      value
)
{
    g_autoptr(YamlNode) node = NULL;

    g_return_if_fail(mapping != NULL);
    g_return_if_fail(member_name != NULL);

    node = yaml_node_alloc();
    yaml_node_init_double(node, value);
    yaml_mapping_set_member(mapping, member_name, node);
}

void
yaml_mapping_set_boolean_member(
    YamlMapping *mapping,
    const gchar *member_name,
    gboolean     value
)
{
    g_autoptr(YamlNode) node = NULL;

    g_return_if_fail(mapping != NULL);
    g_return_if_fail(member_name != NULL);

    node = yaml_node_alloc();
    yaml_node_init_boolean(node, value);
    yaml_mapping_set_member(mapping, member_name, node);
}

void
yaml_mapping_set_null_member(
    YamlMapping *mapping,
    const gchar *member_name
)
{
    g_autoptr(YamlNode) node = NULL;

    g_return_if_fail(mapping != NULL);
    g_return_if_fail(member_name != NULL);

    node = yaml_node_alloc();
    yaml_node_init_null(node);
    yaml_mapping_set_member(mapping, member_name, node);
}

void
yaml_mapping_set_mapping_member(
    YamlMapping *mapping,
    const gchar *member_name,
    YamlMapping *value
)
{
    g_autoptr(YamlNode) node = NULL;

    g_return_if_fail(mapping != NULL);
    g_return_if_fail(member_name != NULL);
    g_return_if_fail(value != NULL);

    node = yaml_node_alloc();
    yaml_node_init_mapping(node, value);
    yaml_mapping_set_member(mapping, member_name, node);
}

void
yaml_mapping_set_sequence_member(
    YamlMapping  *mapping,
    const gchar  *member_name,
    YamlSequence *value
)
{
    g_autoptr(YamlNode) node = NULL;

    g_return_if_fail(mapping != NULL);
    g_return_if_fail(member_name != NULL);
    g_return_if_fail(value != NULL);

    node = yaml_node_alloc();
    yaml_node_init_sequence(node, value);
    yaml_mapping_set_member(mapping, member_name, node);
}

/* Convenience getters */

const gchar *
yaml_mapping_get_string_member(
    YamlMapping *mapping,
    const gchar *member_name
)
{
    YamlNode *node;

    g_return_val_if_fail(mapping != NULL, NULL);
    g_return_val_if_fail(member_name != NULL, NULL);

    node = yaml_mapping_get_member(mapping, member_name);
    if (node == NULL)
        return NULL;

    return yaml_node_get_string(node);
}

gint64
yaml_mapping_get_int_member(
    YamlMapping *mapping,
    const gchar *member_name
)
{
    YamlNode *node;

    g_return_val_if_fail(mapping != NULL, 0);
    g_return_val_if_fail(member_name != NULL, 0);

    node = yaml_mapping_get_member(mapping, member_name);
    if (node == NULL)
        return 0;

    return yaml_node_get_int(node);
}

gdouble
yaml_mapping_get_double_member(
    YamlMapping *mapping,
    const gchar *member_name
)
{
    YamlNode *node;

    g_return_val_if_fail(mapping != NULL, 0.0);
    g_return_val_if_fail(member_name != NULL, 0.0);

    node = yaml_mapping_get_member(mapping, member_name);
    if (node == NULL)
        return 0.0;

    return yaml_node_get_double(node);
}

gboolean
yaml_mapping_get_boolean_member(
    YamlMapping *mapping,
    const gchar *member_name
)
{
    YamlNode *node;

    g_return_val_if_fail(mapping != NULL, FALSE);
    g_return_val_if_fail(member_name != NULL, FALSE);

    node = yaml_mapping_get_member(mapping, member_name);
    if (node == NULL)
        return FALSE;

    return yaml_node_get_boolean(node);
}

gboolean
yaml_mapping_get_null_member(
    YamlMapping *mapping,
    const gchar *member_name
)
{
    YamlNode *node;

    g_return_val_if_fail(mapping != NULL, FALSE);
    g_return_val_if_fail(member_name != NULL, FALSE);

    node = yaml_mapping_get_member(mapping, member_name);
    if (node == NULL)
        return FALSE;

    return yaml_node_is_null(node);
}

YamlMapping *
yaml_mapping_get_mapping_member(
    YamlMapping *mapping,
    const gchar *member_name
)
{
    YamlNode *node;

    g_return_val_if_fail(mapping != NULL, NULL);
    g_return_val_if_fail(member_name != NULL, NULL);

    node = yaml_mapping_get_member(mapping, member_name);
    if (node == NULL)
        return NULL;

    return yaml_node_get_mapping(node);
}

YamlSequence *
yaml_mapping_get_sequence_member(
    YamlMapping *mapping,
    const gchar *member_name
)
{
    YamlNode *node;

    g_return_val_if_fail(mapping != NULL, NULL);
    g_return_val_if_fail(member_name != NULL, NULL);

    node = yaml_mapping_get_member(mapping, member_name);
    if (node == NULL)
        return NULL;

    return yaml_node_get_sequence(node);
}

void
yaml_mapping_foreach_member(
    YamlMapping        *mapping,
    YamlMappingForeach  func,
    gpointer            user_data
)
{
    guint i;

    g_return_if_fail(mapping != NULL);
    g_return_if_fail(func != NULL);

    /* Iterate in insertion order */
    for (i = 0; i < mapping->keys_order->len; i++)
    {
        const gchar *key = g_ptr_array_index(mapping->keys_order, i);
        YamlNode *node = g_hash_table_lookup(mapping->members, key);

        func(mapping, key, node, user_data);
    }
}

guint
yaml_mapping_hash(gconstpointer key)
{
    YamlMapping *mapping = (YamlMapping *)key;
    guint hash = 0;
    guint i;

    if (mapping == NULL)
        return 0;

    /* Hash based on size and first few keys */
    hash = g_direct_hash(GUINT_TO_POINTER(mapping->keys_order->len));

    for (i = 0; i < mapping->keys_order->len && i < 5; i++)
    {
        const gchar *k = g_ptr_array_index(mapping->keys_order, i);
        hash ^= g_str_hash(k);
    }

    return hash;
}

gboolean
yaml_mapping_equal(
    gconstpointer a,
    gconstpointer b
)
{
    YamlMapping *ma = (YamlMapping *)a;
    YamlMapping *mb = (YamlMapping *)b;
    guint i;

    if (ma == mb)
        return TRUE;

    if (ma == NULL || mb == NULL)
        return FALSE;

    if (ma->keys_order->len != mb->keys_order->len)
        return FALSE;

    for (i = 0; i < ma->keys_order->len; i++)
    {
        const gchar *key = g_ptr_array_index(ma->keys_order, i);
        YamlNode *node_a = g_hash_table_lookup(ma->members, key);
        YamlNode *node_b = g_hash_table_lookup(mb->members, key);

        if (!yaml_node_equal(node_a, node_b))
            return FALSE;
    }

    return TRUE;
}
