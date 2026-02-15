# Async I/O Guide

This guide covers asynchronous parsing and generation using yaml-glib with GIO's async patterns.

## Overview

yaml-glib provides async operations for:

- **Parsing** from streams and GFile objects
- **Generating** to streams and GFile objects

Async operations use GLib's `GTask` pattern with `GAsyncReadyCallback` callbacks.

## Async Parsing

### From GFile

```c
#include <yaml-glib/yaml-glib.h>

static void
on_parse_complete(GObject      *source,
                  GAsyncResult *result,
                  gpointer      user_data)
{
    YamlParser *parser = YAML_PARSER(source);
    g_autoptr(GError) error = NULL;

    if (!yaml_parser_load_from_gfile_finish(parser, result, &error))
    {
        g_printerr("Async parse failed: %s\n", error->message);
        return;
    }

    /* Process the parsed data */
    YamlNode *root = yaml_parser_get_root(parser);
    g_print("Parsed root type: %d\n", yaml_node_get_node_type(root));

    /* Signal completion to main loop if needed */
    GMainLoop *loop = user_data;
    g_main_loop_quit(loop);
}

void
parse_file_async(const gchar *path)
{
    g_autoptr(YamlParser) parser = yaml_parser_new();
    g_autoptr(GFile) file = g_file_new_for_path(path);
    GMainLoop *loop = g_main_loop_new(NULL, FALSE);

    yaml_parser_load_from_gfile_async(
        parser,
        file,
        NULL,                   /* GCancellable */
        on_parse_complete,
        loop
    );

    g_main_loop_run(loop);
    g_main_loop_unref(loop);
}
```

### From Stream

```c
static void
on_stream_parse_complete(GObject      *source,
                         GAsyncResult *result,
                         gpointer      user_data)
{
    YamlParser *parser = YAML_PARSER(source);
    g_autoptr(GError) error = NULL;

    if (!yaml_parser_load_from_stream_finish(parser, result, &error))
    {
        g_printerr("Stream parse failed: %s\n", error->message);
        return;
    }

    YamlNode *root = yaml_parser_get_root(parser);
    /* Process... */
}

void
parse_stream_async(GInputStream *stream)
{
    g_autoptr(YamlParser) parser = yaml_parser_new();

    yaml_parser_load_from_stream_async(
        parser,
        stream,
        NULL,                        /* GCancellable */
        on_stream_parse_complete,
        NULL                         /* user_data */
    );
}
```

## Async Generation

### To GFile

```c
static void
on_write_complete(GObject      *source,
                  GAsyncResult *result,
                  gpointer      user_data)
{
    YamlGenerator *gen = YAML_GENERATOR(source);
    g_autoptr(GError) error = NULL;

    if (!yaml_generator_to_gfile_finish(gen, result, &error))
    {
        g_printerr("Async write failed: %s\n", error->message);
        return;
    }

    g_print("File written successfully!\n");
}

void
write_file_async(YamlNode *root, const gchar *path)
{
    g_autoptr(YamlGenerator) gen = yaml_generator_new();
    g_autoptr(GFile) file = g_file_new_for_path(path);

    yaml_generator_set_root(gen, root);
    yaml_generator_set_indent(gen, 2);

    yaml_generator_to_gfile_async(
        gen,
        file,
        NULL,               /* GCancellable */
        on_write_complete,
        NULL
    );
}
```

### To Stream

```c
static void
on_stream_write_complete(GObject      *source,
                         GAsyncResult *result,
                         gpointer      user_data)
{
    YamlGenerator *gen = YAML_GENERATOR(source);
    g_autoptr(GError) error = NULL;

    if (!yaml_generator_to_stream_finish(gen, result, &error))
    {
        g_printerr("Stream write failed: %s\n", error->message);
        return;
    }

    g_print("Stream written successfully!\n");
}

void
write_stream_async(YamlNode      *root,
                   GOutputStream *stream)
{
    g_autoptr(YamlGenerator) gen = yaml_generator_new();

    yaml_generator_set_root(gen, root);

    yaml_generator_to_stream_async(
        gen,
        stream,
        NULL,                       /* GCancellable */
        on_stream_write_complete,
        NULL
    );
}
```

## Cancellation

Use `GCancellable` to cancel async operations:

