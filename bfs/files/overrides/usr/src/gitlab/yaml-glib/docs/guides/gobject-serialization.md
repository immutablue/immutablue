# GObject Serialization Guide

This guide covers serializing GObjects to YAML and deserializing YAML back to GObjects.

## Overview

yaml-glib provides comprehensive GObject serialization:

- **Automatic serialization** of GObject properties
- **YamlSerializable interface** for custom serialization logic
- **Boxed type registration** for custom value types
- **Nested object support** for complex hierarchies

## Basic Serialization

### Serializing a GObject

Any GObject with readable properties can be serialized:

```c
#include <yaml-glib/yaml-glib.h>

void
serialize_example(GObject *object)
{
    /* Serialize to YAML string */
    g_autofree gchar *yaml = yaml_gobject_to_data(object, NULL);
    g_print("%s\n", yaml);

    /* Or serialize to a node for further processing */
    g_autoptr(YamlNode) node = yaml_gobject_serialize(object);
}
```

### Deserializing to a GObject

```c
GObject *
deserialize_example(const gchar *yaml_str, GType object_type)
{
    g_autoptr(GError) error = NULL;

    GObject *object = yaml_gobject_from_data(
        object_type, yaml_str, -1, &error
    );

    if (object == NULL)
    {
        g_printerr("Error: %s\n", error->message);
        return NULL;
    }

    return object;
}
```

## Creating a Serializable GObject

### Simple GObject

```c
#include <yaml-glib/yaml-glib.h>

/* Type declaration */
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
        g_param_spec_string("name", NULL, NULL, NULL,
                            G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS);

    properties[PROP_AGE] =
        g_param_spec_int("age", NULL, NULL, 0, 150, 0,
                         G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS);

    properties[PROP_ACTIVE] =
        g_param_spec_boolean("active", NULL, NULL, FALSE,
                             G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS);

    g_object_class_install_properties(object_class, N_PROPERTIES, properties);
}

static void
my_person_init(MyPerson *self)
{
}
```

### Usage

```c
void
example_usage(void)
{
    /* Create and populate */
    g_autoptr(MyPerson) person = g_object_new(MY_TYPE_PERSON,
        "name", "Alice",
        "age", 30,
        "active", TRUE,
        NULL
    );

    /* Serialize */
    g_autofree gchar *yaml = yaml_gobject_to_data(G_OBJECT(person), NULL);
    g_print("Serialized:\n%s\n", yaml);
    /*
    name: Alice
    age: 30
    active: true
    */

    /* Deserialize */
    const gchar *input = "name: Bob\nage: 25\nactive: false\n";
    g_autoptr(GObject) loaded = yaml_gobject_from_data(
        MY_TYPE_PERSON, input, -1, NULL
    );

    MyPerson *bob = MY_PERSON(loaded);
    g_print("Loaded: %s, %d\n", bob->name, bob->age);
}
```

## Implementing YamlSerializable

For custom serialization behavior, implement the `YamlSerializable` interface.

### Interface Implementation

