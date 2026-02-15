/* yaml-schema.c
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * YamlSchema implementation - Schema validation for YAML nodes.
 *
 * This is a complete rewrite fixing all bugs from the original:
 * - validate_node now returns the actual validation result
 * - Hash tables are created lazily to avoid memory waste
 * - Uses new YamlNode API (boxed type, not GObject)
 * - Proper constraint memory management
 */

#include "yaml-schema.h"
#include "yaml-node.h"
#include "yaml-mapping.h"
#include "yaml-sequence.h"
#include "yaml-private.h"
#include <string.h>

/*
 * PropertyDef:
 *
 * Definition of a property in a mapping schema.
 */
typedef struct
{
    gchar        *name;
    YamlNodeType  type;
    YamlSchema   *schema;  /* Optional nested schema */
    gboolean      required;
} PropertyDef;

static void
property_def_free(PropertyDef *def)
{
    if (def == NULL)
        return;

    g_free(def->name);
    g_clear_object(&def->schema);
    g_free(def);
}

typedef struct
{
    YamlNodeType  expected_type;

    /* For mappings */
    GHashTable   *properties;      /* name -> PropertyDef */
    gboolean      allow_additional;

    /* For sequences */
    YamlNodeType  element_type;
    YamlSchema   *element_schema;
    guint         min_length;
    guint         max_length;
    gboolean      has_min_length;
    gboolean      has_max_length;

    /* For scalars */
    GRegex       *pattern;
    GPtrArray    *enum_values;
    gdouble       min_value;
    gdouble       max_value;
    gboolean      has_min_value;
    gboolean      has_max_value;
    guint         min_string_length;
    guint         max_string_length;
    gboolean      has_min_string_length;
    gboolean      has_max_string_length;
} YamlSchemaPrivate;

G_DEFINE_TYPE_WITH_PRIVATE(YamlSchema, yaml_schema, G_TYPE_OBJECT)

static void
yaml_schema_finalize(GObject *object)
{
    YamlSchema *self = YAML_SCHEMA(object);
    YamlSchemaPrivate *priv = yaml_schema_get_instance_private(self);

    g_clear_pointer(&priv->properties, g_hash_table_destroy);
    g_clear_object(&priv->element_schema);
    g_clear_pointer(&priv->pattern, g_regex_unref);

    if (priv->enum_values != NULL)
    {
        g_ptr_array_free(priv->enum_values, TRUE);
        priv->enum_values = NULL;
    }

    G_OBJECT_CLASS(yaml_schema_parent_class)->finalize(object);
}

static void
yaml_schema_class_init(YamlSchemaClass *klass)
{
    GObjectClass *object_class = G_OBJECT_CLASS(klass);

    object_class->finalize = yaml_schema_finalize;
}

static void
yaml_schema_init(YamlSchema *self)
{
    YamlSchemaPrivate *priv = yaml_schema_get_instance_private(self);

    /*
     * Default to mapping type since it's most common.
     * Note: We do NOT create hash tables or arrays here.
     * They are created lazily when needed to avoid memory waste.
     * This fixes the memory leak bug in the original implementation.
     */
    priv->expected_type = YAML_NODE_MAPPING;
    priv->properties = NULL;
    priv->allow_additional = TRUE;

    priv->element_type = YAML_NODE_SCALAR;
    priv->element_schema = NULL;
    priv->min_length = 0;
    priv->max_length = 0;
    priv->has_min_length = FALSE;
    priv->has_max_length = FALSE;

    priv->pattern = NULL;
    priv->enum_values = NULL;
    priv->min_value = 0.0;
    priv->max_value = 0.0;
    priv->has_min_value = FALSE;
    priv->has_max_value = FALSE;
    priv->min_string_length = 0;
    priv->max_string_length = 0;
    priv->has_min_string_length = FALSE;
    priv->has_max_string_length = FALSE;
}

YamlSchema *
yaml_schema_new(void)
{
    return g_object_new(YAML_TYPE_SCHEMA, NULL);
}

YamlSchema *
yaml_schema_new_for_mapping(void)
{
    YamlSchema *schema = yaml_schema_new();
    yaml_schema_set_expected_type(schema, YAML_NODE_MAPPING);
    return schema;
}

YamlSchema *
yaml_schema_new_for_sequence(void)
{
    YamlSchema *schema = yaml_schema_new();
    yaml_schema_set_expected_type(schema, YAML_NODE_SEQUENCE);
    return schema;
}

