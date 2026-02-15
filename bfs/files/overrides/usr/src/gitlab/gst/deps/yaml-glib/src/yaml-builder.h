/* yaml-builder.h
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * YamlBuilder - Fluent API for building YAML documents.
 */

#ifndef __YAML_BUILDER_H__
#define __YAML_BUILDER_H__

#include <glib.h>
#include <glib-object.h>
#include "yaml-types.h"
#include "yaml-node.h"
#include "yaml-document.h"

G_BEGIN_DECLS

#define YAML_TYPE_BUILDER (yaml_builder_get_type())

G_DECLARE_DERIVABLE_TYPE(YamlBuilder, yaml_builder, YAML, BUILDER, GObject)

/**
 * YamlBuilderClass:
 * @parent_class: the parent class
 *
 * The class structure for #YamlBuilder.
 *
 * Since: 1.0
 */
struct _YamlBuilderClass
{
    GObjectClass parent_class;

    /*< private >*/
    gpointer _reserved[8];
};

/**
 * yaml_builder_new:
 *
 * Creates a new #YamlBuilder.
 *
 * Returns: (transfer full): a new #YamlBuilder
 *
 * Since: 1.0
 */
YamlBuilder *
yaml_builder_new(void);

/**
 * yaml_builder_new_immutable:
 *
 * Creates a new #YamlBuilder that produces immutable nodes.
 * All built nodes will be sealed automatically.
 *
 * Returns: (transfer full): a new #YamlBuilder
 *
 * Since: 1.0
 */
YamlBuilder *
yaml_builder_new_immutable(void);

/**
 * yaml_builder_get_immutable:
 * @builder: a #YamlBuilder
 *
 * Checks whether @builder produces immutable nodes.
 *
 * Returns: %TRUE if nodes are immutable
 *
 * Since: 1.0
 */
gboolean
yaml_builder_get_immutable(YamlBuilder *builder);

/**
 * yaml_builder_set_immutable:
 * @builder: a #YamlBuilder
 * @immutable: whether to produce immutable nodes
 *
 * Sets whether @builder should produce immutable nodes.
 *
 * Since: 1.0
 */
void
yaml_builder_set_immutable(
    YamlBuilder *builder,
    gboolean     immutable
);

/* Mapping construction */

/**
 * yaml_builder_begin_mapping:
 * @builder: a #YamlBuilder
 *
 * Begins a new mapping. Must be matched with yaml_builder_end_mapping().
 * All key-value pairs added after this call will be part of the mapping.
 *
 * Returns: (transfer none): the builder for chaining
 *
 * Since: 1.0
 */
YamlBuilder *
yaml_builder_begin_mapping(YamlBuilder *builder);

/**
 * yaml_builder_end_mapping:
 * @builder: a #YamlBuilder
 *
 * Ends the current mapping started with yaml_builder_begin_mapping().
 *
 * Returns: (transfer none): the builder for chaining
 *
 * Since: 1.0
 */
YamlBuilder *
yaml_builder_end_mapping(YamlBuilder *builder);

/**
 * yaml_builder_set_member_name:
 * @builder: a #YamlBuilder
 * @name: the member name (mapping key)
 *
 * Sets the name for the next value in a mapping.
 * Must be called before adding a value within a mapping context.
 *
 * Returns: (transfer none): the builder for chaining
 *
 * Since: 1.0
 */
YamlBuilder *
yaml_builder_set_member_name(
    YamlBuilder *builder,
    const gchar *name
);

/* Sequence construction */

/**
 * yaml_builder_begin_sequence:
 * @builder: a #YamlBuilder
 *
 * Begins a new sequence. Must be matched with yaml_builder_end_sequence().
 * All values added after this call will be elements of the sequence.
 *
 * Returns: (transfer none): the builder for chaining
 *
 * Since: 1.0
 */
YamlBuilder *
yaml_builder_begin_sequence(YamlBuilder *builder);

/**
 * yaml_builder_end_sequence:
 * @builder: a #YamlBuilder
 *
 * Ends the current sequence started with yaml_builder_begin_sequence().
 *
 * Returns: (transfer none): the builder for chaining
 *
 * Since: 1.0
 */
YamlBuilder *
yaml_builder_end_sequence(YamlBuilder *builder);

/* Scalar values */

/**
 * yaml_builder_add_null_value:
 * @builder: a #YamlBuilder
 *
 * Adds a null value.
 *
 * Returns: (transfer none): the builder for chaining
 *
 * Since: 1.0
 */
YamlBuilder *
yaml_builder_add_null_value(YamlBuilder *builder);

/**
 * yaml_builder_add_boolean_value:
 * @builder: a #YamlBuilder
 * @value: the boolean value
 *
 * Adds a boolean value.
 *
 * Returns: (transfer none): the builder for chaining
 *
 * Since: 1.0
 */
YamlBuilder *
yaml_builder_add_boolean_value(
    YamlBuilder *builder,
    gboolean     value
);

