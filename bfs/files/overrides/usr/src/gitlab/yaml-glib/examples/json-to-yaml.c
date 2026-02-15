/*
 * json-to-yaml.c - Convert a JSON file to YAML
 *
 * Copyright 2025 Zach Podbielniak
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Usage: json-to-yaml <file.json>
 *
 * This example demonstrates loading a JSON file with json-glib
 * and converting it to YAML output.
 */

#include "yaml-glib.h"
#include <json-glib/json-glib.h>

int
main(int argc, char *argv[])
{
	g_autoptr(JsonParser) json_parser = NULL;
	g_autoptr(YamlGenerator) yaml_gen = NULL;
	g_autoptr(YamlNode) yaml_node = NULL;
	g_autoptr(GError) error = NULL;
	g_autoptr(GOptionContext) context = NULL;
	g_autofree gchar *yaml_data = NULL;
	JsonNode *json_root;
	const gchar *filename;
	gboolean show_version = FALSE;
	gboolean explicit_start = FALSE;
	gint indent = 2;

	GOptionEntry entries[] = {
		{ "indent", 'i', 0, G_OPTION_ARG_INT, &indent,
		  "Indentation spaces (default: 2)", "N" },
		{ "explicit-start", 's', 0, G_OPTION_ARG_NONE, &explicit_start,
		  "Include document start marker (---)", NULL },
		{ "version", 'v', 0, G_OPTION_ARG_NONE, &show_version,
		  "Show version information", NULL },
		{ NULL }
	};

	context = g_option_context_new("<file.json> - convert JSON to YAML");
	g_option_context_add_main_entries(context, entries, NULL);
	g_option_context_set_description(context,
		"Examples:\n"
		"  json-to-yaml data.json\n"
		"  json-to-yaml --explicit-start config.json\n"
		"  json-to-yaml -i 4 data.json\n");

	if (!g_option_context_parse(context, &argc, &argv, &error))
	{
		g_printerr("Error: %s\n", error->message);
		return 1;
	}

	if (show_version)
	{
		g_print("json-to-yaml 1.0.0\n");
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

	/* Parse JSON file */
	json_parser = json_parser_new();

	if (!json_parser_load_from_file(json_parser, filename, &error))
	{
		g_printerr("Error parsing '%s': %s\n", filename, error->message);
		return 1;
	}

	json_root = json_parser_get_root(json_parser);

	if (json_root == NULL)
	{
		g_printerr("Error: Empty document\n");
		return 1;
	}

	/* Convert JSON to YAML */
	yaml_node = yaml_node_from_json_node(json_root);

	if (yaml_node == NULL)
	{
		g_printerr("Error: Failed to convert JSON to YAML\n");
		return 1;
	}

	/* Generate YAML output */
	yaml_gen = yaml_generator_new();
	yaml_generator_set_root(yaml_gen, yaml_node);
	yaml_generator_set_indent(yaml_gen, (guint)indent);
	yaml_generator_set_explicit_start(yaml_gen, explicit_start);

	yaml_data = yaml_generator_to_data(yaml_gen, NULL, &error);

	if (yaml_data == NULL)
	{
		g_printerr("Error: Failed to generate YAML output: %s\n",
		           error ? error->message : "unknown error");
		return 1;
	}

	g_print("%s", yaml_data);

	return 0;
}
