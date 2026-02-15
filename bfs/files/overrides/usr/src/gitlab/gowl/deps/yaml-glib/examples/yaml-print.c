/*
 * yaml-print.c - Load a YAML file and print its structure
 *
 * Copyright 2025 Zach Podbielniak
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Usage: yaml-print <file.yaml>
 *
 * This example demonstrates parsing a YAML file and recursively
 * printing all nodes with proper indentation.
 */

#include "yaml-glib.h"

static void print_node(YamlNode *node, gint indent);

/*
 * print_indent:
 * @indent: Number of indentation levels
 *
 * Prints spaces for indentation (2 spaces per level).
 */
static void
print_indent(gint indent)
{
	gint i;

	for (i = 0; i < indent; i++)
	{
		g_print("  ");
	}
}

/*
 * print_mapping:
 * @mapping: The YamlMapping to print
 * @indent: Current indentation level
 *
 * Prints all key-value pairs in a mapping.
 */
static void
print_mapping(YamlMapping *mapping, gint indent)
{
	GList *members;
	GList *iter;

	members = yaml_mapping_get_members(mapping);

	for (iter = members; iter != NULL; iter = iter->next)
	{
		const gchar *key;
		YamlNode *value;

		key = (const gchar *)iter->data;
		value = yaml_mapping_get_member(mapping, key);

		print_indent(indent);
		g_print("%s:", key);

		if (yaml_node_get_node_type(value) == YAML_NODE_SCALAR)
		{
			g_print(" %s\n", yaml_node_get_string(value));
		}
		else
		{
			g_print("\n");
			print_node(value, indent + 1);
		}
	}

	g_list_free(members);
}

/*
 * print_sequence:
 * @sequence: The YamlSequence to print
 * @indent: Current indentation level
 *
 * Prints all elements in a sequence.
 */
static void
print_sequence(YamlSequence *sequence, gint indent)
{
	guint length;
	guint i;

	length = yaml_sequence_get_length(sequence);

	for (i = 0; i < length; i++)
	{
		YamlNode *element;

		element = yaml_sequence_get_element(sequence, i);

		print_indent(indent);
		g_print("-");

		if (yaml_node_get_node_type(element) == YAML_NODE_SCALAR)
		{
			g_print(" %s\n", yaml_node_get_string(element));
		}
		else
		{
			g_print("\n");
			print_node(element, indent + 1);
		}
	}
}

/*
 * print_node:
 * @node: The YamlNode to print
 * @indent: Current indentation level
 *
 * Recursively prints a YAML node and its children.
 */
static void
print_node(YamlNode *node, gint indent)
{
	YamlNodeType node_type;

	if (node == NULL)
	{
		print_indent(indent);
		g_print("(null)\n");
		return;
	}

	node_type = yaml_node_get_node_type(node);

	switch (node_type)
	{
	case YAML_NODE_MAPPING:
		print_mapping(yaml_node_get_mapping(node), indent);
		break;

	case YAML_NODE_SEQUENCE:
		print_sequence(yaml_node_get_sequence(node), indent);
		break;

	case YAML_NODE_SCALAR:
		print_indent(indent);
		g_print("%s\n", yaml_node_get_string(node));
		break;

	case YAML_NODE_NULL:
		print_indent(indent);
		g_print("~\n");
		break;

	default:
		print_indent(indent);
		g_print("(unknown node type)\n");
		break;
	}
}

int
main(int argc, char *argv[])
{
	g_autoptr(YamlParser) parser = NULL;
	g_autoptr(GError) error = NULL;
	g_autoptr(GOptionContext) context = NULL;
	YamlNode *root;
	const gchar *filename;
	gboolean show_version = FALSE;

	GOptionEntry entries[] = {
		{ "version", 'v', 0, G_OPTION_ARG_NONE, &show_version,
		  "Show version information", NULL },
		{ NULL }
	};

	context = g_option_context_new("<file.yaml> - print YAML structure");
	g_option_context_add_main_entries(context, entries, NULL);
	g_option_context_set_description(context,
		"Examples:\n"
		"  yaml-print config.yaml\n"
		"  yaml-print data.yml\n");

	if (!g_option_context_parse(context, &argc, &argv, &error))
	{
		g_printerr("Error: %s\n", error->message);
		return 1;
	}

	if (show_version)
	{
		g_print("yaml-print 1.0.0\n");
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

	print_node(root, 0);

	return 0;
}
