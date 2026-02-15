/* yaml-mapping.h
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * YamlMapping - A YAML mapping (dictionary) with string keys.
 */

#ifndef __YAML_MAPPING_H__
#define __YAML_MAPPING_H__

#include <glib.h>
#include <glib-object.h>
#include "yaml-types.h"

G_BEGIN_DECLS

#define YAML_TYPE_MAPPING (yaml_mapping_get_type())

/**
 * YamlMapping:
 *
 * A YAML mapping containing key-value pairs where keys are strings
 * and values are #YamlNode instances.
 *
 * #YamlMapping is a reference-counted boxed type. Use yaml_mapping_ref()
 * and yaml_mapping_unref() to manage its lifetime.
 *
 * A mapping can be made immutable by calling yaml_mapping_seal().
 * Immutable mappings cannot be modified and are safe to share between
 * threads without synchronization.
 *
 * Since: 1.0
 */

GType yaml_mapping_get_type(void) G_GNUC_CONST;

/**
 * yaml_mapping_new:
 *
 * Creates a new empty #YamlMapping.
 *
 * Returns: (transfer full): a new #YamlMapping. Use yaml_mapping_unref()
 *          when done.
 *
 * Since: 1.0
 */
YamlMapping *
yaml_mapping_new(void);

/**
 * yaml_mapping_ref:
 * @mapping: a #YamlMapping
 *
 * Increases the reference count of @mapping by one.
 *
 * Returns: (transfer full): the passed @mapping
 *
 * Since: 1.0
 */
YamlMapping *
yaml_mapping_ref(YamlMapping *mapping);

/**
 * yaml_mapping_unref:
 * @mapping: a #YamlMapping
 *
 * Decreases the reference count of @mapping by one.
 * When the reference count reaches zero, the mapping is freed.
 *
 * Since: 1.0
 */
void
yaml_mapping_unref(YamlMapping *mapping);

/**
 * yaml_mapping_seal:
 * @mapping: a #YamlMapping
 *
 * Makes @mapping immutable. After calling this function, any attempt
 * to modify the mapping will be silently ignored.
 *
 * This also seals all #YamlNode values contained in the mapping.
 *
 * Since: 1.0
 */
void
yaml_mapping_seal(YamlMapping *mapping);

/**
 * yaml_mapping_is_immutable:
 * @mapping: a #YamlMapping
 *
 * Checks whether @mapping is immutable (sealed).
 *
 * Returns: %TRUE if the mapping is immutable
 *
 * Since: 1.0
 */
gboolean
yaml_mapping_is_immutable(YamlMapping *mapping);

/**
 * yaml_mapping_get_size:
 * @mapping: a #YamlMapping
 *
 * Gets the number of key-value pairs in @mapping.
 *
 * Returns: the number of members
 *
 * Since: 1.0
 */
guint
yaml_mapping_get_size(YamlMapping *mapping);

/**
 * yaml_mapping_get_key:
 * @mapping: a #YamlMapping
 * @index: the index of the key to retrieve
 *
 * Gets the key name at the given index.
 * This is useful for index-based iteration through the mapping.
 *
 * Returns: (transfer none) (nullable): the key name at @index, or %NULL
 *          if @index is out of bounds
 *
 * Since: 1.0
 */
const gchar *
yaml_mapping_get_key(
    YamlMapping *mapping,
    guint        index
);

/**
 * yaml_mapping_get_value:
 * @mapping: a #YamlMapping
 * @index: the index of the value to retrieve
 *
 * Gets the value at the given index.
 * This is useful for index-based iteration through the mapping.
 *
 * Returns: (transfer none) (nullable): the value at @index, or %NULL
 *          if @index is out of bounds
 *
 * Since: 1.0
 */
YamlNode *
yaml_mapping_get_value(
    YamlMapping *mapping,
    guint        index
);

/**
 * yaml_mapping_has_member:
 * @mapping: a #YamlMapping
 * @member_name: the name of the member to check
 *
 * Checks whether @mapping contains a member with the given name.
 *
 * Returns: %TRUE if @member_name exists in the mapping
 *
 * Since: 1.0
 */
gboolean
yaml_mapping_has_member(
    YamlMapping *mapping,
    const gchar *member_name
);

/**
 * yaml_mapping_get_members:
 * @mapping: a #YamlMapping
 *
 * Gets a list of all member names in @mapping.
 *
 * Returns: (transfer container) (element-type utf8): a newly allocated
 *          #GList of member names. The strings are owned by the mapping
 *          and must not be freed. Free the list with g_list_free().
 *
 * Since: 1.0
 */
