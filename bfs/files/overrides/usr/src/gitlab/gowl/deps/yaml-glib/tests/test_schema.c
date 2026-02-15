/* test_schema.c
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Unit tests for YamlSchema validation.
 */

#include <glib.h>
#include "yaml-glib.h"

/* Test basic type validation */
static void
test_schema_type_mapping(void)
{
    YamlSchema *schema;
    YamlParser *parser;
    YamlNode *root;
    GError *error = NULL;

    schema = yaml_schema_new_for_mapping();

    parser = yaml_parser_new();
    yaml_parser_load_from_data(parser, "key: value\n", -1, NULL);
    root = yaml_parser_get_root(parser);

    g_assert_true(yaml_schema_validate(schema, root, &error));
    g_assert_no_error(error);

    g_object_unref(schema);
    g_object_unref(parser);
}

static void
test_schema_type_sequence(void)
{
    YamlSchema *schema;
    YamlParser *parser;
    YamlNode *root;
    GError *error = NULL;

    schema = yaml_schema_new_for_sequence();

    parser = yaml_parser_new();
    yaml_parser_load_from_data(parser, "- one\n- two\n", -1, NULL);
    root = yaml_parser_get_root(parser);

    g_assert_true(yaml_schema_validate(schema, root, &error));
    g_assert_no_error(error);

    g_object_unref(schema);
    g_object_unref(parser);
}

static void
test_schema_type_mismatch(void)
{
    YamlSchema *schema;
    YamlParser *parser;
    YamlNode *root;
    GError *error = NULL;

    /* Expect sequence but provide mapping */
    schema = yaml_schema_new_for_sequence();

    parser = yaml_parser_new();
    yaml_parser_load_from_data(parser, "key: value\n", -1, NULL);
    root = yaml_parser_get_root(parser);

    g_assert_false(yaml_schema_validate(schema, root, &error));
    g_assert_error(error, YAML_SCHEMA_ERROR, YAML_SCHEMA_ERROR_TYPE_MISMATCH);
    g_clear_error(&error);

    g_object_unref(schema);
    g_object_unref(parser);
}

/* Test required properties */
static void
test_schema_required_property(void)
{
    YamlSchema *schema;
    YamlParser *parser;
    YamlNode *root;
    GError *error = NULL;

    schema = yaml_schema_new_for_mapping();
    yaml_schema_add_property(schema, "name", YAML_NODE_SCALAR, TRUE);

    /* Valid: has required property */
    parser = yaml_parser_new();
    yaml_parser_load_from_data(parser, "name: John\n", -1, NULL);
    root = yaml_parser_get_root(parser);

    g_assert_true(yaml_schema_validate(schema, root, &error));
    g_assert_no_error(error);
    g_object_unref(parser);

    /* Invalid: missing required property */
    parser = yaml_parser_new();
    yaml_parser_load_from_data(parser, "age: 30\n", -1, NULL);
    root = yaml_parser_get_root(parser);

    g_assert_false(yaml_schema_validate(schema, root, &error));
    g_assert_error(error, YAML_SCHEMA_ERROR, YAML_SCHEMA_ERROR_MISSING_REQUIRED);
    g_clear_error(&error);

    g_object_unref(schema);
    g_object_unref(parser);
}

/* Test optional properties */
static void
test_schema_optional_property(void)
{
    YamlSchema *schema;
    YamlParser *parser;
    YamlNode *root;
    GError *error = NULL;

    schema = yaml_schema_new_for_mapping();
    yaml_schema_add_property(schema, "name", YAML_NODE_SCALAR, TRUE);
    yaml_schema_add_property(schema, "age", YAML_NODE_SCALAR, FALSE);

    /* Valid: has required, missing optional */
    parser = yaml_parser_new();
    yaml_parser_load_from_data(parser, "name: Jane\n", -1, NULL);
    root = yaml_parser_get_root(parser);

    g_assert_true(yaml_schema_validate(schema, root, &error));
    g_assert_no_error(error);

    g_object_unref(schema);
    g_object_unref(parser);
}

/* Test additional properties */
static void
test_schema_additional_properties(void)
{
    YamlSchema *schema;
    YamlParser *parser;
    YamlNode *root;
    GError *error = NULL;

    schema = yaml_schema_new_for_mapping();
    yaml_schema_add_property(schema, "name", YAML_NODE_SCALAR, TRUE);
    yaml_schema_set_allow_additional_properties(schema, FALSE);

    /* Valid: only defined property */
    parser = yaml_parser_new();
    yaml_parser_load_from_data(parser, "name: Bob\n", -1, NULL);
    root = yaml_parser_get_root(parser);

    g_assert_true(yaml_schema_validate(schema, root, &error));
    g_assert_no_error(error);
    g_object_unref(parser);

    /* Invalid: has extra property */
    parser = yaml_parser_new();
    yaml_parser_load_from_data(parser, "name: Bob\nextra: value\n", -1, NULL);
    root = yaml_parser_get_root(parser);

    g_assert_false(yaml_schema_validate(schema, root, &error));
    g_assert_error(error, YAML_SCHEMA_ERROR, YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION);
    g_clear_error(&error);

    g_object_unref(schema);
    g_object_unref(parser);
}

