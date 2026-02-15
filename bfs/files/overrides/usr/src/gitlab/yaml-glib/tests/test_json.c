/* test_json.c
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Unit tests for JSON-GLib interoperability.
 */

#include <glib.h>
#include <json-glib/json-glib.h>
#include "yaml-glib.h"

/* Test converting YamlNode to JsonNode - scalar */
static void
test_yaml_to_json_scalar(void)
{
    YamlNode *yaml_node;
    JsonNode *json_node;

    /* String */
    yaml_node = yaml_node_new_string("hello");
    json_node = yaml_node_to_json_node(yaml_node);
    g_assert_nonnull(json_node);
    g_assert_cmpint(json_node_get_node_type(json_node), ==, JSON_NODE_VALUE);
    g_assert_cmpstr(json_node_get_string(json_node), ==, "hello");
    json_node_unref(json_node);
    yaml_node_unref(yaml_node);

    /* Integer */
    yaml_node = yaml_node_new_int(42);
    json_node = yaml_node_to_json_node(yaml_node);
    g_assert_cmpint(json_node_get_int(json_node), ==, 42);
    json_node_unref(json_node);
    yaml_node_unref(yaml_node);

    /* Double */
    yaml_node = yaml_node_new_double(3.14);
    json_node = yaml_node_to_json_node(yaml_node);
    g_assert_cmpfloat_with_epsilon(json_node_get_double(json_node), 3.14, 0.01);
    json_node_unref(json_node);
    yaml_node_unref(yaml_node);

    /* Boolean */
    yaml_node = yaml_node_new_boolean(TRUE);
    json_node = yaml_node_to_json_node(yaml_node);
    g_assert_true(json_node_get_boolean(json_node));
    json_node_unref(json_node);
    yaml_node_unref(yaml_node);
}

/* Test converting YamlNode to JsonNode - null */
static void
test_yaml_to_json_null(void)
{
    YamlNode *yaml_node;
    JsonNode *json_node;

    yaml_node = yaml_node_new_null();
    json_node = yaml_node_to_json_node(yaml_node);
    g_assert_nonnull(json_node);
    g_assert_cmpint(json_node_get_node_type(json_node), ==, JSON_NODE_NULL);

    json_node_unref(json_node);
    yaml_node_unref(yaml_node);
}

/* Test converting YamlNode to JsonNode - mapping */
static void
test_yaml_to_json_mapping(void)
{
    YamlMapping *mapping;
    YamlNode *yaml_node;
    JsonNode *json_node;
    JsonObject *json_obj;

    mapping = yaml_mapping_new();
    yaml_mapping_set_string_member(mapping, "name", "Alice");
    yaml_mapping_set_int_member(mapping, "age", 30);

    yaml_node = yaml_node_new_mapping(mapping);
    json_node = yaml_node_to_json_node(yaml_node);

    g_assert_cmpint(json_node_get_node_type(json_node), ==, JSON_NODE_OBJECT);

    json_obj = json_node_get_object(json_node);
    g_assert_cmpstr(json_object_get_string_member(json_obj, "name"), ==, "Alice");
    g_assert_cmpint(json_object_get_int_member(json_obj, "age"), ==, 30);

    json_node_unref(json_node);
    yaml_node_unref(yaml_node);
    yaml_mapping_unref(mapping);
}

/* Test converting YamlNode to JsonNode - sequence */
static void
test_yaml_to_json_sequence(void)
{
    YamlSequence *sequence;
    YamlNode *yaml_node;
    JsonNode *json_node;
    JsonArray *json_array;

    sequence = yaml_sequence_new();
    yaml_sequence_add_string_element(sequence, "one");
    yaml_sequence_add_string_element(sequence, "two");
    yaml_sequence_add_string_element(sequence, "three");

    yaml_node = yaml_node_new_sequence(sequence);
    json_node = yaml_node_to_json_node(yaml_node);

    g_assert_cmpint(json_node_get_node_type(json_node), ==, JSON_NODE_ARRAY);

    json_array = json_node_get_array(json_node);
    g_assert_cmpuint(json_array_get_length(json_array), ==, 3);
    g_assert_cmpstr(json_array_get_string_element(json_array, 0), ==, "one");
    g_assert_cmpstr(json_array_get_string_element(json_array, 1), ==, "two");
    g_assert_cmpstr(json_array_get_string_element(json_array, 2), ==, "three");

    json_node_unref(json_node);
    yaml_node_unref(yaml_node);
    yaml_sequence_unref(sequence);
}