```c
/* Forward declaration */
static void my_config_serializable_init(YamlSerializableInterface *iface);

/* Type with interface */
G_DEFINE_TYPE_WITH_CODE(MyConfig, my_config, G_TYPE_OBJECT,
    G_IMPLEMENT_INTERFACE(YAML_TYPE_SERIALIZABLE, my_config_serializable_init))

struct _MyConfig
{
    GObject parent_instance;

    gchar *api_key;      /* Sensitive - encrypt in YAML */
    gchar *username;
    gint   timeout_ms;   /* Store as seconds in YAML */
};

/* Custom serialization */
static YamlNode *
my_config_serialize_property(YamlSerializable *serializable,
                             const gchar      *property_name,
                             const GValue     *value,
                             GParamSpec       *pspec)
{
    MyConfig *self = MY_CONFIG(serializable);

    /* Encrypt API key */
    if (g_strcmp0(property_name, "api-key") == 0)
    {
        const gchar *key = g_value_get_string(value);
        if (key != NULL)
        {
            g_autofree gchar *encrypted = encrypt_string(key);
            return yaml_node_new_string(encrypted);
        }
        return yaml_node_new_null();
    }

    /* Convert milliseconds to seconds */
    if (g_strcmp0(property_name, "timeout-ms") == 0)
    {
        gint ms = g_value_get_int(value);
        gdouble seconds = ms / 1000.0;
        return yaml_node_new_double(seconds);
    }

    /* Default for other properties */
    return yaml_serializable_default_serialize_property(
        serializable, property_name, value, pspec
    );
}

/* Custom deserialization */
static gboolean
my_config_deserialize_property(YamlSerializable *serializable,
                               const gchar      *property_name,
                               GValue           *value,
                               GParamSpec       *pspec,
                               YamlNode         *node)
{
    /* Decrypt API key */
    if (g_strcmp0(property_name, "api-key") == 0)
    {
        const gchar *encrypted = yaml_node_get_string(node);
        if (encrypted != NULL)
        {
            g_autofree gchar *decrypted = decrypt_string(encrypted);
            g_value_set_string(value, decrypted);
        }
        return TRUE;
    }

    /* Convert seconds to milliseconds */
    if (g_strcmp0(property_name, "timeout-ms") == 0)
    {
        gdouble seconds = yaml_node_get_double(node);
        g_value_set_int(value, (gint)(seconds * 1000));
        return TRUE;
    }

    /* Default for other properties */
    return yaml_serializable_default_deserialize_property(
        serializable, property_name, value, pspec, node
    );
}

/* Property name mapping */
static GParamSpec *
my_config_find_property(YamlSerializable *serializable,
                        const gchar      *name)
{
    /* Map YAML names to property names */
    if (g_strcmp0(name, "timeout") == 0)
    {
        return g_object_class_find_property(
            G_OBJECT_GET_CLASS(serializable), "timeout-ms"
        );
    }

    /* Default lookup */
    return g_object_class_find_property(
        G_OBJECT_GET_CLASS(serializable), name
    );
}

static void
my_config_serializable_init(YamlSerializableInterface *iface)
{
    iface->serialize_property = my_config_serialize_property;
    iface->deserialize_property = my_config_deserialize_property;
    iface->find_property = my_config_find_property;
}
```

## Boxed Type Serialization

For custom value types (boxed types), register serialization handlers.

### Defining a Boxed Type

```c
/* Simple point structure */
typedef struct {
    gdouble x;
    gdouble y;
} MyPoint;

static MyPoint *
my_point_copy(const MyPoint *src)
{
    MyPoint *copy = g_new(MyPoint, 1);
    *copy = *src;
    return copy;
}

static void
my_point_free(MyPoint *point)
{
    g_free(point);
}

G_DEFINE_BOXED_TYPE(MyPoint, my_point, my_point_copy, my_point_free)
```

### Registering Serialization Functions

```c
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

void
register_point_handlers(void)
{
    yaml_boxed_register_serialize_func(MY_TYPE_POINT, my_point_serialize);
    yaml_boxed_register_deserialize_func(MY_TYPE_POINT, my_point_deserialize);
}
```

### Using Boxed Types in Objects

```c
struct _MyShape
{
    GObject   parent;
    MyPoint  *center;
    gdouble   radius;
};

/* After registering handlers, MyPoint properties serialize automatically */
void
example_boxed_usage(void)
{
    register_point_handlers();

    g_autoptr(MyShape) shape = g_object_new(MY_TYPE_SHAPE, NULL);

    MyPoint center = { 10.0, 20.0 };
    my_shape_set_center(shape, &center);
    my_shape_set_radius(shape, 5.0);

    g_autofree gchar *yaml = yaml_gobject_to_data(G_OBJECT(shape), NULL);
    g_print("%s\n", yaml);
    /*
    center:
      x: 10.0
      y: 20.0
    radius: 5.0
    */
}
```

## Nested Objects

GObject properties containing other GObjects are serialized recursively.

```c
struct _MyTeam
{
    GObject    parent;
    gchar     *name;
    GPtrArray *members;  /* Array of MyPerson */
};

/* Properties are serialized as nested YAML */
void
example_nested(void)
{
    g_autoptr(MyTeam) team = my_team_new("Engineering");

    my_team_add_member(team, my_person_new("Alice", 30));
    my_team_add_member(team, my_person_new("Bob", 25));

    g_autofree gchar *yaml = yaml_gobject_to_data(G_OBJECT(team), NULL);
    g_print("%s\n", yaml);
    /*
    name: Engineering
    members:
      - name: Alice
        age: 30
        active: false
      - name: Bob
        age: 25
        active: false
    */
}
```

## Enum and Flags Serialization

Enums are serialized by their nick (short name), flags by combined nicks.

```c
typedef enum {
    MY_STATUS_UNKNOWN,
    MY_STATUS_PENDING,
    MY_STATUS_ACTIVE,
    MY_STATUS_COMPLETED
} MyStatus;

/* Register with glib-mkenums or manually */
GType my_status_get_type(void);

/* In YAML */
/*
status: active
*/

typedef enum {
    MY_FLAG_NONE     = 0,
    MY_FLAG_READ     = 1 << 0,
    MY_FLAG_WRITE    = 1 << 1,
    MY_FLAG_EXECUTE  = 1 << 2
} MyFlags;

/* In YAML */
/*
permissions: read|write
*/
```

