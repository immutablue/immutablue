#!/bin/bash 
# 30-install-packages.sh
#
# This script is part of the Immutablue build process and is responsible for
# installing packages into the image. It runs after the repositories have been
# added in the 20-add-repos.sh script and before packages are removed in the
# 40-uninstall-packages.sh script.
#
# The script performs the following tasks:
# 1. Install packages from packages.yaml through the backend
# 2. Install pip packages
# 3. Install additional tools (hugo, fzf-git, starship, just, voxtype)
# 4. Variant extras: trueblue zerofs, kuberblue tooling, workshop n8n, nix
#
# Kernel, ZFS and NVIDIA work happens in the backend's own stages that run
# around this one (fedora-bootc: stages/29-kernel-zfs-nvidia.sh). A backend
# can also replace this stage entirely (gnomeos: skip_stages).

set -euxo pipefail

# Source the common functions and variables
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

# Get the lists of packages to install from packages.yaml
# These functions are defined in 99-common.sh
#
# Kernel, ZFS, NVIDIA and other release-package work that has to happen first
# is the backend's (fedora-bootc: stages/29-kernel-zfs-nvidia.sh), as are
# package files installed afterwards (stages/31-post-urls.sh).
pkgs=$(get_immutablue_packages)
pip_pkgs=$(get_immutablue_pip_packages)

# Install the main packages defined in packages.yaml
if [[ "$pkgs" != "" ]]
then
    # One package per line from get_yaml_array; one transaction for all of them
    mapfile -t pkg_list <<< "${pkgs}"
    backend_pkg_install "${pkg_list[@]}"
fi


# Install Python packages via pip
# This is skipped for nucleus (headless) and build-a-blue-workshop variants
if [[ "$pip_pkgs" != "" ]] && [[ "$(is_option_in_build_options nucleus)" == "${FALSE}" ]] && [[ "$(is_option_in_build_options build_a_blue_workshop)" == "${FALSE}" ]]
then 
    # Install pip packages to the system-wide Python installation
    pip3 install --prefix=/usr "$(for pkg in $pip_pkgs; do printf '%s ' "$pkg"; done)"
fi


# Install a modern build of Hugo for the documentation site
# Fedora repositories have an older version, so we download a newer release directly
immutablue_curl -fLo /tmp/hugo.tar.gz "${HUGO_RELEASE_URL}"
tar -xzf /tmp/hugo.tar.gz -C /usr/bin/ hugo
rm /tmp/hugo.tar.gz
# Verify the Hugo installation
hugo version

# Install fzf-git for improved git command-line experience
# This provides fuzzy finding for git commands
# https://github.com/junegunn/fzf-git.sh
immutablue_curl -fLo /usr/bin/fzf-git "${FZF_GIT_URL}"
chmod a+x /usr/bin/fzf-git

# Install Starship prompt for a better terminal experience
# https://starship.rs/
immutablue_curl -fLo "/tmp/install_starship.sh" "${STARSHIP_URL}"
sh "/tmp/install_starship.sh" -y -b "/usr/bin/"
rm "/tmp/install_starship.sh"

# Install just command runner
# We install this manually as it somehow breaks the iso installer 
# if its installed as a system level package
# Downloaded to a file rather than piped into tar: immutablue_curl retries by
# re-running curl, and a retry part-way through a pipe would hand tar a second
# overlapping stream on top of what it already read.
mkdir -p /tmp/just
immutablue_curl -fLo /tmp/just.tar.gz "${JUST_RELEASE_URL}"
tar xzf /tmp/just.tar.gz -C /tmp/just
mv /tmp/just/just /usr/bin/just
chmod +x /usr/bin/just
rm -rf /tmp/just /tmp/just.tar.gz

# Install voxtype (push-to-talk voice-to-text).
#
# GUI variants only: it types into a focused window, which a headless image has
# no use for. Nucleus and the workshop image are skipped for the same reason
# the pip block above skips them.
#
# The download is checksum-verified rather than taken on trust. Unlike the
# other binaries fetched here, this one holds the microphone open and injects
# synthetic keystrokes, so a silently substituted build is worth more to an
# attacker than a substituted `just` would be.
if [[ "$(is_option_in_build_options nucleus)" == "${FALSE}" ]] && [[ "$(is_option_in_build_options build_a_blue_workshop)" == "${FALSE}" ]]
then
    immutablue_curl -fLo /tmp/voxtype "${VOXTYPE_RELEASE_URL}"
    echo "${VOXTYPE_SHA256}  /tmp/voxtype" | sha256sum -c -
    install -D -m 0755 /tmp/voxtype /usr/bin/voxtype
    rm -f /tmp/voxtype
    voxtype --version
