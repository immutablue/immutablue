#!/usr/bin/crispy

/* validate_artifacts.c - Verify override files match container contents
 *
 * Compares SHA256 checksums of all files under an expected directory
 * against their corresponding paths on the root filesystem.
 *
 * Usage: crispy validate_artifacts.c <expected_dir>
 *   expected_dir: path to the artifacts/overrides mount (e.g. /expected)
 *
 * Exit codes:
 *   0 - all files match
 *   1 - one or more files failed verification
 *   2 - usage error
 */

#include <glib.h>

/* skip patterns for files that should not be compared */
static gboolean
should_skip(
    const gchar *rel_path
){
    if (g_strstr_len(rel_path, -1, "/test/") != NULL)
        return TRUE;
    if (g_str_has_suffix(rel_path, "/Justfile"))
        return TRUE;
    if (g_str_has_suffix(rel_path, "/system.conf"))
        return TRUE;
    if (g_strstr_len(rel_path, -1, "__pycache__") != NULL)
        return TRUE;

    return FALSE;
}

/* compute SHA256 hex digest of a file */
static gchar *
hash_file(
    const gchar *path
){
    g_autofree gchar *contents = NULL;
    gsize length;
    g_autoptr(GError) error = NULL;
    const gchar *digest;
    g_autoptr(GChecksum) checksum = NULL;

    if (!g_file_get_contents(path, &contents, &length, &error))
        return NULL;

    checksum = g_checksum_new(G_CHECKSUM_SHA256);
    g_checksum_update(checksum, (const guchar *)contents, length);
    digest = g_checksum_get_string(checksum);

    return g_strdup(digest);
}

/* recursively collect all regular files under dir */
static void
collect_files(
    const gchar *dir,
    GPtrArray   *results
){
    g_autoptr(GError) error = NULL;
    g_autoptr(GDir) gdir = NULL;
    const gchar *name;

    gdir = g_dir_open(dir, 0, &error);
    if (gdir == NULL)
    {
        g_printerr("WARN: cannot open %s: %s\n", dir, error->message);
        return;
    }

    while ((name = g_dir_read_name(gdir)) != NULL)
    {
        g_autofree gchar *full = g_build_filename(dir, name, NULL);

        if (g_file_test(full, G_FILE_TEST_IS_DIR))
        {
            collect_files(full, results);
        }
        else if (g_file_test(full, G_FILE_TEST_IS_REGULAR))
        {
            g_ptr_array_add(results, g_strdup(full));
        }
    }
}

gint
main(
    gint    argc,
    gchar **argv
){
    g_autoptr(GPtrArray) files = NULL;
    const gchar *expected_dir;
    gsize prefix_len;
    gint total;
    gint failed;
    gint skipped;
    guint i;

    if (argc < 2)
    {
        g_printerr("Usage: crispy validate_artifacts.c <expected_dir>\n");
        return 2;
    }

    expected_dir = argv[1];
    prefix_len = strlen(expected_dir);

    /* strip trailing slash if present */
    if (expected_dir[prefix_len - 1] == '/')
        prefix_len--;

    /* collect all files under expected_dir */
    files = g_ptr_array_new_with_free_func(g_free);
    collect_files(expected_dir, files);

    if (files->len == 0)
    {
        g_print("INFO: No files found in %s\n", expected_dir);
        return 0;
    }

    /* sort for deterministic output */
    g_ptr_array_sort(files, (GCompareFunc)g_strcmp0);

    total = 0;
    failed = 0;
    skipped = 0;

    for (i = 0; i < files->len; i++)
    {
        const gchar *src_path;
        const gchar *rel_path;
        g_autofree gchar *actual_path = NULL;
        g_autofree gchar *src_hash = NULL;
        g_autofree gchar *actual_hash = NULL;

        src_path = g_ptr_array_index(files, i);
        rel_path = src_path + prefix_len;

        /* check skip patterns */
        if (should_skip(rel_path))
        {
            g_print("SKIP: %s\n", rel_path);
            skipped++;
            continue;
        }

        total++;

        /* actual_path is just rel_path (absolute from /) */
        actual_path = g_strdup(rel_path);

        /* hash expected file */
        src_hash = hash_file(src_path);
        if (src_hash == NULL)
        {
            g_print("FAIL: %s (cannot read source)\n", rel_path);
            failed++;
            continue;
        }

        /* hash actual file on the filesystem */
        if (!g_file_test(actual_path, G_FILE_TEST_EXISTS))
        {
            g_print("FAIL: %s (not found on filesystem)\n", rel_path);
            failed++;
            continue;
        }

        actual_hash = hash_file(actual_path);
        if (actual_hash == NULL)
        {
            g_print("FAIL: %s (cannot read from filesystem)\n", rel_path);
            failed++;
            continue;
        }

        if (g_strcmp0(src_hash, actual_hash) != 0)
        {
            g_print("FAIL: %s\n", rel_path);
            g_print("  expected: %s\n", src_hash);
            g_print("  actual:   %s\n", actual_hash);
            failed++;
        }
        else
        {
            g_print("PASS: %s\n", rel_path);
        }
    }

    g_print("\nSummary:\n");
    g_print("- Files checked: %d\n", total);
    g_print("- Files skipped: %d\n", skipped);
    g_print("- Files failed:  %d\n", failed);

    if (failed > 0)
    {
        g_print("FAIL: %d out of %d override files failed verification\n",
                failed, total);
        return 1;
    }

    g_print("PASS: All %d override files verified\n", total);
    return 0;
}
