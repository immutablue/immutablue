#!/usr/bin/crispy

/* validate_container.c - Validate Immutablue container image contents
 *
 * Runs inside the container to verify:
 *   1. RPM packages from packages.yaml are installed
 *   2. Custom binaries from deps build are present
 *   3. Custom shared libraries from deps build are present
 *   4. Required directories exist
 *   5. Immutablue systemd services are present
 *
 * Usage: crispy validate_container.c
 *
 * Exit codes:
 *   0 - all checks pass
 *   1 - one or more checks failed
 */

#include <glib.h>

/* run a command and capture stdout, return TRUE on success */
static gboolean
run_command(
    const gchar  *cmd,
    gchar       **stdout_out,
    gint         *exit_status
){
    g_autoptr(GError) error = NULL;
    gchar *out = NULL;
    gchar *err = NULL;
    gint status;

    if (!g_spawn_command_line_sync(cmd, &out, &err, &status, &error))
    {
        g_printerr("WARN: failed to run '%s': %s\n", cmd, error->message);
        g_free(out);
        g_free(err);
        return FALSE;
    }

    if (stdout_out != NULL)
        *stdout_out = out;
    else
        g_free(out);

    g_free(err);

    if (exit_status != NULL)
        *exit_status = g_spawn_check_wait_status(status, NULL) ? 0 : 1;

    return TRUE;
}

/* check that all required RPM packages are installed via rpm -q
 * package list sourced from packages.yaml rpm.all */
static gint
check_packages(void)
{
    static const gchar *packages[] = {
        /* packages.yaml: rpm.all */
        "bashmount",
        "bemenu",
        "buildah",
        "buildstream",
        "cloud-init",
        "cmake",
        "ddrescue",
        "dialog",
        "distrobox",
        "e2fsprogs",
        "fuse-sshfs",
        "fzf",
        "gcc",
        "gdb",
        "git",
        "glib2-devel",
        "htop",
        "json-glib-devel",
        "libdex",
        "libdex-devel",
        "libsoup3",
        "libsoup3-devel",
        "libvirt",
        "libvirt-dbus",
        "libyaml-devel",
        "lm_sensors",
        "make",
        "mbuffer",
        "neovim",
        "NetworkManager-tui",
        "pkgconf-pkg-config",
        "podman-compose",
        "powertop",
        "pv",
        "python3-gobject",
        "python3-pip",
        "python3-pyyaml",
        "qemu",
        "qemu-user-binfmt",
        "ramalama",
        "readline-devel",
        "ShellCheck",
        "socat",
        "stow",
        "syncthing",
        "syncthing-tools",
        "tailscale",
        "tmux",
        "usbip",
        "virt-bootstrap",
        NULL
    };

    gint failed;
    gint i;

    g_print("\n--- RPM Package Checks ---\n");
    failed = 0;

    for (i = 0; packages[i] != NULL; i++)
    {
        g_autofree gchar *cmd = NULL;
        g_autofree gchar *output = NULL;
        gint status;

        cmd = g_strdup_printf("rpm -q %s", packages[i]);

        if (!run_command(cmd, &output, &status))
        {
            g_print("FAIL: %s (command error)\n", packages[i]);
            failed++;
            continue;
        }

        if (status != 0)
        {
            g_print("FAIL: %s (not installed)\n", packages[i]);
            failed++;
        }
        else
        {
            g_strstrip(output);
            g_print("PASS: %s (%s)\n", packages[i], output);
        }
    }

    return failed;
}

/* check that custom binaries from deps build are present */
static gint
check_custom_binaries(void)
{
    static const gchar *binaries[] = {
        /* core tools (always installed) */
        "/usr/bin/crispy",
        "/usr/bin/blue2go",
        "/usr/bin/cigar",
        "/usr/bin/zapper",

        /* mcp tools */
        "/usr/bin/mcp-inspect",
        "/usr/bin/mcp-call",
        "/usr/bin/mcp-read",
        "/usr/bin/mcp-prompt",
        "/usr/bin/mcp-shell",
        "/usr/bin/gdb-mcp-server",

        /* gui tools (skipped on nucleus, but present on standard builds) */
        "/usr/bin/gst",
        "/usr/bin/gowl",
        "/usr/bin/gowlbar",
        NULL
    };

    gint failed;
    gint i;

    g_print("\n--- Custom Binary Checks ---\n");
    failed = 0;

    for (i = 0; binaries[i] != NULL; i++)
    {
        if (g_file_test(binaries[i], G_FILE_TEST_IS_EXECUTABLE))
        {
            g_print("PASS: %s\n", binaries[i]);
        }
        else
        {
            g_print("FAIL: %s (missing or not executable)\n", binaries[i]);
            failed++;
        }
    }

    return failed;
}

