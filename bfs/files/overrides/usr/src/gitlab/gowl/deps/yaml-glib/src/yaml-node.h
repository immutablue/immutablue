/* yaml-node.h
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * YamlNode - A generic container for YAML data.
 */

#ifndef __YAML_NODE_H__
#define __YAML_NODE_H__

#include <glib.h>
#include <glib-object.h>
#include <json-glib/json-glib.h>
#include "yaml-types.h"
#include "yaml-mapping.h"
#include "yaml-sequence.h"

G_BEGIN_DECLS

#define YAML_TYPE_NODE (yaml_node_get_type())

/**
 * YamlNode:
 *
 * A generic container for YAML data. Unlike GObject-based types,
 * #YamlNode is a reference-counted boxed type that can contain
 * a #YamlMapping, #YamlSequence, a scalar value, or null.
 *
 * Nodes can be made immutable (sealed) for thread-safety and performance.
 * Once sealed, a node and all its children cannot be modified.
 *
 * Since: 1.0
 */

GType yaml_node_get_type(void) G_GNUC_CONST;

/* Construction */

/**
 * yaml_node_alloc:
 *
 * Allocates a new #YamlNode without initializing it.
 * This is the first step for custom node initialization.
 * You must call one of the yaml_node_init_* functions before using it.
 *
 * Returns: (transfer full): an uninitialized #YamlNode
 *
 * Since: 1.0
 */
YamlNode *
yaml_node_alloc(void);

/**
 * yaml_node_new:
 * @type: the type of node to create
 *
 * Creates a new #YamlNode of the specified type.
 * For %YAML_NODE_MAPPING and %YAML_NODE_SEQUENCE, the node is
 * initialized with an empty mapping or sequence.
 * For %YAML_NODE_SCALAR and %YAML_NODE_NULL, use the specific
 * init functions to set values.
 *
 * Returns: (transfer full): a new #YamlNode
 *
 * Since: 1.0
 */
YamlNode *
yaml_node_new(YamlNodeType type);

/**
 * yaml_node_init:
 * @node: an uninitialized #YamlNode
 * @type: the type to initialize
 *
 * Initializes a #YamlNode with the given type.
 *
 * Returns: (transfer none): the initialized @node
 *
 * Since: 1.0
 */
YamlNode *
yaml_node_init(
    YamlNode    *node,
    YamlNodeType type
);

/**
 * yaml_node_init_mapping:
 * @node: an uninitialized #YamlNode
 * @mapping: (transfer none) (nullable): a #YamlMapping, or %NULL
 *
 * Initializes @node as a mapping node.
 * If @mapping is %NULL, an empty mapping is created.
 *
 * Returns: (transfer none): the initialized @node
 *
 * Since: 1.0
 */
YamlNode *
yaml_node_init_mapping(
    YamlNode    *node,
    YamlMapping *mapping
);

/**
 * yaml_node_init_sequence:
 * @node: an uninitialized #YamlNode
 * @sequence: (transfer none) (nullable): a #YamlSequence, or %NULL
 *
 * Initializes @node as a sequence node.
 * If @sequence is %NULL, an empty sequence is created.
 *
 * Returns: (transfer none): the initialized @node
 *
 * Since: 1.0
 */
YamlNode *
yaml_node_init_sequence(
    YamlNode     *node,
    YamlSequence *sequence
);

/**
 * yaml_node_init_string:
 * @node: an uninitialized #YamlNode
 * @value: the string value
 *
 * Initializes @node as a string scalar node.
 *
 * Returns: (transfer none): the initialized @node
 *
 * Since: 1.0
 */
YamlNode *
yaml_node_init_string(
    YamlNode    *node,
    const gchar *value
);

/**
 * yaml_node_init_int:
 * @node: an uninitialized #YamlNode
 * @value: the integer value
 *
 * Initializes @node as an integer scalar node.
 *
 * Returns: (transfer none): the initialized @node
 *
 * Since: 1.0
 */
YamlNode *
yaml_node_init_int(
    YamlNode *node,
    gint64    value
);

