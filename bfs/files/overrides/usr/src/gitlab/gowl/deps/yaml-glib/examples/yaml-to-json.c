/*
 * yaml-to-json.c - Convert a YAML file to pretty-printed JSON
 *
 * Copyright 2025 Zach Podbielniak
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Usage: yaml-to-json <file.yaml>
 *
 * This example demonstrates parsing a YAML file and converting
 * it to JSON using json-glib with pretty-printing enabled.
 */

#include "yaml-glib.h"
#include <json-glib/json-glib.h>

int
main(int argc, char *argv[])
{
	g_autoptr(YamlParser) parser = NULL;
	g_autoptr(JsonGenerator) json_gen = NULL;
	g_autoptr(JsonNode) json_node = NULL;
	g_autoptr(GError) error = NULL;
	g_autoptr(GOptionContext) context = NULL;
	g_autofree gchar *json_data = NULL;
	YamlNode *root;
	const gchar *filename;
	gboolean show_version = FALSE;
	gboolean compact = FALSE;
	gint indent = 4;

	GOptionEntry entries[] = {
		{ "compact", 'c', 0, G_OPTION_ARG_NONE, &compact,
		  "Output compact JSON (no pretty-printing)", NULL },
		{ "indent", 'i', 0, G_OPTION_ARG_INT, &indent,
		  "Indentation spaces (default: 4)", "N" },
		{ "version", 'v', 0, G_OPTION_ARG_NONE, &show_version,
		  "Show version information", NULL },
		{ NULL }
	};

	context = g_option_context_new("<file.yaml> - convert YAML to JSON");
	g_option_context_add_main_entries(context, entries, NULL);
	g_option_context_set_description(context,
		"Examples:\n"
		"  yaml-to-json config.yaml\n"
		"  yaml-to-json --compact data.yml\n"
		"  yaml-to-json -i 2 config.yaml\n");

	if (!g_option_context_parse(context, &argc, &argv, &error))
	{
		g_printerr("Error: %s\n", error->message);
		return 1;
	}

	if (show_version)
	{
		g_print("yaml-to-json 1.0.0\n");
		g_print("License: AGPL-3.0-or-later\n");
		return 0;
	}

	if (argc < 2)
	{
		g_autofree gchar *help = NULL;

		help = g_option_context_get_help(context, TRUE, NULL);
		g_printerr("%s", help);
		return 1;
	}

	filename = argv[1];

	/* Parse YAML file */
	parser = yaml_parser_new();

	if (!yaml_parser_load_from_file(parser, filename, &error))
	{
		g_printerr("Error parsing '%s': %s\n", filename, error->message);
		return 1;
	}

	root = yaml_parser_get_root(parser);

	if (root == NULL)
	{
		g_printerr("Error: Empty document\n");
		return 1;
	}

	/* Convert YAML to JSON */
	json_node = yaml_node_to_json_node(root);

	if (json_node == NULL)
	{
		g_printerr("Error: Failed to convert YAML to JSON\n");
		return 1;
	}

	/* Generate JSON output */
	json_gen = json_generator_new();
	json_generator_set_root(json_gen, json_node);
	json_generator_set_pretty(json_gen, !compact);
	json_generator_set_indent(json_gen, (guint)indent);

	json_data = json_generator_to_data(json_gen, NULL);

	if (json_data == NULL)
	{
		g_printerr("Error: Failed to generate JSON output\n");
		return 1;
	}

	g_print("%s\n", json_data);

	return 0;
}