GList *
yaml_mapping_get_members(YamlMapping *mapping);

/**
 * yaml_mapping_set_member:
 * @mapping: a #YamlMapping
 * @member_name: the name of the member
 * @node: (transfer none): the #YamlNode value to set
 *
 * Sets the value of @member_name in @mapping.
 * If a member with this name already exists, it is replaced.
 *
 * This function takes a reference on @node.
 *
 * Since: 1.0
 */
void
yaml_mapping_set_member(
    YamlMapping *mapping,
    const gchar *member_name,
    YamlNode    *node
);

/**
 * yaml_mapping_get_member:
 * @mapping: a #YamlMapping
 * @member_name: the name of the member
 *
 * Gets the #YamlNode value for @member_name.
 *
 * Returns: (transfer none) (nullable): the node value, or %NULL if
 *          the member doesn't exist. The returned node is owned by
 *          the mapping and must not be freed.
 *
 * Since: 1.0
 */
YamlNode *
yaml_mapping_get_member(
    YamlMapping *mapping,
    const gchar *member_name
);

/**
 * yaml_mapping_dup_member:
 * @mapping: a #YamlMapping
 * @member_name: the name of the member
 *
 * Gets a copy of the #YamlNode value for @member_name.
 *
 * Returns: (transfer full) (nullable): a new reference to the node
 *          value, or %NULL if the member doesn't exist. Use
 *          yaml_node_unref() when done.
 *
 * Since: 1.0
 */
YamlNode *
yaml_mapping_dup_member(
    YamlMapping *mapping,
    const gchar *member_name
);

/**
 * yaml_mapping_remove_member:
 * @mapping: a #YamlMapping
 * @member_name: the name of the member to remove
 *
 * Removes @member_name from @mapping.
 *
 * Returns: %TRUE if the member was removed, %FALSE if it didn't exist
 *
 * Since: 1.0
 */
gboolean
yaml_mapping_remove_member(
    YamlMapping *mapping,
    const gchar *member_name
);

/* Convenience setters for common types */

/**
 * yaml_mapping_set_string_member:
 * @mapping: a #YamlMapping
 * @member_name: the name of the member
 * @value: the string value to set
 *
 * Sets a string value for @member_name.
 *
 * Since: 1.0
 */
void
yaml_mapping_set_string_member(
    YamlMapping *mapping,
    const gchar *member_name,
    const gchar *value
);

/**
 * yaml_mapping_set_int_member:
 * @mapping: a #YamlMapping
 * @member_name: the name of the member
 * @value: the integer value to set
 *
 * Sets an integer value for @member_name.
 *
 * Since: 1.0
 */
void
yaml_mapping_set_int_member(
    YamlMapping *mapping,
    const gchar *member_name,
    gint64       value
);

/**
 * yaml_mapping_set_double_member:
 * @mapping: a #YamlMapping
 * @member_name: the name of the member
 * @value: the double value to set
 *
 * Sets a double value for @member_name.
 *
 * Since: 1.0
 */
void
yaml_mapping_set_double_member(
    YamlMapping *mapping,
    const gchar *member_name,
    gdouble      value
);

/**
 * yaml_mapping_set_boolean_member:
 * @mapping: a #YamlMapping
 * @member_name: the name of the member
 * @value: the boolean value to set
 *
 * Sets a boolean value for @member_name.
 *
 * Since: 1.0
 */
void
yaml_mapping_set_boolean_member(
    YamlMapping *mapping,
    const gchar *member_name,
    gboolean     value
);

/**
 * yaml_mapping_set_null_member:
 * @mapping: a #YamlMapping
 * @member_name: the name of the member
 *
 * Sets a null value for @member_name.
 *
 * Since: 1.0
 */
void
yaml_mapping_set_null_member(
    YamlMapping *mapping,
    const gchar *member_name
);

/**
 * yaml_mapping_set_mapping_member:
 * @mapping: a #YamlMapping
 * @member_name: the name of the member
 * @value: (transfer none): the mapping value to set
 *
 * Sets a mapping value for @member_name.
 *
 * Since: 1.0
 */
void
yaml_mapping_set_mapping_member(
    YamlMapping *mapping,
    const gchar *member_name,
    YamlMapping *value
);

/**
 * yaml_mapping_set_sequence_member:
 * @mapping: a #YamlMapping
 * @member_name: the name of the member
 * @value: (transfer none): the sequence value to set
 *
 * Sets a sequence value for @member_name.
 *
 * Since: 1.0
 */
void
yaml_mapping_set_sequence_member(
    YamlMapping  *mapping,
    const gchar  *member_name,
    YamlSequence *value
);