YamlSchema *
yaml_schema_new_for_scalar(void)
{
    YamlSchema *schema = yaml_schema_new();
    yaml_schema_set_expected_type(schema, YAML_NODE_SCALAR);
    return schema;
}

void
yaml_schema_set_expected_type(
    YamlSchema   *schema,
    YamlNodeType  type
)
{
    YamlSchemaPrivate *priv;

    g_return_if_fail(YAML_IS_SCHEMA(schema));

    priv = yaml_schema_get_instance_private(schema);
    priv->expected_type = type;
}

YamlNodeType
yaml_schema_get_expected_type(YamlSchema *schema)
{
    YamlSchemaPrivate *priv;

    g_return_val_if_fail(YAML_IS_SCHEMA(schema), YAML_NODE_NULL);

    priv = yaml_schema_get_instance_private(schema);

    return priv->expected_type;
}

/*
 * ensure_properties_table:
 *
 * Lazily creates the properties hash table.
 */
static void
ensure_properties_table(YamlSchemaPrivate *priv)
{
    if (priv->properties == NULL)
    {
        priv->properties = g_hash_table_new_full(
            g_str_hash,
            g_str_equal,
            NULL,  /* keys are owned by PropertyDef */
            (GDestroyNotify)property_def_free
        );
    }
}

void
yaml_schema_add_property(
    YamlSchema   *schema,
    const gchar  *name,
    YamlNodeType  type,
    gboolean      required
)
{
    YamlSchemaPrivate *priv;
    PropertyDef *def;

    g_return_if_fail(YAML_IS_SCHEMA(schema));
    g_return_if_fail(name != NULL);

    priv = yaml_schema_get_instance_private(schema);

    ensure_properties_table(priv);

    def = g_new0(PropertyDef, 1);
    def->name = g_strdup(name);
    def->type = type;
    def->schema = NULL;
    def->required = required;

    g_hash_table_insert(priv->properties, def->name, def);
}

void
yaml_schema_add_property_with_schema(
    YamlSchema  *schema,
    const gchar *name,
    YamlSchema  *property_schema,
    gboolean     required
)
{
    YamlSchemaPrivate *priv;
    PropertyDef *def;

    g_return_if_fail(YAML_IS_SCHEMA(schema));
    g_return_if_fail(name != NULL);
    g_return_if_fail(YAML_IS_SCHEMA(property_schema));

    priv = yaml_schema_get_instance_private(schema);

    ensure_properties_table(priv);

    def = g_new0(PropertyDef, 1);
    def->name = g_strdup(name);
    def->type = yaml_schema_get_expected_type(property_schema);
    def->schema = g_object_ref(property_schema);
    def->required = required;

    g_hash_table_insert(priv->properties, def->name, def);
}

void
yaml_schema_set_allow_additional_properties(
    YamlSchema *schema,
    gboolean    allow
)
{
    YamlSchemaPrivate *priv;

    g_return_if_fail(YAML_IS_SCHEMA(schema));

    priv = yaml_schema_get_instance_private(schema);
    priv->allow_additional = allow;
}

gboolean
yaml_schema_get_allow_additional_properties(YamlSchema *schema)
{
    YamlSchemaPrivate *priv;

    g_return_val_if_fail(YAML_IS_SCHEMA(schema), TRUE);

    priv = yaml_schema_get_instance_private(schema);

    return priv->allow_additional;
}

void
yaml_schema_set_element_type(
    YamlSchema   *schema,
    YamlNodeType  type
)
{
    YamlSchemaPrivate *priv;

    g_return_if_fail(YAML_IS_SCHEMA(schema));

    priv = yaml_schema_get_instance_private(schema);
    priv->element_type = type;
}

void
yaml_schema_set_element_schema(
    YamlSchema *schema,
    YamlSchema *element_schema
)
{
    YamlSchemaPrivate *priv;

    g_return_if_fail(YAML_IS_SCHEMA(schema));
    g_return_if_fail(YAML_IS_SCHEMA(element_schema));

    priv = yaml_schema_get_instance_private(schema);

    g_clear_object(&priv->element_schema);
    priv->element_schema = g_object_ref(element_schema);
    priv->element_type = yaml_schema_get_expected_type(element_schema);
}

void
yaml_schema_set_min_length(
    YamlSchema *schema,
    guint       min_length
)
{
    YamlSchemaPrivate *priv;

    g_return_if_fail(YAML_IS_SCHEMA(schema));

    priv = yaml_schema_get_instance_private(schema);
    priv->min_length = min_length;
    priv->has_min_length = TRUE;
}

