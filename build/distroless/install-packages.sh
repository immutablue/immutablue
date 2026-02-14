#!/bin/bash
# -----------------------------------
# Distroless Package Installation
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

# Hugo (static binary release)
echo "Installing Hugo..."
HUGO_RELEASE_URL_x86_64="https://github.com/gohugoio/hugo/releases/download/v0.148.1/hugo_extended_withdeploy_0.148.1_linux-amd64.tar.gz"
HUGO_RELEASE_URL_aarch64="https://github.com/gohugoio/hugo/releases/download/v0.148.1/hugo_extended_withdeploy_0.148.1_linux-arm64.tar.gz"
MARCH="$(uname -m)"

if [[ "${MARCH}" == "aarch64" ]]; then
    HUGO_RELEASE_URL="${HUGO_RELEASE_URL_aarch64}"
else
    HUGO_RELEASE_URL="${HUGO_RELEASE_URL_x86_64}"
fi

curl -Lo /tmp/hugo.tar.gz "${HUGO_RELEASE_URL}"
tar -xzf /tmp/hugo.tar.gz -C /usr/bin/ hugo
rm /tmp/hugo.tar.gz
hugo version || true

# fzf-git (shell script)
echo "Installing fzf-git..."
FZF_GIT_URL="https://raw.githubusercontent.com/junegunn/fzf-git.sh/refs/heads/main/fzf-git.sh"
curl -Lo /usr/bin/fzf-git "${FZF_GIT_URL}"
chmod a+x /usr/bin/fzf-git

# Starship (static binary)
echo "Installing Starship..."
STARSHIP_URL="https://starship.rs/install.sh"
curl -Lo "/tmp/install_starship.sh" "${STARSHIP_URL}"
sh "/tmp/install_starship.sh" -y -b "/usr/bin/" || true
rm -f "/tmp/install_starship.sh"

# Just command runner (static binary)
echo "Installing just..."
JUST_RELEASE_URL="https://github.com/casey/just/releases/download/1.42.3/just-1.42.3-$(uname -m)-unknown-linux-musl.tar.gz"
mkdir -p /tmp/just
curl -L "${JUST_RELEASE_URL}" | tar xz -C /tmp/just
mv /tmp/just/just /usr/bin/just
chmod +x /usr/bin/just
rm -rf /tmp/just

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
