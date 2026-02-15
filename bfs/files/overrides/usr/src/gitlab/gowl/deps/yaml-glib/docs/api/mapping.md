# YamlMapping API Reference

`YamlMapping` is a container for YAML key-value pairs where keys are strings and values are `YamlNode` instances.

## Overview

```c
#include <yaml-glib/yaml-glib.h>

#define YAML_TYPE_MAPPING (yaml_mapping_get_type())
```

`YamlMapping` is a reference-counted boxed type. Use `yaml_mapping_ref()` and `yaml_mapping_unref()` to manage its lifetime.

A mapping can be made immutable by calling `yaml_mapping_seal()`. Immutable mappings cannot be modified and are safe to share between threads.

## Type Definition

```c
typedef struct _YamlMapping YamlMapping;
```

## Callback Types

### YamlMappingForeach

```c
typedef void (*YamlMappingForeach)(
    YamlMapping *mapping,
    const gchar *member_name,
    YamlNode    *member_node,
    gpointer     user_data
);
```

Callback function type for `yaml_mapping_foreach_member()`.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | The iterated mapping |
| member_name | `const gchar *` | The name of the current member |
| member_node | `YamlNode *` | The value of the current member |
| user_data | `gpointer` | User data passed to `yaml_mapping_foreach_member()` |

---

## Construction

### yaml_mapping_new

```c
YamlMapping *yaml_mapping_new(void);
```

Creates a new empty `YamlMapping`.

**Returns:** `(transfer full)` A new `YamlMapping`. Use `yaml_mapping_unref()` when done.

**Example:**
```c
g_autoptr(YamlMapping) mapping = yaml_mapping_new();
yaml_mapping_set_string_member(mapping, "name", "John");
yaml_mapping_set_int_member(mapping, "age", 30);
```

---

## Reference Counting

### yaml_mapping_ref

```c
YamlMapping *yaml_mapping_ref(YamlMapping *mapping);
```

Increases the reference count by one.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |

**Returns:** `(transfer full)` The same mapping.

---

### yaml_mapping_unref

```c
void yaml_mapping_unref(YamlMapping *mapping);
```

Decreases the reference count by one. When the count reaches zero, the mapping is freed.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |

---

## Immutability

### yaml_mapping_seal

```c
void yaml_mapping_seal(YamlMapping *mapping);
```

Makes the mapping immutable. Also seals all contained nodes.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |

---

### yaml_mapping_is_immutable

```c
gboolean yaml_mapping_is_immutable(YamlMapping *mapping);
```

Checks whether the mapping is immutable (sealed).

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |

**Returns:** `TRUE` if the mapping is immutable.

---

## Size and Member Queries

### yaml_mapping_get_size

```c
guint yaml_mapping_get_size(YamlMapping *mapping);
```

Gets the number of key-value pairs.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |

**Returns:** The number of members.

---

### yaml_mapping_get_key

```c
const gchar *yaml_mapping_get_key(YamlMapping *mapping, guint index);
```

Gets the key name at the given index. Useful for index-based iteration.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |
| index | `guint` | The index of the key |

**Returns:** `(transfer none) (nullable)` The key name, or `NULL` if out of bounds.

---

### yaml_mapping_get_value

```c
YamlNode *yaml_mapping_get_value(YamlMapping *mapping, guint index);
```

Gets the value at the given index. Useful for index-based iteration.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |
| index | `guint` | The index of the value |

**Returns:** `(transfer none) (nullable)` The value, or `NULL` if out of bounds.

**Example:**
```c
/* Index-based iteration */
guint size = yaml_mapping_get_size(mapping);
for (guint i = 0; i < size; i++)
{
    const gchar *key = yaml_mapping_get_key(mapping, i);
    YamlNode *value = yaml_mapping_get_value(mapping, i);
    g_print("%s: %s\n", key, yaml_node_get_string(value));
}
```

---

### yaml_mapping_has_member

```c
gboolean yaml_mapping_has_member(YamlMapping *mapping, const gchar *member_name);
```

Checks whether the mapping contains a member with the given name.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |
| member_name | `const gchar *` | The member name to check |

**Returns:** `TRUE` if the member exists.

**Example:**
```c
if (yaml_mapping_has_member(mapping, "email"))
{
    const gchar *email = yaml_mapping_get_string_member(mapping, "email");
    send_notification(email);
}
```

---

### yaml_mapping_get_members

```c
GList *yaml_mapping_get_members(YamlMapping *mapping);
```