/* Test converting JsonNode to YamlNode - scalar */
static void
test_json_to_yaml_scalar(void)
{
    JsonNode *json_node;
    YamlNode *yaml_node;

    /* String */
    json_node = json_node_new(JSON_NODE_VALUE);
    json_node_set_string(json_node, "hello");
    yaml_node = yaml_node_from_json_node(json_node);
    g_assert_cmpint(yaml_node_get_node_type(yaml_node), ==, YAML_NODE_SCALAR);
    g_assert_cmpstr(yaml_node_get_scalar(yaml_node), ==, "hello");
    yaml_node_unref(yaml_node);
    json_node_unref(json_node);

    /* Integer */
    json_node = json_node_new(JSON_NODE_VALUE);
    json_node_set_int(json_node, 42);
    yaml_node = yaml_node_from_json_node(json_node);
    g_assert_cmpint(yaml_node_get_int(yaml_node), ==, 42);
    yaml_node_unref(yaml_node);
    json_node_unref(json_node);

    /* Double */
    json_node = json_node_new(JSON_NODE_VALUE);
    json_node_set_double(json_node, 3.14);
    yaml_node = yaml_node_from_json_node(json_node);
    g_assert_cmpfloat_with_epsilon(yaml_node_get_double(yaml_node), 3.14, 0.01);
    yaml_node_unref(yaml_node);
    json_node_unref(json_node);

    /* Boolean */
    json_node = json_node_new(JSON_NODE_VALUE);
    json_node_set_boolean(json_node, TRUE);
    yaml_node = yaml_node_from_json_node(json_node);
    g_assert_true(yaml_node_get_boolean(yaml_node));
    yaml_node_unref(yaml_node);
    json_node_unref(json_node);
}

/* Test converting JsonNode to YamlNode - null */
static void
test_json_to_yaml_null(void)
{
    JsonNode *json_node;
    YamlNode *yaml_node;

    json_node = json_node_new(JSON_NODE_NULL);
    yaml_node = yaml_node_from_json_node(json_node);
    g_assert_cmpint(yaml_node_get_node_type(yaml_node), ==, YAML_NODE_NULL);

    yaml_node_unref(yaml_node);
    json_node_unref(json_node);
}

/* Test converting JsonNode to YamlNode - object */
static void
test_json_to_yaml_object(void)
{
    JsonNode *json_node;
    JsonObject *json_obj;
    YamlNode *yaml_node;
    YamlMapping *mapping;

    json_obj = json_object_new();
    json_object_set_string_member(json_obj, "name", "Bob");
    json_object_set_int_member(json_obj, "age", 25);

    json_node = json_node_new(JSON_NODE_OBJECT);
    json_node_set_object(json_node, json_obj);

    yaml_node = yaml_node_from_json_node(json_node);
    g_assert_cmpint(yaml_node_get_node_type(yaml_node), ==, YAML_NODE_MAPPING);

    mapping = yaml_node_get_mapping(yaml_node);
    g_assert_cmpstr(yaml_mapping_get_string_member(mapping, "name"), ==, "Bob");
    g_assert_cmpint(yaml_mapping_get_int_member(mapping, "age"), ==, 25);

    yaml_node_unref(yaml_node);
    json_node_unref(json_node);
}