/**
 * yaml_node_init_double:
 * @node: an uninitialized #YamlNode
 * @value: the double value
 *
 * Initializes @node as a double scalar node.
 *
 * Returns: (transfer none): the initialized @node
 *
 * Since: 1.0
 */
YamlNode *
yaml_node_init_double(
    YamlNode *node,
    gdouble   value
);

/**
 * yaml_node_init_boolean:
 * @node: an uninitialized #YamlNode
 * @value: the boolean value
 *
 * Initializes @node as a boolean scalar node.
 *
 * Returns: (transfer none): the initialized @node
 *
 * Since: 1.0
 */
YamlNode *
yaml_node_init_boolean(
    YamlNode *node,
    gboolean  value
);

/**
 * yaml_node_init_null:
 * @node: an uninitialized #YamlNode
 *
 * Initializes @node as a null node.
 *
 * Returns: (transfer none): the initialized @node
 *
 * Since: 1.0
 */
YamlNode *
yaml_node_init_null(YamlNode *node);

/* Convenience constructors */

/**
 * yaml_node_new_mapping:
 * @mapping: (transfer none) (nullable): a #YamlMapping, or %NULL
 *
 * Creates a new mapping node.
 * If @mapping is %NULL, an empty mapping is created.
 *
 * Returns: (transfer full): a new #YamlNode
 *
 * Since: 1.0
 */
YamlNode *
yaml_node_new_mapping(YamlMapping *mapping);

/**
 * yaml_node_new_sequence:
 * @sequence: (transfer none) (nullable): a #YamlSequence, or %NULL
 *
 * Creates a new sequence node.
 * If @sequence is %NULL, an empty sequence is created.
 *
 * Returns: (transfer full): a new #YamlNode
 *
 * Since: 1.0
 */
YamlNode *
yaml_node_new_sequence(YamlSequence *sequence);

/**
 * yaml_node_new_string:
 * @value: the string value
 *
 * Creates a new string scalar node.
 *
 * Returns: (transfer full): a new #YamlNode
 *
 * Since: 1.0
 */
YamlNode *
yaml_node_new_string(const gchar *value);

/**
 * yaml_node_new_int:
 * @value: the integer value
 *
 * Creates a new integer scalar node.
 *
 * Returns: (transfer full): a new #YamlNode
 *
 * Since: 1.0
 */
YamlNode *
yaml_node_new_int(gint64 value);

/**
 * yaml_node_new_double:
 * @value: the double value
 *
 * Creates a new double scalar node.
 *
 * Returns: (transfer full): a new #YamlNode
 *
 * Since: 1.0
 */
YamlNode *
yaml_node_new_double(gdouble value);

/**
 * yaml_node_new_boolean:
 * @value: the boolean value
 *
 * Creates a new boolean scalar node.
 *
 * Returns: (transfer full): a new #YamlNode
 *
 * Since: 1.0
 */
YamlNode *
yaml_node_new_boolean(gboolean value);

/**
 * yaml_node_new_null:
 *
 * Creates a new null node.
 *
 * Returns: (transfer full): a new #YamlNode
 *
 * Since: 1.0
 */
YamlNode *
yaml_node_new_null(void);

/**
 * yaml_node_new_scalar:
 * @value: the scalar string value
 * @style: the preferred scalar style
 *
 * Creates a new scalar node with the specified style.
 *
 * Returns: (transfer full): a new #YamlNode
 *
 * Since: 1.0
 */
YamlNode *
yaml_node_new_scalar(
    const gchar    *value,
    YamlScalarStyle style
);

/* Reference counting */

/**
 * yaml_node_ref:
 * @node: a #YamlNode
 *
 * Increases the reference count of @node by one.
 *
 * Returns: (transfer full): the passed @node
 *
 * Since: 1.0
 */
YamlNode *
yaml_node_ref(YamlNode *node);

/**
 * yaml_node_unref:
 * @node: a #YamlNode
 *
 * Decreases the reference count of @node by one.
 * When the reference count reaches zero, the node is freed.
 *
 * Since: 1.0
 */
