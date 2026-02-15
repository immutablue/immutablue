/* yaml-sequence.h
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * YamlSequence - A YAML sequence (array/list).
 */

#ifndef __YAML_SEQUENCE_H__
#define __YAML_SEQUENCE_H__

#include <glib.h>
#include <glib-object.h>
#include "yaml-types.h"

G_BEGIN_DECLS

#define YAML_TYPE_SEQUENCE (yaml_sequence_get_type())

/**
 * YamlSequence:
 *
 * A YAML sequence containing an ordered list of #YamlNode elements.
 *
 * #YamlSequence is a reference-counted boxed type. Use yaml_sequence_ref()
 * and yaml_sequence_unref() to manage its lifetime.
 *
 * A sequence can be made immutable by calling yaml_sequence_seal().
 * Immutable sequences cannot be modified and are safe to share between
 * threads without synchronization.
 *
 * Since: 1.0
 */

GType yaml_sequence_get_type(void) G_GNUC_CONST;

/**
 * yaml_sequence_new:
 *
 * Creates a new empty #YamlSequence.
 *
 * Returns: (transfer full): a new #YamlSequence. Use yaml_sequence_unref()
 *          when done.
 *
 * Since: 1.0
 */
YamlSequence *
yaml_sequence_new(void);

/**
 * yaml_sequence_sized_new:
 * @n_elements: the initial capacity
 *
 * Creates a new #YamlSequence with pre-allocated capacity.
 *
 * Returns: (transfer full): a new #YamlSequence
 *
 * Since: 1.0
 */
YamlSequence *
yaml_sequence_sized_new(guint n_elements);

/**
 * yaml_sequence_ref:
 * @sequence: a #YamlSequence
 *
 * Increases the reference count of @sequence by one.
 *
 * Returns: (transfer full): the passed @sequence
 *
 * Since: 1.0
 */
YamlSequence *
yaml_sequence_ref(YamlSequence *sequence);

/**
 * yaml_sequence_unref:
 * @sequence: a #YamlSequence
 *
 * Decreases the reference count of @sequence by one.
 * When the reference count reaches zero, the sequence is freed.
 *
 * Since: 1.0
 */
void
yaml_sequence_unref(YamlSequence *sequence);

/**
 * yaml_sequence_seal:
 * @sequence: a #YamlSequence
 *
 * Makes @sequence immutable. After calling this function, any attempt
 * to modify the sequence will be silently ignored.
 *
 * This also seals all #YamlNode elements contained in the sequence.
 *
 * Since: 1.0
 */
void
yaml_sequence_seal(YamlSequence *sequence);

/**
 * yaml_sequence_is_immutable:
 * @sequence: a #YamlSequence
 *
 * Checks whether @sequence is immutable (sealed).
 *
 * Returns: %TRUE if the sequence is immutable
 *
 * Since: 1.0
 */
gboolean
yaml_sequence_is_immutable(YamlSequence *sequence);

/**
 * yaml_sequence_get_length:
 * @sequence: a #YamlSequence
 *
 * Gets the number of elements in @sequence.
 *
 * Returns: the number of elements
 *
 * Since: 1.0
 */
guint
yaml_sequence_get_length(YamlSequence *sequence);

/**
 * yaml_sequence_add_element:
 * @sequence: a #YamlSequence
 * @node: (transfer none): the #YamlNode to add
 *
 * Appends @node to the end of @sequence.
 * This function takes a reference on @node.
 *
 * Since: 1.0
 */
void
yaml_sequence_add_element(
    YamlSequence *sequence,
    YamlNode     *node
);

/**
 * yaml_sequence_get_element:
 * @sequence: a #YamlSequence
 * @index_: the element index
 *
 * Gets the element at @index_ in @sequence.
 *
 * Returns: (transfer none) (nullable): the element node, or %NULL if
 *          the index is out of bounds. The returned node is owned by
 *          the sequence and must not be freed.
 *
 * Since: 1.0
 */
YamlNode *
yaml_sequence_get_element(
    YamlSequence *sequence,
    guint         index_
);