Gets a list of all member names.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |

**Returns:** `(transfer container) (element-type utf8)` A newly allocated `GList` of member names. The strings are owned by the mapping. Free the list with `g_list_free()`.

**Example:**
```c
GList *members = yaml_mapping_get_members(mapping);
for (GList *l = members; l != NULL; l = l->next)
{
    const gchar *name = l->data;
    g_print("Member: %s\n", name);
}
g_list_free(members);
```

---

## Generic Member Access

### yaml_mapping_set_member

```c
void yaml_mapping_set_member(
    YamlMapping *mapping,
    const gchar *member_name,
    YamlNode    *node
);
```

Sets the value of a member. Takes a reference on the node.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |
| member_name | `const gchar *` | The member name |
| node | `YamlNode *` | The value to set |

---

### yaml_mapping_get_member

```c
YamlNode *yaml_mapping_get_member(
    YamlMapping *mapping,
    const gchar *member_name
);
```

Gets the node value for a member.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |
| member_name | `const gchar *` | The member name |

**Returns:** `(transfer none) (nullable)` The node value, or `NULL` if not found.

---

### yaml_mapping_dup_member

```c
YamlNode *yaml_mapping_dup_member(
    YamlMapping *mapping,
    const gchar *member_name
);
```

Gets a new reference to the member value.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |
| member_name | `const gchar *` | The member name |

**Returns:** `(transfer full) (nullable)` A new reference, or `NULL`. Free with `yaml_node_unref()`.

---

### yaml_mapping_remove_member

```c
gboolean yaml_mapping_remove_member(
    YamlMapping *mapping,
    const gchar *member_name
);
```

Removes a member from the mapping.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |
| member_name | `const gchar *` | The member name to remove |

**Returns:** `TRUE` if the member was removed, `FALSE` if it didn't exist.

---

## Convenience Setters

### yaml_mapping_set_string_member

```c
void yaml_mapping_set_string_member(
    YamlMapping *mapping,
    const gchar *member_name,
    const gchar *value
);
```

Sets a string value for a member.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |
| member_name | `const gchar *` | The member name |
| value | `const gchar *` | The string value |

**Example:**
```c
yaml_mapping_set_string_member(mapping, "name", "John Doe");
yaml_mapping_set_string_member(mapping, "email", "john@example.com");
```

---

### yaml_mapping_set_int_member

```c
void yaml_mapping_set_int_member(
    YamlMapping *mapping,
    const gchar *member_name,
    gint64       value
);
```

Sets an integer value for a member.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |
| member_name | `const gchar *` | The member name |
| value | `gint64` | The integer value |

---

### yaml_mapping_set_double_member

```c
void yaml_mapping_set_double_member(
    YamlMapping *mapping,
    const gchar *member_name,
    gdouble      value
);
```

Sets a double value for a member.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |
| member_name | `const gchar *` | The member name |
| value | `gdouble` | The double value |

---

### yaml_mapping_set_boolean_member

```c
void yaml_mapping_set_boolean_member(
    YamlMapping *mapping,
    const gchar *member_name,
    gboolean     value
);
```

Sets a boolean value for a member.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |
| member_name | `const gchar *` | The member name |
| value | `gboolean` | The boolean value |

---

### yaml_mapping_set_null_member

```c
void yaml_mapping_set_null_member(
    YamlMapping *mapping,
    const gchar *member_name
);
```

Sets a null value for a member.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |
| member_name | `const gchar *` | The member name |

---

### yaml_mapping_set_mapping_member

```c
void yaml_mapping_set_mapping_member(
    YamlMapping *mapping,
    const gchar *member_name,
    YamlMapping *value
);
```

Sets a mapping value for a member.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |
| member_name | `const gchar *` | The member name |
| value | `YamlMapping *` | The mapping value |

**Example:**
```c
g_autoptr(YamlMapping) address = yaml_mapping_new();
yaml_mapping_set_string_member(address, "city", "Springfield");
yaml_mapping_set_string_member(address, "zip", "12345");

yaml_mapping_set_mapping_member(person, "address", address);
```

---

### yaml_mapping_set_sequence_member

```c
void yaml_mapping_set_sequence_member(
    YamlMapping  *mapping,
    const gchar  *member_name,
    YamlSequence *value
);
```

Sets a sequence value for a member.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |
| member_name | `const gchar *` | The member name |
| value | `YamlSequence *` | The sequence value |

---

