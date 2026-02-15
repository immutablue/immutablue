/* yaml-gobject.c
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * GObject serialization functions for YAML.
 */

#include "yaml-gobject.h"
#include "yaml-serializable.h"
#include "yaml-node.h"
#include "yaml-mapping.h"
#include "yaml-sequence.h"
#include "yaml-parser.h"
#include "yaml-generator.h"
#include "yaml-private.h"
#include <string.h>

/*
 * Boxed type registration tables
 */
static GHashTable *serialize_funcs = NULL;
static GHashTable *deserialize_funcs = NULL;

static void
ensure_boxed_tables(void)
{
    if (serialize_funcs == NULL)
    {
        serialize_funcs = g_hash_table_new(g_direct_hash, g_direct_equal);
    }

    if (deserialize_funcs == NULL)
    {
        deserialize_funcs = g_hash_table_new(g_direct_hash, g_direct_equal);
    }
}

void
yaml_boxed_register_serialize_func(
    GType                    gtype,
    YamlBoxedSerializeFunc   serialize_func
)
{
    g_return_if_fail(G_TYPE_IS_BOXED(gtype));
    g_return_if_fail(serialize_func != NULL);

    ensure_boxed_tables();

    g_hash_table_insert(
        serialize_funcs,
        GSIZE_TO_POINTER(gtype),
        serialize_func
    );
}

void
yaml_boxed_register_deserialize_func(
    GType                      gtype,
    YamlBoxedDeserializeFunc   deserialize_func
)
{
    g_return_if_fail(G_TYPE_IS_BOXED(gtype));
    g_return_if_fail(deserialize_func != NULL);

    ensure_boxed_tables();

    g_hash_table_insert(
        deserialize_funcs,
        GSIZE_TO_POINTER(gtype),
        deserialize_func
    );
}

gboolean
yaml_boxed_can_serialize(GType gtype)
{
    if (serialize_funcs == NULL)
        return FALSE;

    return g_hash_table_contains(serialize_funcs, GSIZE_TO_POINTER(gtype));
}

gboolean
yaml_boxed_can_deserialize(GType gtype)
{
    if (deserialize_funcs == NULL)
        return FALSE;

    return g_hash_table_contains(deserialize_funcs, GSIZE_TO_POINTER(gtype));
}

YamlNode *
yaml_boxed_serialize(
    GType         gtype,
    gconstpointer boxed
)
{
    YamlBoxedSerializeFunc func;

    g_return_val_if_fail(G_TYPE_IS_BOXED(gtype), NULL);

    if (boxed == NULL)
        return yaml_node_new_null();

    if (serialize_funcs == NULL)
        return NULL;

    func = g_hash_table_lookup(serialize_funcs, GSIZE_TO_POINTER(gtype));

    if (func == NULL)
        return NULL;

    return func(boxed);
}

gpointer
yaml_boxed_deserialize(
    GType     gtype,
    YamlNode *node
)
{
    YamlBoxedDeserializeFunc func;

    g_return_val_if_fail(G_TYPE_IS_BOXED(gtype), NULL);
    g_return_val_if_fail(node != NULL, NULL);

    if (yaml_node_get_node_type(node) == YAML_NODE_NULL)
        return NULL;

    if (deserialize_funcs == NULL)
        return NULL;

    func = g_hash_table_lookup(deserialize_funcs, GSIZE_TO_POINTER(gtype));

    if (func == NULL)
        return NULL;

    return func(node);
}

/*
 * serialize_gobject_internal:
 * @gobject: the object to serialize
 *
 * Internal serialization function that handles both YamlSerializable
 * implementors and plain GObjects.
 *
 * Returns: (transfer full): a YamlNode mapping
 */
