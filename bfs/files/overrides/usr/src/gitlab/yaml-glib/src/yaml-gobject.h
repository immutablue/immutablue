/* yaml-gobject.h
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * GObject serialization functions for YAML.
 */

#ifndef __YAML_GOBJECT_H__
#define __YAML_GOBJECT_H__

#include <glib.h>
#include <glib-object.h>
#include "yaml-types.h"
#include "yaml-node.h"

G_BEGIN_DECLS

/**
 * yaml_gobject_serialize:
 * @gobject: a #GObject
 *
 * Serializes a GObject to a YAML node.
 *
 * If the object implements #YamlSerializable, the interface methods
 * are used for serialization. Otherwise, default property-based
 * serialization is used.
 *
 * Returns: (transfer full) (nullable): a #YamlNode, or %NULL on error
 *
 * Since: 1.0
 */
YamlNode *
yaml_gobject_serialize(GObject *gobject);

/**
 * yaml_gobject_deserialize:
 * @gtype: the #GType of the object to create
 * @node: the YAML node containing the data
 *
 * Deserializes a YAML node into a new GObject of the specified type.
 *
 * If the type implements #YamlSerializable, the interface methods
 * are used for deserialization. Otherwise, default property-based
 * deserialization is used.
 *
 * Returns: (transfer full) (nullable): a new #GObject, or %NULL on error
 *
 * Since: 1.0
 */
GObject *
yaml_gobject_deserialize(
    GType     gtype,
    YamlNode *node
);

/**
 * yaml_gobject_from_data:
 * @gtype: the #GType of the object to create
 * @data: the YAML string
 * @length: the length of @data, or -1 if null-terminated
 * @error: (nullable): return location for a #GError
 *
 * Convenience function to deserialize a GObject from a YAML string.
 *
 * Returns: (transfer full) (nullable): a new #GObject, or %NULL on error
 *
 * Since: 1.0
 */
GObject *
yaml_gobject_from_data(
    GType         gtype,
    const gchar  *data,
    gssize        length,
    GError      **error
);

/**
 * yaml_gobject_to_data:
 * @gobject: a #GObject
 * @length: (out) (optional): location for the output length
 *
 * Convenience function to serialize a GObject to a YAML string.
 *
 * Returns: (transfer full) (nullable): the YAML string, or %NULL on error.
 *          Free with g_free().
 *
 * Since: 1.0
 */
gchar *
yaml_gobject_to_data(
    GObject *gobject,
    gsize   *length
);

/**
 * YamlBoxedSerializeFunc:
 * @boxed: the boxed value to serialize
 *
 * Callback type for serializing boxed types.
 *
 * Returns: (transfer full): a #YamlNode
 *
 * Since: 1.0
 */
typedef YamlNode * (*YamlBoxedSerializeFunc)   (gconstpointer boxed);

/**
 * YamlBoxedDeserializeFunc:
 * @node: the YAML node to deserialize
 *
 * Callback type for deserializing boxed types.
 *
 * Returns: (transfer full): a new boxed value
 *
 * Since: 1.0
 */
typedef gpointer   (*YamlBoxedDeserializeFunc) (YamlNode *node);

/**
 * yaml_boxed_register_serialize_func:
 * @gtype: the boxed #GType
 * @serialize_func: the serialization function
 *
 * Registers a serialization function for a boxed type.
 *
 * Since: 1.0
 */
void
yaml_boxed_register_serialize_func(
    GType                    gtype,
    YamlBoxedSerializeFunc   serialize_func
);

/**
 * yaml_boxed_register_deserialize_func:
 * @gtype: the boxed #GType
 * @deserialize_func: the deserialization function
 *
 * Registers a deserialization function for a boxed type.
 *
 * Since: 1.0
 */
void
yaml_boxed_register_deserialize_func(
    GType                      gtype,
    YamlBoxedDeserializeFunc   deserialize_func
);

/**
 * yaml_boxed_can_serialize:
 * @gtype: a boxed #GType
 *
 * Checks whether the boxed type has a registered serialization function.
 *
 * Returns: %TRUE if the type can be serialized
 *
 * Since: 1.0
 */
gboolean
yaml_boxed_can_serialize(GType gtype);

/**
 * yaml_boxed_can_deserialize:
 * @gtype: a boxed #GType
 *
 * Checks whether the boxed type has a registered deserialization function.
 *
 * Returns: %TRUE if the type can be deserialized
 *
 * Since: 1.0
 */
gboolean
yaml_boxed_can_deserialize(GType gtype);

/**
 * yaml_boxed_serialize:
 * @gtype: the boxed #GType
 * @boxed: the boxed value
 *
 * Serializes a boxed value using the registered function.
 *
 * Returns: (transfer full) (nullable): a #YamlNode, or %NULL
 *
 * Since: 1.0
 */
YamlNode *
yaml_boxed_serialize(
    GType         gtype,
    gconstpointer boxed
);

/**
 * yaml_boxed_deserialize:
 * @gtype: the boxed #GType
 * @node: the YAML node
 *
 * Deserializes a boxed value using the registered function.
 *
 * Returns: (transfer full) (nullable): a new boxed value, or %NULL
 *
 * Since: 1.0
 */
gpointer
yaml_boxed_deserialize(
    GType     gtype,
    YamlNode *node
);

G_END_DECLS

#endif /* __YAML_GOBJECT_H__ */
