# YamlSequence API Reference

`YamlSequence` is a container for an ordered list of `YamlNode` elements.

## Overview

```c
#include <yaml-glib/yaml-glib.h>

#define YAML_TYPE_SEQUENCE (yaml_sequence_get_type())
```

`YamlSequence` is a reference-counted boxed type. Use `yaml_sequence_ref()` and `yaml_sequence_unref()` to manage its lifetime.

A sequence can be made immutable by calling `yaml_sequence_seal()`. Immutable sequences cannot be modified and are safe to share between threads.

## Type Definition

```c
typedef struct _YamlSequence YamlSequence;
```

## Callback Types

### YamlSequenceForeach

```c
typedef void (*YamlSequenceForeach)(
    YamlSequence *sequence,
    guint         index_,
    YamlNode     *element_node,
    gpointer      user_data
);
```

Callback function type for `yaml_sequence_foreach_element()`.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | The iterated sequence |
| index_ | `guint` | The index of the current element |
| element_node | `YamlNode *` | The current element |
| user_data | `gpointer` | User data passed to `yaml_sequence_foreach_element()` |

---

## Construction

### yaml_sequence_new

```c
YamlSequence *yaml_sequence_new(void);
```

Creates a new empty `YamlSequence`.

**Returns:** `(transfer full)` A new `YamlSequence`. Use `yaml_sequence_unref()` when done.

**Example:**
```c
g_autoptr(YamlSequence) tags = yaml_sequence_new();
yaml_sequence_add_string_element(tags, "important");
yaml_sequence_add_string_element(tags, "urgent");
```

---

### yaml_sequence_sized_new

```c
YamlSequence *yaml_sequence_sized_new(guint n_elements);
```

Creates a new `YamlSequence` with pre-allocated capacity.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| n_elements | `guint` | The initial capacity |

**Returns:** `(transfer full)` A new `YamlSequence`.

**Example:**
```c
/* Pre-allocate for 100 elements */
g_autoptr(YamlSequence) large_list = yaml_sequence_sized_new(100);
```

---

## Reference Counting

### yaml_sequence_ref

```c
YamlSequence *yaml_sequence_ref(YamlSequence *sequence);
```

Increases the reference count by one.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |

**Returns:** `(transfer full)` The same sequence.

---

### yaml_sequence_unref

```c
void yaml_sequence_unref(YamlSequence *sequence);
```

Decreases the reference count by one. When the count reaches zero, the sequence is freed.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |

---

## Immutability

### yaml_sequence_seal

```c
void yaml_sequence_seal(YamlSequence *sequence);
```

Makes the sequence immutable. Also seals all contained nodes.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |

---

### yaml_sequence_is_immutable

```c
gboolean yaml_sequence_is_immutable(YamlSequence *sequence);
```

Checks whether the sequence is immutable (sealed).

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |

**Returns:** `TRUE` if the sequence is immutable.

---

## Size and Element Access

### yaml_sequence_get_length

```c
guint yaml_sequence_get_length(YamlSequence *sequence);
```

Gets the number of elements.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |

**Returns:** The number of elements.

---

### yaml_sequence_add_element

```c
void yaml_sequence_add_element(YamlSequence *sequence, YamlNode *node);
```

Appends a node to the end of the sequence. Takes a reference on the node.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |
| node | `YamlNode *` | The node to add |

**Example:**
```c
g_autoptr(YamlNode) item = yaml_node_new_string("new item");
yaml_sequence_add_element(sequence, item);
```

---

### yaml_sequence_get_element

```c
YamlNode *yaml_sequence_get_element(YamlSequence *sequence, guint index_);
```

Gets the element at the specified index.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |
| index_ | `guint` | The element index |

**Returns:** `(transfer none) (nullable)` The element node, or `NULL` if out of bounds.

**Example:**
```c
guint len = yaml_sequence_get_length(sequence);
for (guint i = 0; i < len; i++)
{
    YamlNode *item = yaml_sequence_get_element(sequence, i);
    g_print("Item %u: %s\n", i, yaml_node_get_string(item));
}
```

---

### yaml_sequence_dup_element

```c
YamlNode *yaml_sequence_dup_element(YamlSequence *sequence, guint index_);
```

Gets a new reference to the element at the specified index.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |
| index_ | `guint` | The element index |

**Returns:** `(transfer full) (nullable)` A new reference to the element, or `NULL`. Free with `yaml_node_unref()`.

---

### yaml_sequence_remove_element

```c
void yaml_sequence_remove_element(YamlSequence *sequence, guint index_);
```

Removes the element at the specified index.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |
| index_ | `guint` | The element index to remove |

---

### yaml_sequence_get_elements

```c
GList *yaml_sequence_get_elements(YamlSequence *sequence);
```

Gets a list of all elements.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |

**Returns:** `(transfer container) (element-type YamlNode)` A newly allocated `GList` of `YamlNode`. The nodes are owned by the sequence. Free the list with `g_list_free()`.

---

## Convenience Adders

### yaml_sequence_add_string_element

```c
void yaml_sequence_add_string_element(YamlSequence *sequence, const gchar *value);
```

Appends a string value.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |
| value | `const gchar *` | The string value to add |

**Example:**
```c
g_autoptr(YamlSequence) hobbies = yaml_sequence_new();
yaml_sequence_add_string_element(hobbies, "reading");
yaml_sequence_add_string_element(hobbies, "hiking");
yaml_sequence_add_string_element(hobbies, "photography");
```

---

### yaml_sequence_add_int_element

```c
void yaml_sequence_add_int_element(YamlSequence *sequence, gint64 value);
```

Appends an integer value.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |
| value | `gint64` | The integer value to add |