/* Test converting JsonNode to YamlNode - array */
static void
test_json_to_yaml_array(void)
{
    JsonNode *json_node;
    JsonArray *json_array;
    YamlNode *yaml_node;
    YamlSequence *sequence;
    YamlNode *element;

    json_array = json_array_new();
    json_array_add_string_element(json_array, "a");
    json_array_add_string_element(json_array, "b");
    json_array_add_string_element(json_array, "c");

    json_node = json_node_new(JSON_NODE_ARRAY);
    json_node_set_array(json_node, json_array);

    yaml_node = yaml_node_from_json_node(json_node);
    g_assert_cmpint(yaml_node_get_node_type(yaml_node), ==, YAML_NODE_SEQUENCE);

    sequence = yaml_node_get_sequence(yaml_node);
    g_assert_cmpuint(yaml_sequence_get_length(sequence), ==, 3);

    element = yaml_sequence_get_element(sequence, 0);
    g_assert_cmpstr(yaml_node_get_scalar(element), ==, "a");

    yaml_node_unref(yaml_node);
    json_node_unref(json_node);
}

/* Test nested structure conversion */
static void
test_nested_conversion(void)
{
    YamlParser *parser;
    YamlNode *yaml_root;
    JsonNode *json_node;
    YamlNode *yaml_converted;
    YamlMapping *mapping;
    GError *error = NULL;
    const gchar *yaml =
        "person:\n"
        "  name: Charlie\n"
        "  hobbies:\n"
        "    - reading\n"
        "    - coding\n";

    parser = yaml_parser_new();
    g_assert_true(yaml_parser_load_from_data(parser, yaml, -1, &error));

    yaml_root = yaml_parser_dup_root(parser);

    /* Convert to JSON and back */
    json_node = yaml_node_to_json_node(yaml_root);
    g_assert_nonnull(json_node);

    yaml_converted = yaml_node_from_json_node(json_node);
    g_assert_nonnull(yaml_converted);

    /* Verify structure is preserved */
    mapping = yaml_node_get_mapping(yaml_converted);
    g_assert_true(yaml_mapping_has_member(mapping, "person"));

    yaml_node_unref(yaml_root);
    yaml_node_unref(yaml_converted);
    json_node_unref(json_node);
    g_object_unref(parser);
}

/* Test document-level conversion */
static void
test_document_json_conversion(void)
{
    YamlParser *parser;
    YamlDocument *doc;
    JsonNode *json_node;
    YamlDocument *doc_from_json;
    YamlNode *root;
    YamlMapping *mapping;
    GError *error = NULL;
    const gchar *yaml = "key: value\n";

    parser = yaml_parser_new();
    g_assert_true(yaml_parser_load_from_data(parser, yaml, -1, &error));

    doc = yaml_parser_dup_document(parser, 0);

    /* Convert document to JSON */
    json_node = yaml_document_to_json_node(doc);
    g_assert_nonnull(json_node);

    /* Convert JSON back to document */
    doc_from_json = yaml_document_from_json_node(json_node);
    g_assert_nonnull(doc_from_json);

    root = yaml_document_get_root(doc_from_json);
    g_assert_cmpint(yaml_node_get_node_type(root), ==, YAML_NODE_MAPPING);

    mapping = yaml_node_get_mapping(root);
    g_assert_cmpstr(yaml_mapping_get_string_member(mapping, "key"), ==, "value");

    json_node_unref(json_node);
    g_object_unref(doc);
    g_object_unref(doc_from_json);
    g_object_unref(parser);
}

int
main(
    int   argc,
    char *argv[]
)
{
    g_test_init(&argc, &argv, NULL);

    /* YAML to JSON tests */
    g_test_add_func("/json/yaml_to_json/scalar", test_yaml_to_json_scalar);
    g_test_add_func("/json/yaml_to_json/null", test_yaml_to_json_null);
    g_test_add_func("/json/yaml_to_json/mapping", test_yaml_to_json_mapping);
    g_test_add_func("/json/yaml_to_json/sequence", test_yaml_to_json_sequence);

    /* JSON to YAML tests */
    g_test_add_func("/json/json_to_yaml/scalar", test_json_to_yaml_scalar);
    g_test_add_func("/json/json_to_yaml/null", test_json_to_yaml_null);
    g_test_add_func("/json/json_to_yaml/object", test_json_to_yaml_object);
    g_test_add_func("/json/json_to_yaml/array", test_json_to_yaml_array);

    /* Integration tests */
    g_test_add_func("/json/nested_conversion", test_nested_conversion);
    g_test_add_func("/json/document_conversion", test_document_json_conversion);

    return g_test_run();
}