void
yaml_schema_set_max_length(
    YamlSchema *schema,
    guint       max_length
)
{
    YamlSchemaPrivate *priv;

    g_return_if_fail(YAML_IS_SCHEMA(schema));

    priv = yaml_schema_get_instance_private(schema);
    priv->max_length = max_length;
    priv->has_max_length = TRUE;
}

void
yaml_schema_set_pattern(
    YamlSchema  *schema,
    const gchar *pattern
)
{
    YamlSchemaPrivate *priv;
    GError *error = NULL;

    g_return_if_fail(YAML_IS_SCHEMA(schema));
    g_return_if_fail(pattern != NULL);

    priv = yaml_schema_get_instance_private(schema);

    g_clear_pointer(&priv->pattern, g_regex_unref);

    priv->pattern = g_regex_new(pattern, 0, 0, &error);

    if (error != NULL)
    {
        g_warning("yaml_schema_set_pattern: invalid pattern '%s': %s",
                  pattern, error->message);
        g_error_free(error);
    }
}

void
yaml_schema_add_enum_value(
    YamlSchema  *schema,
    const gchar *value
)
{
    YamlSchemaPrivate *priv;

    g_return_if_fail(YAML_IS_SCHEMA(schema));
    g_return_if_fail(value != NULL);

    priv = yaml_schema_get_instance_private(schema);

    if (priv->enum_values == NULL)
    {
        priv->enum_values = g_ptr_array_new_with_free_func(g_free);
    }

    g_ptr_array_add(priv->enum_values, g_strdup(value));
}

void
yaml_schema_set_min_value(
    YamlSchema *schema,
    gdouble     min_value
)
{
    YamlSchemaPrivate *priv;

    g_return_if_fail(YAML_IS_SCHEMA(schema));

    priv = yaml_schema_get_instance_private(schema);
    priv->min_value = min_value;
    priv->has_min_value = TRUE;
}

void
yaml_schema_set_max_value(
    YamlSchema *schema,
    gdouble     max_value
)
{
    YamlSchemaPrivate *priv;

    g_return_if_fail(YAML_IS_SCHEMA(schema));

    priv = yaml_schema_get_instance_private(schema);
    priv->max_value = max_value;
    priv->has_max_value = TRUE;
}

void
yaml_schema_set_min_string_length(
    YamlSchema *schema,
    guint       min_length
)
{
    YamlSchemaPrivate *priv;

    g_return_if_fail(YAML_IS_SCHEMA(schema));

    priv = yaml_schema_get_instance_private(schema);
    priv->min_string_length = min_length;
    priv->has_min_string_length = TRUE;
}

void
yaml_schema_set_max_string_length(
    YamlSchema *schema,
    guint       max_length
)
{
    YamlSchemaPrivate *priv;

    g_return_if_fail(YAML_IS_SCHEMA(schema));

    priv = yaml_schema_get_instance_private(schema);
    priv->max_string_length = max_length;
    priv->has_max_string_length = TRUE;
}

/*
 * get_type_name:
 *
 * Returns a human-readable type name.
 */
static const gchar *
get_type_name(YamlNodeType type)
{
    switch (type)
    {
        case YAML_NODE_MAPPING:
            return "mapping";
        case YAML_NODE_SEQUENCE:
            return "sequence";
        case YAML_NODE_SCALAR:
            return "scalar";
        case YAML_NODE_NULL:
            return "null";
        default:
            return "unknown";
    }
}

/*
 * make_path:
 *
 * Creates a path string for error messages.
 */
static gchar *
make_path(
    const gchar *base,
    const gchar *key
)
{
    if (base == NULL || *base == '\0')
        return g_strdup_printf("$.%s", key);
    else
        return g_strdup_printf("%s.%s", base, key);
}

static gchar *
make_path_index(
    const gchar *base,
    guint        index
)
{
    if (base == NULL || *base == '\0')
        return g_strdup_printf("$[%u]", index);
    else
        return g_strdup_printf("%s[%u]", base, index);
}

/*
 * validate_scalar:
 *
 * Validates a scalar node against schema constraints.
 */