/* Test sequence length constraints */
static void
test_schema_sequence_length(void)
{
    YamlSchema *schema;
    YamlParser *parser;
    YamlNode *root;
    GError *error = NULL;

    schema = yaml_schema_new_for_sequence();
    yaml_schema_set_min_length(schema, 2);
    yaml_schema_set_max_length(schema, 4);

    /* Valid: within range */
    parser = yaml_parser_new();
    yaml_parser_load_from_data(parser, "- a\n- b\n- c\n", -1, NULL);
    root = yaml_parser_get_root(parser);

    g_assert_true(yaml_schema_validate(schema, root, &error));
    g_assert_no_error(error);
    g_object_unref(parser);

    /* Invalid: too short */
    parser = yaml_parser_new();
    yaml_parser_load_from_data(parser, "- a\n", -1, NULL);
    root = yaml_parser_get_root(parser);

    g_assert_false(yaml_schema_validate(schema, root, &error));
    g_assert_error(error, YAML_SCHEMA_ERROR, YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION);
    g_clear_error(&error);
    g_object_unref(parser);

    /* Invalid: too long */
    parser = yaml_parser_new();
    yaml_parser_load_from_data(parser, "- a\n- b\n- c\n- d\n- e\n", -1, NULL);
    root = yaml_parser_get_root(parser);

    g_assert_false(yaml_schema_validate(schema, root, &error));
    g_assert_error(error, YAML_SCHEMA_ERROR, YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION);
    g_clear_error(&error);

    g_object_unref(schema);
    g_object_unref(parser);
}

/* Test scalar enum values */
static void
test_schema_enum_values(void)
{
    YamlSchema *schema;
    YamlParser *parser;
    YamlNode *root;
    GError *error = NULL;

    schema = yaml_schema_new_for_scalar();
    yaml_schema_add_enum_value(schema, "red");
    yaml_schema_add_enum_value(schema, "green");
    yaml_schema_add_enum_value(schema, "blue");

    /* Valid: value in enum */
    parser = yaml_parser_new();
    yaml_parser_load_from_data(parser, "green\n", -1, NULL);
    root = yaml_parser_get_root(parser);

    g_assert_true(yaml_schema_validate(schema, root, &error));
    g_assert_no_error(error);
    g_object_unref(parser);

    /* Invalid: value not in enum */
    parser = yaml_parser_new();
    yaml_parser_load_from_data(parser, "yellow\n", -1, NULL);
    root = yaml_parser_get_root(parser);

    g_assert_false(yaml_schema_validate(schema, root, &error));
    g_assert_error(error, YAML_SCHEMA_ERROR, YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION);
    g_clear_error(&error);

    g_object_unref(schema);
    g_object_unref(parser);
}

/* Test scalar pattern matching */
static void
test_schema_pattern(void)
{
    YamlSchema *schema;
    YamlParser *parser;
    YamlNode *root;
    GError *error = NULL;

    schema = yaml_schema_new_for_scalar();
    yaml_schema_set_pattern(schema, "^[a-z]+$");

    /* Valid: matches pattern */
    parser = yaml_parser_new();
    yaml_parser_load_from_data(parser, "hello\n", -1, NULL);
    root = yaml_parser_get_root(parser);

    g_assert_true(yaml_schema_validate(schema, root, &error));
    g_assert_no_error(error);
    g_object_unref(parser);

    /* Invalid: doesn't match pattern */
    parser = yaml_parser_new();
    yaml_parser_load_from_data(parser, "Hello123\n", -1, NULL);
    root = yaml_parser_get_root(parser);

    g_assert_false(yaml_schema_validate(schema, root, &error));
    g_assert_error(error, YAML_SCHEMA_ERROR, YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION);
    g_clear_error(&error);

    g_object_unref(schema);
    g_object_unref(parser);
}