```c
typedef struct {
    YamlParser   *parser;
    GCancellable *cancellable;
    GMainLoop    *loop;
} ParseOperation;

static void
on_parse_complete_with_cancel(GObject      *source,
                              GAsyncResult *result,
                              gpointer      user_data)
{
    ParseOperation *op = user_data;
    g_autoptr(GError) error = NULL;

    if (!yaml_parser_load_from_gfile_finish(YAML_PARSER(source), result, &error))
    {
        if (g_error_matches(error, G_IO_ERROR, G_IO_ERROR_CANCELLED))
        {
            g_print("Operation was cancelled\n");
        }
        else
        {
            g_printerr("Error: %s\n", error->message);
        }
    }
    else
    {
        g_print("Parse completed\n");
    }

    g_main_loop_quit(op->loop);
}

void
parse_with_timeout(const gchar *path, guint timeout_seconds)
{
    g_autoptr(YamlParser) parser = yaml_parser_new();
    g_autoptr(GFile) file = g_file_new_for_path(path);
    g_autoptr(GCancellable) cancellable = g_cancellable_new();
    GMainLoop *loop = g_main_loop_new(NULL, FALSE);

    ParseOperation op = {
        .parser = parser,
        .cancellable = cancellable,
        .loop = loop
    };

    /* Start async parse */
    yaml_parser_load_from_gfile_async(
        parser, file, cancellable,
        on_parse_complete_with_cancel, &op
    );

    /* Schedule cancellation after timeout */
    g_timeout_add_seconds(timeout_seconds, (GSourceFunc)g_cancellable_cancel,
                          cancellable);

    g_main_loop_run(loop);
    g_main_loop_unref(loop);
}
```

## Integration with GTask

For custom async operations using yaml-glib:

```c
typedef struct {
    gchar *filename;
    YamlNode *result;
} LoadConfigData;

static void
load_config_data_free(LoadConfigData *data)
{
    g_free(data->filename);
    g_clear_pointer(&data->result, yaml_node_unref);
    g_free(data);
}

static void
load_config_thread(GTask        *task,
                   gpointer      source_object,
                   gpointer      task_data,
                   GCancellable *cancellable)
{
    LoadConfigData *data = task_data;
    g_autoptr(YamlParser) parser = yaml_parser_new();
    g_autoptr(GError) error = NULL;

    /* Check for cancellation */
    if (g_task_return_error_if_cancelled(task))
        return;

    /* Parse file synchronously in thread */
    if (!yaml_parser_load_from_file(parser, data->filename, &error))
    {
        g_task_return_error(task, g_steal_pointer(&error));
        return;
    }

    /* Steal the root to keep it after parser is freed */
    data->result = yaml_parser_steal_root(parser);

    if (data->result == NULL)
    {
        g_task_return_new_error(task, YAML_GLIB_PARSER_ERROR,
                                YAML_GLIB_PARSER_ERROR_DOCUMENT,
                                "Empty document");
        return;
    }

    g_task_return_pointer(task, yaml_node_ref(data->result), yaml_node_unref);
}

void
load_config_async(const gchar         *filename,
                  GCancellable        *cancellable,
                  GAsyncReadyCallback  callback,
                  gpointer             user_data)
{
    GTask *task = g_task_new(NULL, cancellable, callback, user_data);

    LoadConfigData *data = g_new0(LoadConfigData, 1);
    data->filename = g_strdup(filename);

    g_task_set_task_data(task, data, (GDestroyNotify)load_config_data_free);
    g_task_run_in_thread(task, load_config_thread);
    g_object_unref(task);
}

YamlNode *
load_config_finish(GAsyncResult  *result,
                   GError       **error)
{
    return g_task_propagate_pointer(G_TASK(result), error);
}

/* Usage */
static void
on_config_loaded(GObject      *source,
                 GAsyncResult *result,
                 gpointer      user_data)
{
    g_autoptr(GError) error = NULL;
    g_autoptr(YamlNode) config = load_config_finish(result, &error);

    if (config == NULL)
    {
        g_printerr("Failed to load config: %s\n", error->message);
        return;
    }

    g_print("Config loaded!\n");
}
```

## Network File Loading

Load YAML from a remote source:

```c
static void
on_remote_loaded(GObject      *source,
                 GAsyncResult *result,
                 gpointer      user_data)
{
    YamlParser *parser = user_data;
    g_autoptr(GError) error = NULL;

    if (!yaml_parser_load_from_gfile_finish(parser, result, &error))
    {
        g_printerr("Remote load failed: %s\n", error->message);
        return;
    }

    YamlNode *root = yaml_parser_get_root(parser);
    g_print("Loaded remote config\n");
}

void
load_remote_config(const gchar *uri)
{
    g_autoptr(YamlParser) parser = yaml_parser_new();
    g_autoptr(GFile) file = g_file_new_for_uri(uri);

    yaml_parser_load_from_gfile_async(
        parser, file, NULL,
        on_remote_loaded, parser
    );
}
```

## Batch Processing

Process multiple files asynchronously:

