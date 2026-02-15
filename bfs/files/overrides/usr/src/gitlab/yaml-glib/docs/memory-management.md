# Memory Management

yaml-glib uses reference counting for memory management, following GLib/GObject conventions. This guide explains ownership patterns, automatic cleanup, and best practices.

## Reference Counting Basics

All yaml-glib types use reference counting:

- **GObject types** (YamlParser, YamlBuilder, YamlGenerator, YamlDocument, YamlSchema):
  - Use `g_object_ref()` to increment reference count
  - Use `g_object_unref()` to decrement reference count

- **Boxed types** (YamlNode, YamlMapping, YamlSequence):
  - Use `*_ref()` to increment (e.g., `yaml_node_ref()`)
  - Use `*_unref()` to decrement (e.g., `yaml_node_unref()`)

When the reference count reaches zero, the object is freed.

```c
/* Reference counting example */
YamlNode *node = yaml_node_new_string("hello");  /* ref_count = 1 */
yaml_node_ref(node);                              /* ref_count = 2 */
yaml_node_unref(node);                            /* ref_count = 1 */
yaml_node_unref(node);                            /* ref_count = 0, freed */
```

## Ownership Conventions

yaml-glib uses consistent naming conventions to indicate ownership:

### get_* Functions

Returns a **borrowed reference**. The caller must NOT free the returned value. The value remains valid as long as the parent object exists.

```c
/* yaml_parser_get_root() returns borrowed reference */
YamlParser *parser = yaml_parser_new();
yaml_parser_load_from_data(parser, "key: value\n", -1, NULL);

YamlNode *root = yaml_parser_get_root(parser);  /* borrowed */
/* Use root, but don't free it */

g_object_unref(parser);  /* root is now invalid */
```

### dup_* Functions

Returns a **new reference**. The caller owns the returned value and must free it.

```c
/* yaml_parser_dup_root() returns new reference */
YamlParser *parser = yaml_parser_new();
yaml_parser_load_from_data(parser, "key: value\n", -1, NULL);

YamlNode *root = yaml_parser_dup_root(parser);  /* new reference */

g_object_unref(parser);  /* root is still valid */

/* Use root... */

yaml_node_unref(root);  /* caller must free */
```

### steal_* Functions

**Steals ownership** from the source object. The caller owns the returned value, and the source no longer contains it.

```c
/* yaml_parser_steal_root() transfers ownership */
YamlParser *parser = yaml_parser_new();
yaml_parser_load_from_data(parser, "key: value\n", -1, NULL);

YamlNode *root = yaml_parser_steal_root(parser);  /* ownership transferred */

/* parser no longer has a root */
g_assert(yaml_parser_get_root(parser) == NULL);

g_object_unref(parser);
yaml_node_unref(root);  /* caller owns it now */
```

### set_* Functions

Takes a **copy of the reference**. The caller retains their reference.

```c
/* yaml_node_set_mapping() copies the reference */
YamlMapping *mapping = yaml_mapping_new();  /* ref_count = 1 */
YamlNode *node = yaml_node_new(YAML_NODE_MAPPING);

yaml_node_set_mapping(node, mapping);  /* mapping ref_count = 2 */

yaml_mapping_unref(mapping);  /* ref_count = 1, node still has reference */
yaml_node_unref(node);        /* mapping ref_count = 0, freed */
```

### take_* Functions

**Steals the reference** from the caller. The caller loses their reference.

```c
/* yaml_node_take_mapping() steals the reference */
YamlMapping *mapping = yaml_mapping_new();  /* ref_count = 1 */
YamlNode *node = yaml_node_new(YAML_NODE_MAPPING);

yaml_node_take_mapping(node, mapping);  /* mapping ref_count = 1 (unchanged) */

/* Don't unref mapping - node owns it now */
yaml_node_unref(node);  /* mapping is freed with node */
```

## Automatic Cleanup with g_autoptr

