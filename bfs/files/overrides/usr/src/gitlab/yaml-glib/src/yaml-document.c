/* yaml-document.c
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * YamlDocument implementation.
 */

#include "yaml-document.h"
#include "yaml-node.h"
#include "yaml-private.h"

typedef struct
{
    YamlNode   *root;
    gboolean    immutable;
    guint       version_major;
    guint       version_minor;
    GHashTable *tag_directives;  /* handle -> prefix */
} YamlDocumentPrivate;

G_DEFINE_TYPE_WITH_PRIVATE(YamlDocument, yaml_document, G_TYPE_OBJECT)

enum {
    PROP_0,
    PROP_ROOT,
    PROP_IMMUTABLE,
    N_PROPS
};

static GParamSpec *properties[N_PROPS];

static void
yaml_document_finalize(GObject *object)
{
    YamlDocument *self = YAML_DOCUMENT(object);
    YamlDocumentPrivate *priv = yaml_document_get_instance_private(self);

    g_clear_pointer(&priv->root, yaml_node_unref);
    g_clear_pointer(&priv->tag_directives, g_hash_table_destroy);

    G_OBJECT_CLASS(yaml_document_parent_class)->finalize(object);
}

static void
yaml_document_get_property(
    GObject    *object,
    guint       prop_id,
    GValue     *value,
    GParamSpec *pspec
)
{
    YamlDocument *self = YAML_DOCUMENT(object);
    YamlDocumentPrivate *priv = yaml_document_get_instance_private(self);

    switch (prop_id)
    {
        case PROP_ROOT:
            g_value_set_boxed(value, priv->root);
            break;

        case PROP_IMMUTABLE:
            g_value_set_boolean(value, priv->immutable);
            break;

        default:
            G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
            break;
    }
}

static void
yaml_document_set_property(
    GObject      *object,
    guint         prop_id,
    const GValue *value,
    GParamSpec   *pspec
)
{
    YamlDocument *self = YAML_DOCUMENT(object);

    switch (prop_id)
    {
        case PROP_ROOT:
            yaml_document_set_root(self, g_value_get_boxed(value));
            break;

        default:
            G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
            break;
    }
}

static void
yaml_document_class_init(YamlDocumentClass *klass)
{
    GObjectClass *object_class = G_OBJECT_CLASS(klass);

    object_class->finalize = yaml_document_finalize;
    object_class->get_property = yaml_document_get_property;
    object_class->set_property = yaml_document_set_property;

    /**
     * YamlDocument:root:
     *
     * The root node of the document.
     *
     * Since: 1.0
     */
    properties[PROP_ROOT] =
        g_param_spec_boxed("root",
                           "Root",
                           "The root node of the document",
                           YAML_TYPE_NODE,
                           G_PARAM_READWRITE |
                           G_PARAM_STATIC_STRINGS);

    /**
     * YamlDocument:immutable:
     *
     * Whether the document is immutable.
     *
     * Since: 1.0
     */
    properties[PROP_IMMUTABLE] =
        g_param_spec_boolean("immutable",
                             "Immutable",
                             "Whether the document is immutable",
                             FALSE,
                             G_PARAM_READABLE |
                             G_PARAM_STATIC_STRINGS);

    g_object_class_install_properties(object_class, N_PROPS, properties);
}

static void
yaml_document_init(YamlDocument *self)
{
    YamlDocumentPrivate *priv = yaml_document_get_instance_private(self);

    priv->root = NULL;
    priv->immutable = FALSE;
    priv->version_major = 1;
    priv->version_minor = 2;
    priv->tag_directives = g_hash_table_new_full(
        g_str_hash,
        g_str_equal,
        g_free,
        g_free
    );
}

YamlDocument *
yaml_document_new(void)
{
    return g_object_new(YAML_TYPE_DOCUMENT, NULL);
}

YamlDocument *
yaml_document_new_with_root(YamlNode *root)
{
    YamlDocument *doc;

    doc = g_object_new(YAML_TYPE_DOCUMENT, NULL);
    yaml_document_set_root(doc, root);

    return doc;
}

void
yaml_document_set_root(
    YamlDocument *document,
    YamlNode     *root
)
{
    YamlDocumentPrivate *priv;

    g_return_if_fail(YAML_IS_DOCUMENT(document));

    priv = yaml_document_get_instance_private(document);

    if (priv->immutable)
    {
        g_warning("yaml_document_set_root: document is immutable");
        return;
    }

    if (priv->root == root)
        return;

    g_clear_pointer(&priv->root, yaml_node_unref);

    if (root != NULL)
        priv->root = yaml_node_ref(root);

    g_object_notify_by_pspec(G_OBJECT(document), properties[PROP_ROOT]);
}