fi

# Special packages for trueblue builds
if [[ "$(is_option_in_build_options trueblue)" == "${TRUE}" ]]
then 
    immutablue_curl -fLo /tmp/zerofs.tar.gz "${ZEROFS_RELEASE_URL}"
    zerofs_file="zerofs-amd64"

    if [[ "${MARCH}" == "aarch64" ]]
    then 
        zerofs_file="zerofs-arm64"
    fi

    tar -xzf /tmp/zerofs.tar.gz -C /usr/bin/ "${zerofs_file}"
    mv "/usr/bin/${zerofs_file}" /usr/bin/zerofs
    chmod a+x /usr/bin/zerofs
fi


# Special packages for kuberblue builds
if [[ "$(is_option_in_build_options kuberblue)" == "${TRUE}" ]]
then
    # Chainsaw: Kubernetes integration test runner (kyverno/chainsaw)
    # Only installed in dev/staging builds (KUBERBLUE_DEV=1)
    if [[ "$(is_option_in_build_options kuberblue_dev)" == "${TRUE}" ]]
    then
        immutablue_curl -fLo /tmp/chainsaw.tar.gz "${CHAINSAW_RELEASE_URL}"
        tar -xzf /tmp/chainsaw.tar.gz -C /usr/bin/ chainsaw
        chmod a+x /usr/bin/chainsaw
        rm /tmp/chainsaw.tar.gz
    fi

    # Flux CLI: GitOps continuous delivery for Kubernetes
    immutablue_curl -fLo /tmp/flux.tar.gz "${FLUX_RELEASE_URL}"
    tar -xzf /tmp/flux.tar.gz -C /usr/bin/ flux
    chmod a+x /usr/bin/flux
    rm /tmp/flux.tar.gz

    # CRIO: container runtime for Kubernetes (GCS bucket, binary at cri-o/bin/crio)
    immutablue_curl -fLo /tmp/crio.tar.gz "${CRIO_RELEASE_URL}"
    tar -xzf /tmp/crio.tar.gz -C /usr/bin/ --strip-components=2 cri-o/bin/crio
    chmod a+x /usr/bin/crio
    mkdir -p /usr/lib/systemd/system
    tar -xzf /tmp/crio.tar.gz -C /usr/lib/systemd/system/ --strip-components=2 cri-o/contrib/crio.service
    rm /tmp/crio.tar.gz

    # SOPS: secret operations for Kubernetes (not in Fedora repos — binary release)
    immutablue_curl -fLo /usr/bin/sops "${SOPS_RELEASE_URL}"
    chmod a+x /usr/bin/sops
fi

# Special installation for the build-a-blue-workshop variant
# This installs n8n, a workflow automation tool
if [[ "$(is_option_in_build_options build_a_blue_workshop)" == "${TRUE}" ]]
then
    # The /root directory is a symlink in the container, but npm needs it to be a real directory
    # So we need to temporarily replace the symlink with a real directory
    
    # Remove the symlink
    unlink /root
    # Create a real directory
    mkdir -p /root
    # Create the directory for n8n installation
    mkdir -p /usr/libexec/immutablue/node
    # Install n8n
    npm install --global --prefix /usr/libexec/immutablue/node n8n
    # Create a symlink to make n8n accessible in the PATH
    ln -s /usr/libexec/immutablue/node/bin/n8n /usr/bin/n8n
    # Clean up: remove the temporary directory
    rm -rf /root 
    # Restore the original symlink
    ln -s var/roothome /root
fi


if [[ "$(is_option_in_build_options nix)" == "${TRUE}" ]]
then 
    # Remove the symlink
    unlink /root
    # Create a real directory
    mkdir -p /root

    # TODO: get this into its own file. however, it was 
    # causing gid mis-users if it put it under artifcats_nix/
    # and would create the gid as 968.
    # Create systemd-sysusers configuration for Nix users
    cat > /usr/lib/sysusers.d/nix.conf <<'EOF'
# Nix build group
g nixbld 30000