static gboolean
validate_scalar(
    YamlSchema  *schema,
    YamlNode    *node,
    const gchar *path,
    GError     **error
)
{
    YamlSchemaPrivate *priv = yaml_schema_get_instance_private(schema);
    const gchar *value;
    gsize len;

    value = yaml_node_get_scalar(node);
    if (value == NULL)
        value = "";

    len = strlen(value);

    /* Check string length constraints */
    if (priv->has_min_string_length && len < priv->min_string_length)
    {
        g_set_error(error,
                    YAML_SCHEMA_ERROR,
                    YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION,
                    "%s: string length %zu is less than minimum %u",
                    path, len, priv->min_string_length);
        return FALSE;
    }

    if (priv->has_max_string_length && len > priv->max_string_length)
    {
        g_set_error(error,
                    YAML_SCHEMA_ERROR,
                    YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION,
                    "%s: string length %zu exceeds maximum %u",
                    path, len, priv->max_string_length);
        return FALSE;
    }

    /* Check pattern */
    if (priv->pattern != NULL)
    {
        if (!g_regex_match(priv->pattern, value, 0, NULL))
        {
            g_set_error(error,
                        YAML_SCHEMA_ERROR,
                        YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION,
                        "%s: value '%s' does not match pattern",
                        path, value);
            return FALSE;
        }
    }

    /* Check enum values */
    if (priv->enum_values != NULL)
    {
        gboolean found = FALSE;
        guint i;

        for (i = 0; i < priv->enum_values->len; i++)
        {
            if (g_strcmp0(value, g_ptr_array_index(priv->enum_values, i)) == 0)
            {
                found = TRUE;
                break;
            }
        }

        if (!found)
        {
            g_set_error(error,
                        YAML_SCHEMA_ERROR,
                        YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION,
                        "%s: value '%s' is not in allowed enum values",
                        path, value);
            return FALSE;
        }
    }

    /* Check numeric constraints */
    if (priv->has_min_value || priv->has_max_value)
    {
        gdouble num_value = yaml_node_get_double(node);

        if (priv->has_min_value && num_value < priv->min_value)
        {
            g_set_error(error,
                        YAML_SCHEMA_ERROR,
                        YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION,
                        "%s: value %g is less than minimum %g",
                        path, num_value, priv->min_value);
            return FALSE;
        }

        if (priv->has_max_value && num_value > priv->max_value)
        {
            g_set_error(error,
                        YAML_SCHEMA_ERROR,
                        YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION,
                        "%s: value %g exceeds maximum %g",
                        path, num_value, priv->max_value);
            return FALSE;
        }
    }

    return TRUE;
}

/*
 * validate_sequence:
 *
 * Validates a sequence node against schema constraints.
 */
static gboolean
validate_sequence(
    YamlSchema  *schema,
    YamlNode    *node,
    const gchar *path,
    GError     **error
)
{
    YamlSchemaPrivate *priv = yaml_schema_get_instance_private(schema);
    YamlSequence *sequence;
    guint len;
    guint i;

    sequence = yaml_node_get_sequence(node);
    len = yaml_sequence_get_length(sequence);

    /* Check length constraints */
    if (priv->has_min_length && len < priv->min_length)
    {
        g_set_error(error,
                    YAML_SCHEMA_ERROR,
                    YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION,
                    "%s: sequence length %u is less than minimum %u",
                    path, len, priv->min_length);
        return FALSE;
    }

    if (priv->has_max_length && len > priv->max_length)
    {
        g_set_error(error,
                    YAML_SCHEMA_ERROR,
                    YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION,
                    "%s: sequence length %u exceeds maximum %u",
                    path, len, priv->max_length);
        return FALSE;
    }

    /* Validate each element */
    for (i = 0; i < len; i++)
    {
        YamlNode *element = yaml_sequence_get_element(sequence, i);
        YamlNodeType element_type = yaml_node_get_node_type(element);
        gchar *element_path = make_path_index(path, i);

        /* Check element type */
        if (element_type != priv->element_type &&
            priv->element_type != YAML_NODE_NULL)
        {
            g_set_error(error,
                        YAML_SCHEMA_ERROR,
                        YAML_SCHEMA_ERROR_TYPE_MISMATCH,
                        "%s: expected %s but got %s",
                        element_path,
                        get_type_name(priv->element_type),
                        get_type_name(element_type));
            g_free(element_path);
            return FALSE;
        }

        /* Validate with element schema if present */
        if (priv->element_schema != NULL)
        {
            if (!yaml_schema_validate_with_path(
                    priv->element_schema,
                    element,
                    element_path,
                    error))
            {
                g_free(element_path);
                return FALSE;
            }
        }

        g_free(element_path);
    }

    return TRUE;
}

/*
 * validate_mapping:
 *
 * Validates a mapping node against schema constraints.
 */