YamlNode *
yaml_document_get_root(YamlDocument *document)
{
    YamlDocumentPrivate *priv;

    g_return_val_if_fail(YAML_IS_DOCUMENT(document), NULL);

    priv = yaml_document_get_instance_private(document);

    return priv->root;
}

YamlNode *
yaml_document_dup_root(YamlDocument *document)
{
    YamlDocumentPrivate *priv;

    g_return_val_if_fail(YAML_IS_DOCUMENT(document), NULL);

    priv = yaml_document_get_instance_private(document);

    if (priv->root != NULL)
        return yaml_node_ref(priv->root);

    return NULL;
}

YamlNode *
yaml_document_steal_root(YamlDocument *document)
{
    YamlDocumentPrivate *priv;
    YamlNode *root;

    g_return_val_if_fail(YAML_IS_DOCUMENT(document), NULL);

    priv = yaml_document_get_instance_private(document);

    if (priv->immutable)
    {
        g_warning("yaml_document_steal_root: document is immutable");
        return NULL;
    }

    root = priv->root;
    priv->root = NULL;

    g_object_notify_by_pspec(G_OBJECT(document), properties[PROP_ROOT]);

    return root;
}

void
yaml_document_seal(YamlDocument *document)
{
    YamlDocumentPrivate *priv;

    g_return_if_fail(YAML_IS_DOCUMENT(document));

    priv = yaml_document_get_instance_private(document);

    if (priv->immutable)
        return;

    priv->immutable = TRUE;

    if (priv->root != NULL)
        yaml_node_seal(priv->root);

    g_object_notify_by_pspec(G_OBJECT(document), properties[PROP_IMMUTABLE]);
}

gboolean
yaml_document_is_immutable(YamlDocument *document)
{
    YamlDocumentPrivate *priv;

    g_return_val_if_fail(YAML_IS_DOCUMENT(document), TRUE);

    priv = yaml_document_get_instance_private(document);

    return priv->immutable;
}

void
yaml_document_set_version(
    YamlDocument *document,
    guint         major,
    guint         minor
)
{
    YamlDocumentPrivate *priv;

    g_return_if_fail(YAML_IS_DOCUMENT(document));

    priv = yaml_document_get_instance_private(document);

    if (priv->immutable)
    {
        g_warning("yaml_document_set_version: document is immutable");
        return;
    }

    priv->version_major = major;
    priv->version_minor = minor;
}

void
yaml_document_get_version(
    YamlDocument *document,
    guint        *major,
    guint        *minor
)
{
    YamlDocumentPrivate *priv;

    g_return_if_fail(YAML_IS_DOCUMENT(document));

    priv = yaml_document_get_instance_private(document);

    if (major != NULL)
        *major = priv->version_major;
    if (minor != NULL)
        *minor = priv->version_minor;
}

void
yaml_document_add_tag_directive(
    YamlDocument *document,
    const gchar  *handle,
    const gchar  *prefix
)
{
    YamlDocumentPrivate *priv;

    g_return_if_fail(YAML_IS_DOCUMENT(document));
    g_return_if_fail(handle != NULL);
    g_return_if_fail(prefix != NULL);

    priv = yaml_document_get_instance_private(document);

    if (priv->immutable)
    {
        g_warning("yaml_document_add_tag_directive: document is immutable");
        return;
    }

    g_hash_table_insert(
        priv->tag_directives,
        g_strdup(handle),
        g_strdup(prefix)
    );
}

GHashTable *
yaml_document_get_tag_directives(YamlDocument *document)
{
    YamlDocumentPrivate *priv;

    g_return_val_if_fail(YAML_IS_DOCUMENT(document), NULL);

    priv = yaml_document_get_instance_private(document);

    return priv->tag_directives;
}

YamlDocument *
yaml_document_from_json_node(JsonNode *json_node)
{
    YamlDocument *doc;
    YamlNode *root;

    g_return_val_if_fail(json_node != NULL, NULL);

    doc = yaml_document_new();
    root = yaml_node_from_json_node(json_node);
    yaml_document_set_root(doc, root);
    yaml_node_unref(root);

    return doc;
}

JsonNode *
yaml_document_to_json_node(YamlDocument *document)
{
    YamlDocumentPrivate *priv;

    g_return_val_if_fail(YAML_IS_DOCUMENT(document), NULL);

    priv = yaml_document_get_instance_private(document);

    if (priv->root == NULL)
        return json_node_new(JSON_NODE_NULL);

    return yaml_node_to_json_node(priv->root);
}
