/* yaml-serializable.c
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * YamlSerializable implementation - Interface for custom GObject serialization.
 */

#include "yaml-serializable.h"
#include "yaml-node.h"
#include "yaml-mapping.h"
#include "yaml-sequence.h"
#include "yaml-private.h"
#include <string.h>

G_DEFINE_INTERFACE(YamlSerializable, yaml_serializable, G_TYPE_OBJECT)

/*
 * default_serialize_property_impl:
 *
 * Default vfunc implementation that calls the standalone default function.
 */
static YamlNode *
default_serialize_property_impl(
    YamlSerializable *serializable,
    const gchar      *property_name,
    const GValue     *value,
    GParamSpec       *pspec
)
{
    return yaml_serializable_default_serialize_property(
        serializable,
        property_name,
        value,
        pspec
    );
}

/*
 * default_deserialize_property_impl:
 *
 * Default vfunc implementation that calls the standalone default function.
 */
static gboolean
default_deserialize_property_impl(
    YamlSerializable *serializable,
    const gchar      *property_name,
    GValue           *value,
    GParamSpec       *pspec,
    YamlNode         *node
)
{
    return yaml_serializable_default_deserialize_property(
        serializable,
        property_name,
        value,
        pspec,
        node
    );
}

/*
 * default_find_property_impl:
 *
 * Default implementation that uses g_object_class_find_property.
 */
static GParamSpec *
default_find_property_impl(
    YamlSerializable *serializable,
    const gchar      *name
)
{
    GObjectClass *klass;

    klass = G_OBJECT_GET_CLASS(serializable);

    return g_object_class_find_property(klass, name);
}

/*
 * default_list_properties_impl:
 *
 * Default implementation that uses g_object_class_list_properties.
 */
static GParamSpec **
default_list_properties_impl(
    YamlSerializable *serializable,
    guint            *n_pspecs
)
{
    GObjectClass *klass;

    klass = G_OBJECT_GET_CLASS(serializable);

    return g_object_class_list_properties(klass, n_pspecs);
}

/*
 * default_get_property_impl:
 *
 * Default implementation that uses g_object_get_property.
 */
static void
default_get_property_impl(
    YamlSerializable *serializable,
    GParamSpec       *pspec,
    GValue           *value
)
{
    g_object_get_property(G_OBJECT(serializable), pspec->name, value);
}

/*
 * default_set_property_impl:
 *
 * Default implementation that uses g_object_set_property.
 */
static gboolean
default_set_property_impl(
    YamlSerializable *serializable,
    GParamSpec       *pspec,
    const GValue     *value
)
{
    g_object_set_property(G_OBJECT(serializable), pspec->name, value);
    return TRUE;
}

static void
yaml_serializable_default_init(YamlSerializableInterface *iface)
{
    iface->serialize_property = default_serialize_property_impl;
    iface->deserialize_property = default_deserialize_property_impl;
    iface->find_property = default_find_property_impl;
    iface->list_properties = default_list_properties_impl;
    iface->get_property = default_get_property_impl;
    iface->set_property = default_set_property_impl;
}

YamlNode *
yaml_serializable_serialize_property(
    YamlSerializable *serializable,
    const gchar      *property_name,
    const GValue     *value,
    GParamSpec       *pspec
)
{
    YamlSerializableInterface *iface;

    g_return_val_if_fail(YAML_IS_SERIALIZABLE(serializable), NULL);
    g_return_val_if_fail(property_name != NULL, NULL);
    g_return_val_if_fail(value != NULL, NULL);
    g_return_val_if_fail(pspec != NULL, NULL);

    iface = YAML_SERIALIZABLE_GET_IFACE(serializable);

    return iface->serialize_property(serializable, property_name, value, pspec);
}

