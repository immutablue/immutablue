/* yaml-schema.h
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * YamlSchema - Schema validation for YAML nodes.
 */

#ifndef __YAML_SCHEMA_H__
#define __YAML_SCHEMA_H__

#include <glib.h>
#include <glib-object.h>
#include "yaml-types.h"
#include "yaml-node.h"

G_BEGIN_DECLS

#define YAML_TYPE_SCHEMA (yaml_schema_get_type())

G_DECLARE_DERIVABLE_TYPE(YamlSchema, yaml_schema, YAML, SCHEMA, GObject)

/**
 * YamlSchemaClass:
 * @parent_class: the parent class
 *
 * The class structure for #YamlSchema.
 *
 * Since: 1.0
 */
struct _YamlSchemaClass
{
    GObjectClass parent_class;

    /*< private >*/
    gpointer _reserved[8];
};

/**
 * yaml_schema_new:
 *
 * Creates a new empty #YamlSchema.
 *
 * Returns: (transfer full): a new #YamlSchema
 *
 * Since: 1.0
 */
YamlSchema *
yaml_schema_new(void);

/**
 * yaml_schema_new_for_mapping:
 *
 * Creates a new #YamlSchema that expects a mapping root.
 *
 * Returns: (transfer full): a new #YamlSchema
 *
 * Since: 1.0
 */
YamlSchema *
yaml_schema_new_for_mapping(void);

/**
 * yaml_schema_new_for_sequence:
 *
 * Creates a new #YamlSchema that expects a sequence root.
 *
 * Returns: (transfer full): a new #YamlSchema
 *
 * Since: 1.0
 */
YamlSchema *
yaml_schema_new_for_sequence(void);

/**
 * yaml_schema_new_for_scalar:
 *
 * Creates a new #YamlSchema that expects a scalar root.
 *
 * Returns: (transfer full): a new #YamlSchema
 *
 * Since: 1.0
 */
YamlSchema *
yaml_schema_new_for_scalar(void);

/* Schema type configuration */

/**
 * yaml_schema_set_expected_type:
 * @schema: a #YamlSchema
 * @type: the expected node type
 *
 * Sets the expected root node type.
 *
 * Since: 1.0
 */
void
yaml_schema_set_expected_type(
    YamlSchema   *schema,
    YamlNodeType  type
);

/**
 * yaml_schema_get_expected_type:
 * @schema: a #YamlSchema
 *
 * Gets the expected root node type.
 *
 * Returns: the expected node type
 *
 * Since: 1.0
 */
YamlNodeType
yaml_schema_get_expected_type(YamlSchema *schema);

/* Mapping property definitions */

/**
 * yaml_schema_add_property:
 * @schema: a #YamlSchema
 * @name: the property name
 * @type: the expected property type
 * @required: whether the property is required
 *
 * Adds a property definition to a mapping schema.
 *
 * Since: 1.0
 */
void
yaml_schema_add_property(
    YamlSchema   *schema,
    const gchar  *name,
    YamlNodeType  type,
    gboolean      required
);

/**
 * yaml_schema_add_property_with_schema:
 * @schema: a #YamlSchema
 * @name: the property name
 * @property_schema: (transfer none): schema for the property value
 * @required: whether the property is required
 *
 * Adds a property definition with a nested schema.
 *
 * Since: 1.0
 */
void
yaml_schema_add_property_with_schema(
    YamlSchema  *schema,
    const gchar *name,
    YamlSchema  *property_schema,
    gboolean     required
);

/**
 * yaml_schema_set_allow_additional_properties:
 * @schema: a #YamlSchema
 * @allow: whether to allow additional properties
 *
 * Sets whether the mapping allows properties not defined in the schema.
 * Default is %TRUE.
 *
 * Since: 1.0
 */
void
yaml_schema_set_allow_additional_properties(
    YamlSchema *schema,
    gboolean    allow
);

/**
 * yaml_schema_get_allow_additional_properties:
 * @schema: a #YamlSchema
 *
 * Gets whether additional properties are allowed.
 *
 * Returns: %TRUE if additional properties are allowed
 *
 * Since: 1.0
 */
gboolean
yaml_schema_get_allow_additional_properties(YamlSchema *schema);