void
yaml_node_unref(YamlNode *node);

/**
 * yaml_node_copy:
 * @node: a #YamlNode
 *
 * Creates a deep copy of @node.
 *
 * Returns: (transfer full): a new #YamlNode with copied content
 *
 * Since: 1.0
 */
YamlNode *
yaml_node_copy(YamlNode *node);

/* Type queries */

/**
 * yaml_node_get_node_type:
 * @node: a #YamlNode
 *
 * Gets the type of content stored in @node.
 *
 * Returns: the #YamlNodeType
 *
 * Since: 1.0
 */
YamlNodeType
yaml_node_get_node_type(YamlNode *node);

/**
 * yaml_node_is_null:
 * @node: a #YamlNode
 *
 * Checks whether @node contains a null value.
 *
 * Returns: %TRUE if the node is null
 *
 * Since: 1.0
 */
gboolean
yaml_node_is_null(YamlNode *node);

/* Immutability */

/**
 * yaml_node_seal:
 * @node: a #YamlNode
 *
 * Makes @node and all its children immutable.
 * After calling this function, any attempt to modify the node
 * or its children will be silently ignored.
 *
 * Since: 1.0
 */
void
yaml_node_seal(YamlNode *node);

/**
 * yaml_node_is_immutable:
 * @node: a #YamlNode
 *
 * Checks whether @node is immutable (sealed).
 *
 * Returns: %TRUE if the node is immutable
 *
 * Since: 1.0
 */
gboolean
yaml_node_is_immutable(YamlNode *node);

/* Mapping accessors */

/**
 * yaml_node_set_mapping:
 * @node: a #YamlNode
 * @mapping: (transfer none): a #YamlMapping
 *
 * Sets the mapping content of @node.
 * This changes the node type to %YAML_NODE_MAPPING.
 *
 * Since: 1.0
 */
void
yaml_node_set_mapping(
    YamlNode    *node,
    YamlMapping *mapping
);

/**
 * yaml_node_take_mapping:
 * @node: a #YamlNode
 * @mapping: (transfer full): a #YamlMapping
 *
 * Sets the mapping content of @node, taking ownership of @mapping.
 *
 * Since: 1.0
 */
void
yaml_node_take_mapping(
    YamlNode    *node,
    YamlMapping *mapping
);

/**
 * yaml_node_get_mapping:
 * @node: a #YamlNode
 *
 * Gets the mapping content of @node.
 *
 * Returns: (transfer none) (nullable): the #YamlMapping, or %NULL
 *          if @node is not a mapping node
 *
 * Since: 1.0
 */
YamlMapping *
yaml_node_get_mapping(YamlNode *node);

/**
 * yaml_node_dup_mapping:
 * @node: a #YamlNode
 *
 * Gets a reference to the mapping content of @node.
 *
 * Returns: (transfer full) (nullable): a new reference to the
 *          #YamlMapping, or %NULL if @node is not a mapping node.
 *          Use yaml_mapping_unref() when done.
 *
 * Since: 1.0
 */
YamlMapping *
yaml_node_dup_mapping(YamlNode *node);

/* Sequence accessors */

/**
 * yaml_node_set_sequence:
 * @node: a #YamlNode
 * @sequence: (transfer none): a #YamlSequence
 *
 * Sets the sequence content of @node.
 * This changes the node type to %YAML_NODE_SEQUENCE.
 *
 * Since: 1.0
 */
void
yaml_node_set_sequence(
    YamlNode     *node,
    YamlSequence *sequence
);

/**
 * yaml_node_take_sequence:
 * @node: a #YamlNode
 * @sequence: (transfer full): a #YamlSequence
 *
 * Sets the sequence content of @node, taking ownership of @sequence.
 *
 * Since: 1.0
 */
void
yaml_node_take_sequence(
    YamlNode     *node,
    YamlSequence *sequence
);