## Property Filtering

Control which properties are serialized:

```c
static GParamSpec **
my_object_list_properties(YamlSerializable *serializable,
                          guint            *n_pspecs)
{
    GObjectClass *klass = G_OBJECT_GET_CLASS(serializable);
    guint n_props;
    GParamSpec **all_props = g_object_class_list_properties(klass, &n_props);

    /* Filter out private/internal properties */
    GPtrArray *filtered = g_ptr_array_new();

    for (guint i = 0; i < n_props; i++)
    {
        GParamSpec *pspec = all_props[i];

        /* Skip properties starting with underscore */
        if (pspec->name[0] == '_')
            continue;

        /* Skip construct-only properties */
        if (pspec->flags & G_PARAM_CONSTRUCT_ONLY)
            continue;

        g_ptr_array_add(filtered, pspec);
    }

    g_free(all_props);

    *n_pspecs = filtered->len;
    return (GParamSpec **)g_ptr_array_free(filtered, FALSE);
}
```

## Complete Example

```c
#include <yaml-glib/yaml-glib.h>

/* Address boxed type */
typedef struct {
    gchar *street;
    gchar *city;
    gchar *zip;
} Address;

static Address *
address_copy(const Address *src)
{
    Address *copy = g_new(Address, 1);
    copy->street = g_strdup(src->street);
    copy->city = g_strdup(src->city);
    copy->zip = g_strdup(src->zip);
    return copy;
}

static void
address_free(Address *addr)
{
    g_free(addr->street);
    g_free(addr->city);
    g_free(addr->zip);
    g_free(addr);
}

G_DEFINE_BOXED_TYPE(Address, address, address_copy, address_free)

static YamlNode *
address_serialize(gconstpointer boxed)
{
    const Address *addr = boxed;
    g_autoptr(YamlBuilder) b = yaml_builder_new();

    yaml_builder_begin_mapping(b);
    yaml_builder_set_member_name(b, "street");
    yaml_builder_add_string_value(b, addr->street);
    yaml_builder_set_member_name(b, "city");
    yaml_builder_add_string_value(b, addr->city);
    yaml_builder_set_member_name(b, "zip");
    yaml_builder_add_string_value(b, addr->zip);
    yaml_builder_end_mapping(b);

    return yaml_builder_steal_root(b);
}

static gpointer
address_deserialize(YamlNode *node)
{
    YamlMapping *m = yaml_node_get_mapping(node);
    Address *addr = g_new0(Address, 1);

    addr->street = g_strdup(yaml_mapping_get_string_member(m, "street"));
    addr->city = g_strdup(yaml_mapping_get_string_member(m, "city"));
    addr->zip = g_strdup(yaml_mapping_get_string_member(m, "zip"));

    return addr;
}

/* Person with address */
struct _MyPerson
{
    GObject   parent;
    gchar    *name;
    Address  *address;
};

/* ... property implementation ... */

int
main(void)
{
    /* Register boxed handlers */
    yaml_boxed_register_serialize_func(address_get_type(), address_serialize);
    yaml_boxed_register_deserialize_func(address_get_type(), address_deserialize);

    /* Create person with address */
    Address addr = {
        .street = "123 Main St",
        .city = "Springfield",
        .zip = "12345"
    };

    g_autoptr(MyPerson) person = g_object_new(MY_TYPE_PERSON,
        "name", "Alice",
        "address", &addr,
        NULL
    );

    /* Serialize */
    g_autofree gchar *yaml = yaml_gobject_to_data(G_OBJECT(person), NULL);
    g_print("%s\n", yaml);
    /*
    name: Alice
    address:
      street: 123 Main St
      city: Springfield
      zip: '12345'
    */

    /* Deserialize */
    const gchar *input =
        "name: Bob\n"
        "address:\n"
        "  street: 456 Oak Ave\n"
        "  city: Shelbyville\n"
        "  zip: '67890'\n";

    g_autoptr(GObject) loaded = yaml_gobject_from_data(
        MY_TYPE_PERSON, input, -1, NULL
    );

    MyPerson *bob = MY_PERSON(loaded);
    g_print("Loaded: %s at %s, %s\n",
            bob->name,
            bob->address->street,
            bob->address->city);

    return 0;
}
```

## See Also

- [YamlSerializable API](../api/serializable.md) - Interface reference
- [GObject Serialization API](../api/gobject.md) - Function reference
- [Memory Management](../memory-management.md) - Ownership patterns
