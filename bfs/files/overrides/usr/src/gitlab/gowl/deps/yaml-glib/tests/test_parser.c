/* test_parser.c
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Unit tests for YamlParser.
 */

#include <glib.h>
#include "yaml-glib.h"

/* Test parsing a simple mapping */
static void
test_parser_simple_mapping(void)
{
    YamlParser *parser;
    YamlNode *root;
    YamlMapping *mapping;
    GError *error = NULL;
    const gchar *yaml = "name: John\nage: 30\nactive: true\n";

    parser = yaml_parser_new();
    g_assert_nonnull(parser);

    g_assert_true(yaml_parser_load_from_data(parser, yaml, -1, &error));
    g_assert_no_error(error);

    g_assert_cmpuint(yaml_parser_get_n_documents(parser), ==, 1);

    root = yaml_parser_get_root(parser);
    g_assert_nonnull(root);
    g_assert_cmpint(yaml_node_get_node_type(root), ==, YAML_NODE_MAPPING);

    mapping = yaml_node_get_mapping(root);
    g_assert_cmpstr(yaml_mapping_get_string_member(mapping, "name"), ==, "John");
    g_assert_cmpint(yaml_mapping_get_int_member(mapping, "age"), ==, 30);
    g_assert_true(yaml_mapping_get_boolean_member(mapping, "active"));

    g_object_unref(parser);
}

/* Test parsing a sequence */
static void
test_parser_sequence(void)
{
    YamlParser *parser;
    YamlNode *root;
    YamlSequence *sequence;
    YamlNode *element;
    GError *error = NULL;
    const gchar *yaml = "- one\n- two\n- three\n";

    parser = yaml_parser_new();
    g_assert_true(yaml_parser_load_from_data(parser, yaml, -1, &error));
    g_assert_no_error(error);

    root = yaml_parser_get_root(parser);
    g_assert_cmpint(yaml_node_get_node_type(root), ==, YAML_NODE_SEQUENCE);

    sequence = yaml_node_get_sequence(root);
    g_assert_cmpuint(yaml_sequence_get_length(sequence), ==, 3);

    element = yaml_sequence_get_element(sequence, 0);
    g_assert_cmpstr(yaml_node_get_scalar(element), ==, "one");

    element = yaml_sequence_get_element(sequence, 1);
    g_assert_cmpstr(yaml_node_get_scalar(element), ==, "two");

    element = yaml_sequence_get_element(sequence, 2);
    g_assert_cmpstr(yaml_node_get_scalar(element), ==, "three");

    g_object_unref(parser);
}

/* Test parsing nested structures */
static void
test_parser_nested(void)
{
    YamlParser *parser;
    YamlNode *root;
    YamlMapping *mapping;
    YamlNode *nested_node;
    YamlMapping *nested_mapping;
    GError *error = NULL;
    const gchar *yaml =
        "person:\n"
        "  name: Alice\n"
        "  address:\n"
        "    city: Wonderland\n"
        "    zip: 12345\n";

    parser = yaml_parser_new();
    g_assert_true(yaml_parser_load_from_data(parser, yaml, -1, &error));
    g_assert_no_error(error);

    root = yaml_parser_get_root(parser);
    mapping = yaml_node_get_mapping(root);

    nested_node = yaml_mapping_get_member(mapping, "person");
    g_assert_nonnull(nested_node);
    g_assert_cmpint(yaml_node_get_node_type(nested_node), ==, YAML_NODE_MAPPING);

    nested_mapping = yaml_node_get_mapping(nested_node);
    g_assert_cmpstr(yaml_mapping_get_string_member(nested_mapping, "name"), ==, "Alice");

    nested_node = yaml_mapping_get_member(nested_mapping, "address");
    nested_mapping = yaml_node_get_mapping(nested_node);
    g_assert_cmpstr(yaml_mapping_get_string_member(nested_mapping, "city"), ==, "Wonderland");
    g_assert_cmpint(yaml_mapping_get_int_member(nested_mapping, "zip"), ==, 12345);

    g_object_unref(parser);
}