GLib provides automatic cleanup macros that call the appropriate free function when a variable goes out of scope.

yaml-glib registers all types for use with `g_autoptr()`:

```c
void
example_function(void)
{
    /* Automatic cleanup - no manual unref needed */
    g_autoptr(YamlParser) parser = yaml_parser_new();
    g_autoptr(YamlNode) node = yaml_node_new_string("hello");
    g_autoptr(YamlMapping) mapping = yaml_mapping_new();
    g_autoptr(YamlSequence) sequence = yaml_sequence_new();
    g_autoptr(YamlBuilder) builder = yaml_builder_new();
    g_autoptr(YamlGenerator) generator = yaml_generator_new();
    g_autoptr(YamlDocument) document = yaml_document_new(NULL);
    g_autoptr(YamlSchema) schema = yaml_schema_new_for_mapping();
    g_autoptr(GError) error = NULL;
    g_autofree gchar *output = NULL;

    /* Use the objects... */

}  /* All objects automatically freed here */
```

### Using g_steal_pointer

When you need to return ownership or transfer to another function:

```c
YamlNode *
create_config_node(void)
{
    g_autoptr(YamlMapping) mapping = yaml_mapping_new();
    yaml_mapping_set_string_member(mapping, "name", "config");
    yaml_mapping_set_int_member(mapping, "version", 1);

    g_autoptr(YamlNode) node = yaml_node_new_mapping(mapping);

    /* Transfer ownership to caller, prevent auto-cleanup */
    return g_steal_pointer(&node);
}
```

## Common Patterns

### Parsing and Modifying

```c
void
parse_and_modify(const gchar *filename)
{
    g_autoptr(YamlParser) parser = yaml_parser_new();
    g_autoptr(GError) error = NULL;

    if (!yaml_parser_load_from_file(parser, filename, &error))
    {
        g_printerr("Parse error: %s\n", error->message);
        return;
    }

    /* Get borrowed reference - valid while parser exists */
    YamlNode *root = yaml_parser_get_root(parser);
    YamlMapping *mapping = yaml_node_get_mapping(root);

    /* Modify the data */
    yaml_mapping_set_string_member(mapping, "modified", "yes");

}  /* parser freed, root and mapping become invalid */
```

### Keeping Data After Parser is Freed

```c
YamlNode *
load_and_keep(const gchar *filename)
{
    g_autoptr(YamlParser) parser = yaml_parser_new();
    g_autoptr(GError) error = NULL;

    if (!yaml_parser_load_from_file(parser, filename, &error))
    {
        g_printerr("Parse error: %s\n", error->message);
        return NULL;
    }

    /* Steal the root - parser no longer owns it */
    return yaml_parser_steal_root(parser);
}  /* parser freed, but returned node remains valid */
```

### Building Complex Structures

```c
YamlNode *
build_structure(void)
{
    g_autoptr(YamlBuilder) builder = yaml_builder_new();

    yaml_builder_begin_mapping(builder);
    yaml_builder_set_member_name(builder, "users");
    yaml_builder_begin_sequence(builder);

    /* Add users... */

    yaml_builder_end_sequence(builder);
    yaml_builder_end_mapping(builder);

    /* Steal to prevent auto-cleanup */
    return yaml_builder_steal_root(builder);
}
```

### Iterating with Borrowed References

```c
void
process_items(YamlSequence *sequence)
{
    guint i;
    guint len = yaml_sequence_get_length(sequence);

    for (i = 0; i < len; i++)
    {
        /* Borrowed reference - don't free */
        YamlNode *item = yaml_sequence_get_element(sequence, i);
        const gchar *value = yaml_node_get_string(item);
        g_print("Item %u: %s\n", i, value);
    }
}
```

### Adding to Collections

