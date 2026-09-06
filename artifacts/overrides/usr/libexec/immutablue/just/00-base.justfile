IMMUTABLUE_INSTALL_DIR := "/usr/immutablue"

# Reboot to bios
bios:
    #!/bin/bash 
    set -euo pipefail 

    if [[ -d /sys/firmware/efi ]]
    then
        systemctl reboot --firmware-setup
    else
        echo "not supported on BIOS booted installs"
    fi


# Print out system info. Useful for filing a ticket
sysinfo:
    #!/bin/bash 
    set -euo pipefail

    rpm-ostree status --verbose
    fpaste --sysinfo --printonly
    flatpak list --columns=application,version,options
    distrobox list
    distrobox list --root


# Post system info to a pastebin. Share link with a friend
sysinfo_post:
    #!/bin/bash 
    set -euo pipefail

    fpaste -t "immutablue-sysinfo-$(date +\"%Y-%s-%m\")" <(just sysinfo)


logs_since_boot:
    sudo journalctl -b 0
logs_since_last_boot:
    sudo journalctl -b 1

check_local_etc_overrides:
    #!/usr/bin/bash
    diff -r \
      --suppress-common-lines \
      --color="always" \
      --exclude "passwd*" \
      --exclude "group*" \
      --exclude="subgid*" \
      --exclude="subuid*" \
      --exclude="machine-id" \
      --exclude="adjtime" \
      --exclude="fstab" \
      --exclude="system-connections" \
      --exclude="shadow*" \
      --exclude="gshadow*" \
      --exclude="ssh_host*" \
      --exclude="cmdline" \
      --exclude="crypttab" \
      --exclude="hostname" \
      --exclude="localtime" \
      --exclude="locale*" \
      --exclude="*lock" \
      --exclude=".updated" \
      --exclude="*LOCK" \
      --exclude="vconsole*" \
      --exclude="00-keyboard.conf" \
      --exclude="grub" \
      --exclude="system.control*" \
      --exclude="cdi" \
      --exclude="default.target" \
      /usr/etc /etc 2>/dev/null | sed '/Binary\ files\ /d'




# Makefile proxying -- Likely you don't need to call this
immutablue_make_command COMMAND:
    #!/bin/bash 
    set -euo pipefail

    cd "{{IMMUTABLUE_INSTALL_DIR}}"
    make "{{COMMAND}}"


# Run post install stuff: installs distrobox, brew, flatpaks, etc.
install:
    just immutablue_make_command install

alias install_dbox := install_distrobox
install_distrobox:
    just immutablue_make_command install_distrobox
    
install_flatpak:
    just immutablue_make_command install_flatpak

install_brew:
    just immutablue_make_command install_brew

install_services:
    just immutablue_make_command install_services
    
post_install:
    just immutablue_make_command post_install

post_install_notes:
    just immutablue_make_command post_install_notes

# Update your machine
update:
    immutablue-update


# re-run initial setup (like the first login)
initial_setup:
    #!/usr/bin/bash
    set -euo pipefail

    if [[ -n "${DISPLAY:-}" ]]
    then 
        /usr/libexec/immutablue/setup/immutablue_setup_gui.py --no-reboot
    else 
        /usr/libexec/immutablue/setup/immutablue_setup_tui.py --no-reboot
    fi


# Clean up unused images, volumes, flatpaks and such
clean_system:
    #!/usr/bin/bash
    set -euo pipefail

    podman image prune -af
    podman volume prune -f
    flatpak uninstall --unused
    rpm-ostree cleanup -bm


# toggle firewall (useful for testing connection issues)
toggle_firewall:
    #!/usr/bin/bash 
    set -euo pipefail 

    if [[ "$(firewall-cmd --state 2>&1)" == "running" ]]
    then 
        sudo systemctl stop firewalld.service
        echo "stopped"
    else
        sudo systemctl start firewalld.service
        echo "started"
    fi

# disable tailscale (enabled by default)
disable_tailscale:
    sudo systemctl disable --now tailscaled.service

# enable tailscale (enabled by default)
enable_tailscale:
    sudo systemctl enable --now tailscaled.service

# disable syncthing (enabled by default)
disable_syncthing:
    sudo systemctl --global disable --now syncthing.service

