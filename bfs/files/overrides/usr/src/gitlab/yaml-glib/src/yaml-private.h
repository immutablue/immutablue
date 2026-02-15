/* yaml-private.h
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Private declarations shared between yaml-glib source files.
 * This header should not be installed or used by external code.
 */

#ifndef __YAML_PRIVATE_H__
#define __YAML_PRIVATE_H__

#include <glib.h>
#include "yaml-types.h"
#include "yaml-node.h"
#include "yaml-mapping.h"
#include "yaml-sequence.h"

G_BEGIN_DECLS

/*
 * YamlNode internal structure.
 * This is the actual layout of a YamlNode.
 */
struct _YamlNode
{
    volatile gint ref_count;
    YamlNodeType  type;
    gboolean      immutable;

    /* Parent node (weak reference, not ref-counted to avoid cycles) */
    YamlNode     *parent;

    /* YAML-specific metadata */
    gchar        *tag;
    gchar        *anchor;

    /* Type-specific data */
    union {
        YamlMapping  *mapping;
        YamlSequence *sequence;
        struct {
            gchar           *value;
            YamlScalarStyle  style;
            /* Cached typed value for scalars */
            gboolean         has_int;
            gint64           int_value;
            gboolean         has_double;
            gdouble          double_value;
            gboolean         has_boolean;
            gboolean         boolean_value;
        } scalar;
    } data;
};

/*
 * YamlMapping internal structure.
 */
struct _YamlMapping
{
    volatile gint  ref_count;
    gboolean       immutable;
    GHashTable    *members;  /* gchar* -> YamlNode* */
    /* Preserve insertion order for consistent output */
    GPtrArray     *keys_order;
};

/*
 * YamlSequence internal structure.
 */
struct _YamlSequence
{
    volatile gint  ref_count;
    gboolean       immutable;
    GPtrArray     *elements;  /* YamlNode* */
};

/*
 * Internal helper to free node contents without freeing the node itself.
 * Used during reinitialization.
 */
void
yaml_node_clear_internal(YamlNode *node);

/*
 * Internal helper to parse scalar string to typed values.
 * Populates the cached int/double/boolean values.
 */
void
yaml_node_parse_scalar_internal(YamlNode *node);

/*
 * Internal helper to set parent on child nodes.
 */
void
yaml_node_set_parent_internal(
    YamlNode *child,
    YamlNode *parent
);

G_END_DECLS

#endif /* __YAML_PRIVATE_H__ */
