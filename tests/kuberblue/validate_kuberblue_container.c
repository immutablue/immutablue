#!/usr/bin/crispy

/* validate_kuberblue_container.c - Validate Kuberblue container image contents
 *
 * Runs inside the container to verify:
 *   1. Kubernetes RPM packages (version-aware: 1.32 on Fedora 42, 1.35 on Fedora 43+)
 *   2. Kuberblue-specific binaries (crio, kubeadm, kubectl, kubelet, sops, helm, flux, chainsaw)
 *   3. Kuberblue directories and configuration files
 *   4. Kuberblue and Kubernetes systemd services
 *
 * Usage: crispy validate_kuberblue_container.c
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

/* detect Fedora version from /etc/os-release */
static gint
detect_fedora_version(void)
{
    g_autofree gchar *contents = NULL;
    g_autoptr(GError) error = NULL;
    gchar **lines;
    gint version = 43; /* default */
    guint i;

    if (!g_file_get_contents("/etc/os-release", &contents, NULL, &error))
    {
        g_printerr("WARN: cannot read /etc/os-release: %s\n", error->message);
        return version;
    }

    lines = g_strsplit(contents, "\n", -1);
    for (i = 0; lines[i] != NULL; i++)
    {
        if (g_str_has_prefix(lines[i], "VERSION_ID="))
        {
            const gchar *val = lines[i] + strlen("VERSION_ID=");
            /* strip surrounding quotes if any */
            gchar *stripped = g_strstrip(g_strdup(val));
            if (stripped[0] == '"')
            {
                gsize len = strlen(stripped);
                if (len > 1 && stripped[len - 1] == '"')
                    stripped[len - 1] = '\0';
                version = atoi(stripped + 1);
            }
            else
            {
                version = atoi(stripped);
            }
            g_free(stripped);
            break;
        }
    }
    g_strfreev(lines);
    return version;
}

