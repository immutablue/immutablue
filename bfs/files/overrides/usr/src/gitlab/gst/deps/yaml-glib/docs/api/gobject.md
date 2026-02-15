# GObject Serialization API Reference

Functions for serializing GObjects to and from YAML.

## Overview

```c
#include <yaml-glib/yaml-glib.h>
```

The GObject serialization API provides high-level functions for converting GObjects to YAML and back. It works with any GObject and optionally integrates with the `YamlSerializable` interface for custom behavior.

## GObject Serialization

### yaml_gobject_serialize

```c
YamlNode *yaml_gobject_serialize(GObject *gobject);
```

Serializes a GObject to a YAML node.

If the object implements `YamlSerializable`, the interface methods are used for serialization. Otherwise, default property-based serialization is used.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| gobject | `GObject *` | A GObject |

**Returns:** `(transfer full) (nullable)` A `YamlNode`, or `NULL` on error.

**Example:**
```c
g_autoptr(MyPerson) person = my_person_new("John", 30);
g_autoptr(YamlNode) node = yaml_gobject_serialize(G_OBJECT(person));

if (node != NULL)
{
    g_autoptr(YamlGenerator) gen = yaml_generator_new();
    yaml_generator_set_root(gen, node);

    g_autofree gchar *yaml = yaml_generator_to_data(gen, NULL, NULL);
    g_print("%s\n", yaml);
}
```

---

### yaml_gobject_deserialize

```c
GObject *yaml_gobject_deserialize(
    GType     gtype,
    YamlNode *node
);
```

Deserializes a YAML node into a new GObject of the specified type.

If the type implements `YamlSerializable`, the interface methods are used for deserialization. Otherwise, default property-based deserialization is used.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| gtype | `GType` | The GType of the object to create |
| node | `YamlNode *` | The YAML node containing the data |

**Returns:** `(transfer full) (nullable)` A new `GObject`, or `NULL` on error.

**Example:**
```c
g_autoptr(YamlParser) parser = yaml_parser_new();
yaml_parser_load_from_data(parser, yaml_str, -1, NULL);

YamlNode *root = yaml_parser_get_root(parser);
g_autoptr(GObject) obj = yaml_gobject_deserialize(MY_TYPE_PERSON, root);

MyPerson *person = MY_PERSON(obj);
g_print("Name: %s\n", my_person_get_name(person));
```

---

### yaml_gobject_from_data

```c
GObject *yaml_gobject_from_data(
    GType         gtype,
    const gchar  *data,
    gssize        length,
    GError      **error
);
```

Convenience function to deserialize a GObject from a YAML string.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| gtype | `GType` | The GType of the object to create |
| data | `const gchar *` | The YAML string |
| length | `gssize` | Length of data, or -1 if null-terminated |
| error | `GError **` `(nullable)` | Return location for error |

**Returns:** `(transfer full) (nullable)` A new `GObject`, or `NULL` on error.

**Example:**
```c
const gchar *yaml_str = "name: Jane\nage: 25\n";
g_autoptr(GError) error = NULL;

g_autoptr(GObject) obj = yaml_gobject_from_data(
    MY_TYPE_PERSON, yaml_str, -1, &error
);

if (obj == NULL)
{
    g_printerr("Error: %s\n", error->message);
}
```

---

### yaml_gobject_to_data

```c
gchar *yaml_gobject_to_data(
    GObject *gobject,
    gsize   *length
);
```

Convenience function to serialize a GObject to a YAML string.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| gobject | `GObject *` | A GObject |
| length | `gsize *` `(out) (optional)` | Location for the output length |

**Returns:** `(transfer full) (nullable)` The YAML string, or `NULL` on error. Free with `g_free()`.

**Example:**
```c
g_autoptr(MyConfig) config = my_config_new();
my_config_set_host(config, "localhost");
my_config_set_port(config, 8080);

gsize len;
g_autofree gchar *yaml = yaml_gobject_to_data(G_OBJECT(config), &len);

g_print("YAML (%zu bytes):\n%s", len, yaml);
```

---

## Boxed Type Registration

For boxed types (registered with `G_DEFINE_BOXED_TYPE`), you must register custom serialization functions.

### YamlBoxedSerializeFunc

```c
typedef YamlNode *(*YamlBoxedSerializeFunc)(gconstpointer boxed);
```

Callback type for serializing boxed types.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| boxed | `gconstpointer` | The boxed value to serialize |