## Convenience Getters

### yaml_mapping_get_string_member

```c
const gchar *yaml_mapping_get_string_member(
    YamlMapping *mapping,
    const gchar *member_name
);
```

Gets the string value of a member.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |
| member_name | `const gchar *` | The member name |

**Returns:** `(transfer none) (nullable)` The string value, or `NULL`.

**Example:**
```c
const gchar *name = yaml_mapping_get_string_member(mapping, "name");
if (name != NULL)
{
    g_print("Name: %s\n", name);
}
```

---

### yaml_mapping_get_int_member

```c
gint64 yaml_mapping_get_int_member(
    YamlMapping *mapping,
    const gchar *member_name
);
```

Gets the integer value of a member.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |
| member_name | `const gchar *` | The member name |

**Returns:** The integer value, or 0 if not found or not an integer.

---

### yaml_mapping_get_double_member

```c
gdouble yaml_mapping_get_double_member(
    YamlMapping *mapping,
    const gchar *member_name
);
```

Gets the double value of a member.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |
| member_name | `const gchar *` | The member name |

**Returns:** The double value, or 0.0 if not found or not a number.

---

### yaml_mapping_get_boolean_member

```c
gboolean yaml_mapping_get_boolean_member(
    YamlMapping *mapping,
    const gchar *member_name
);
```

Gets the boolean value of a member.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |
| member_name | `const gchar *` | The member name |

**Returns:** The boolean value, or `FALSE` if not found.

---

### yaml_mapping_get_null_member

```c
gboolean yaml_mapping_get_null_member(
    YamlMapping *mapping,
    const gchar *member_name
);
```

Checks if a member is a null value.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |
| member_name | `const gchar *` | The member name |

**Returns:** `TRUE` if the member is null.

---

### yaml_mapping_get_mapping_member

```c
YamlMapping *yaml_mapping_get_mapping_member(
    YamlMapping *mapping,
    const gchar *member_name
);
```

Gets the mapping value of a member.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |
| member_name | `const gchar *` | The member name |

**Returns:** `(transfer none) (nullable)` The mapping value, or `NULL`.

---

### yaml_mapping_get_sequence_member

```c
YamlSequence *yaml_mapping_get_sequence_member(
    YamlMapping *mapping,
    const gchar *member_name
);
```

Gets the sequence value of a member.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |
| member_name | `const gchar *` | The member name |

**Returns:** `(transfer none) (nullable)` The sequence value, or `NULL`.

---

## Iteration

### yaml_mapping_foreach_member

```c
void yaml_mapping_foreach_member(
    YamlMapping        *mapping,
    YamlMappingForeach  func,
    gpointer            user_data
);
```

Calls a function for each member in the mapping.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| mapping | `YamlMapping *` | A mapping |
| func | `YamlMappingForeach` | The callback function |
| user_data | `gpointer` | User data to pass to the callback |

**Example:**
```c
static void
print_member(
    YamlMapping *mapping,
    const gchar *name,
    YamlNode    *node,
    gpointer     user_data
)
{
    (void)mapping;
    (void)user_data;
    g_print("%s: %s\n", name, yaml_node_get_string(node));
}

yaml_mapping_foreach_member(mapping, print_member, NULL);
```

---

## Equality and Hashing

### yaml_mapping_hash

```c
guint yaml_mapping_hash(gconstpointer key);
```

Computes a hash value for the mapping.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| key | `gconstpointer` | A `YamlMapping` |

**Returns:** A hash value.

---

### yaml_mapping_equal

```c
gboolean yaml_mapping_equal(gconstpointer a, gconstpointer b);
```

Checks if two mappings have equal content.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| a | `gconstpointer` | A `YamlMapping` |
| b | `gconstpointer` | Another `YamlMapping` |

**Returns:** `TRUE` if the mappings are equal.

---

## Autoptr Support

```c
G_DEFINE_AUTOPTR_CLEANUP_FUNC(YamlMapping, yaml_mapping_unref)
```

Use `g_autoptr(YamlMapping)` for automatic cleanup:

```c
void example(void)
{
    g_autoptr(YamlMapping) mapping = yaml_mapping_new();
    yaml_mapping_set_string_member(mapping, "key", "value");
    /* mapping automatically freed when leaving scope */
}
```

## See Also

- [YamlNode](node.md) - Generic container
- [YamlSequence](sequence.md) - Ordered arrays
- [Memory Management](../memory-management.md) - Ownership patterns