/* Test parsing multiple documents */
static void
test_parser_multi_document(void)
{
    YamlParser *parser;
    YamlDocument *doc;
    YamlNode *root;
    GError *error = NULL;
    const gchar *yaml =
        "---\n"
        "first: document\n"
        "---\n"
        "second: document\n"
        "...\n";

    parser = yaml_parser_new();
    g_assert_true(yaml_parser_load_from_data(parser, yaml, -1, &error));
    g_assert_no_error(error);

    g_assert_cmpuint(yaml_parser_get_n_documents(parser), ==, 2);

    doc = yaml_parser_get_document(parser, 0);
    g_assert_nonnull(doc);
    root = yaml_document_get_root(doc);
    g_assert_cmpstr(
        yaml_mapping_get_string_member(yaml_node_get_mapping(root), "first"),
        ==, "document"
    );

    doc = yaml_parser_get_document(parser, 1);
    g_assert_nonnull(doc);
    root = yaml_document_get_root(doc);
    g_assert_cmpstr(
        yaml_mapping_get_string_member(yaml_node_get_mapping(root), "second"),
        ==, "document"
    );

    g_object_unref(parser);
}

/* Test immutable parser mode */
static void
test_parser_immutable(void)
{
    YamlParser *parser;
    YamlDocument *doc;
    GError *error = NULL;
    const gchar *yaml = "key: value\n";

    parser = yaml_parser_new_immutable();
    g_assert_true(yaml_parser_get_immutable(parser));

    g_assert_true(yaml_parser_load_from_data(parser, yaml, -1, &error));
    g_assert_no_error(error);

    doc = yaml_parser_get_document(parser, 0);
    g_assert_true(yaml_document_is_immutable(doc));

    g_object_unref(parser);
}

/* Test parser reset */
static void
test_parser_reset(void)
{
    YamlParser *parser;
    GError *error = NULL;
    const gchar *yaml1 = "first: true\n";
    const gchar *yaml2 = "second: true\n";

    parser = yaml_parser_new();

    g_assert_true(yaml_parser_load_from_data(parser, yaml1, -1, &error));
    g_assert_cmpuint(yaml_parser_get_n_documents(parser), ==, 1);

    yaml_parser_reset(parser);
    g_assert_cmpuint(yaml_parser_get_n_documents(parser), ==, 0);

    g_assert_true(yaml_parser_load_from_data(parser, yaml2, -1, &error));
    g_assert_cmpuint(yaml_parser_get_n_documents(parser), ==, 1);

    g_object_unref(parser);
}

/* Test parsing scalar values */
static void
test_parser_scalar_types(void)
{
    YamlParser *parser;
    YamlNode *root;
    YamlMapping *mapping;
    GError *error = NULL;
    const gchar *yaml =
        "string: hello\n"
        "integer: 42\n"
        "float: 3.14\n"
        "bool_true: true\n"
        "bool_false: false\n"
        "null_value: null\n"
        "empty: ~\n";

    parser = yaml_parser_new();
    g_assert_true(yaml_parser_load_from_data(parser, yaml, -1, &error));
    g_assert_no_error(error);

    root = yaml_parser_get_root(parser);
    mapping = yaml_node_get_mapping(root);

    g_assert_cmpstr(yaml_mapping_get_string_member(mapping, "string"), ==, "hello");
    g_assert_cmpint(yaml_mapping_get_int_member(mapping, "integer"), ==, 42);
    g_assert_cmpfloat_with_epsilon(
        yaml_mapping_get_double_member(mapping, "float"), 3.14, 0.01
    );
    g_assert_true(yaml_mapping_get_boolean_member(mapping, "bool_true"));
    g_assert_false(yaml_mapping_get_boolean_member(mapping, "bool_false"));

    g_object_unref(parser);
}

/* Test error handling */
static void
test_parser_error(void)
{
    YamlParser *parser;
    GError *error = NULL;
    const gchar *invalid_yaml = "key: [unclosed bracket";

    parser = yaml_parser_new();
    g_assert_false(yaml_parser_load_from_data(parser, invalid_yaml, -1, &error));
    g_assert_error(error, YAML_GLIB_PARSER_ERROR, YAML_GLIB_PARSER_ERROR_PARSE);
    g_error_free(error);

    g_object_unref(parser);
}

int
main(
    int   argc,
    char *argv[]
)
{
    g_test_init(&argc, &argv, NULL);

    g_test_add_func("/parser/simple_mapping", test_parser_simple_mapping);
    g_test_add_func("/parser/sequence", test_parser_sequence);
    g_test_add_func("/parser/nested", test_parser_nested);
    g_test_add_func("/parser/multi_document", test_parser_multi_document);
    g_test_add_func("/parser/immutable", test_parser_immutable);
    g_test_add_func("/parser/reset", test_parser_reset);
    g_test_add_func("/parser/scalar_types", test_parser_scalar_types);
    g_test_add_func("/parser/error", test_parser_error);

    return g_test_run();
}
