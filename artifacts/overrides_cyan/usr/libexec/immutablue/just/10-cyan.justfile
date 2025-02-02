# Enable the nvidia kmod (requires reboot)
enable_nvidia_kmod:
    #!/bin/bash 
    set -euo pipefail 

    sudo rpm-ostree kargs --append-if-missing=rd.driver.blacklist=nouveau --append-if-missing=modprobe.blacklist=nouveau --append-if-missing=nvidia-drm.modeset=1 --unchanged-exit-77
    exit_status=$?
    if [[ $exit_status -eq 0 ]]; then
        echo "Nvidia kargs have been appended. Run 'systemctl reboot' to enable nvidia drivers."
    fi

# Disable nvidia kmod (useful when rebasing off -cyan)
disable_nvidia_kmod:
    #!/bin/bash 
    set -euo pipefail 

    sudo rpm-ostree kargs --delete-if-present=rd.driver.blacklist=nouveau --delete-if-present=modprobe.blacklist=nouveau --delete-if-present=nvidia-drm.modeset=1 --unchanged-exit-77
    exit_status=$?
    if [[ $exit_status -eq 0 ]]; then
        echo "Nvidia kargs have been appended. Run 'systemctl reboot' to enable nvidia drivers."
    fi