/**
 * yaml_sequence_dup_element:
 * @sequence: a #YamlSequence
 * @index_: the element index
 *
 * Gets a reference to the element at @index_.
 *
 * Returns: (transfer full) (nullable): a new reference to the element,
 *          or %NULL if the index is out of bounds. Use yaml_node_unref()
 *          when done.
 *
 * Since: 1.0
 */
YamlNode *
yaml_sequence_dup_element(
    YamlSequence *sequence,
    guint         index_
);

/**
 * yaml_sequence_remove_element:
 * @sequence: a #YamlSequence
 * @index_: the element index to remove
 *
 * Removes the element at @index_ from @sequence.
 *
 * Since: 1.0
 */
void
yaml_sequence_remove_element(
    YamlSequence *sequence,
    guint         index_
);

/* Convenience adders for common types */

/**
 * yaml_sequence_add_string_element:
 * @sequence: a #YamlSequence
 * @value: the string value to add
 *
 * Appends a string value to @sequence.
 *
 * Since: 1.0
 */
void
yaml_sequence_add_string_element(
    YamlSequence *sequence,
    const gchar  *value
);

/**
 * yaml_sequence_add_int_element:
 * @sequence: a #YamlSequence
 * @value: the integer value to add
 *
 * Appends an integer value to @sequence.
 *
 * Since: 1.0
 */
void
yaml_sequence_add_int_element(
    YamlSequence *sequence,
    gint64        value
);

/**
 * yaml_sequence_add_double_element:
 * @sequence: a #YamlSequence
 * @value: the double value to add
 *
 * Appends a double value to @sequence.
 *
 * Since: 1.0
 */
void
yaml_sequence_add_double_element(
    YamlSequence *sequence,
    gdouble       value
);

/**
 * yaml_sequence_add_boolean_element:
 * @sequence: a #YamlSequence
 * @value: the boolean value to add
 *
 * Appends a boolean value to @sequence.
 *
 * Since: 1.0
 */
void
yaml_sequence_add_boolean_element(
    YamlSequence *sequence,
    gboolean      value
);

/**
 * yaml_sequence_add_null_element:
 * @sequence: a #YamlSequence
 *
 * Appends a null value to @sequence.
 *
 * Since: 1.0
 */
void
yaml_sequence_add_null_element(YamlSequence *sequence);

/**
 * yaml_sequence_add_mapping_element:
 * @sequence: a #YamlSequence
 * @value: (transfer none): the mapping value to add
 *
 * Appends a mapping value to @sequence.
 *
 * Since: 1.0
 */
void
yaml_sequence_add_mapping_element(
    YamlSequence *sequence,
    YamlMapping  *value
);

/**
 * yaml_sequence_add_sequence_element:
 * @sequence: a #YamlSequence
 * @value: (transfer none): the sequence value to add
 *
 * Appends a sequence value to @sequence.
 *
 * Since: 1.0
 */
void
yaml_sequence_add_sequence_element(
    YamlSequence *sequence,
    YamlSequence *value
);

/* Convenience getters for common types */

/**
 * yaml_sequence_get_string_element:
 * @sequence: a #YamlSequence
 * @index_: the element index
 *
 * Gets the string value at @index_.
 *
 * Returns: (transfer none) (nullable): the string value, or %NULL
 *
 * Since: 1.0
 */
const gchar *
yaml_sequence_get_string_element(
    YamlSequence *sequence,
    guint         index_
);

/**
 * yaml_sequence_get_int_element:
 * @sequence: a #YamlSequence
 * @index_: the element index
 *
 * Gets the integer value at @index_.
 *
 * Returns: the integer value, or 0 if not found or not an integer
 *
 * Since: 1.0
 */
gint64
yaml_sequence_get_int_element(
    YamlSequence *sequence,
    guint         index_
);

/**
 * yaml_sequence_get_double_element:
 * @sequence: a #YamlSequence
 * @index_: the element index
 *
 * Gets the double value at @index_.
 *
 * Returns: the double value, or 0.0 if not found or not a number
 *
 * Since: 1.0
 */