/**
 * yaml_node_get_sequence:
 * @node: a #YamlNode
 *
 * Gets the sequence content of @node.
 *
 * Returns: (transfer none) (nullable): the #YamlSequence, or %NULL
 *          if @node is not a sequence node
 *
 * Since: 1.0
 */
YamlSequence *
yaml_node_get_sequence(YamlNode *node);

/**
 * yaml_node_dup_sequence:
 * @node: a #YamlNode
 *
 * Gets a reference to the sequence content of @node.
 *
 * Returns: (transfer full) (nullable): a new reference to the
 *          #YamlSequence, or %NULL if @node is not a sequence node.
 *          Use yaml_sequence_unref() when done.
 *
 * Since: 1.0
 */
YamlSequence *
yaml_node_dup_sequence(YamlNode *node);

/* Scalar accessors */

/**
 * yaml_node_set_string:
 * @node: a #YamlNode
 * @value: the string value
 *
 * Sets @node to a string scalar.
 *
 * Since: 1.0
 */
void
yaml_node_set_string(
    YamlNode    *node,
    const gchar *value
);

/**
 * yaml_node_get_string:
 * @node: a #YamlNode
 *
 * Gets the string value of a scalar @node.
 *
 * Returns: (transfer none) (nullable): the string value, or %NULL
 *
 * Since: 1.0
 */
const gchar *
yaml_node_get_string(YamlNode *node);

/**
 * yaml_node_get_scalar:
 * @node: a #YamlNode
 *
 * Gets the raw scalar value of @node as a string.
 * This is the underlying string representation regardless of type.
 *
 * Returns: (transfer none) (nullable): the scalar string, or %NULL
 *
 * Since: 1.0
 */
const gchar *
yaml_node_get_scalar(YamlNode *node);

/**
 * yaml_node_dup_string:
 * @node: a #YamlNode
 *
 * Gets a copy of the string value.
 *
 * Returns: (transfer full) (nullable): a newly allocated string,
 *          or %NULL. Free with g_free().
 *
 * Since: 1.0
 */
gchar *
yaml_node_dup_string(YamlNode *node);

/**
 * yaml_node_set_int:
 * @node: a #YamlNode
 * @value: the integer value
 *
 * Sets @node to an integer scalar.
 *
 * Since: 1.0
 */
void
yaml_node_set_int(
    YamlNode *node,
    gint64    value
);

/**
 * yaml_node_get_int:
 * @node: a #YamlNode
 *
 * Gets the integer value of a scalar @node.
 *
 * Returns: the integer value, or 0 if not an integer
 *
 * Since: 1.0
 */
gint64
yaml_node_get_int(YamlNode *node);

/**
 * yaml_node_set_double:
 * @node: a #YamlNode
 * @value: the double value
 *
 * Sets @node to a double scalar.
 *
 * Since: 1.0
 */
void
yaml_node_set_double(
    YamlNode *node,
    gdouble   value
);

/**
 * yaml_node_get_double:
 * @node: a #YamlNode
 *
 * Gets the double value of a scalar @node.
 *
 * Returns: the double value, or 0.0 if not a number
 *
 * Since: 1.0
 */
gdouble
yaml_node_get_double(YamlNode *node);

/**
 * yaml_node_set_boolean:
 * @node: a #YamlNode
 * @value: the boolean value
 *
 * Sets @node to a boolean scalar.
 *
 * Since: 1.0
 */
void
yaml_node_set_boolean(
    YamlNode *node,
    gboolean  value
);

/**
 * yaml_node_get_boolean:
 * @node: a #YamlNode
 *
 * Gets the boolean value of a scalar @node.
 *
 * Returns: the boolean value, or %FALSE if not a boolean
 *
 * Since: 1.0
 */
gboolean
yaml_node_get_boolean(YamlNode *node);

/* YAML-specific metadata */

/**
 * yaml_node_set_tag:
 * @node: a #YamlNode
 * @tag: (nullable): the YAML tag, or %NULL
 *
 * Sets the YAML tag for @node.
 * Common tags include "!!str", "!!int", "!!bool", etc.
 *
 * Since: 1.0
 */