**Returns:** `(transfer full)` A `YamlNode`.

---

### YamlBoxedDeserializeFunc

```c
typedef gpointer (*YamlBoxedDeserializeFunc)(YamlNode *node);
```

Callback type for deserializing boxed types.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| node | `YamlNode *` | The YAML node to deserialize |

**Returns:** `(transfer full)` A new boxed value.

---

### yaml_boxed_register_serialize_func

```c
void yaml_boxed_register_serialize_func(
    GType                    gtype,
    YamlBoxedSerializeFunc   serialize_func
);
```

Registers a serialization function for a boxed type.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| gtype | `GType` | The boxed GType |
| serialize_func | `YamlBoxedSerializeFunc` | The serialization function |

---

### yaml_boxed_register_deserialize_func

```c
void yaml_boxed_register_deserialize_func(
    GType                      gtype,
    YamlBoxedDeserializeFunc   deserialize_func
);
```

Registers a deserialization function for a boxed type.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| gtype | `GType` | The boxed GType |
| deserialize_func | `YamlBoxedDeserializeFunc` | The deserialization function |

---

### yaml_boxed_can_serialize

```c
gboolean yaml_boxed_can_serialize(GType gtype);
```

Checks whether the boxed type has a registered serialization function.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| gtype | `GType` | A boxed GType |

**Returns:** `TRUE` if the type can be serialized.

---

### yaml_boxed_can_deserialize

```c
gboolean yaml_boxed_can_deserialize(GType gtype);
```

Checks whether the boxed type has a registered deserialization function.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| gtype | `GType` | A boxed GType |

**Returns:** `TRUE` if the type can be deserialized.

---

### yaml_boxed_serialize

```c
YamlNode *yaml_boxed_serialize(
    GType         gtype,
    gconstpointer boxed
);
```

Serializes a boxed value using the registered function.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| gtype | `GType` | The boxed GType |
| boxed | `gconstpointer` | The boxed value |

**Returns:** `(transfer full) (nullable)` A `YamlNode`, or `NULL`.

---

### yaml_boxed_deserialize

```c
gpointer yaml_boxed_deserialize(
    GType     gtype,
    YamlNode *node
);
```

Deserializes a boxed value using the registered function.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| gtype | `GType` | The boxed GType |
| node | `YamlNode *` | The YAML node |

**Returns:** `(transfer full) (nullable)` A new boxed value, or `NULL`.

---

## Boxed Type Example

```c
#include <yaml-glib/yaml-glib.h>

/* Define a simple point structure */
typedef struct {
    gdouble x;
    gdouble y;
} MyPoint;

/* Boxed type copy/free functions */
static MyPoint *
my_point_copy(const MyPoint *src)
{
    MyPoint *copy = g_new(MyPoint, 1);
    copy->x = src->x;
    copy->y = src->y;
    return copy;
}

static void
my_point_free(MyPoint *point)
{
    g_free(point);
}

G_DEFINE_BOXED_TYPE(MyPoint, my_point, my_point_copy, my_point_free)

/* Serialize to YAML mapping */
static YamlNode *
my_point_serialize(gconstpointer boxed)
{
    const MyPoint *point = boxed;
    g_autoptr(YamlBuilder) builder = yaml_builder_new();

    yaml_builder_begin_mapping(builder);
    {
        yaml_builder_set_member_name(builder, "x");
        yaml_builder_add_double_value(builder, point->x);

        yaml_builder_set_member_name(builder, "y");
        yaml_builder_add_double_value(builder, point->y);
    }
    yaml_builder_end_mapping(builder);

    return yaml_builder_steal_root(builder);
}

/* Deserialize from YAML mapping */
static gpointer
my_point_deserialize(YamlNode *node)
{
    if (yaml_node_get_node_type(node) != YAML_NODE_MAPPING)
        return NULL;

    YamlMapping *mapping = yaml_node_get_mapping(node);
    MyPoint *point = g_new(MyPoint, 1);

    point->x = yaml_mapping_get_double_member(mapping, "x");
    point->y = yaml_mapping_get_double_member(mapping, "y");

    return point;
}

/* Registration */
void
register_my_point_yaml(void)
{
    yaml_boxed_register_serialize_func(MY_TYPE_POINT, my_point_serialize);
    yaml_boxed_register_deserialize_func(MY_TYPE_POINT, my_point_deserialize);
}

/* Usage with a GObject that has a MyPoint property */
void
example_usage(void)
{
    /* Register handlers first */
    register_my_point_yaml();

    /* Now MyPoint properties can be serialized automatically */
    g_autoptr(MyShape) shape = my_shape_new();

    MyPoint center = { 10.5, 20.5 };
    my_shape_set_center(shape, &center);

    g_autofree gchar *yaml = yaml_gobject_to_data(G_OBJECT(shape), NULL);
    g_print("%s\n", yaml);
    /*
    center:
      x: 10.5
      y: 20.5
    */
}
```