/* Convenience getters for common types */

/**
 * yaml_mapping_get_string_member:
 * @mapping: a #YamlMapping
 * @member_name: the name of the member
 *
 * Gets the string value of @member_name.
 *
 * Returns: (transfer none) (nullable): the string value, or %NULL
 *
 * Since: 1.0
 */
const gchar *
yaml_mapping_get_string_member(
    YamlMapping *mapping,
    const gchar *member_name
);

/**
 * yaml_mapping_get_int_member:
 * @mapping: a #YamlMapping
 * @member_name: the name of the member
 *
 * Gets the integer value of @member_name.
 *
 * Returns: the integer value, or 0 if not found or not an integer
 *
 * Since: 1.0
 */
gint64
yaml_mapping_get_int_member(
    YamlMapping *mapping,
    const gchar *member_name
);

/**
 * yaml_mapping_get_double_member:
 * @mapping: a #YamlMapping
 * @member_name: the name of the member
 *
 * Gets the double value of @member_name.
 *
 * Returns: the double value, or 0.0 if not found or not a number
 *
 * Since: 1.0
 */
gdouble
yaml_mapping_get_double_member(
    YamlMapping *mapping,
    const gchar *member_name
);

/**
 * yaml_mapping_get_boolean_member:
 * @mapping: a #YamlMapping
 * @member_name: the name of the member
 *
 * Gets the boolean value of @member_name.
 *
 * Returns: the boolean value, or %FALSE if not found
 *
 * Since: 1.0
 */
gboolean
yaml_mapping_get_boolean_member(
    YamlMapping *mapping,
    const gchar *member_name
);

/**
 * yaml_mapping_get_null_member:
 * @mapping: a #YamlMapping
 * @member_name: the name of the member
 *
 * Checks if @member_name is a null value.
 *
 * Returns: %TRUE if the member is null
 *
 * Since: 1.0
 */
gboolean
yaml_mapping_get_null_member(
    YamlMapping *mapping,
    const gchar *member_name
);

/**
 * yaml_mapping_get_mapping_member:
 * @mapping: a #YamlMapping
 * @member_name: the name of the member
 *
 * Gets the mapping value of @member_name.
 *
 * Returns: (transfer none) (nullable): the mapping value, or %NULL
 *
 * Since: 1.0
 */
YamlMapping *
yaml_mapping_get_mapping_member(
    YamlMapping *mapping,
    const gchar *member_name
);

/**
 * yaml_mapping_get_sequence_member:
 * @mapping: a #YamlMapping
 * @member_name: the name of the member
 *
 * Gets the sequence value of @member_name.
 *
 * Returns: (transfer none) (nullable): the sequence value, or %NULL
 *
 * Since: 1.0
 */
YamlSequence *
yaml_mapping_get_sequence_member(
    YamlMapping *mapping,
    const gchar *member_name
);

/**
 * YamlMappingForeach:
 * @mapping: the iterated #YamlMapping
 * @member_name: the name of the current member
 * @member_node: the value of the current member
 * @user_data: user data passed to yaml_mapping_foreach_member()
 *
 * Callback function type for yaml_mapping_foreach_member().
 *
 * Since: 1.0
 */
typedef void (*YamlMappingForeach)(
    YamlMapping *mapping,
    const gchar *member_name,
    YamlNode    *member_node,
    gpointer     user_data
);

/**
 * yaml_mapping_foreach_member:
 * @mapping: a #YamlMapping
 * @func: (scope call): the function to call for each member
 * @user_data: user data to pass to @func
 *
 * Calls @func for each member in @mapping.
 *
 * Since: 1.0
 */
void
yaml_mapping_foreach_member(
    YamlMapping        *mapping,
    YamlMappingForeach  func,
    gpointer            user_data
);

/**
 * yaml_mapping_hash:
 * @key: (type YamlMapping): a #YamlMapping
 *
 * Computes a hash value for the mapping.
 *
 * Returns: a hash value
 *
 * Since: 1.0
 */
guint
yaml_mapping_hash(gconstpointer key);

/**
 * yaml_mapping_equal:
 * @a: (type YamlMapping): a #YamlMapping
 * @b: (type YamlMapping): another #YamlMapping
 *
 * Checks if two mappings have equal content.
 *
 * Returns: %TRUE if the mappings are equal
 *
 * Since: 1.0
 */
gboolean
yaml_mapping_equal(
    gconstpointer a,
    gconstpointer b
);

G_DEFINE_AUTOPTR_CLEANUP_FUNC(YamlMapping, yaml_mapping_unref)

G_END_DECLS

#endif /* __YAML_MAPPING_H__ */