void
yaml_node_set_tag(
    YamlNode    *node,
    const gchar *tag
);

/**
 * yaml_node_get_tag:
 * @node: a #YamlNode
 *
 * Gets the YAML tag of @node.
 *
 * Returns: (transfer none) (nullable): the tag, or %NULL
 *
 * Since: 1.0
 */
const gchar *
yaml_node_get_tag(YamlNode *node);

/**
 * yaml_node_set_anchor:
 * @node: a #YamlNode
 * @anchor: (nullable): the anchor name, or %NULL
 *
 * Sets the anchor name for @node.
 * Anchors can be referenced elsewhere using aliases.
 *
 * Since: 1.0
 */
void
yaml_node_set_anchor(
    YamlNode    *node,
    const gchar *anchor
);

/**
 * yaml_node_get_anchor:
 * @node: a #YamlNode
 *
 * Gets the anchor name of @node.
 *
 * Returns: (transfer none) (nullable): the anchor, or %NULL
 *
 * Since: 1.0
 */
const gchar *
yaml_node_get_anchor(YamlNode *node);

/**
 * yaml_node_set_scalar_style:
 * @node: a #YamlNode
 * @style: the scalar style
 *
 * Sets the preferred output style for a scalar @node.
 *
 * Since: 1.0
 */
void
yaml_node_set_scalar_style(
    YamlNode       *node,
    YamlScalarStyle style
);

/**
 * yaml_node_get_scalar_style:
 * @node: a #YamlNode
 *
 * Gets the preferred output style for a scalar @node.
 *
 * Returns: the #YamlScalarStyle
 *
 * Since: 1.0
 */
YamlScalarStyle
yaml_node_get_scalar_style(YamlNode *node);

/* Parent relationship */

/**
 * yaml_node_set_parent:
 * @node: a #YamlNode
 * @parent: (nullable): the parent node, or %NULL
 *
 * Sets the parent of @node. This is typically managed automatically.
 *
 * Since: 1.0
 */
void
yaml_node_set_parent(
    YamlNode *node,
    YamlNode *parent
);

/**
 * yaml_node_get_parent:
 * @node: a #YamlNode
 *
 * Gets the parent of @node.
 *
 * Returns: (transfer none) (nullable): the parent node, or %NULL
 *
 * Since: 1.0
 */
YamlNode *
yaml_node_get_parent(YamlNode *node);

/* Equality and hashing */

/**
 * yaml_node_hash:
 * @key: (type YamlNode): a #YamlNode
 *
 * Computes a hash value for the node.
 *
 * Returns: a hash value
 *
 * Since: 1.0
 */
guint
yaml_node_hash(gconstpointer key);

/**
 * yaml_node_equal:
 * @a: (type YamlNode): a #YamlNode
 * @b: (type YamlNode): another #YamlNode
 *
 * Checks if two nodes have equal content.
 *
 * Returns: %TRUE if the nodes are equal
 *
 * Since: 1.0
 */
gboolean
yaml_node_equal(
    gconstpointer a,
    gconstpointer b
);

/* JSON-GLib interoperability */

/**
 * yaml_node_from_json_node:
 * @json_node: a #JsonNode
 *
 * Creates a #YamlNode from a #JsonNode.
 * This performs a deep conversion of the JSON structure.
 *
 * Returns: (transfer full): a new #YamlNode
 *
 * Since: 1.0
 */
YamlNode *
yaml_node_from_json_node(JsonNode *json_node);

/**
 * yaml_node_to_json_node:
 * @node: a #YamlNode
 *
 * Creates a #JsonNode from a #YamlNode.
 * This performs a deep conversion to JSON.
 *
 * Returns: (transfer full): a new #JsonNode
 *
 * Since: 1.0
 */
JsonNode *
yaml_node_to_json_node(YamlNode *node);

G_DEFINE_AUTOPTR_CLEANUP_FUNC(YamlNode, yaml_node_unref)

G_END_DECLS

#endif /* __YAML_NODE_H__ */