static YamlNode *
serialize_gobject_internal(GObject *gobject)
{
    YamlMapping *mapping;
    YamlNode *node;
    GParamSpec **pspecs;
    guint n_pspecs;
    guint i;
    gboolean is_serializable;

    is_serializable = YAML_IS_SERIALIZABLE(gobject);

    /* Get list of properties */
    if (is_serializable)
    {
        pspecs = yaml_serializable_list_properties(
            YAML_SERIALIZABLE(gobject),
            &n_pspecs
        );
    }
    else
    {
        GObjectClass *klass = G_OBJECT_GET_CLASS(gobject);
        pspecs = g_object_class_list_properties(klass, &n_pspecs);
    }

    mapping = yaml_mapping_new();

    for (i = 0; i < n_pspecs; i++)
    {
        GParamSpec *pspec = pspecs[i];
        GValue value = G_VALUE_INIT;
        YamlNode *prop_node;
        const gchar *name;

        /* Skip non-readable and construct-only properties */
        if ((pspec->flags & G_PARAM_READABLE) == 0)
            continue;
        if ((pspec->flags & G_PARAM_WRITABLE) == 0 &&
            (pspec->flags & G_PARAM_CONSTRUCT_ONLY) == 0)
            continue;

        name = pspec->name;
        g_value_init(&value, G_PARAM_SPEC_VALUE_TYPE(pspec));

        /* Get property value */
        if (is_serializable)
        {
            yaml_serializable_get_property(
                YAML_SERIALIZABLE(gobject),
                pspec,
                &value
            );
        }
        else
        {
            g_object_get_property(gobject, name, &value);
        }

        /* Serialize the property */
        if (is_serializable)
        {
            prop_node = yaml_serializable_serialize_property(
                YAML_SERIALIZABLE(gobject),
                name,
                &value,
                pspec
            );
        }
        else
        {
            prop_node = yaml_serializable_default_serialize_property(
                NULL,
                name,
                &value,
                pspec
            );
        }

        g_value_unset(&value);

        if (prop_node != NULL)
        {
            yaml_mapping_set_member(mapping, name, prop_node);
            yaml_node_unref(prop_node);
        }
    }

    g_free(pspecs);

    node = yaml_node_new_mapping(mapping);
    yaml_mapping_unref(mapping);

    return node;
}

YamlNode *
yaml_gobject_serialize(GObject *gobject)
{
    g_return_val_if_fail(G_IS_OBJECT(gobject), NULL);

    return serialize_gobject_internal(gobject);
}

/*
 * deserialize_gobject_internal:
 * @gtype: the GType to instantiate
 * @node: the YAML mapping node
 *
 * Internal deserialization function.
 *
 * Returns: (transfer full): a new GObject
 */