/* check version-specific Kubernetes RPM packages */
static gint
check_kubernetes_packages(gint fedora_version)
{
    const gchar *k8s_ver = (fedora_version <= 42) ? "1.32" : "1.35";
    g_autofree gchar *pkg_kube      = g_strdup_printf("kubernetes%s", k8s_ver);
    g_autofree gchar *pkg_client    = g_strdup_printf("kubernetes%s-client", k8s_ver);
    g_autofree gchar *pkg_kubeadm   = g_strdup_printf("kubernetes%s-kubeadm", k8s_ver);
    g_autofree gchar *pkg_systemd   = g_strdup_printf("kubernetes%s-systemd", k8s_ver);
    g_autofree gchar *pkg_critools  = g_strdup_printf("cri-tools%s", k8s_ver);

    const gchar *packages[] = {
        pkg_kube,
        pkg_client,
        pkg_kubeadm,
        pkg_systemd,
        pkg_critools,
        NULL
    };

    gint failed = 0;
    gint i;

    g_print("\n--- Kubernetes RPM Checks (Fedora %d / k8s %s) ---\n", fedora_version, k8s_ver);

    for (i = 0; packages[i] != NULL; i++)
    {
        g_autofree gchar *cmd = g_strdup_printf("rpm -q %s", packages[i]);
        g_autofree gchar *output = NULL;
        gint status;

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

/* check kuberblue-specific RPM packages (version-independent) */
static gint
check_kuberblue_packages(void)
{
    static const gchar *packages[] = {
        "age",
        "cockpit",
        "fzf",
        "glances",
        "helm",
        "htop",
        "neovim",
        "tailscale",
        "tmux",
        NULL
    };

    gint failed = 0;
    gint i;

    g_print("\n--- Kuberblue RPM Checks ---\n");

    for (i = 0; packages[i] != NULL; i++)
    {
        g_autofree gchar *cmd = g_strdup_printf("rpm -q %s", packages[i]);
        g_autofree gchar *output = NULL;
        gint status;

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

/* check kuberblue binary tools (installed as binary releases, not RPMs) */
static gint
check_kuberblue_binaries(void)
{
    static const gchar *binaries[] = {
        /* Kubernetes runtime */
        "/usr/bin/crio",
        /* SOPS: secret encryption */
        "/usr/bin/sops",
        /* GitOps / CI tooling */
        "/usr/bin/flux",
        "/usr/bin/chainsaw",
        NULL
    };

    static const gchar *k8s_binaries[] = {
        /* Installed by kubernetes RPMs into /usr/sbin */
        "/usr/sbin/kubeadm",
        "/usr/sbin/kubelet",
        "/usr/sbin/kubectl",
        NULL
    };

    gint failed = 0;
    gint i;

    g_print("\n--- Kuberblue Binary Checks ---\n");

    for (i = 0; binaries[i] != NULL; i++)
    {
        if (g_file_test(binaries[i], G_FILE_TEST_IS_EXECUTABLE))
            g_print("PASS: %s\n", binaries[i]);
        else
        {
            g_print("FAIL: %s (missing or not executable)\n", binaries[i]);
            failed++;
        }
    }

    for (i = 0; k8s_binaries[i] != NULL; i++)
    {
        if (g_file_test(k8s_binaries[i], G_FILE_TEST_IS_EXECUTABLE))
            g_print("PASS: %s\n", k8s_binaries[i]);
        else
        {
            g_print("FAIL: %s (missing or not executable)\n", k8s_binaries[i]);
            failed++;
        }
    }

    return failed;
}

/* check kuberblue configuration directories and files */
static gint
check_kuberblue_files(void)
{
    static const gchar *dirs[] = {
        "/etc/kuberblue",
        "/etc/kuberblue/manifests",
        "/usr/kuberblue",
        "/usr/libexec/kuberblue",
        "/usr/libexec/kuberblue/kube_setup",
        NULL
    };

    static const gchar *files[] = {
        /* cluster config (in /usr/kuberblue, not /etc) */
        "/usr/kuberblue/kubeadm.yaml",
        "/usr/kuberblue/cluster.yaml",
        "/usr/kuberblue/cni.yaml",
        /* manifests */
        "/etc/kuberblue/manifests/metadata.yaml.tpl",
        "/etc/kuberblue/manifests/00-infrastructure/00-cilium/00-metadata.yaml",
        "/etc/kuberblue/manifests/00-infrastructure/10-openebs/00-metadata.yaml",
        /* runtime scripts */
        "/usr/libexec/kuberblue/99-common.sh",
        "/usr/libexec/kuberblue/variables.sh",
        "/usr/libexec/kuberblue/kube_setup/kube_init.sh",
        "/usr/libexec/kuberblue/kube_setup/kube_deploy.sh",
        "/usr/libexec/kuberblue/kube_setup/kube_reset.sh",
        "/usr/libexec/kuberblue/kube_setup/kube_add_kuberblue_user.sh",
        /* just integration */
        "/usr/libexec/immutablue/just/30-kuberblue.justfile",
        NULL
    };

    gint failed = 0;
    gint i;

    g_print("\n--- Kuberblue Directory Checks ---\n");

    for (i = 0; dirs[i] != NULL; i++)
    {
        if (g_file_test(dirs[i], G_FILE_TEST_IS_DIR))
            g_print("PASS: %s\n", dirs[i]);
        else
        {
            g_print("FAIL: %s (missing)\n", dirs[i]);
            failed++;
        }
    }

    g_print("\n--- Kuberblue File Checks ---\n");

    for (i = 0; files[i] != NULL; i++)
    {
        if (g_file_test(files[i], G_FILE_TEST_EXISTS))
            g_print("PASS: %s\n", files[i]);
        else
        {
            g_print("FAIL: %s (missing)\n", files[i]);
            failed++;
        }
    }

    return failed;
}

/* check kuberblue and kubernetes systemd services are present */
static gint
check_kuberblue_services(void)
{
    g_autofree gchar *output = NULL;
    gint status;
    gchar **lines;
    gint failed = 0;
    guint i;

    static const gchar *required_services[] = {
        "crio.service",
        "kubelet.service",
        "kuberblue-onboot.service",
        NULL
    };

    g_print("\n--- Kuberblue Systemd Service Checks ---\n");

    if (!run_command("systemctl list-unit-files", &output, &status))
    {
        g_print("FAIL: cannot list systemd unit files\n");
        return 1;
    }

    for (i = 0; required_services[i] != NULL; i++)
    {
        if (g_strstr_len(output, -1, required_services[i]) != NULL)
            g_print("PASS: %s found\n", required_services[i]);
        else
        {
            g_print("FAIL: %s not found\n", required_services[i]);
            failed++;
        }
    }

    /* also count total kuberblue services */
    lines = g_strsplit(output, "\n", -1);
    gint kuberblue_count = 0;
    for (i = 0; lines[i] != NULL; i++)
    {
        if (g_strstr_len(lines[i], -1, "kuberblue") != NULL)
            kuberblue_count++;
    }
    g_strfreev(lines);
    g_print("INFO: %d kuberblue systemd unit(s) found\n", kuberblue_count);

    return failed;
}

gint
main(
    gint    argc,
    gchar **argv
){
    gint fedora_version;
    gint total_failed;

    (void)argc;
    (void)argv;

    g_print("=== Kuberblue Container Validation ===\n");

    fedora_version = detect_fedora_version();
    g_print("Detected Fedora version: %d\n", fedora_version);

    total_failed = 0;
    total_failed += check_kubernetes_packages(fedora_version);
    total_failed += check_kuberblue_packages();
    total_failed += check_kuberblue_binaries();
    total_failed += check_kuberblue_files();
    total_failed += check_kuberblue_services();

    g_print("\n=== Summary ===\n");

    if (total_failed > 0)
    {
        g_print("FAIL: %d check(s) failed\n", total_failed);
        return 1;
    }

    g_print("PASS: All kuberblue container checks passed\n");
    return 0;
}
