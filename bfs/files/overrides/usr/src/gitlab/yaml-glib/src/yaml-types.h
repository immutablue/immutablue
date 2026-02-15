/* yaml-types.h
 *
 * Copyright 2025 Zach Podbielniak
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Core type definitions for yaml-glib.
 */

#ifndef __YAML_TYPES_H__
#define __YAML_TYPES_H__

#include <glib.h>
#include <glib-object.h>

G_BEGIN_DECLS

/*
 * Forward declarations for all yaml-glib types.
 * These allow headers to reference each other without circular includes.
 */

typedef struct _YamlNode YamlNode;
typedef struct _YamlMapping YamlMapping;
typedef struct _YamlSequence YamlSequence;
typedef struct _YamlDocument YamlDocument;
typedef struct _YamlParser YamlParser;
typedef struct _YamlBuilder YamlBuilder;
typedef struct _YamlGenerator YamlGenerator;
typedef struct _YamlSchema YamlSchema;

/**
 * YamlNodeType:
 * @YAML_NODE_MAPPING: The node contains a YAML mapping (key-value pairs)
 * @YAML_NODE_SEQUENCE: The node contains a YAML sequence (ordered array)
 * @YAML_NODE_SCALAR: The node contains a scalar value (string, int, etc.)
 * @YAML_NODE_NULL: The node contains a null value
 *
 * Indicates the type of content stored in a #YamlNode.
 *
 * Since: 1.0
 */
typedef enum {
    YAML_NODE_MAPPING,
    YAML_NODE_SEQUENCE,
    YAML_NODE_SCALAR,
    YAML_NODE_NULL
} YamlNodeType;

/**
 * YamlScalarStyle:
 * @YAML_SCALAR_STYLE_ANY: Let the emitter choose the best style
 * @YAML_SCALAR_STYLE_PLAIN: Plain unquoted scalar
 * @YAML_SCALAR_STYLE_SINGLE_QUOTED: Single-quoted scalar ('value')
 * @YAML_SCALAR_STYLE_DOUBLE_QUOTED: Double-quoted scalar ("value")
 * @YAML_SCALAR_STYLE_LITERAL: Literal block scalar (|)
 * @YAML_SCALAR_STYLE_FOLDED: Folded block scalar (>)
 *
 * Style hint for scalar serialization in YAML output.
 * The generator may override this hint if the content requires
 * a different style (e.g., special characters requiring quoting).
 *
 * Since: 1.0
 */
typedef enum {
    YAML_SCALAR_STYLE_ANY,
    YAML_SCALAR_STYLE_PLAIN,
    YAML_SCALAR_STYLE_SINGLE_QUOTED,
    YAML_SCALAR_STYLE_DOUBLE_QUOTED,
    YAML_SCALAR_STYLE_LITERAL,
    YAML_SCALAR_STYLE_FOLDED
} YamlScalarStyle;

/**
 * YamlMappingStyle:
 * @YAML_MAPPING_STYLE_ANY: Let the emitter choose
 * @YAML_MAPPING_STYLE_BLOCK: Block style mapping (one key per line)
 * @YAML_MAPPING_STYLE_FLOW: Flow style mapping ({key: value})
 *
 * Style hint for mapping serialization in YAML output.
 *
 * Since: 1.0
 */
typedef enum {
    YAML_MAPPING_STYLE_ANY,
    YAML_MAPPING_STYLE_BLOCK,
    YAML_MAPPING_STYLE_FLOW
} YamlMappingStyle;

/**
 * YamlSequenceStyle:
 * @YAML_SEQUENCE_STYLE_ANY: Let the emitter choose
 * @YAML_SEQUENCE_STYLE_BLOCK: Block style sequence (one item per line)
 * @YAML_SEQUENCE_STYLE_FLOW: Flow style sequence ([item1, item2])
 *
 * Style hint for sequence serialization in YAML output.
 *
 * Since: 1.0
 */
typedef enum {
    YAML_SEQUENCE_STYLE_ANY,
    YAML_SEQUENCE_STYLE_BLOCK,
    YAML_SEQUENCE_STYLE_FLOW
} YamlSequenceStyle;

