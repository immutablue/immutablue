/* test_node.c
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Unit tests for YamlNode, YamlMapping, and YamlSequence.
 */

#include <glib.h>
#include "yaml-glib.h"

/* Test scalar node creation and value retrieval */
static void
test_node_scalar_string(void)
{
    YamlNode *node;

    node = yaml_node_new_string("hello world");
    g_assert_nonnull(node);
    g_assert_cmpint(yaml_node_get_node_type(node), ==, YAML_NODE_SCALAR);
    g_assert_cmpstr(yaml_node_get_scalar(node), ==, "hello world");

    yaml_node_unref(node);
}

static void
test_node_scalar_int(void)
{
    YamlNode *node;

    node = yaml_node_new_int(42);
    g_assert_nonnull(node);
    g_assert_cmpint(yaml_node_get_node_type(node), ==, YAML_NODE_SCALAR);
    g_assert_cmpint(yaml_node_get_int(node), ==, 42);

    yaml_node_unref(node);
}

static void
test_node_scalar_double(void)
{
    YamlNode *node;

    node = yaml_node_new_double(3.14159);
    g_assert_nonnull(node);
    g_assert_cmpint(yaml_node_get_node_type(node), ==, YAML_NODE_SCALAR);
    g_assert_cmpfloat_with_epsilon(yaml_node_get_double(node), 3.14159, 0.00001);

    yaml_node_unref(node);
}

static void
test_node_scalar_boolean(void)
{
    YamlNode *node_true;
    YamlNode *node_false;

    node_true = yaml_node_new_boolean(TRUE);
    g_assert_nonnull(node_true);
    g_assert_true(yaml_node_get_boolean(node_true));

    node_false = yaml_node_new_boolean(FALSE);
    g_assert_nonnull(node_false);
    g_assert_false(yaml_node_get_boolean(node_false));

    yaml_node_unref(node_true);
    yaml_node_unref(node_false);
}

static void
test_node_null(void)
{
    YamlNode *node;

    node = yaml_node_new_null();
    g_assert_nonnull(node);
    g_assert_cmpint(yaml_node_get_node_type(node), ==, YAML_NODE_NULL);

    yaml_node_unref(node);
}

/* Test mapping operations */
static void
test_mapping_basic(void)
{
    YamlMapping *mapping;
    YamlNode *node;
    YamlNode *value;

    mapping = yaml_mapping_new();
    g_assert_nonnull(mapping);
    g_assert_cmpuint(yaml_mapping_get_size(mapping), ==, 0);

    /* Add some values */
    yaml_mapping_set_string_member(mapping, "name", "test");
    yaml_mapping_set_int_member(mapping, "count", 42);
    yaml_mapping_set_boolean_member(mapping, "active", TRUE);

    g_assert_cmpuint(yaml_mapping_get_size(mapping), ==, 3);
    g_assert_true(yaml_mapping_has_member(mapping, "name"));
    g_assert_true(yaml_mapping_has_member(mapping, "count"));
    g_assert_true(yaml_mapping_has_member(mapping, "active"));
    g_assert_false(yaml_mapping_has_member(mapping, "nonexistent"));

    /* Retrieve values */
    g_assert_cmpstr(yaml_mapping_get_string_member(mapping, "name"), ==, "test");
    g_assert_cmpint(yaml_mapping_get_int_member(mapping, "count"), ==, 42);
    g_assert_true(yaml_mapping_get_boolean_member(mapping, "active"));

    /* Create node from mapping */
    node = yaml_node_new_mapping(mapping);
    g_assert_nonnull(node);
    g_assert_cmpint(yaml_node_get_node_type(node), ==, YAML_NODE_MAPPING);

    /* Verify we can get the mapping back */
    g_assert_true(yaml_node_get_mapping(node) == mapping);

    yaml_node_unref(node);
    yaml_mapping_unref(mapping);
}

static void
test_mapping_key_order(void)
{
    YamlMapping *mapping;
    const gchar *key;

    mapping = yaml_mapping_new();

    yaml_mapping_set_string_member(mapping, "first", "1");
    yaml_mapping_set_string_member(mapping, "second", "2");
    yaml_mapping_set_string_member(mapping, "third", "3");

    /* Keys should be returned in insertion order */
    key = yaml_mapping_get_key(mapping, 0);
    g_assert_cmpstr(key, ==, "first");

    key = yaml_mapping_get_key(mapping, 1);
    g_assert_cmpstr(key, ==, "second");

    key = yaml_mapping_get_key(mapping, 2);
    g_assert_cmpstr(key, ==, "third");

    yaml_mapping_unref(mapping);
}

