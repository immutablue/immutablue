#!/bin/bash
# -----------------------------------
# 30-install-packages.sh (gnomeos)
#
# Replaces build/30-install-packages.sh for the gnomeos backend (backend.yaml
# skip_stages). Formerly build/distroless/install-packages.sh.
# -----------------------------------
# This script handles package installation for distroless builds
# which use GNOME OS as the base image instead of Fedora Silverblue.
#
# GNOME OS doesn't use dnf/rpm-ostree, so we must either:
# 1. Copy pre-built binaries (like from the devel stage)
# 2. Download and extract statically-linked tools
# 3. Rely on what's already in the GNOME OS base
# -----------------------------------

set -euxo pipefail

# Source the common functions and variables
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

echo "=== Installing packages for distroless build ==="

# -----------------------------------
# Install tools that have static/standalone releases
# -----------------------------------

# The release URLs and pins are the shared ones from build/99-common.sh, so a
# version bump there reaches this backend too (this file used to carry its own,
# older hugo pin), and downloads go through immutablue_curl's retry.

# Hugo (static binary release)
echo "Installing Hugo..."
immutablue_curl -fLo /tmp/hugo.tar.gz "${HUGO_RELEASE_URL}"
tar -xzf /tmp/hugo.tar.gz -C /usr/bin/ hugo
rm /tmp/hugo.tar.gz
hugo version || true

# fzf-git (shell script)
echo "Installing fzf-git..."
immutablue_curl -fLo /usr/bin/fzf-git "${FZF_GIT_URL}"
chmod a+x /usr/bin/fzf-git

# Starship (static binary)
echo "Installing Starship..."
immutablue_curl -fLo "/tmp/install_starship.sh" "${STARSHIP_URL}"
sh "/tmp/install_starship.sh" -y -b "/usr/bin/" || true
rm -f "/tmp/install_starship.sh"

# Just command runner (static binary). Downloaded to a file rather than piped
# into tar: a retried transfer must not be appended to a stream tar has
# already started reading.
echo "Installing just..."
mkdir -p /tmp/just
immutablue_curl -fLo /tmp/just.tar.gz "${JUST_RELEASE_URL}"
tar xzf /tmp/just.tar.gz -C /tmp/just
mv /tmp/just/just /usr/bin/just
chmod +x /usr/bin/just
rm -rf /tmp/just /tmp/just.tar.gz

# -----------------------------------
# Copy immutablue custom tools (if available)
# -----------------------------------

if [[ -d "/mnt-build-deps" ]]; then
    echo "Copying immutablue custom tools..."
    cp /mnt-build-deps/blue2go/blue2go /usr/bin/blue2go 2>/dev/null || true
    cp /mnt-build-deps/cigar/src/cigar /usr/bin/cigar 2>/dev/null || true
    cp /mnt-build-deps/zapper/zapper /usr/bin/zapper 2>/dev/null || true
fi

# -----------------------------------
# GNOME OS specific configuration
# -----------------------------------

echo "Configuring GNOME OS specific settings..."

# Create default user 'immutablue' with wheel group for sudo
# Password is 'immutablue' - change on first login!
echo "Creating default user..."
if command -v useradd &>/dev/null; then
    useradd -m -G wheel -s /bin/bash immutablue 2>/dev/null || true
    echo 'immutablue:immutablue' | chpasswd 2>/dev/null || true
fi

# Ensure GDM autologin is disabled and initial-setup runs
mkdir -p /etc/gdm
cat > /etc/gdm/custom.conf << 'GDMEOF'
[daemon]
WaylandEnable=true
AutomaticLoginEnable=false

[security]

[xdmcp]

[chooser]

[debug]
GDMEOF

# Create immutablue branding/identification
mkdir -p /usr/share/immutablue
cat > /usr/share/immutablue/image-info.json << EOF
{
    "image-name": "immutablue-distroless",
    "image-flavor": "distroless",
    "image-vendor": "immutablue",
    "base-image-name": "gnome-build-meta:gnomeos-nightly"
}
EOF

# Update os-release to identify as Immutablue
if [[ -f "/etc/os-release" ]]; then
    # Backup original
    cp /etc/os-release /etc/os-release.gnomeos || true

    # Append Immutablue identification
    cat >> /etc/os-release << EOF

# Immutablue Distroless
IMMUTABLUE_VARIANT="distroless"
IMMUTABLUE_BASE="gnomeos"
EOF
fi

echo "=== Distroless package installation complete ==="