static gboolean
validate_mapping(
    YamlSchema  *schema,
    YamlNode    *node,
    const gchar *path,
    GError     **error
)
{
    YamlSchemaPrivate *priv = yaml_schema_get_instance_private(schema);
    YamlMapping *mapping;
    guint n_members;
    guint i;
    GHashTableIter iter;
    gpointer key;
    gpointer value;

    mapping = yaml_node_get_mapping(node);
    n_members = yaml_mapping_get_size(mapping);

    /* Check required properties */
    if (priv->properties != NULL)
    {
        g_hash_table_iter_init(&iter, priv->properties);
        while (g_hash_table_iter_next(&iter, &key, &value))
        {
            PropertyDef *def = value;

            if (def->required)
            {
                YamlNode *prop_node = yaml_mapping_get_member(mapping, def->name);

                if (prop_node == NULL)
                {
                    gchar *prop_path = make_path(path, def->name);
                    g_set_error(error,
                                YAML_SCHEMA_ERROR,
                                YAML_SCHEMA_ERROR_MISSING_REQUIRED,
                                "%s: required property is missing",
                                prop_path);
                    g_free(prop_path);
                    return FALSE;
                }
            }
        }
    }

    /* Validate each property */
    for (i = 0; i < n_members; i++)
    {
        const gchar *prop_name = yaml_mapping_get_key(mapping, i);
        YamlNode *prop_node = yaml_mapping_get_member(mapping, prop_name);
        YamlNodeType prop_type = yaml_node_get_node_type(prop_node);
        gchar *prop_path = make_path(path, prop_name);
        PropertyDef *def = NULL;

        if (priv->properties != NULL)
        {
            def = g_hash_table_lookup(priv->properties, prop_name);
        }

        if (def == NULL)
        {
            /* Unknown property */
            if (!priv->allow_additional)
            {
                g_set_error(error,
                            YAML_SCHEMA_ERROR,
                            YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION,
                            "%s: unexpected property",
                            prop_path);
                g_free(prop_path);
                return FALSE;
            }
        }
        else
        {
            /* Check property type */
            if (prop_type != def->type && def->type != YAML_NODE_NULL)
            {
                g_set_error(error,
                            YAML_SCHEMA_ERROR,
                            YAML_SCHEMA_ERROR_TYPE_MISMATCH,
                            "%s: expected %s but got %s",
                            prop_path,
                            get_type_name(def->type),
                            get_type_name(prop_type));
                g_free(prop_path);
                return FALSE;
            }

            /* Validate with property schema if present */
            if (def->schema != NULL)
            {
                if (!yaml_schema_validate_with_path(
                        def->schema,
                        prop_node,
                        prop_path,
                        error))
                {
                    g_free(prop_path);
                    return FALSE;
                }
            }
        }

        g_free(prop_path);
    }

    return TRUE;
}

gboolean
yaml_schema_validate(
    YamlSchema  *schema,
    YamlNode    *node,
    GError     **error
)
{
    return yaml_schema_validate_with_path(schema, node, "$", error);
}

gboolean
yaml_schema_validate_with_path(
    YamlSchema  *schema,
    YamlNode    *node,
    const gchar *path,
    GError     **error
)
{
    YamlSchemaPrivate *priv;
    YamlNodeType node_type;

    g_return_val_if_fail(YAML_IS_SCHEMA(schema), FALSE);
    g_return_val_if_fail(node != NULL, FALSE);

    priv = yaml_schema_get_instance_private(schema);
    node_type = yaml_node_get_node_type(node);

    if (path == NULL)
        path = "$";

    /* Check type match */
    if (node_type != priv->expected_type)
    {
        /* Allow null for any type (optional values) */
        if (node_type != YAML_NODE_NULL)
        {
            g_set_error(error,
                        YAML_SCHEMA_ERROR,
                        YAML_SCHEMA_ERROR_TYPE_MISMATCH,
                        "%s: expected %s but got %s",
                        path,
                        get_type_name(priv->expected_type),
                        get_type_name(node_type));
            return FALSE;
        }

        /* Null is valid for optional values */
        return TRUE;
    }

    /* Type-specific validation */
    switch (node_type)
    {
        case YAML_NODE_MAPPING:
            return validate_mapping(schema, node, path, error);

        case YAML_NODE_SEQUENCE:
            return validate_sequence(schema, node, path, error);

        case YAML_NODE_SCALAR:
            return validate_scalar(schema, node, path, error);

        case YAML_NODE_NULL:
            /* Null nodes are always valid */
            return TRUE;
    }

    return TRUE;
}
