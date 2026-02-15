# YamlSerializable API Reference

`YamlSerializable` is an interface for custom GObject serialization.

## Overview

```c
#include <yaml-glib/yaml-glib.h>

#define YAML_TYPE_SERIALIZABLE (yaml_serializable_get_type())

G_DECLARE_INTERFACE(YamlSerializable, yaml_serializable, YAML, SERIALIZABLE, GObject)
```

`YamlSerializable` allows GObjects to customize how they are serialized to and deserialized from YAML. By implementing this interface, objects can:

- Map property names between YAML and GObject
- Transform values during serialization/deserialization
- Serialize computed or virtual properties
- Handle complex nested structures

## Interface Structure

```c
struct _YamlSerializableInterface
{
    GTypeInterface g_iface;

    YamlNode *  (* serialize_property)   (YamlSerializable *serializable,
                                          const gchar      *property_name,
                                          const GValue     *value,
                                          GParamSpec       *pspec);

    gboolean    (* deserialize_property) (YamlSerializable *serializable,
                                          const gchar      *property_name,
                                          GValue           *value,
                                          GParamSpec       *pspec,
                                          YamlNode         *node);

    GParamSpec * (* find_property)       (YamlSerializable *serializable,
                                          const gchar      *name);

    GParamSpec ** (* list_properties)    (YamlSerializable *serializable,
                                          guint            *n_pspecs);

    void        (* get_property)         (YamlSerializable *serializable,
                                          GParamSpec       *pspec,
                                          GValue           *value);

    gboolean    (* set_property)         (YamlSerializable *serializable,
                                          GParamSpec       *pspec,
                                          const GValue     *value);

    gpointer _reserved[8];
};
```

## Virtual Methods

### serialize_property

Called to serialize a property to a YAML node. Return `NULL` to use the default serialization.

**Signature:**
```c
YamlNode *(* serialize_property)(
    YamlSerializable *serializable,
    const gchar      *property_name,
    const GValue     *value,
    GParamSpec       *pspec
);
```

---

### deserialize_property

Called to deserialize a property from a YAML node. Return `FALSE` to use the default deserialization.

**Signature:**
```c
gboolean (* deserialize_property)(
    YamlSerializable *serializable,
    const gchar      *property_name,
    GValue           *value,
    GParamSpec       *pspec,
    YamlNode         *node
);
```

---

### find_property

Called to find a property by name. Override to support property name mapping (e.g., snake_case to kebab-case).

**Signature:**
```c
GParamSpec *(* find_property)(
    YamlSerializable *serializable,
    const gchar      *name
);
```

---

### list_properties

Called to get the list of serializable properties. Override to filter or add properties.

**Signature:**
```c
GParamSpec **(* list_properties)(
    YamlSerializable *serializable,
    guint            *n_pspecs
);
```

---

### get_property / set_property

Called to get or set a property value. Override for computed or virtual properties.

**Signatures:**
```c
void (* get_property)(
    YamlSerializable *serializable,
    GParamSpec       *pspec,
    GValue           *value
);

gboolean (* set_property)(
    YamlSerializable *serializable,
    GParamSpec       *pspec,
    const GValue     *value
);
```

---

## Interface Functions

### yaml_serializable_serialize_property

```c
YamlNode *yaml_serializable_serialize_property(
    YamlSerializable *serializable,
    const gchar      *property_name,
    const GValue     *value,
    GParamSpec       *pspec
);
```

Asks `serializable` to serialize a property.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| serializable | `YamlSerializable *` | A serializable object |
| property_name | `const gchar *` | The property name |
| value | `const GValue *` | The property value |
| pspec | `GParamSpec *` | The property specification |

**Returns:** `(transfer full) (nullable)` A `YamlNode`, or `NULL`.

---

### yaml_serializable_deserialize_property

```c
gboolean yaml_serializable_deserialize_property(
    YamlSerializable *serializable,
    const gchar      *property_name,
    GValue           *value,
    GParamSpec       *pspec,
    YamlNode         *node
);
```

Asks `serializable` to deserialize a property.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| serializable | `YamlSerializable *` | A serializable object |
| property_name | `const gchar *` | The property name |
| value | `GValue *` `(out)` | Location for the property value |
| pspec | `GParamSpec *` | The property specification |
| node | `YamlNode *` | The YAML node containing the value |

**Returns:** `TRUE` if the property was handled.

---

### yaml_serializable_find_property

