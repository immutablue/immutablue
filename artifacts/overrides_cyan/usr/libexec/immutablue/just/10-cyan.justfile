# Enable the nvidia kmod (requires reboot)
enable_nvidia_kmod:
    #!/bin/bash
    set -euo pipefail

    if [[ -f /usr/lib/immutablue/nvidia/open/manifest.json ]]; then
        sudo /usr/bin/immutablue-nvidia-setup
    fi
    exit_status=0
    sudo rpm-ostree kargs --append-if-missing=rd.driver.blacklist=nouveau --append-if-missing=modprobe.blacklist=nouveau --append-if-missing=nvidia-drm.modeset=1 --unchanged-exit-77 || exit_status=$?
    [[ $exit_status -eq 0 || $exit_status -eq 77 ]] || exit "$exit_status"
    if [[ $exit_status -eq 0 ]]; then
        echo "Nvidia kargs have been appended. Run 'systemctl reboot' to enable nvidia drivers."
    fi

# Disable nvidia kmod (useful when rebasing off -cyan)
disable_nvidia_kmod:
    #!/bin/bash
    set -euo pipefail

    if [[ -f /usr/lib/immutablue/nvidia/open/manifest.json ]]; then
        sudo /usr/bin/immutablue-nvidia-setup --driver none
    fi
    exit_status=0
    sudo rpm-ostree kargs --delete-if-present=rd.driver.blacklist=nouveau --delete-if-present=modprobe.blacklist=nouveau --delete-if-present=nvidia-drm.modeset=1 --unchanged-exit-77 || exit_status=$?
    [[ $exit_status -eq 0 || $exit_status -eq 77 ]] || exit "$exit_status"
    if [[ $exit_status -eq 0 ]]; then
        echo "Nvidia kargs have been removed. Run 'systemctl reboot' to apply the change."
    fi

# Re-detect the GPU and save the driver for the next boot
nvidia_setup *args:
    sudo /usr/bin/immutablue-nvidia-setup {{ args }}

# Show the saved driver choice without root privileges
nvidia_status:
    /usr/bin/immutablue-nvidia-setup --status
