/* yaml-serializable.h
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * YamlSerializable - Interface for custom GObject serialization.
 */

#ifndef __YAML_SERIALIZABLE_H__
#define __YAML_SERIALIZABLE_H__

#include <glib.h>
#include <glib-object.h>
#include "yaml-types.h"
#include "yaml-node.h"

G_BEGIN_DECLS

#define YAML_TYPE_SERIALIZABLE (yaml_serializable_get_type())

G_DECLARE_INTERFACE(YamlSerializable, yaml_serializable, YAML, SERIALIZABLE, GObject)

/**
 * YamlSerializableInterface:
 * @serialize_property: virtual function for serializing a property
 * @deserialize_property: virtual function for deserializing a property
 * @find_property: virtual function to find a property by name
 * @list_properties: virtual function to list serializable properties
 * @get_property: virtual function to get a property value
 * @set_property: virtual function to set a property value
 *
 * Interface for objects that want custom YAML serialization behavior.
 *
 * Since: 1.0
 */
struct _YamlSerializableInterface
{
    GTypeInterface g_iface;

    /**
     * YamlSerializableInterface::serialize_property:
     * @serializable: the object being serialized
     * @property_name: the property name
     * @value: the property value
     * @pspec: the property spec
     *
     * Called to serialize a property to a YAML node.
     * Return %NULL to use the default serialization.
     *
     * Returns: (transfer full) (nullable): a #YamlNode or %NULL
     */
    YamlNode *  (* serialize_property)   (YamlSerializable *serializable,
                                          const gchar      *property_name,
                                          const GValue     *value,
                                          GParamSpec       *pspec);

    /**
     * YamlSerializableInterface::deserialize_property:
     * @serializable: the object being deserialized
     * @property_name: the property name
     * @value: (out): location for the property value
     * @pspec: the property spec
     * @node: the YAML node containing the value
     *
     * Called to deserialize a property from a YAML node.
     * Returns %FALSE to use the default deserialization.
     *
     * Returns: %TRUE if the property was handled
     */
    gboolean    (* deserialize_property) (YamlSerializable *serializable,
                                          const gchar      *property_name,
                                          GValue           *value,
                                          GParamSpec       *pspec,
                                          YamlNode         *node);

    /**
     * YamlSerializableInterface::find_property:
     * @serializable: the object
     * @name: the property name to find
     *
     * Called to find a property by name.
     * Override to support property name mapping.
     *
     * Returns: (transfer none) (nullable): the #GParamSpec or %NULL
     */
    GParamSpec * (* find_property)       (YamlSerializable *serializable,
                                          const gchar      *name);

    /**
     * YamlSerializableInterface::list_properties:
     * @serializable: the object
     * @n_pspecs: (out): return location for array length
     *
     * Called to get the list of serializable properties.
     *
     * Returns: (transfer container) (array length=n_pspecs): array of
     *          #GParamSpec pointers
     */
    GParamSpec ** (* list_properties)    (YamlSerializable *serializable,
                                          guint            *n_pspecs);

    /**
     * YamlSerializableInterface::get_property:
     * @serializable: the object
     * @pspec: the property spec
     * @value: (out): location for the value
     *
     * Called to get a property value.
     * Override for computed or virtual properties.
     */
    void        (* get_property)         (YamlSerializable *serializable,
                                          GParamSpec       *pspec,
                                          GValue           *value);

    /**
     * YamlSerializableInterface::set_property:
     * @serializable: the object
     * @pspec: the property spec
     * @value: the value to set
     *
     * Called to set a property value.
     * Override for computed or virtual properties.
     *
     * Returns: %TRUE if the property was handled
     */
    gboolean    (* set_property)         (YamlSerializable *serializable,
                                          GParamSpec       *pspec,
                                          const GValue     *value);

    /*< private >*/
    gpointer _reserved[8];
};