/* check that custom shared libraries from deps build are present
 * and that their versioned symlinks are correct */
static gint
check_custom_libraries(void)
{
    /* check both the versioned .so and the unversioned symlink */
    static const gchar *libraries[] = {
        /* yaml-glib */
        "/usr/lib64/libyaml-glib.so.1.0.0",
        "/usr/lib64/libyaml-glib.so",

        /* crispy */
        "/usr/lib64/libcrispy.so.0.1.0",
        "/usr/lib64/libcrispy.so",

        /* gst */
        "/usr/lib64/libgst.so.0.1.0",
        "/usr/lib64/libgst.so",

        /* gowl */
        "/usr/lib64/libgowl.so.0.1.0",
        "/usr/lib64/libgowl.so",

        /* mcp-glib */
        "/usr/lib64/libmcp-glib-1.0.so",

        /* ai-glib */
        "/usr/lib64/libai-glib-1.0.so",
        NULL
    };

    gint failed;
    gint i;

    g_print("\n--- Custom Library Checks ---\n");
    failed = 0;

    for (i = 0; libraries[i] != NULL; i++)
    {
        if (g_file_test(libraries[i], G_FILE_TEST_EXISTS))
        {
            g_print("PASS: %s\n", libraries[i]);
        }
        else
        {
            g_print("FAIL: %s (missing)\n", libraries[i]);
            failed++;
        }
    }

    return failed;
}

/* check that required directories exist */
static gint
check_directories(void)
{
    static const gchar *dirs[] = {
        "/usr/libexec/immutablue",
        "/etc/immutablue",
        "/etc/gowl",
        NULL
    };

    gint failed;
    gint i;

    g_print("\n--- Directory Checks ---\n");
    failed = 0;

    for (i = 0; dirs[i] != NULL; i++)
    {
        if (g_file_test(dirs[i], G_FILE_TEST_IS_DIR))
        {
            g_print("PASS: %s exists\n", dirs[i]);
        }
        else
        {
            g_print("FAIL: %s missing\n", dirs[i]);
            failed++;
        }
    }

    return failed;
}

/* check that immutablue systemd services are installed */
static gint
check_systemd_services(void)
{
    g_autofree gchar *output = NULL;
    gint status;
    gchar **lines;
    gint found;
    guint i;

    g_print("\n--- Systemd Service Checks ---\n");

    if (!run_command("systemctl list-unit-files", &output, &status))
    {
        g_print("FAIL: cannot list systemd unit files\n");
        return 1;
    }

    /* count lines containing "immutablue" */
    lines = g_strsplit(output, "\n", -1);
    found = 0;

    for (i = 0; lines[i] != NULL; i++)
    {
        if (g_strstr_len(lines[i], -1, "immutablue") != NULL)
        {
            g_print("FOUND: %s\n", g_strstrip(lines[i]));
            found++;
        }
    }

    g_strfreev(lines);

    if (found == 0)
    {
        g_print("FAIL: no immutablue systemd services found\n");
        return 1;
    }

    g_print("PASS: %d immutablue service(s) found\n", found);
    return 0;
}

gint
main(
    gint    argc,
    gchar **argv
){
    gint total_failed;

    (void)argc;
    (void)argv;

    g_print("=== Immutablue Container Validation ===\n");

    total_failed = 0;
    total_failed += check_packages();
    total_failed += check_custom_binaries();
    total_failed += check_custom_libraries();
    total_failed += check_directories();
    total_failed += check_systemd_services();

    g_print("\n=== Summary ===\n");

    if (total_failed > 0)
    {
        g_print("FAIL: %d check(s) failed\n", total_failed);
        return 1;
    }

    g_print("PASS: All container checks passed\n");
    return 0;
}