gboolean
yaml_serializable_deserialize_property(
    YamlSerializable *serializable,
    const gchar      *property_name,
    GValue           *value,
    GParamSpec       *pspec,
    YamlNode         *node
)
{
    YamlSerializableInterface *iface;

    g_return_val_if_fail(YAML_IS_SERIALIZABLE(serializable), FALSE);
    g_return_val_if_fail(property_name != NULL, FALSE);
    g_return_val_if_fail(value != NULL, FALSE);
    g_return_val_if_fail(pspec != NULL, FALSE);
    g_return_val_if_fail(node != NULL, FALSE);

    iface = YAML_SERIALIZABLE_GET_IFACE(serializable);

    return iface->deserialize_property(serializable, property_name, value, pspec, node);
}

GParamSpec *
yaml_serializable_find_property(
    YamlSerializable *serializable,
    const gchar      *name
)
{
    YamlSerializableInterface *iface;

    g_return_val_if_fail(YAML_IS_SERIALIZABLE(serializable), NULL);
    g_return_val_if_fail(name != NULL, NULL);

    iface = YAML_SERIALIZABLE_GET_IFACE(serializable);

    return iface->find_property(serializable, name);
}

GParamSpec **
yaml_serializable_list_properties(
    YamlSerializable *serializable,
    guint            *n_pspecs
)
{
    YamlSerializableInterface *iface;

    g_return_val_if_fail(YAML_IS_SERIALIZABLE(serializable), NULL);

    iface = YAML_SERIALIZABLE_GET_IFACE(serializable);

    return iface->list_properties(serializable, n_pspecs);
}

void
yaml_serializable_get_property(
    YamlSerializable *serializable,
    GParamSpec       *pspec,
    GValue           *value
)
{
    YamlSerializableInterface *iface;

    g_return_if_fail(YAML_IS_SERIALIZABLE(serializable));
    g_return_if_fail(pspec != NULL);
    g_return_if_fail(value != NULL);

    iface = YAML_SERIALIZABLE_GET_IFACE(serializable);

    iface->get_property(serializable, pspec, value);
}

gboolean
yaml_serializable_set_property(
    YamlSerializable *serializable,
    GParamSpec       *pspec,
    const GValue     *value
)
{
    YamlSerializableInterface *iface;

    g_return_val_if_fail(YAML_IS_SERIALIZABLE(serializable), FALSE);
    g_return_val_if_fail(pspec != NULL, FALSE);
    g_return_val_if_fail(value != NULL, FALSE);

    iface = YAML_SERIALIZABLE_GET_IFACE(serializable);

    return iface->set_property(serializable, pspec, value);
}

/*
 * serialize_strv:
 * @strv: a NULL-terminated string array
 *
 * Converts a string array to a YAML sequence.
 *
 * Returns: (transfer full): a new YamlNode sequence
 */
static YamlNode *
serialize_strv(gchar **strv)
{
    YamlSequence *sequence;
    YamlNode *node;
    guint i;

    sequence = yaml_sequence_new();

    if (strv != NULL)
    {
        for (i = 0; strv[i] != NULL; i++)
        {
            yaml_sequence_add_string_element(sequence, strv[i]);
        }
    }

    node = yaml_node_new_sequence(sequence);
    yaml_sequence_unref(sequence);

    return node;
}

/*
 * deserialize_strv:
 * @node: a YAML sequence node
 *
 * Converts a YAML sequence to a string array.
 *
 * Returns: (transfer full): a NULL-terminated string array
 */
static gchar **
deserialize_strv(YamlNode *node)
{
    YamlSequence *sequence;
    GPtrArray *array;
    guint i;
    guint n_elements;

    if (yaml_node_get_node_type(node) != YAML_NODE_SEQUENCE)
        return NULL;

    sequence = yaml_node_get_sequence(node);
    n_elements = yaml_sequence_get_length(sequence);

    array = g_ptr_array_new();

    for (i = 0; i < n_elements; i++)
    {
        YamlNode *element;
        const gchar *str;

        element = yaml_sequence_get_element(sequence, i);
        str = yaml_node_get_scalar(element);

        if (str != NULL)
            g_ptr_array_add(array, g_strdup(str));
    }

    g_ptr_array_add(array, NULL);

    return (gchar **)g_ptr_array_free(array, FALSE);
}