/**
 * yaml_serializable_serialize_property:
 * @serializable: a #YamlSerializable
 * @property_name: the property name
 * @value: the property value
 * @pspec: the property spec
 *
 * Asks @serializable to serialize a property.
 *
 * Returns: (transfer full) (nullable): a #YamlNode or %NULL
 *
 * Since: 1.0
 */
YamlNode *
yaml_serializable_serialize_property(
    YamlSerializable *serializable,
    const gchar      *property_name,
    const GValue     *value,
    GParamSpec       *pspec
);

/**
 * yaml_serializable_deserialize_property:
 * @serializable: a #YamlSerializable
 * @property_name: the property name
 * @value: (out): location for the value
 * @pspec: the property spec
 * @node: the YAML node
 *
 * Asks @serializable to deserialize a property.
 *
 * Returns: %TRUE if the property was handled
 *
 * Since: 1.0
 */
gboolean
yaml_serializable_deserialize_property(
    YamlSerializable *serializable,
    const gchar      *property_name,
    GValue           *value,
    GParamSpec       *pspec,
    YamlNode         *node
);

/**
 * yaml_serializable_find_property:
 * @serializable: a #YamlSerializable
 * @name: the property name
 *
 * Finds a property by name.
 *
 * Returns: (transfer none) (nullable): the #GParamSpec or %NULL
 *
 * Since: 1.0
 */
GParamSpec *
yaml_serializable_find_property(
    YamlSerializable *serializable,
    const gchar      *name
);

/**
 * yaml_serializable_list_properties:
 * @serializable: a #YamlSerializable
 * @n_pspecs: (out): return location for array length
 *
 * Lists all serializable properties.
 *
 * Returns: (transfer container) (array length=n_pspecs): array of
 *          #GParamSpec pointers. Free with g_free().
 *
 * Since: 1.0
 */
GParamSpec **
yaml_serializable_list_properties(
    YamlSerializable *serializable,
    guint            *n_pspecs
);

/**
 * yaml_serializable_get_property:
 * @serializable: a #YamlSerializable
 * @pspec: the property spec
 * @value: (out): location for the value
 *
 * Gets a property value.
 *
 * Since: 1.0
 */
void
yaml_serializable_get_property(
    YamlSerializable *serializable,
    GParamSpec       *pspec,
    GValue           *value
);

/**
 * yaml_serializable_set_property:
 * @serializable: a #YamlSerializable
 * @pspec: the property spec
 * @value: the value to set
 *
 * Sets a property value.
 *
 * Returns: %TRUE if the property was handled
 *
 * Since: 1.0
 */
gboolean
yaml_serializable_set_property(
    YamlSerializable *serializable,
    GParamSpec       *pspec,
    const GValue     *value
);

/**
 * yaml_serializable_default_serialize_property:
 * @serializable: a #YamlSerializable
 * @property_name: the property name
 * @value: the property value
 * @pspec: the property spec
 *
 * Default implementation for property serialization.
 * Converts GValue to YamlNode using standard type mappings.
 *
 * Returns: (transfer full) (nullable): a #YamlNode or %NULL
 *
 * Since: 1.0
 */
YamlNode *
yaml_serializable_default_serialize_property(
    YamlSerializable *serializable,
    const gchar      *property_name,
    const GValue     *value,
    GParamSpec       *pspec
);

/**
 * yaml_serializable_default_deserialize_property:
 * @serializable: a #YamlSerializable
 * @property_name: the property name
 * @value: (out): location for the value
 * @pspec: the property spec
 * @node: the YAML node
 *
 * Default implementation for property deserialization.
 * Converts YamlNode to GValue using standard type mappings.
 *
 * Returns: %TRUE if successful
 *
 * Since: 1.0
 */
gboolean
yaml_serializable_default_deserialize_property(
    YamlSerializable *serializable,
    const gchar      *property_name,
    GValue           *value,
    GParamSpec       *pspec,
    YamlNode         *node
);

G_END_DECLS

#endif /* __YAML_SERIALIZABLE_H__ */