# Nix build users
u nixbld1  30001 "Nix build user 1"  /var/empty /sbin/nologin
u nixbld2  30002 "Nix build user 2"  /var/empty /sbin/nologin
u nixbld3  30003 "Nix build user 3"  /var/empty /sbin/nologin
u nixbld4  30004 "Nix build user 4"  /var/empty /sbin/nologin
u nixbld5  30005 "Nix build user 5"  /var/empty /sbin/nologin
u nixbld6  30006 "Nix build user 6"  /var/empty /sbin/nologin
u nixbld7  30007 "Nix build user 7"  /var/empty /sbin/nologin
u nixbld8  30008 "Nix build user 8"  /var/empty /sbin/nologin
u nixbld9  30009 "Nix build user 9"  /var/empty /sbin/nologin
u nixbld10 30010 "Nix build user 10" /var/empty /sbin/nologin
u nixbld11 30011 "Nix build user 11" /var/empty /sbin/nologin
u nixbld12 30012 "Nix build user 12" /var/empty /sbin/nologin
u nixbld13 30013 "Nix build user 13" /var/empty /sbin/nologin
u nixbld14 30014 "Nix build user 14" /var/empty /sbin/nologin
u nixbld15 30015 "Nix build user 15" /var/empty /sbin/nologin
u nixbld16 30016 "Nix build user 16" /var/empty /sbin/nologin
u nixbld17 30017 "Nix build user 17" /var/empty /sbin/nologin
u nixbld18 30018 "Nix build user 18" /var/empty /sbin/nologin
u nixbld19 30019 "Nix build user 19" /var/empty /sbin/nologin
u nixbld20 30020 "Nix build user 20" /var/empty /sbin/nologin
u nixbld21 30021 "Nix build user 21" /var/empty /sbin/nologin
u nixbld22 30022 "Nix build user 22" /var/empty /sbin/nologin
u nixbld23 30023 "Nix build user 23" /var/empty /sbin/nologin
u nixbld24 30024 "Nix build user 24" /var/empty /sbin/nologin
u nixbld25 30025 "Nix build user 25" /var/empty /sbin/nologin
u nixbld26 30026 "Nix build user 26" /var/empty /sbin/nologin
u nixbld27 30027 "Nix build user 27" /var/empty /sbin/nologin
u nixbld28 30028 "Nix build user 28" /var/empty /sbin/nologin
u nixbld29 30029 "Nix build user 29" /var/empty /sbin/nologin
u nixbld30 30030 "Nix build user 30" /var/empty /sbin/nologin
u nixbld31 30031 "Nix build user 31" /var/empty /sbin/nologin
u nixbld32 30032 "Nix build user 32" /var/empty /sbin/nologin

# Add build users to nixbld group
m nixbld1 nixbld
m nixbld2 nixbld
m nixbld3 nixbld
m nixbld4 nixbld
m nixbld5 nixbld
m nixbld6 nixbld
m nixbld7 nixbld
m nixbld8 nixbld
m nixbld9 nixbld
m nixbld10 nixbld
m nixbld11 nixbld
m nixbld12 nixbld
m nixbld13 nixbld
m nixbld14 nixbld
m nixbld15 nixbld
m nixbld16 nixbld
m nixbld17 nixbld
m nixbld18 nixbld
m nixbld19 nixbld
m nixbld20 nixbld
m nixbld21 nixbld
m nixbld22 nixbld
m nixbld23 nixbld
m nixbld24 nixbld
m nixbld25 nixbld
m nixbld26 nixbld
m nixbld27 nixbld
m nixbld28 nixbld
m nixbld29 nixbld
m nixbld30 nixbld
m nixbld31 nixbld
m nixbld32 nixbld
EOF

    # Install nix
    # Fetched to a file rather than piped into sh, for the same reason as just
    # above: a retried transfer must not be appended to bytes an interpreter
    # has already started executing.
    immutablue_curl --proto '=https' --tlsv1.2 -sSf -Lo /tmp/nix-installer.sh \
        https://install.determinate.systems/nix
    sh /tmp/nix-installer.sh install linux \
        --extra-conf "sandbox = false" \
        --init none \
        --no-confirm
    rm -f /tmp/nix-installer.sh
    
    # Create systemd service for nix-daemon
    cp /nix/var/nix/profiles/default/lib/systemd/system/nix-daemon.service /etc/systemd/system/
    
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
    nix-channel --update
    
    # Optional: Pre-install some Nix packages
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    nix_pkgs=$(get_nix_install_packages)
    nix-env -iA $(for pkg in ${nix_pkgs}; do printf '%s ' "${pkg}"; done)
 

    # Put the /nix under /etc/immutablue 
    # this is bind-mounted to /nix at runtime
    mkdir -p /etc/immutablue/nix
    mv /nix /etc/immutablue/nix/install
    mkdir -p /nix

    # Clean up: remove the temporary directory
    rm -rf /root 
    # Restore the original symlink
    ln -s var/roothome /root
fi