YamlNode *
yaml_serializable_default_serialize_property(
    YamlSerializable *serializable,
    const gchar      *property_name,
    const GValue     *value,
    GParamSpec       *pspec
)
{
    GType value_type;

    g_return_val_if_fail(value != NULL, NULL);

    value_type = G_VALUE_TYPE(value);

    /*
     * Handle fundamental types and common GLib types.
     */

    /* Boolean */
    if (value_type == G_TYPE_BOOLEAN)
    {
        return yaml_node_new_boolean(g_value_get_boolean(value));
    }

    /* Integers */
    if (value_type == G_TYPE_CHAR)
    {
        return yaml_node_new_int((gint64)g_value_get_schar(value));
    }
    if (value_type == G_TYPE_UCHAR)
    {
        return yaml_node_new_int((gint64)g_value_get_uchar(value));
    }
    if (value_type == G_TYPE_INT)
    {
        return yaml_node_new_int((gint64)g_value_get_int(value));
    }
    if (value_type == G_TYPE_UINT)
    {
        return yaml_node_new_int((gint64)g_value_get_uint(value));
    }
    if (value_type == G_TYPE_LONG)
    {
        return yaml_node_new_int((gint64)g_value_get_long(value));
    }
    if (value_type == G_TYPE_ULONG)
    {
        return yaml_node_new_int((gint64)g_value_get_ulong(value));
    }
    if (value_type == G_TYPE_INT64)
    {
        return yaml_node_new_int(g_value_get_int64(value));
    }
    if (value_type == G_TYPE_UINT64)
    {
        /* Note: may lose precision for very large values */
        return yaml_node_new_int((gint64)g_value_get_uint64(value));
    }

    /* Floating point */
    if (value_type == G_TYPE_FLOAT)
    {
        return yaml_node_new_double((gdouble)g_value_get_float(value));
    }
    if (value_type == G_TYPE_DOUBLE)
    {
        return yaml_node_new_double(g_value_get_double(value));
    }

    /* String */
    if (value_type == G_TYPE_STRING)
    {
        const gchar *str = g_value_get_string(value);
        if (str == NULL)
            return yaml_node_new_null();
        return yaml_node_new_string(str);
    }

    /* String array */
    if (value_type == G_TYPE_STRV)
    {
        gchar **strv = g_value_get_boxed(value);
        return serialize_strv(strv);
    }

    /* Enum */
    if (G_TYPE_IS_ENUM(value_type))
    {
        GEnumClass *enum_class;
        GEnumValue *enum_value;
        gint enum_int;

        enum_class = g_type_class_ref(value_type);
        enum_int = g_value_get_enum(value);
        enum_value = g_enum_get_value(enum_class, enum_int);

        if (enum_value != NULL)
        {
            YamlNode *node = yaml_node_new_string(enum_value->value_nick);
            g_type_class_unref(enum_class);
            return node;
        }

        g_type_class_unref(enum_class);

        /* Fall back to integer */
        return yaml_node_new_int((gint64)enum_int);
    }

    /* Flags */
    if (G_TYPE_IS_FLAGS(value_type))
    {
        GFlagsClass *flags_class;
        guint flags_int;
        YamlSequence *sequence;
        YamlNode *node;
        guint i;

        flags_class = g_type_class_ref(value_type);
        flags_int = g_value_get_flags(value);

        sequence = yaml_sequence_new();

        for (i = 0; i < flags_class->n_values; i++)
        {
            if (flags_int & flags_class->values[i].value)
            {
                yaml_sequence_add_string_element(
                    sequence,
                    flags_class->values[i].value_nick
                );
            }
        }

        g_type_class_unref(flags_class);

        node = yaml_node_new_sequence(sequence);
        yaml_sequence_unref(sequence);

        return node;
    }

    /* GObject - serialize if it implements YamlSerializable */
    if (g_type_is_a(value_type, G_TYPE_OBJECT))
    {
        GObject *obj = g_value_get_object(value);

        if (obj == NULL)
            return yaml_node_new_null();

        /*
         * Recursive serialization would be handled by yaml_gobject_serialize
         * which is defined in yaml-gobject.c. For now, just return null
         * since we don't have access to that function here without
         * creating a circular dependency.
         */
        g_warning("yaml_serializable_default_serialize_property: "
                  "GObject serialization not supported in default handler. "
                  "Use yaml_gobject_serialize() instead.");
        return yaml_node_new_null();
    }

    /* Boxed type: YamlNode passthrough */
    if (value_type == YAML_TYPE_NODE)
    {
        YamlNode *boxed_node = g_value_get_boxed(value);
        if (boxed_node == NULL)
            return yaml_node_new_null();
        return yaml_node_ref(boxed_node);
    }

    /* Unknown type - try to convert to string */
    {
        GValue str_value = G_VALUE_INIT;

        g_value_init(&str_value, G_TYPE_STRING);

        if (g_value_transform(value, &str_value))
        {
            const gchar *str = g_value_get_string(&str_value);
            YamlNode *node;

            if (str == NULL)
                node = yaml_node_new_null();
            else
                node = yaml_node_new_string(str);

            g_value_unset(&str_value);
            return node;
        }

        g_value_unset(&str_value);
    }

    g_warning("yaml_serializable_default_serialize_property: "
              "cannot serialize property '%s' of type '%s'",
              property_name,
              g_type_name(value_type));

    return yaml_node_new_null();
}