static void
test_mapping_remove(void)
{
    YamlMapping *mapping;

    mapping = yaml_mapping_new();

    yaml_mapping_set_string_member(mapping, "a", "1");
    yaml_mapping_set_string_member(mapping, "b", "2");
    yaml_mapping_set_string_member(mapping, "c", "3");

    g_assert_cmpuint(yaml_mapping_get_size(mapping), ==, 3);

    yaml_mapping_remove_member(mapping, "b");

    g_assert_cmpuint(yaml_mapping_get_size(mapping), ==, 2);
    g_assert_true(yaml_mapping_has_member(mapping, "a"));
    g_assert_false(yaml_mapping_has_member(mapping, "b"));
    g_assert_true(yaml_mapping_has_member(mapping, "c"));

    yaml_mapping_unref(mapping);
}

/* Test sequence operations */
static void
test_sequence_basic(void)
{
    YamlSequence *sequence;
    YamlNode *node;
    YamlNode *element;

    sequence = yaml_sequence_new();
    g_assert_nonnull(sequence);
    g_assert_cmpuint(yaml_sequence_get_length(sequence), ==, 0);

    /* Add some elements */
    yaml_sequence_add_string_element(sequence, "one");
    yaml_sequence_add_string_element(sequence, "two");
    yaml_sequence_add_string_element(sequence, "three");

    g_assert_cmpuint(yaml_sequence_get_length(sequence), ==, 3);

    /* Retrieve elements */
    element = yaml_sequence_get_element(sequence, 0);
    g_assert_nonnull(element);
    g_assert_cmpstr(yaml_node_get_scalar(element), ==, "one");

    element = yaml_sequence_get_element(sequence, 1);
    g_assert_cmpstr(yaml_node_get_scalar(element), ==, "two");

    element = yaml_sequence_get_element(sequence, 2);
    g_assert_cmpstr(yaml_node_get_scalar(element), ==, "three");

    /* Create node from sequence */
    node = yaml_node_new_sequence(sequence);
    g_assert_nonnull(node);
    g_assert_cmpint(yaml_node_get_node_type(node), ==, YAML_NODE_SEQUENCE);

    yaml_node_unref(node);
    yaml_sequence_unref(sequence);
}

static void
test_sequence_mixed_types(void)
{
    YamlSequence *sequence;
    YamlNode *element;

    sequence = yaml_sequence_new();

    yaml_sequence_add_string_element(sequence, "hello");
    yaml_sequence_add_int_element(sequence, 42);
    yaml_sequence_add_double_element(sequence, 3.14);
    yaml_sequence_add_boolean_element(sequence, TRUE);
    yaml_sequence_add_null_element(sequence);

    g_assert_cmpuint(yaml_sequence_get_length(sequence), ==, 5);

    element = yaml_sequence_get_element(sequence, 0);
    g_assert_cmpint(yaml_node_get_node_type(element), ==, YAML_NODE_SCALAR);

    element = yaml_sequence_get_element(sequence, 4);
    g_assert_cmpint(yaml_node_get_node_type(element), ==, YAML_NODE_NULL);

    yaml_sequence_unref(sequence);
}

/* Test node sealing (immutability) */
static void
test_node_seal(void)
{
    YamlMapping *mapping;
    YamlNode *node;

    mapping = yaml_mapping_new();
    yaml_mapping_set_string_member(mapping, "key", "value");

    node = yaml_node_new_mapping(mapping);
    g_assert_false(yaml_node_is_immutable(node));

    yaml_node_seal(node);
    g_assert_true(yaml_node_is_immutable(node));

    yaml_node_unref(node);
    yaml_mapping_unref(mapping);
}

/* Test node reference counting */
static void
test_node_refcount(void)
{
    YamlNode *node;
    YamlNode *ref;

    node = yaml_node_new_string("test");
    g_assert_nonnull(node);

    ref = yaml_node_ref(node);
    g_assert_true(ref == node);

    /* Should not crash - both refs should be valid */
    g_assert_cmpstr(yaml_node_get_scalar(node), ==, "test");
    g_assert_cmpstr(yaml_node_get_scalar(ref), ==, "test");

    yaml_node_unref(ref);
    yaml_node_unref(node);
}

int
main(
    int   argc,
    char *argv[]
)
{
    g_test_init(&argc, &argv, NULL);

    /* Scalar tests */
    g_test_add_func("/node/scalar/string", test_node_scalar_string);
    g_test_add_func("/node/scalar/int", test_node_scalar_int);
    g_test_add_func("/node/scalar/double", test_node_scalar_double);
    g_test_add_func("/node/scalar/boolean", test_node_scalar_boolean);
    g_test_add_func("/node/null", test_node_null);

    /* Mapping tests */
    g_test_add_func("/mapping/basic", test_mapping_basic);
    g_test_add_func("/mapping/key_order", test_mapping_key_order);
    g_test_add_func("/mapping/remove", test_mapping_remove);

    /* Sequence tests */
    g_test_add_func("/sequence/basic", test_sequence_basic);
    g_test_add_func("/sequence/mixed_types", test_sequence_mixed_types);

    /* Node features */
    g_test_add_func("/node/seal", test_node_seal);
    g_test_add_func("/node/refcount", test_node_refcount);

    return g_test_run();
}