## Complete GObject Example

```c
#include <yaml-glib/yaml-glib.h>

/* Simple person class */
#define MY_TYPE_PERSON (my_person_get_type())
G_DECLARE_FINAL_TYPE(MyPerson, my_person, MY, PERSON, GObject)

struct _MyPerson
{
    GObject parent_instance;
    gchar   *name;
    gint     age;
    gboolean active;
};

G_DEFINE_TYPE(MyPerson, my_person, G_TYPE_OBJECT)

enum {
    PROP_0,
    PROP_NAME,
    PROP_AGE,
    PROP_ACTIVE,
    N_PROPERTIES
};

static GParamSpec *properties[N_PROPERTIES];

static void
my_person_set_property(GObject      *object,
                       guint         prop_id,
                       const GValue *value,
                       GParamSpec   *pspec)
{
    MyPerson *self = MY_PERSON(object);

    switch (prop_id)
    {
    case PROP_NAME:
        g_free(self->name);
        self->name = g_value_dup_string(value);
        break;
    case PROP_AGE:
        self->age = g_value_get_int(value);
        break;
    case PROP_ACTIVE:
        self->active = g_value_get_boolean(value);
        break;
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
    }
}

static void
my_person_get_property(GObject    *object,
                       guint       prop_id,
                       GValue     *value,
                       GParamSpec *pspec)
{
    MyPerson *self = MY_PERSON(object);

    switch (prop_id)
    {
    case PROP_NAME:
        g_value_set_string(value, self->name);
        break;
    case PROP_AGE:
        g_value_set_int(value, self->age);
        break;
    case PROP_ACTIVE:
        g_value_set_boolean(value, self->active);
        break;
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
    }
}

static void
my_person_finalize(GObject *object)
{
    MyPerson *self = MY_PERSON(object);
    g_free(self->name);
    G_OBJECT_CLASS(my_person_parent_class)->finalize(object);
}

static void
my_person_class_init(MyPersonClass *klass)
{
    GObjectClass *object_class = G_OBJECT_CLASS(klass);

    object_class->set_property = my_person_set_property;
    object_class->get_property = my_person_get_property;
    object_class->finalize = my_person_finalize;

    properties[PROP_NAME] =
        g_param_spec_string("name", "Name", "Person name",
                            NULL,
                            G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS);

    properties[PROP_AGE] =
        g_param_spec_int("age", "Age", "Person age",
                         0, 150, 0,
                         G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS);

    properties[PROP_ACTIVE] =
        g_param_spec_boolean("active", "Active", "Is active",
                             FALSE,
                             G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS);

    g_object_class_install_properties(object_class, N_PROPERTIES, properties);
}

static void
my_person_init(MyPerson *self)
{
}

/* Main example */
int
main(int argc, char *argv[])
{
    /* Create and populate object */
    g_autoptr(MyPerson) person = g_object_new(MY_TYPE_PERSON,
        "name", "Alice",
        "age", 30,
        "active", TRUE,
        NULL
    );

    /* Serialize to YAML */
    g_autofree gchar *yaml = yaml_gobject_to_data(G_OBJECT(person), NULL);
    g_print("Serialized:\n%s\n", yaml);
    /*
    name: Alice
    age: 30
    active: true
    */

    /* Deserialize from YAML */
    const gchar *input =
        "name: Bob\n"
        "age: 25\n"
        "active: false\n";

    g_autoptr(GError) error = NULL;
    g_autoptr(GObject) loaded = yaml_gobject_from_data(
        MY_TYPE_PERSON, input, -1, &error
    );

    if (loaded != NULL)
    {
        MyPerson *bob = MY_PERSON(loaded);
        g_print("Loaded: %s, age %d\n",
                bob->name, bob->age);
    }

    return 0;
}
```

## See Also

- [YamlSerializable](serializable.md) - Custom serialization interface
- [GObject Serialization Guide](../guides/gobject-serialization.md) - Complete guide
- [YamlBuilder](builder.md) - Building YAML structures
