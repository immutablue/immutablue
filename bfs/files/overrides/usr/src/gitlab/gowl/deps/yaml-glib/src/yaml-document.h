/* yaml-document.h
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * YamlDocument - Represents a single YAML document.
 */

#ifndef __YAML_DOCUMENT_H__
#define __YAML_DOCUMENT_H__

#include <glib.h>
#include <glib-object.h>
#include <gio/gio.h>
#include <json-glib/json-glib.h>
#include "yaml-types.h"
#include "yaml-node.h"

G_BEGIN_DECLS

#define YAML_TYPE_DOCUMENT (yaml_document_get_type())

G_DECLARE_DERIVABLE_TYPE(YamlDocument, yaml_document, YAML, DOCUMENT, GObject)

/**
 * YamlDocumentClass:
 * @parent_class: the parent class
 *
 * The class structure for #YamlDocument.
 *
 * Since: 1.0
 */
struct _YamlDocumentClass
{
    GObjectClass parent_class;

    /*< private >*/
    gpointer _reserved[8];
};

/**
 * yaml_document_new:
 *
 * Creates a new empty #YamlDocument.
 *
 * Returns: (transfer full): a new #YamlDocument
 *
 * Since: 1.0
 */
YamlDocument *
yaml_document_new(void);

/**
 * yaml_document_new_with_root:
 * @root: (transfer none): the root node
 *
 * Creates a new #YamlDocument with the specified root node.
 *
 * Returns: (transfer full): a new #YamlDocument
 *
 * Since: 1.0
 */
YamlDocument *
yaml_document_new_with_root(YamlNode *root);

/**
 * yaml_document_set_root:
 * @document: a #YamlDocument
 * @root: (transfer none) (nullable): the root node, or %NULL
 *
 * Sets the root node of @document.
 *
 * Since: 1.0
 */
void
yaml_document_set_root(
    YamlDocument *document,
    YamlNode     *root
);

/**
 * yaml_document_get_root:
 * @document: a #YamlDocument
 *
 * Gets the root node of @document.
 *
 * Returns: (transfer none) (nullable): the root node, or %NULL
 *
 * Since: 1.0
 */
YamlNode *
yaml_document_get_root(YamlDocument *document);

/**
 * yaml_document_dup_root:
 * @document: a #YamlDocument
 *
 * Gets a reference to the root node of @document.
 *
 * Returns: (transfer full) (nullable): a new reference to the root
 *          node, or %NULL. Use yaml_node_unref() when done.
 *
 * Since: 1.0
 */
YamlNode *
yaml_document_dup_root(YamlDocument *document);

/**
 * yaml_document_steal_root:
 * @document: a #YamlDocument
 *
 * Steals the root node from @document, leaving the document empty.
 *
 * Returns: (transfer full) (nullable): the root node, or %NULL
 *
 * Since: 1.0
 */
YamlNode *
yaml_document_steal_root(YamlDocument *document);

/**
 * yaml_document_seal:
 * @document: a #YamlDocument
 *
 * Makes @document and its root node immutable.
 *
 * Since: 1.0
 */
void
yaml_document_seal(YamlDocument *document);

/**
 * yaml_document_is_immutable:
 * @document: a #YamlDocument
 *
 * Checks whether @document is immutable.
 *
 * Returns: %TRUE if the document is immutable
 *
 * Since: 1.0
 */
gboolean
yaml_document_is_immutable(YamlDocument *document);

/* YAML version directives */

/**
 * yaml_document_set_version:
 * @document: a #YamlDocument
 * @major: the major version number
 * @minor: the minor version number
 *
 * Sets the YAML version directive for @document.
 * Common values are (1, 1) for YAML 1.1 and (1, 2) for YAML 1.2.
 *
 * Since: 1.0
 */
void
yaml_document_set_version(
    YamlDocument *document,
    guint         major,
    guint         minor
);

/**
 * yaml_document_get_version:
 * @document: a #YamlDocument
 * @major: (out) (optional): location for major version
 * @minor: (out) (optional): location for minor version
 *
 * Gets the YAML version directive from @document.
 *
 * Since: 1.0
 */
void
yaml_document_get_version(
    YamlDocument *document,
    guint        *major,
    guint        *minor
);

/**
 * yaml_document_add_tag_directive:
 * @document: a #YamlDocument
 * @handle: the tag handle (e.g., "!e!")
 * @prefix: the tag prefix (e.g., "tag:example.com,2024:")
 *
 * Adds a tag directive to @document.
 *
 * Since: 1.0
 */
void
yaml_document_add_tag_directive(
    YamlDocument *document,
    const gchar  *handle,
    const gchar  *prefix
);

/**
 * yaml_document_get_tag_directives:
 * @document: a #YamlDocument
 *
 * Gets all tag directives from @document.
 *
 * Returns: (transfer none) (element-type utf8 utf8): a hash table
 *          mapping handles to prefixes. Do not modify.
 *
 * Since: 1.0
 */
GHashTable *
yaml_document_get_tag_directives(YamlDocument *document);

/* JSON-GLib interoperability */

/**
 * yaml_document_from_json_node:
 * @json_node: a #JsonNode
 *
 * Creates a new #YamlDocument from a #JsonNode.
 *
 * Returns: (transfer full): a new #YamlDocument
 *
 * Since: 1.0
 */
YamlDocument *
yaml_document_from_json_node(JsonNode *json_node);

/**
 * yaml_document_to_json_node:
 * @document: a #YamlDocument
 *
 * Converts @document to a #JsonNode.
 *
 * Returns: (transfer full) (nullable): a new #JsonNode, or %NULL
 *
 * Since: 1.0
 */
JsonNode *
yaml_document_to_json_node(YamlDocument *document);

G_END_DECLS

#endif /* __YAML_DOCUMENT_H__ */