/* Sequence element schema */

/**
 * yaml_schema_set_element_type:
 * @schema: a #YamlSchema
 * @type: the expected element type
 *
 * Sets the expected type for sequence elements.
 *
 * Since: 1.0
 */
void
yaml_schema_set_element_type(
    YamlSchema   *schema,
    YamlNodeType  type
);

/**
 * yaml_schema_set_element_schema:
 * @schema: a #YamlSchema
 * @element_schema: (transfer none): schema for sequence elements
 *
 * Sets a schema for validating sequence elements.
 *
 * Since: 1.0
 */
void
yaml_schema_set_element_schema(
    YamlSchema *schema,
    YamlSchema *element_schema
);

/**
 * yaml_schema_set_min_length:
 * @schema: a #YamlSchema
 * @min_length: minimum sequence length
 *
 * Sets the minimum sequence length.
 *
 * Since: 1.0
 */
void
yaml_schema_set_min_length(
    YamlSchema *schema,
    guint       min_length
);

/**
 * yaml_schema_set_max_length:
 * @schema: a #YamlSchema
 * @max_length: maximum sequence length
 *
 * Sets the maximum sequence length.
 *
 * Since: 1.0
 */
void
yaml_schema_set_max_length(
    YamlSchema *schema,
    guint       max_length
);

/* Scalar constraints */

/**
 * yaml_schema_set_pattern:
 * @schema: a #YamlSchema
 * @pattern: a regex pattern
 *
 * Sets a regex pattern for scalar validation.
 *
 * Since: 1.0
 */
void
yaml_schema_set_pattern(
    YamlSchema  *schema,
    const gchar *pattern
);

/**
 * yaml_schema_add_enum_value:
 * @schema: a #YamlSchema
 * @value: an allowed value
 *
 * Adds an allowed value for enum validation.
 *
 * Since: 1.0
 */
void
yaml_schema_add_enum_value(
    YamlSchema  *schema,
    const gchar *value
);

/**
 * yaml_schema_set_min_value:
 * @schema: a #YamlSchema
 * @min_value: minimum numeric value
 *
 * Sets the minimum numeric value for scalars.
 *
 * Since: 1.0
 */
void
yaml_schema_set_min_value(
    YamlSchema *schema,
    gdouble     min_value
);

/**
 * yaml_schema_set_max_value:
 * @schema: a #YamlSchema
 * @max_value: maximum numeric value
 *
 * Sets the maximum numeric value for scalars.
 *
 * Since: 1.0
 */
void
yaml_schema_set_max_value(
    YamlSchema *schema,
    gdouble     max_value
);

/**
 * yaml_schema_set_min_string_length:
 * @schema: a #YamlSchema
 * @min_length: minimum string length
 *
 * Sets the minimum string length for scalars.
 *
 * Since: 1.0
 */
void
yaml_schema_set_min_string_length(
    YamlSchema *schema,
    guint       min_length
);

/**
 * yaml_schema_set_max_string_length:
 * @schema: a #YamlSchema
 * @max_length: maximum string length
 *
 * Sets the maximum string length for scalars.
 *
 * Since: 1.0
 */
void
yaml_schema_set_max_string_length(
    YamlSchema *schema,
    guint       max_length
);

/* Validation */

/**
 * yaml_schema_validate:
 * @schema: a #YamlSchema
 * @node: the node to validate
 * @error: (nullable): return location for a #GError
 *
 * Validates a node against the schema.
 *
 * Returns: %TRUE if valid
 *
 * Since: 1.0
 */
gboolean
yaml_schema_validate(
    YamlSchema  *schema,
    YamlNode    *node,
    GError     **error
);

/**
 * yaml_schema_validate_with_path:
 * @schema: a #YamlSchema
 * @node: the node to validate
 * @path: the current path (for error messages)
 * @error: (nullable): return location for a #GError
 *
 * Validates a node against the schema, tracking the path for errors.
 *
 * Returns: %TRUE if valid
 *
 * Since: 1.0
 */
gboolean
yaml_schema_validate_with_path(
    YamlSchema  *schema,
    YamlNode    *node,
    const gchar *path,
    GError     **error
);

G_END_DECLS

#endif /* __YAML_SCHEMA_H__ */