```c
GParamSpec *yaml_serializable_find_property(
    YamlSerializable *serializable,
    const gchar      *name
);
```

Finds a property by name.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| serializable | `YamlSerializable *` | A serializable object |
| name | `const gchar *` | The property name |

**Returns:** `(transfer none) (nullable)` The `GParamSpec`, or `NULL` if not found.

---

### yaml_serializable_list_properties

```c
GParamSpec **yaml_serializable_list_properties(
    YamlSerializable *serializable,
    guint            *n_pspecs
);
```

Lists all serializable properties.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| serializable | `YamlSerializable *` | A serializable object |
| n_pspecs | `guint *` `(out)` | Location for the array length |

**Returns:** `(transfer container) (array length=n_pspecs)` Array of `GParamSpec` pointers. Free with `g_free()`.

---

### yaml_serializable_get_property

```c
void yaml_serializable_get_property(
    YamlSerializable *serializable,
    GParamSpec       *pspec,
    GValue           *value
);
```

Gets a property value.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| serializable | `YamlSerializable *` | A serializable object |
| pspec | `GParamSpec *` | The property specification |
| value | `GValue *` `(out)` | Location for the value |

---

### yaml_serializable_set_property

```c
gboolean yaml_serializable_set_property(
    YamlSerializable *serializable,
    GParamSpec       *pspec,
    const GValue     *value
);
```

Sets a property value.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| serializable | `YamlSerializable *` | A serializable object |
| pspec | `GParamSpec *` | The property specification |
| value | `const GValue *` | The value to set |

**Returns:** `TRUE` if the property was handled.

---

## Default Implementations

### yaml_serializable_default_serialize_property

```c
YamlNode *yaml_serializable_default_serialize_property(
    YamlSerializable *serializable,
    const gchar      *property_name,
    const GValue     *value,
    GParamSpec       *pspec
);
```

Default implementation for property serialization. Converts `GValue` to `YamlNode` using standard type mappings.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| serializable | `YamlSerializable *` | A serializable object |
| property_name | `const gchar *` | The property name |
| value | `const GValue *` | The property value |
| pspec | `GParamSpec *` | The property specification |

**Returns:** `(transfer full) (nullable)` A `YamlNode`, or `NULL`.

**Example:**
```c
static YamlNode *
my_object_serialize_property(YamlSerializable *serializable,
                             const gchar      *property_name,
                             const GValue     *value,
                             GParamSpec       *pspec)
{
    /* Custom handling for specific property */
    if (g_strcmp0(property_name, "password") == 0)
    {
        /* Encrypt password before serialization */
        const gchar *plain = g_value_get_string(value);
        g_autofree gchar *encrypted = encrypt_password(plain);
        return yaml_node_new_string(encrypted);
    }

    /* Fall back to default for other properties */
    return yaml_serializable_default_serialize_property(
        serializable, property_name, value, pspec
    );
}
```

---

### yaml_serializable_default_deserialize_property

```c
gboolean yaml_serializable_default_deserialize_property(
    YamlSerializable *serializable,
    const gchar      *property_name,
    GValue           *value,
    GParamSpec       *pspec,
    YamlNode         *node
);
```

Default implementation for property deserialization. Converts `YamlNode` to `GValue` using standard type mappings.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| serializable | `YamlSerializable *` | A serializable object |
| property_name | `const gchar *` | The property name |
| value | `GValue *` `(out)` | Location for the value |
| pspec | `GParamSpec *` | The property specification |
| node | `YamlNode *` | The YAML node |

**Returns:** `TRUE` if successful.

---

## Complete Implementation Example