/* Test numeric constraints */
static void
test_schema_numeric_range(void)
{
    YamlSchema *schema;
    YamlParser *parser;
    YamlNode *root;
    GError *error = NULL;

    schema = yaml_schema_new_for_scalar();
    yaml_schema_set_min_value(schema, 0);
    yaml_schema_set_max_value(schema, 100);

    /* Valid: within range */
    parser = yaml_parser_new();
    yaml_parser_load_from_data(parser, "50\n", -1, NULL);
    root = yaml_parser_get_root(parser);

    g_assert_true(yaml_schema_validate(schema, root, &error));
    g_assert_no_error(error);
    g_object_unref(parser);

    /* Invalid: below minimum */
    parser = yaml_parser_new();
    yaml_parser_load_from_data(parser, "-10\n", -1, NULL);
    root = yaml_parser_get_root(parser);

    g_assert_false(yaml_schema_validate(schema, root, &error));
    g_assert_error(error, YAML_SCHEMA_ERROR, YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION);
    g_clear_error(&error);
    g_object_unref(parser);

    /* Invalid: above maximum */
    parser = yaml_parser_new();
    yaml_parser_load_from_data(parser, "150\n", -1, NULL);
    root = yaml_parser_get_root(parser);

    g_assert_false(yaml_schema_validate(schema, root, &error));
    g_assert_error(error, YAML_SCHEMA_ERROR, YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION);
    g_clear_error(&error);

    g_object_unref(schema);
    g_object_unref(parser);
}

/* Test nested schema validation */
static void
test_schema_nested(void)
{
    YamlSchema *root_schema;
    YamlSchema *address_schema;
    YamlParser *parser;
    YamlNode *root;
    GError *error = NULL;

    /* Create nested schema */
    address_schema = yaml_schema_new_for_mapping();
    yaml_schema_add_property(address_schema, "city", YAML_NODE_SCALAR, TRUE);
    yaml_schema_add_property(address_schema, "zip", YAML_NODE_SCALAR, TRUE);

    root_schema = yaml_schema_new_for_mapping();
    yaml_schema_add_property(root_schema, "name", YAML_NODE_SCALAR, TRUE);
    yaml_schema_add_property_with_schema(root_schema, "address", address_schema, TRUE);

    /* Valid: complete nested structure */
    parser = yaml_parser_new();
    yaml_parser_load_from_data(parser,
        "name: Test\n"
        "address:\n"
        "  city: Springfield\n"
        "  zip: '12345'\n", -1, NULL);
    root = yaml_parser_get_root(parser);

    g_assert_true(yaml_schema_validate(root_schema, root, &error));
    g_assert_no_error(error);
    g_object_unref(parser);

    /* Invalid: missing nested required property */
    parser = yaml_parser_new();
    yaml_parser_load_from_data(parser,
        "name: Test\n"
        "address:\n"
        "  city: Springfield\n", -1, NULL);
    root = yaml_parser_get_root(parser);

    g_assert_false(yaml_schema_validate(root_schema, root, &error));
    g_assert_error(error, YAML_SCHEMA_ERROR, YAML_SCHEMA_ERROR_MISSING_REQUIRED);
    g_clear_error(&error);

    g_object_unref(root_schema);
    g_object_unref(address_schema);
    g_object_unref(parser);
}

/* Test null values are accepted */
static void
test_schema_null_allowed(void)
{
    YamlSchema *schema;
    YamlParser *parser;
    YamlNode *root;
    GError *error = NULL;

    /* Sequence schema but we pass null */
    schema = yaml_schema_new_for_sequence();

    parser = yaml_parser_new();
    yaml_parser_load_from_data(parser, "~\n", -1, NULL);
    root = yaml_parser_get_root(parser);

    /* Null should be accepted for any type */
    g_assert_true(yaml_schema_validate(schema, root, &error));
    g_assert_no_error(error);

    g_object_unref(schema);
    g_object_unref(parser);
}

int
main(
    int   argc,
    char *argv[]
)
{
    g_test_init(&argc, &argv, NULL);

    /* Type validation */
    g_test_add_func("/schema/type/mapping", test_schema_type_mapping);
    g_test_add_func("/schema/type/sequence", test_schema_type_sequence);
    g_test_add_func("/schema/type/mismatch", test_schema_type_mismatch);

    /* Property validation */
    g_test_add_func("/schema/property/required", test_schema_required_property);
    g_test_add_func("/schema/property/optional", test_schema_optional_property);
    g_test_add_func("/schema/property/additional", test_schema_additional_properties);

    /* Sequence constraints */
    g_test_add_func("/schema/sequence/length", test_schema_sequence_length);

    /* Scalar constraints */
    g_test_add_func("/schema/scalar/enum", test_schema_enum_values);
    g_test_add_func("/schema/scalar/pattern", test_schema_pattern);
    g_test_add_func("/schema/scalar/numeric_range", test_schema_numeric_range);

    /* Nested validation */
    g_test_add_func("/schema/nested", test_schema_nested);

    /* Null handling */
    g_test_add_func("/schema/null_allowed", test_schema_null_allowed);

    return g_test_run();
}