```c
void
add_to_mapping(YamlMapping *mapping)
{
    /* Option 1: Create and let mapping take ownership */
    g_autoptr(YamlNode) node = yaml_node_new_string("value");
    yaml_mapping_set_member(mapping, "key", node);
    /* node will be freed at scope end, but mapping has its own ref */

    /* Option 2: Create without auto-cleanup */
    YamlNode *node2 = yaml_node_new_string("value2");
    yaml_mapping_set_member(mapping, "key2", node2);
    yaml_node_unref(node2);  /* Must manually unref */
}
```

## Immutability (Sealing)

yaml-glib supports making nodes immutable through sealing:

```c
g_autoptr(YamlNode) node = yaml_node_new_string("hello");

/* Seal the node - it becomes immutable */
yaml_node_seal(node);

/* Attempting to modify is silently ignored */
yaml_node_set_string(node, "world");  /* No effect */

const gchar *value = yaml_node_get_string(node);
g_assert_cmpstr(value, ==, "hello");  /* Still "hello" */
```

### Benefits of Sealing

1. **Thread Safety**: Sealed nodes can be shared between threads without synchronization
2. **Performance**: No need for defensive copies
3. **Data Integrity**: Prevents accidental modifications

### Creating Immutable Documents

```c
/* Parser that produces immutable documents */
g_autoptr(YamlParser) parser = yaml_parser_new_immutable();
yaml_parser_load_from_file(parser, "config.yaml", &error);

YamlNode *root = yaml_parser_get_root(parser);
g_assert_true(yaml_node_is_immutable(root));

/* Builder that produces immutable nodes */
g_autoptr(YamlBuilder) builder = yaml_builder_new_immutable();
/* ... build structure ... */
YamlNode *node = yaml_builder_get_root(builder);
g_assert_true(yaml_node_is_immutable(node));
```

### Recursive Sealing

Sealing a node also seals all its children:

```c
g_autoptr(YamlMapping) mapping = yaml_mapping_new();
yaml_mapping_set_string_member(mapping, "name", "John");

g_autoptr(YamlSequence) tags = yaml_sequence_new();
yaml_sequence_add_string_element(tags, "admin");

yaml_mapping_set_sequence_member(mapping, "tags", tags);

g_autoptr(YamlNode) root = yaml_node_new_mapping(mapping);

/* Seal root - also seals mapping, tags, and all children */
yaml_node_seal(root);

g_assert_true(yaml_mapping_is_immutable(mapping));
g_assert_true(yaml_sequence_is_immutable(tags));
```

## Memory Debugging

### Detecting Leaks

Use Valgrind to detect memory leaks:

```bash
G_DEBUG=gc-friendly G_SLICE=always-malloc valgrind --leak-check=full ./myprogram
```

### GLib Memory Debugging

Enable GLib memory debugging:

```bash
G_DEBUG=fatal-warnings,fatal-criticals ./myprogram
```

## Best Practices

1. **Use g_autoptr() whenever possible** - It prevents leaks from early returns
2. **Use g_steal_pointer() for ownership transfer** - Makes intent clear
3. **Prefer borrowed references** - Use `get_*` when you don't need to outlive the parent
4. **Use steal for long-lived data** - When data should outlive the parser
5. **Seal shared data** - Make immutable before sharing between threads
6. **Match ref/unref calls** - Every `*_ref()` needs a matching `*_unref()`
7. **Don't free borrowed references** - Check function documentation

## Quick Reference

| Function Pattern | Returns | Caller Action |
|-----------------|---------|---------------|
| `*_get_*()` | Borrowed | Don't free |
| `*_dup_*()` | New reference | Must free |
| `*_steal_*()` | Transfers ownership | Must free |
| `*_set_*()` | N/A | Keep caller's reference |
| `*_take_*()` | N/A | Don't free (ownership stolen) |
| `*_new*()` | New object | Must free |
| `*_copy()` | Deep copy | Must free |

## See Also

- [Error Handling](error-handling.md) - GError usage patterns
- [API Reference](api/node.md) - Detailed function documentation
- [GLib Memory](https://docs.gtk.org/glib/memory.html) - GLib memory management documentation