```c
#include <yaml-glib/yaml-glib.h>

/* Forward declaration */
static void my_config_serializable_init(YamlSerializableInterface *iface);

/* Type definition with interface */
G_DEFINE_TYPE_WITH_CODE(MyConfig, my_config, G_TYPE_OBJECT,
    G_IMPLEMENT_INTERFACE(YAML_TYPE_SERIALIZABLE, my_config_serializable_init))

/* Properties */
enum {
    PROP_0,
    PROP_NAME,
    PROP_PORT,
    PROP_ENABLED,
    N_PROPERTIES
};

static GParamSpec *properties[N_PROPERTIES];

struct _MyConfig
{
    GObject parent_instance;
    gchar   *name;
    gint     port;
    gboolean enabled;
};

/* Custom property serialization */
static YamlNode *
my_config_serialize_property(YamlSerializable *serializable,
                             const gchar      *property_name,
                             const GValue     *value,
                             GParamSpec       *pspec)
{
    /* Use kebab-case in YAML instead of snake_case */
    if (g_strcmp0(property_name, "port") == 0)
    {
        /* Custom: serialize port as string */
        gint port = g_value_get_int(value);
        g_autofree gchar *str = g_strdup_printf("%d", port);
        return yaml_node_new_string(str);
    }

    /* Default serialization for other properties */
    return yaml_serializable_default_serialize_property(
        serializable, property_name, value, pspec
    );
}

/* Custom property deserialization */
static gboolean
my_config_deserialize_property(YamlSerializable *serializable,
                               const gchar      *property_name,
                               GValue           *value,
                               GParamSpec       *pspec,
                               YamlNode         *node)
{
    if (g_strcmp0(property_name, "port") == 0)
    {
        /* Custom: parse port from string */
        const gchar *str = yaml_node_get_string(node);
        gint port = (gint)g_ascii_strtoll(str, NULL, 10);
        g_value_set_int(value, port);
        return TRUE;
    }

    /* Default deserialization for other properties */
    return yaml_serializable_default_deserialize_property(
        serializable, property_name, value, pspec, node
    );
}

/* Property name mapping (YAML uses kebab-case) */
static GParamSpec *
my_config_find_property(YamlSerializable *serializable,
                        const gchar      *name)
{
    /* Map kebab-case to snake_case */
    if (g_strcmp0(name, "is-enabled") == 0)
    {
        return properties[PROP_ENABLED];
    }

    /* Default lookup */
    return g_object_class_find_property(
        G_OBJECT_GET_CLASS(serializable), name
    );
}

/* Interface initialization */
static void
my_config_serializable_init(YamlSerializableInterface *iface)
{
    iface->serialize_property = my_config_serialize_property;
    iface->deserialize_property = my_config_deserialize_property;
    iface->find_property = my_config_find_property;
    /* Other methods use defaults */
}

/* Class initialization */
static void
my_config_class_init(MyConfigClass *klass)
{
    GObjectClass *object_class = G_OBJECT_CLASS(klass);

    properties[PROP_NAME] =
        g_param_spec_string("name", "Name", "Config name",
                            NULL, G_PARAM_READWRITE);

    properties[PROP_PORT] =
        g_param_spec_int("port", "Port", "Server port",
                         0, 65535, 8080, G_PARAM_READWRITE);

    properties[PROP_ENABLED] =
        g_param_spec_boolean("enabled", "Enabled", "Is enabled",
                             FALSE, G_PARAM_READWRITE);

    g_object_class_install_properties(object_class, N_PROPERTIES, properties);
}

static void
my_config_init(MyConfig *self)
{
    self->port = 8080;
}

/* Usage */
void
example_usage(void)
{
    g_autoptr(MyConfig) config = g_object_new(MY_TYPE_CONFIG,
        "name", "production",
        "port", 443,
        "enabled", TRUE,
        NULL
    );

    /* Serialize to YAML */
    g_autofree gchar *yaml = yaml_gobject_to_data(G_OBJECT(config), NULL);
    g_print("%s\n", yaml);
    /*
    name: production
    port: '443'
    enabled: true
    */

    /* Deserialize from YAML */
    const gchar *input = "name: staging\nis-enabled: false\n";
    g_autoptr(GObject) loaded = yaml_gobject_from_data(
        MY_TYPE_CONFIG, input, -1, NULL
    );
}
```

## Type Mappings

The default implementations map between GObject and YAML types:

| GObject Type | YAML Node Type |
|--------------|----------------|
| `G_TYPE_BOOLEAN` | Scalar (true/false) |
| `G_TYPE_INT`, `G_TYPE_INT64` | Scalar (integer) |
| `G_TYPE_UINT`, `G_TYPE_UINT64` | Scalar (integer) |
| `G_TYPE_FLOAT`, `G_TYPE_DOUBLE` | Scalar (float) |
| `G_TYPE_STRING` | Scalar (string) |
| `G_TYPE_ENUM` | Scalar (nick) |
| `G_TYPE_FLAGS` | Scalar (combined nicks) |
| `G_TYPE_BOXED` | Depends on registered handlers |
| `G_TYPE_OBJECT` | Mapping (nested) |

## See Also

- [GObject Serialization](gobject.md) - High-level serialization functions
- [GObject Serialization Guide](../guides/gobject-serialization.md) - Complete guide
- [YamlNode](node.md) - Node types