```c
typedef struct {
    gchar   **files;
    guint     n_files;
    guint     current;
    guint     completed;
    guint     failed;
    GMainLoop *loop;
} BatchContext;

static void process_next_file(BatchContext *ctx);

static void
on_file_parsed(GObject      *source,
               GAsyncResult *result,
               gpointer      user_data)
{
    BatchContext *ctx = user_data;
    YamlParser *parser = YAML_PARSER(source);
    g_autoptr(GError) error = NULL;

    if (yaml_parser_load_from_gfile_finish(parser, result, &error))
    {
        ctx->completed++;
        g_print("Parsed: %s\n", ctx->files[ctx->current - 1]);
    }
    else
    {
        ctx->failed++;
        g_printerr("Failed: %s - %s\n",
                   ctx->files[ctx->current - 1], error->message);
    }

    /* Process next or finish */
    if (ctx->current < ctx->n_files)
    {
        process_next_file(ctx);
    }
    else
    {
        g_print("Batch complete: %u succeeded, %u failed\n",
                ctx->completed, ctx->failed);
        g_main_loop_quit(ctx->loop);
    }
}

static void
process_next_file(BatchContext *ctx)
{
    g_autoptr(YamlParser) parser = yaml_parser_new();
    g_autoptr(GFile) file = g_file_new_for_path(ctx->files[ctx->current]);

    ctx->current++;

    yaml_parser_load_from_gfile_async(
        parser, file, NULL,
        on_file_parsed, ctx
    );
}

void
batch_parse_files(gchar **files, guint n_files)
{
    BatchContext ctx = {
        .files = files,
        .n_files = n_files,
        .current = 0,
        .completed = 0,
        .failed = 0,
        .loop = g_main_loop_new(NULL, FALSE)
    };

    process_next_file(&ctx);
    g_main_loop_run(ctx.loop);
    g_main_loop_unref(ctx.loop);
}
```

## Complete Example

```c
#include <yaml-glib/yaml-glib.h>

typedef struct {
    YamlParser *parser;
    YamlNode   *config;
    GMainLoop  *loop;
} AppContext;

static void
on_config_written(GObject      *source,
                  GAsyncResult *result,
                  gpointer      user_data)
{
    AppContext *ctx = user_data;
    g_autoptr(GError) error = NULL;

    if (!yaml_generator_to_gfile_finish(YAML_GENERATOR(source), result, &error))
    {
        g_printerr("Failed to save config: %s\n", error->message);
    }
    else
    {
        g_print("Configuration saved!\n");
    }

    g_main_loop_quit(ctx->loop);
}

static void
modify_and_save_config(AppContext *ctx)
{
    /* Modify the config */
    YamlMapping *mapping = yaml_node_get_mapping(ctx->config);
    yaml_mapping_set_boolean_member(mapping, "modified", TRUE);

    /* Save asynchronously */
    g_autoptr(YamlGenerator) gen = yaml_generator_new();
    g_autoptr(GFile) file = g_file_new_for_path("output.yaml");

    yaml_generator_set_root(gen, ctx->config);
    yaml_generator_set_indent(gen, 2);
    yaml_generator_set_explicit_start(gen, TRUE);

    yaml_generator_to_gfile_async(
        gen, file, NULL,
        on_config_written, ctx
    );
}

static void
on_config_loaded(GObject      *source,
                 GAsyncResult *result,
                 gpointer      user_data)
{
    AppContext *ctx = user_data;
    g_autoptr(GError) error = NULL;

    if (!yaml_parser_load_from_gfile_finish(ctx->parser, result, &error))
    {
        g_printerr("Failed to load config: %s\n", error->message);
        g_main_loop_quit(ctx->loop);
        return;
    }

    g_print("Configuration loaded!\n");

    /* Steal the config to keep it */
    ctx->config = yaml_parser_steal_root(ctx->parser);

    /* Now modify and save */
    modify_and_save_config(ctx);
}

int
main(int argc, char *argv[])
{
    if (argc < 2)
    {
        g_printerr("Usage: %s <config.yaml>\n", argv[0]);
        return 1;
    }

    AppContext ctx = {
        .parser = yaml_parser_new(),
        .config = NULL,
        .loop = g_main_loop_new(NULL, FALSE)
    };

    g_autoptr(GFile) file = g_file_new_for_path(argv[1]);

    /* Start async load */
    yaml_parser_load_from_gfile_async(
        ctx.parser, file, NULL,
        on_config_loaded, &ctx
    );

    /* Run until complete */
    g_main_loop_run(ctx.loop);

    /* Cleanup */
    g_clear_pointer(&ctx.config, yaml_node_unref);
    g_object_unref(ctx.parser);
    g_main_loop_unref(ctx.loop);

    return 0;
}
```

## Best Practices

1. **Use g_autoptr** for automatic cleanup of GLib objects
2. **Check for cancellation** in long-running operations
3. **Handle errors** in finish callbacks
4. **Steal nodes** if you need them after the parser is freed
5. **Use GTask** for custom async operations that involve yaml-glib

## See Also

- [YamlParser API](../api/parser.md) - Async parsing functions
- [YamlGenerator API](../api/generator.md) - Async generation functions
- [Parsing Guide](parsing.md) - Synchronous parsing
- [GIO Async Documentation](https://docs.gtk.org/gio/concepts.html#async-io)