---

### yaml_sequence_add_double_element

```c
void yaml_sequence_add_double_element(YamlSequence *sequence, gdouble value);
```

Appends a double value.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |
| value | `gdouble` | The double value to add |

---

### yaml_sequence_add_boolean_element

```c
void yaml_sequence_add_boolean_element(YamlSequence *sequence, gboolean value);
```

Appends a boolean value.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |
| value | `gboolean` | The boolean value to add |

---

### yaml_sequence_add_null_element

```c
void yaml_sequence_add_null_element(YamlSequence *sequence);
```

Appends a null value.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |

---

### yaml_sequence_add_mapping_element

```c
void yaml_sequence_add_mapping_element(YamlSequence *sequence, YamlMapping *value);
```

Appends a mapping value.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |
| value | `YamlMapping *` | The mapping value to add |

**Example:**
```c
/* Create a list of users */
g_autoptr(YamlSequence) users = yaml_sequence_new();

for (int i = 0; i < 3; i++)
{
    g_autoptr(YamlMapping) user = yaml_mapping_new();
    g_autofree gchar *name = g_strdup_printf("User %d", i);
    yaml_mapping_set_string_member(user, "name", name);
    yaml_mapping_set_int_member(user, "id", i);
    yaml_sequence_add_mapping_element(users, user);
}
```

---

### yaml_sequence_add_sequence_element

```c
void yaml_sequence_add_sequence_element(YamlSequence *sequence, YamlSequence *value);
```

Appends a sequence value (nested sequence).

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |
| value | `YamlSequence *` | The sequence value to add |

---

## Convenience Getters

### yaml_sequence_get_string_element

```c
const gchar *yaml_sequence_get_string_element(YamlSequence *sequence, guint index_);
```

Gets the string value at the specified index.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |
| index_ | `guint` | The element index |

**Returns:** `(transfer none) (nullable)` The string value, or `NULL`.

---

### yaml_sequence_get_int_element

```c
gint64 yaml_sequence_get_int_element(YamlSequence *sequence, guint index_);
```

Gets the integer value at the specified index.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |
| index_ | `guint` | The element index |

**Returns:** The integer value, or 0 if not found or not an integer.

---

### yaml_sequence_get_double_element

```c
gdouble yaml_sequence_get_double_element(YamlSequence *sequence, guint index_);
```

Gets the double value at the specified index.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |
| index_ | `guint` | The element index |

**Returns:** The double value, or 0.0 if not found or not a number.

---

### yaml_sequence_get_boolean_element

```c
gboolean yaml_sequence_get_boolean_element(YamlSequence *sequence, guint index_);
```

Gets the boolean value at the specified index.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |
| index_ | `guint` | The element index |

**Returns:** The boolean value, or `FALSE` if not found.

---

### yaml_sequence_get_null_element

```c
gboolean yaml_sequence_get_null_element(YamlSequence *sequence, guint index_);
```

Checks if the element at the index is null.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |
| index_ | `guint` | The element index |

**Returns:** `TRUE` if the element is null.

---

### yaml_sequence_get_mapping_element

```c
YamlMapping *yaml_sequence_get_mapping_element(YamlSequence *sequence, guint index_);
```

Gets the mapping value at the specified index.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |
| index_ | `guint` | The element index |

**Returns:** `(transfer none) (nullable)` The mapping value, or `NULL`.

---

### yaml_sequence_get_sequence_element

```c
YamlSequence *yaml_sequence_get_sequence_element(YamlSequence *sequence, guint index_);
```

Gets the sequence value at the specified index (nested sequence).

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |
| index_ | `guint` | The element index |

**Returns:** `(transfer none) (nullable)` The sequence value, or `NULL`.

---

## Iteration

### yaml_sequence_foreach_element

```c
void yaml_sequence_foreach_element(
    YamlSequence        *sequence,
    YamlSequenceForeach  func,
    gpointer             user_data
);
```

Calls a function for each element in the sequence.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| sequence | `YamlSequence *` | A sequence |
| func | `YamlSequenceForeach` | The callback function |
| user_data | `gpointer` | User data to pass to the callback |

**Example:**
```c
static void
print_element(
    YamlSequence *sequence,
    guint         index_,
    YamlNode     *node,
    gpointer      user_data
)
{
    (void)sequence;
    (void)user_data;
    g_print("[%u] %s\n", index_, yaml_node_get_string(node));
}

yaml_sequence_foreach_element(sequence, print_element, NULL);
```

---

## Equality and Hashing

### yaml_sequence_hash

```c
guint yaml_sequence_hash(gconstpointer key);
```

Computes a hash value for the sequence.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| key | `gconstpointer` | A `YamlSequence` |

**Returns:** A hash value.

---

### yaml_sequence_equal

```c
gboolean yaml_sequence_equal(gconstpointer a, gconstpointer b);
```

Checks if two sequences have equal content.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| a | `gconstpointer` | A `YamlSequence` |
| b | `gconstpointer` | Another `YamlSequence` |

**Returns:** `TRUE` if the sequences are equal.

---

## Autoptr Support

```c
G_DEFINE_AUTOPTR_CLEANUP_FUNC(YamlSequence, yaml_sequence_unref)
```

Use `g_autoptr(YamlSequence)` for automatic cleanup:

```c
void example(void)
{
    g_autoptr(YamlSequence) sequence = yaml_sequence_new();
    yaml_sequence_add_string_element(sequence, "item");
    /* sequence automatically freed when leaving scope */
}
```

## See Also

- [YamlNode](node.md) - Generic container
- [YamlMapping](mapping.md) - Key-value pairs
- [Memory Management](../memory-management.md) - Ownership patterns