static GObject *
deserialize_gobject_internal(
    GType     gtype,
    YamlNode *node
)
{
    GObject *gobject;
    YamlMapping *mapping;
    GObjectClass *klass;
    GParamSpec **pspecs;
    guint n_pspecs;
    guint i;
    guint n_construct_props = 0;
    GParameter *construct_params = NULL;
    gboolean is_serializable;

    if (yaml_node_get_node_type(node) != YAML_NODE_MAPPING)
    {
        g_warning("yaml_gobject_deserialize: expected mapping node");
        return NULL;
    }

    mapping = yaml_node_get_mapping(node);
    klass = g_type_class_ref(gtype);
    pspecs = g_object_class_list_properties(klass, &n_pspecs);

    /*
     * First pass: collect construct-only properties
     */
    for (i = 0; i < n_pspecs; i++)
    {
        GParamSpec *pspec = pspecs[i];

        if (pspec->flags & G_PARAM_CONSTRUCT_ONLY)
        {
            YamlNode *prop_node;

            prop_node = yaml_mapping_get_member(mapping, pspec->name);
            if (prop_node != NULL)
                n_construct_props++;
        }
    }

    if (n_construct_props > 0)
    {
        guint prop_idx = 0;

        construct_params = g_new0(GParameter, n_construct_props);

        for (i = 0; i < n_pspecs && prop_idx < n_construct_props; i++)
        {
            GParamSpec *pspec = pspecs[i];
            YamlNode *prop_node;

            if ((pspec->flags & G_PARAM_CONSTRUCT_ONLY) == 0)
                continue;

            prop_node = yaml_mapping_get_member(mapping, pspec->name);
            if (prop_node == NULL)
                continue;

            construct_params[prop_idx].name = pspec->name;
            g_value_init(&construct_params[prop_idx].value,
                         G_PARAM_SPEC_VALUE_TYPE(pspec));

            yaml_serializable_default_deserialize_property(
                NULL,
                pspec->name,
                &construct_params[prop_idx].value,
                pspec,
                prop_node
            );

            prop_idx++;
        }
    }

    /* Create the object with construct properties */
    G_GNUC_BEGIN_IGNORE_DEPRECATIONS
    gobject = g_object_newv(gtype, n_construct_props, construct_params);
    G_GNUC_END_IGNORE_DEPRECATIONS

    /* Clean up construct params */
    for (i = 0; i < n_construct_props; i++)
    {
        g_value_unset(&construct_params[i].value);
    }
    g_free(construct_params);

    if (gobject == NULL)
    {
        g_free(pspecs);
        g_type_class_unref(klass);
        return NULL;
    }

    is_serializable = YAML_IS_SERIALIZABLE(gobject);

    /*
     * Second pass: set non-construct properties
     */
    for (i = 0; i < n_pspecs; i++)
    {
        GParamSpec *pspec = pspecs[i];
        YamlNode *prop_node;
        GValue value = G_VALUE_INIT;
        gboolean handled;

        /* Skip non-writable properties */
        if ((pspec->flags & G_PARAM_WRITABLE) == 0)
            continue;

        /* Skip construct-only (already handled) */
        if (pspec->flags & G_PARAM_CONSTRUCT_ONLY)
            continue;

        prop_node = yaml_mapping_get_member(mapping, pspec->name);
        if (prop_node == NULL)
            continue;

        g_value_init(&value, G_PARAM_SPEC_VALUE_TYPE(pspec));

        /* Deserialize the property */
        if (is_serializable)
        {
            handled = yaml_serializable_deserialize_property(
                YAML_SERIALIZABLE(gobject),
                pspec->name,
                &value,
                pspec,
                prop_node
            );
        }
        else
        {
            handled = yaml_serializable_default_deserialize_property(
                NULL,
                pspec->name,
                &value,
                pspec,
                prop_node
            );
        }

        if (handled)
        {
            /* Set the property */
            if (is_serializable)
            {
                yaml_serializable_set_property(
                    YAML_SERIALIZABLE(gobject),
                    pspec,
                    &value
                );
            }
            else
            {
                g_object_set_property(gobject, pspec->name, &value);
            }
        }

        g_value_unset(&value);
    }

    g_free(pspecs);
    g_type_class_unref(klass);

    return gobject;
}

GObject *
yaml_gobject_deserialize(
    GType     gtype,
    YamlNode *node
)
{
    g_return_val_if_fail(g_type_is_a(gtype, G_TYPE_OBJECT), NULL);
    g_return_val_if_fail(node != NULL, NULL);

    if (yaml_node_get_node_type(node) == YAML_NODE_NULL)
        return NULL;

    return deserialize_gobject_internal(gtype, node);
}

GObject *
yaml_gobject_from_data(
    GType         gtype,
    const gchar  *data,
    gssize        length,
    GError      **error
)
{
    YamlParser *parser;
    YamlNode *root;
    GObject *gobject = NULL;

    g_return_val_if_fail(g_type_is_a(gtype, G_TYPE_OBJECT), NULL);
    g_return_val_if_fail(data != NULL, NULL);

    parser = yaml_parser_new();

    if (!yaml_parser_load_from_data(parser, data, length, error))
    {
        g_object_unref(parser);
        return NULL;
    }

    root = yaml_parser_get_root(parser);

    if (root != NULL)
    {
        gobject = yaml_gobject_deserialize(gtype, root);
    }

    g_object_unref(parser);

    return gobject;
}

gchar *
yaml_gobject_to_data(
    GObject *gobject,
    gsize   *length
)
{
    YamlNode *node;
    YamlGenerator *generator;
    gchar *data;
    GError *error = NULL;

    g_return_val_if_fail(G_IS_OBJECT(gobject), NULL);

    node = yaml_gobject_serialize(gobject);
    if (node == NULL)
        return NULL;

    generator = yaml_generator_new();
    yaml_generator_set_root(generator, node);

    data = yaml_generator_to_data(generator, length, &error);

    if (error != NULL)
    {
        g_warning("yaml_gobject_to_data: %s", error->message);
        g_error_free(error);
    }

    yaml_node_unref(node);
    g_object_unref(generator);

    return data;
}