# enable syncthing (enabled by default)
enable_syncthing:
    sudo systemctl --global enable --now syncthing.service


# disable libvirt (vm hosting)
disable_libvirt:
    immutablue-libvirt-manager -s disable

# disable libvirt (vm hosting) (DRY-RUN)
disable_libvirt_dry_run:
    immutablue-libvirt-manager -s --dry-run disable

# enable libvirt (vm hosting). also sets up group membership (requires restart)
enable_libvirt:
    immutablue-libvirt-manager -s enable

# enable libvirt (vm hosting). also sets up group membership (DRY RUN)
enable_libvirt_dry_run:
    immutablue-libvirt-manager -s --dry-run enable

# libvirt status (vm hosting)
status_libvirt:
    immutablue-libvirt-manager -s status

# repair libvirt SELinux labels under /var. use when VMs fail to start with "network 'default' is not active" or virtlogd "Permission denied"
fix_libvirt_selinux_mislabel:
    #!/bin/bash
    set -euo pipefail

    # libvirt is installed during the image build, so RPM labels its /var
    # directories against the build container rather than this host's policy.
    # ostree never relabels /var, so those wrong labels (var_lib_t, var_log_t,
    # var_t instead of virt_var_lib_t, virt_log_t, virt_cache_t) persist across
    # every upgrade and rebase, and the confined modular daemons cannot write
    # their own state. Each daemon fails on its own directory, so all three are
    # repaired together rather than one error at a time.

    paths=(/var/lib/libvirt /var/log/libvirt /var/cache/libvirt)

    echo "== current SELinux label drift =="
    total=0
    for p in "${paths[@]}"
    do
        [[ -e "${p}" ]] || continue
        n="$(sudo restorecon -nRv "${p}" 2>/dev/null | grep -c 'Would relabel' || true)"
        total=$(( total + n ))
        printf '  %-22s %s mislabeled\n' "${p}" "${n}"
    done

    if [[ "${total}" -eq 0 ]]
    then
        echo "labels are already correct; nothing to relabel"
    else
        echo
        echo "== relabeling =="
        # -F forces the SELinux user and role as well as the type. Needed
        # because directories created by an unconfined process drift to
        # unconfined_u, which a plain restorecon leaves in place.
        sudo restorecon -RFv "${paths[@]}"
    fi

    # The same root cause drifts the directory modes: these arrive with the
    # generic 0755 instead of what libvirt-daemon-common actually declares.
    # 0700 on the log directory matters -- domain logs can carry guest detail.
    echo
    echo "== restoring rpm-declared modes on the top-level directories =="
    [[ -d /var/lib/libvirt ]]   && sudo chmod 0755 /var/lib/libvirt
    [[ -d /var/log/libvirt ]]   && sudo chmod 0700 /var/log/libvirt
    [[ -d /var/cache/libvirt ]] && sudo chmod 0711 /var/cache/libvirt
    stat -c '  %n mode=%a %U:%G' "${paths[@]}" 2>/dev/null || true

    # /run/libvirt is intentionally untouched. Its labels come from SELinux type
    # transitions on live daemon state, and the shipped file_contexts regex for
    # that path predates the modular daemon split, so restorecon there would
    # force dnsmasq_var_run_t onto running virtnetworkd files. /run is tmpfs and
    # is rebuilt every boot, so it cannot drift persistently.

    echo
    echo "done. start the network with: virsh --connect qemu:///system net-start default"
    echo "(the shipped /usr/lib/tmpfiles.d/immutablue-libvirt-selinux.conf reasserts these labels every boot)"


# ════════════════════════════════════════════════════════════════════════════
# SYSTEM HEALTH
# ════════════════════════════════════════════════════════════════════════════

# Run system health checks
doctor:
    /usr/libexec/immutablue/immutablue-doctor

# Run system health checks with verbose output
doctor_verbose:
    /usr/libexec/immutablue/immutablue-doctor --verbose

# Run system health checks and attempt to fix issues
doctor_fix:
    /usr/libexec/immutablue/immutablue-doctor --fix

# Run system health checks with JSON output (for scripting)
doctor_json:
    /usr/libexec/immutablue/immutablue-doctor --json

# Run system health checks with YAML output (for scripting)
doctor_yaml:
    /usr/libexec/immutablue/immutablue-doctor --yaml