gboolean
yaml_serializable_default_deserialize_property(
    YamlSerializable *serializable,
    const gchar      *property_name,
    GValue           *value,
    GParamSpec       *pspec,
    YamlNode         *node
)
{
    GType value_type;
    YamlNodeType node_type;

    g_return_val_if_fail(value != NULL, FALSE);
    g_return_val_if_fail(pspec != NULL, FALSE);
    g_return_val_if_fail(node != NULL, FALSE);

    value_type = G_PARAM_SPEC_VALUE_TYPE(pspec);
    node_type = yaml_node_get_node_type(node);

    /* Initialize the value if needed */
    if (!G_IS_VALUE(value))
        g_value_init(value, value_type);

    /* Handle null node */
    if (node_type == YAML_NODE_NULL)
    {
        /* Set to default value */
        g_param_value_set_default(pspec, value);
        return TRUE;
    }

    /* Boolean */
    if (value_type == G_TYPE_BOOLEAN)
    {
        g_value_set_boolean(value, yaml_node_get_boolean(node));
        return TRUE;
    }

    /* Integers */
    if (value_type == G_TYPE_CHAR)
    {
        g_value_set_schar(value, (gint8)yaml_node_get_int(node));
        return TRUE;
    }
    if (value_type == G_TYPE_UCHAR)
    {
        g_value_set_uchar(value, (guint8)yaml_node_get_int(node));
        return TRUE;
    }
    if (value_type == G_TYPE_INT)
    {
        g_value_set_int(value, (gint)yaml_node_get_int(node));
        return TRUE;
    }
    if (value_type == G_TYPE_UINT)
    {
        g_value_set_uint(value, (guint)yaml_node_get_int(node));
        return TRUE;
    }
    if (value_type == G_TYPE_LONG)
    {
        g_value_set_long(value, (glong)yaml_node_get_int(node));
        return TRUE;
    }
    if (value_type == G_TYPE_ULONG)
    {
        g_value_set_ulong(value, (gulong)yaml_node_get_int(node));
        return TRUE;
    }
    if (value_type == G_TYPE_INT64)
    {
        g_value_set_int64(value, yaml_node_get_int(node));
        return TRUE;
    }
    if (value_type == G_TYPE_UINT64)
    {
        g_value_set_uint64(value, (guint64)yaml_node_get_int(node));
        return TRUE;
    }

    /* Floating point */
    if (value_type == G_TYPE_FLOAT)
    {
        g_value_set_float(value, (gfloat)yaml_node_get_double(node));
        return TRUE;
    }
    if (value_type == G_TYPE_DOUBLE)
    {
        g_value_set_double(value, yaml_node_get_double(node));
        return TRUE;
    }

    /* String */
    if (value_type == G_TYPE_STRING)
    {
        g_value_set_string(value, yaml_node_get_scalar(node));
        return TRUE;
    }

    /* String array */
    if (value_type == G_TYPE_STRV)
    {
        gchar **strv = deserialize_strv(node);
        g_value_take_boxed(value, strv);
        return TRUE;
    }

    /* Enum */
    if (G_TYPE_IS_ENUM(value_type))
    {
        GEnumClass *enum_class;
        GEnumValue *enum_value;
        const gchar *str;
        gint enum_int = 0;

        enum_class = g_type_class_ref(value_type);

        if (node_type == YAML_NODE_SCALAR)
        {
            str = yaml_node_get_scalar(node);

            /* Try nick first */
            enum_value = g_enum_get_value_by_nick(enum_class, str);
            if (enum_value != NULL)
            {
                enum_int = enum_value->value;
            }
            else
            {
                /* Try name */
                enum_value = g_enum_get_value_by_name(enum_class, str);
                if (enum_value != NULL)
                {
                    enum_int = enum_value->value;
                }
                else
                {
                    /* Try integer value */
                    enum_int = (gint)yaml_node_get_int(node);
                }
            }
        }
        else
        {
            enum_int = (gint)yaml_node_get_int(node);
        }

        g_value_set_enum(value, enum_int);
        g_type_class_unref(enum_class);

        return TRUE;
    }

    /* Flags */
    if (G_TYPE_IS_FLAGS(value_type))
    {
        GFlagsClass *flags_class;
        guint flags_int = 0;

        flags_class = g_type_class_ref(value_type);

        if (node_type == YAML_NODE_SEQUENCE)
        {
            YamlSequence *sequence = yaml_node_get_sequence(node);
            guint i;
            guint n_elements = yaml_sequence_get_length(sequence);

            for (i = 0; i < n_elements; i++)
            {
                YamlNode *element = yaml_sequence_get_element(sequence, i);
                const gchar *str = yaml_node_get_scalar(element);
                GFlagsValue *flag_value;

                if (str != NULL)
                {
                    flag_value = g_flags_get_value_by_nick(flags_class, str);
                    if (flag_value != NULL)
                    {
                        flags_int |= flag_value->value;
                    }
                    else
                    {
                        flag_value = g_flags_get_value_by_name(flags_class, str);
                        if (flag_value != NULL)
                            flags_int |= flag_value->value;
                    }
                }
            }
        }
        else
        {
            flags_int = (guint)yaml_node_get_int(node);
        }

        g_value_set_flags(value, flags_int);
        g_type_class_unref(flags_class);

        return TRUE;
    }

    /* Boxed type: YamlNode passthrough */
    if (value_type == YAML_TYPE_NODE)
    {
        g_value_set_boxed(value, node);
        return TRUE;
    }

    /* GObject deserialization would require yaml_gobject_deserialize */
    if (g_type_is_a(value_type, G_TYPE_OBJECT))
    {
        g_warning("yaml_serializable_default_deserialize_property: "
                  "GObject deserialization not supported in default handler. "
                  "Use yaml_gobject_deserialize() instead.");
        return FALSE;
    }

    /* Unknown type - try to transform from string */
    if (node_type == YAML_NODE_SCALAR)
    {
        GValue str_value = G_VALUE_INIT;
        const gchar *str = yaml_node_get_scalar(node);

        g_value_init(&str_value, G_TYPE_STRING);
        g_value_set_string(&str_value, str);

        if (g_value_transform(&str_value, value))
        {
            g_value_unset(&str_value);
            return TRUE;
        }

        g_value_unset(&str_value);
    }

    g_warning("yaml_serializable_default_deserialize_property: "
              "cannot deserialize property '%s' of type '%s'",
              property_name,
              g_type_name(value_type));

    return FALSE;
}