/**
 * yaml_builder_add_int_value:
 * @builder: a #YamlBuilder
 * @value: the integer value
 *
 * Adds an integer value.
 *
 * Returns: (transfer none): the builder for chaining
 *
 * Since: 1.0
 */
YamlBuilder *
yaml_builder_add_int_value(
    YamlBuilder *builder,
    gint64       value
);

/**
 * yaml_builder_add_double_value:
 * @builder: a #YamlBuilder
 * @value: the double value
 *
 * Adds a double value.
 *
 * Returns: (transfer none): the builder for chaining
 *
 * Since: 1.0
 */
YamlBuilder *
yaml_builder_add_double_value(
    YamlBuilder *builder,
    gdouble      value
);

/**
 * yaml_builder_add_string_value:
 * @builder: a #YamlBuilder
 * @value: the string value
 *
 * Adds a string value.
 *
 * Returns: (transfer none): the builder for chaining
 *
 * Since: 1.0
 */
YamlBuilder *
yaml_builder_add_string_value(
    YamlBuilder *builder,
    const gchar *value
);

/**
 * yaml_builder_add_scalar_value:
 * @builder: a #YamlBuilder
 * @value: the scalar string value
 * @style: the scalar style hint
 *
 * Adds a scalar value with explicit style.
 *
 * Returns: (transfer none): the builder for chaining
 *
 * Since: 1.0
 */
YamlBuilder *
yaml_builder_add_scalar_value(
    YamlBuilder     *builder,
    const gchar     *value,
    YamlScalarStyle  style
);

/* Node insertion */

/**
 * yaml_builder_add_value:
 * @builder: a #YamlBuilder
 * @node: (transfer none): the node to add
 *
 * Adds an existing node value.
 *
 * Returns: (transfer none): the builder for chaining
 *
 * Since: 1.0
 */
YamlBuilder *
yaml_builder_add_value(
    YamlBuilder *builder,
    YamlNode    *node
);

/* Anchor and tag support */

/**
 * yaml_builder_set_anchor:
 * @builder: a #YamlBuilder
 * @anchor: the anchor name
 *
 * Sets the anchor for the next node to be created.
 * The anchor will be applied to the next mapping, sequence, or scalar.
 *
 * Returns: (transfer none): the builder for chaining
 *
 * Since: 1.0
 */
YamlBuilder *
yaml_builder_set_anchor(
    YamlBuilder *builder,
    const gchar *anchor
);

/**
 * yaml_builder_set_tag:
 * @builder: a #YamlBuilder
 * @tag: the tag URI
 *
 * Sets the tag for the next node to be created.
 *
 * Returns: (transfer none): the builder for chaining
 *
 * Since: 1.0
 */
YamlBuilder *
yaml_builder_set_tag(
    YamlBuilder *builder,
    const gchar *tag
);

/**
 * yaml_builder_add_alias:
 * @builder: a #YamlBuilder
 * @anchor: the anchor name to reference
 *
 * Adds an alias node referencing a previously anchored node.
 *
 * Returns: (transfer none): the builder for chaining
 *
 * Since: 1.0
 */
YamlBuilder *
yaml_builder_add_alias(
    YamlBuilder *builder,
    const gchar *anchor
);

/* Result retrieval */

/**
 * yaml_builder_get_root:
 * @builder: a #YamlBuilder
 *
 * Gets the root node that was built.
 * The builder must have a complete structure (all begin calls matched
 * with end calls).
 *
 * Returns: (transfer none) (nullable): the root node, or %NULL
 *
 * Since: 1.0
 */
YamlNode *
yaml_builder_get_root(YamlBuilder *builder);

/**
 * yaml_builder_dup_root:
 * @builder: a #YamlBuilder
 *
 * Gets a reference to the root node that was built.
 *
 * Returns: (transfer full) (nullable): the root node, or %NULL
 *
 * Since: 1.0
 */
YamlNode *
yaml_builder_dup_root(YamlBuilder *builder);

/**
 * yaml_builder_steal_root:
 * @builder: a #YamlBuilder
 *
 * Steals the root node from the builder, resetting the builder.
 *
 * Returns: (transfer full) (nullable): the root node, or %NULL
 *
 * Since: 1.0
 */
YamlNode *
yaml_builder_steal_root(YamlBuilder *builder);

/**
 * yaml_builder_get_document:
 * @builder: a #YamlBuilder
 *
 * Gets the built structure as a document.
 * Convenience method that wraps the root in a YamlDocument.
 *
 * Returns: (transfer full) (nullable): a new document, or %NULL
 *
 * Since: 1.0
 */
YamlDocument *
yaml_builder_get_document(YamlBuilder *builder);

/**
 * yaml_builder_reset:
 * @builder: a #YamlBuilder
 *
 * Resets the builder, clearing all state.
 *
 * Since: 1.0
 */
void
yaml_builder_reset(YamlBuilder *builder);

G_END_DECLS

#endif /* __YAML_BUILDER_H__ */