/**
 * YamlGlibParserError:
 * @YAML_GLIB_PARSER_ERROR_INVALID_DATA: The input data is not valid YAML
 * @YAML_GLIB_PARSER_ERROR_PARSE: A parsing error occurred
 * @YAML_GLIB_PARSER_ERROR_SCANNER: A scanner error occurred
 * @YAML_GLIB_PARSER_ERROR_EMPTY_DOCUMENT: The document is empty
 * @YAML_GLIB_PARSER_ERROR_UNKNOWN: An unknown error occurred
 *
 * Error codes for the %YAML_GLIB_PARSER_ERROR domain.
 *
 * Since: 1.0
 */
typedef enum {
    YAML_GLIB_PARSER_ERROR_INVALID_DATA,
    YAML_GLIB_PARSER_ERROR_PARSE,
    YAML_GLIB_PARSER_ERROR_SCANNER,
    YAML_GLIB_PARSER_ERROR_EMPTY_DOCUMENT,
    YAML_GLIB_PARSER_ERROR_UNKNOWN
} YamlGlibParserError;

/**
 * YamlGeneratorError:
 * @YAML_GENERATOR_ERROR_EMIT: An emitter error occurred
 * @YAML_GENERATOR_ERROR_INVALID_NODE: The node structure is invalid
 * @YAML_GENERATOR_ERROR_IO: An I/O error occurred
 *
 * Error codes for the %YAML_GENERATOR_ERROR domain.
 *
 * Since: 1.0
 */
typedef enum {
    YAML_GENERATOR_ERROR_EMIT,
    YAML_GENERATOR_ERROR_INVALID_NODE,
    YAML_GENERATOR_ERROR_IO
} YamlGeneratorError;

/**
 * YamlSchemaError:
 * @YAML_SCHEMA_ERROR_TYPE_MISMATCH: Node type doesn't match schema
 * @YAML_SCHEMA_ERROR_MISSING_REQUIRED: Required property is missing
 * @YAML_SCHEMA_ERROR_EXTRA_FIELD: Unexpected property found
 * @YAML_SCHEMA_ERROR_PATTERN_MISMATCH: String doesn't match pattern
 * @YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION: Min/max constraint violated
 * @YAML_SCHEMA_ERROR_ENUM_VIOLATION: Value not in allowed enum values
 * @YAML_SCHEMA_ERROR_INVALID_SCHEMA: The schema definition is invalid
 *
 * Error codes for the %YAML_SCHEMA_ERROR domain.
 *
 * Since: 1.0
 */
typedef enum {
    YAML_SCHEMA_ERROR_TYPE_MISMATCH,
    YAML_SCHEMA_ERROR_MISSING_REQUIRED,
    YAML_SCHEMA_ERROR_EXTRA_FIELD,
    YAML_SCHEMA_ERROR_PATTERN_MISMATCH,
    YAML_SCHEMA_ERROR_CONSTRAINT_VIOLATION,
    YAML_SCHEMA_ERROR_ENUM_VIOLATION,
    YAML_SCHEMA_ERROR_INVALID_SCHEMA
} YamlSchemaError;

/**
 * YAML_GLIB_PARSER_ERROR:
 *
 * Error domain for #YamlParser errors.
 *
 * Since: 1.0
 */
#define YAML_GLIB_PARSER_ERROR (yaml_glib_parser_error_quark())
GQuark yaml_glib_parser_error_quark(void);

/**
 * YAML_GENERATOR_ERROR:
 *
 * Error domain for #YamlGenerator errors.
 *
 * Since: 1.0
 */
#define YAML_GENERATOR_ERROR (yaml_generator_error_quark())
GQuark yaml_generator_error_quark(void);

/**
 * YAML_SCHEMA_ERROR:
 *
 * Error domain for #YamlSchema errors.
 *
 * Since: 1.0
 */
#define YAML_SCHEMA_ERROR (yaml_schema_error_quark())
GQuark yaml_schema_error_quark(void);

G_END_DECLS

#endif /* __YAML_TYPES_H__ */