gdouble
yaml_sequence_get_double_element(
    YamlSequence *sequence,
    guint         index_
);

/**
 * yaml_sequence_get_boolean_element:
 * @sequence: a #YamlSequence
 * @index_: the element index
 *
 * Gets the boolean value at @index_.
 *
 * Returns: the boolean value, or %FALSE if not found
 *
 * Since: 1.0
 */
gboolean
yaml_sequence_get_boolean_element(
    YamlSequence *sequence,
    guint         index_
);

/**
 * yaml_sequence_get_null_element:
 * @sequence: a #YamlSequence
 * @index_: the element index
 *
 * Checks if the element at @index_ is null.
 *
 * Returns: %TRUE if the element is null
 *
 * Since: 1.0
 */
gboolean
yaml_sequence_get_null_element(
    YamlSequence *sequence,
    guint         index_
);

/**
 * yaml_sequence_get_mapping_element:
 * @sequence: a #YamlSequence
 * @index_: the element index
 *
 * Gets the mapping value at @index_.
 *
 * Returns: (transfer none) (nullable): the mapping value, or %NULL
 *
 * Since: 1.0
 */
YamlMapping *
yaml_sequence_get_mapping_element(
    YamlSequence *sequence,
    guint         index_
);

/**
 * yaml_sequence_get_sequence_element:
 * @sequence: a #YamlSequence
 * @index_: the element index
 *
 * Gets the sequence value at @index_.
 *
 * Returns: (transfer none) (nullable): the sequence value, or %NULL
 *
 * Since: 1.0
 */
YamlSequence *
yaml_sequence_get_sequence_element(
    YamlSequence *sequence,
    guint         index_
);

/**
 * yaml_sequence_get_elements:
 * @sequence: a #YamlSequence
 *
 * Gets a list of all elements in @sequence.
 *
 * Returns: (transfer container) (element-type YamlNode): a newly
 *          allocated #GList of #YamlNode. The nodes are owned by
 *          the sequence and must not be freed. Free the list with
 *          g_list_free().
 *
 * Since: 1.0
 */
GList *
yaml_sequence_get_elements(YamlSequence *sequence);

/**
 * YamlSequenceForeach:
 * @sequence: the iterated #YamlSequence
 * @index_: the index of the current element
 * @element_node: the current element
 * @user_data: user data passed to yaml_sequence_foreach_element()
 *
 * Callback function type for yaml_sequence_foreach_element().
 *
 * Since: 1.0
 */
typedef void (*YamlSequenceForeach)(
    YamlSequence *sequence,
    guint         index_,
    YamlNode     *element_node,
    gpointer      user_data
);

/**
 * yaml_sequence_foreach_element:
 * @sequence: a #YamlSequence
 * @func: (scope call): the function to call for each element
 * @user_data: user data to pass to @func
 *
 * Calls @func for each element in @sequence.
 *
 * Since: 1.0
 */
void
yaml_sequence_foreach_element(
    YamlSequence        *sequence,
    YamlSequenceForeach  func,
    gpointer             user_data
);

/**
 * yaml_sequence_hash:
 * @key: (type YamlSequence): a #YamlSequence
 *
 * Computes a hash value for the sequence.
 *
 * Returns: a hash value
 *
 * Since: 1.0
 */
guint
yaml_sequence_hash(gconstpointer key);

/**
 * yaml_sequence_equal:
 * @a: (type YamlSequence): a #YamlSequence
 * @b: (type YamlSequence): another #YamlSequence
 *
 * Checks if two sequences have equal content.
 *
 * Returns: %TRUE if the sequences are equal
 *
 * Since: 1.0
 */
gboolean
yaml_sequence_equal(
    gconstpointer a,
    gconstpointer b
);

G_DEFINE_AUTOPTR_CLEANUP_FUNC(YamlSequence, yaml_sequence_unref)

G_END_DECLS

#endif /* __YAML_SEQUENCE_H__ */
