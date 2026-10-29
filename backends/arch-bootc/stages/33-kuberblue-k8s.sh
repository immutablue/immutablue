#!/bin/bash
set -euxo pipefail
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

# 33-kuberblue-k8s.sh (arch-bootc)
#
# Kubernetes and CRI-O for KUBERBLUE=1 on Arch, at the same minor version
# Fedora's kuberblue uses.
#
# Arch packages whatever Kubernetes is newest, and a rolling image rebuild
# would carry kubelet across minor versions under a running cluster: kubelet
# may never be newer than the API server, and kubeadm upgrades one minor at a
# time. So the version is pinned the way Fedora pins it, by taking it FROM
# Fedora: packages.yaml's rpm_kuberblue.<current Fedora release> names
# kubernetes<major>.<minor> (kubernetes1.36 for 44), and that minor is
# installed here. When the current Fedora release moves (45), the next Arch
# image follows to the same minor, in step with Fedora's kuberblue.
#
# The binaries are upstream's static release builds, checked against the
# checksums published next to them:
#
#   kubeadm, kubelet, kubectl  dl.k8s.io, latest patch of the minor
#                              (release/stable-<minor>.txt)
#   CRI-O bundle               storage.googleapis.com/cri-o, latest patch of
#                              the same minor (latest-<minor>.txt): crio,
#                              pinns, conmon(rs), crun, runc and the CNI
#                              plugins
#   crictl                     cri-tools' release, latest patch of the minor
#
# kubelet's unit and kubeadm's drop-in are the ones the official packages
# ship, vendored in backends/arch-bootc/kuberblue/.

if [[ "$(is_option_in_build_options kuberblue)" != "${TRUE}" ]]
then
    exit 0
fi

K8S_RELEASE_URL="https://dl.k8s.io/release"
CRIO_URL="https://storage.googleapis.com/cri-o"
CRI_TOOLS_URL="https://github.com/kubernetes-sigs/cri-tools"
UNITS_DIR="${INSTALL_DIR}/backends/arch-bootc/kuberblue"


# -----------------------------------
# The minor version, from Fedora's current kuberblue list.
# -----------------------------------
if [[ -z "${FEDORA_CURRENT:-}" ]]
then
    echo "ERROR: FEDORA_CURRENT is not set; the Makefile passes it (CURRENT in makefiles/00-variables.mk)" >&2
    exit 1
fi

k8s_minor="$(yq ".immutablue.rpm_kuberblue.\"${FEDORA_CURRENT}\" // [] | .[]" < "${PACKAGES_YAML}" \
    | sed -nE 's/^kubernetes([0-9]+\.[0-9]+)$/\1/p' | head -n 1)"
if [[ -z "${k8s_minor}" ]]
then
    echo "ERROR: packages.yaml rpm_kuberblue.${FEDORA_CURRENT} names no kubernetes<major>.<minor> package" >&2
    exit 1
fi

case "$(uname -m)" in
    x86_64) k8s_arch="amd64" ;;
    aarch64) k8s_arch="arm64" ;;
    *) echo "ERROR: no Kubernetes release binaries for $(uname -m)" >&2; exit 1 ;;
esac

k8s_version="$(immutablue_curl -fsSL "${K8S_RELEASE_URL}/stable-${k8s_minor}.txt")"
crio_version="$(immutablue_curl -fsSL "${CRIO_URL}/latest-${k8s_minor}.txt")"
for version in "${k8s_version}" "${crio_version}"
do
    if [[ ! "${version}" =~ ^v${k8s_minor//./\\.}\.[0-9]+$ ]]
    then
        echo "ERROR: upstream reported '${version}' for Kubernetes ${k8s_minor}" >&2
        exit 1
    fi
done
echo "kuberblue: Kubernetes ${k8s_version}, CRI-O ${crio_version} (Fedora ${FEDORA_CURRENT}'s ${k8s_minor})"

# Recorded for the image's own checks (tests/kuberblue/validate_kuberblue_container.c):
# an Arch image has no Fedora VERSION_ID to look the minor up by.
echo "${k8s_minor}" > "${INSTALL_DIR}/kuberblue-k8s-minor"

work_dir="$(mktemp -d)"


# -----------------------------------
# kubeadm, kubelet, kubectl.
# -----------------------------------
for binary in kubeadm kubelet kubectl
do
    url="${K8S_RELEASE_URL}/${k8s_version}/bin/linux/${k8s_arch}/${binary}"
    immutablue_curl -fsSLo "${work_dir}/${binary}" "${url}"
    expected="$(immutablue_curl -fsSL "${url}.sha256")"
    echo "${expected}  ${work_dir}/${binary}" | sha256sum -c -
    install -m 0755 "${work_dir}/${binary}" "/usr/bin/${binary}"
done

install -D -m 0644 "${UNITS_DIR}/kubelet.service" /usr/lib/systemd/system/kubelet.service
install -D -m 0644 "${UNITS_DIR}/10-kubeadm.conf" /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf


# -----------------------------------
# CRI-O, from its release bundle's own installer.
#
# Everything goes under /usr: /usr/local and /opt are symlinks into /var on a
# bootc image, so files installed there would not ship. CNI plugins go to
# /usr/libexec/cni (Fedora's location); /opt/cni/bin stays in CRI-O's
# plugin_dirs for the plugins Cilium installs at runtime.
# -----------------------------------
tarball="cri-o.${k8s_arch}.${crio_version}.tar.gz"
immutablue_curl -fsSLo "${work_dir}/${tarball}" "${CRIO_URL}/artifacts/${tarball}"
immutablue_curl -fsSLo "${work_dir}/${tarball}.sha256sum" "${CRIO_URL}/artifacts/${tarball}.sha256sum"
(cd "${work_dir}" && sha256sum -c "${tarball}.sha256sum")
tar -xzf "${work_dir}/${tarball}" -C "${work_dir}"

(
    cd "${work_dir}/cri-o"
    PREFIX=/usr \
        OPT_CNI_BIN_DIR=/usr/libexec/cni \
        SYSTEMDDIR=/usr/lib/systemd/system \
        bash ./install
)

mkdir -p /etc/crio/crio.conf.d
cat > /etc/crio/crio.conf.d/20-immutablue-cni.conf <<'EOF'
# Immutablue (arch-bootc): the bundle's CNI plugins live in /usr/libexec/cni
# (/opt is in /var on a bootc image); Cilium installs its own to /opt/cni/bin.
[crio.network]
plugin_dirs = [
    "/usr/libexec/cni",
    "/opt/cni/bin",
]
EOF

# crictl at the same minor too. The CRI-O bundle carries whatever crictl its
# release branch pins (1.36.7 ships crictl 1.37), while Fedora's kuberblue
# pins cri-tools<minor>; the latest cri-tools v<minor>.N tag (read from the
# repository's refs, which needs no API token) replaces the bundle's.
crictl_version="$(immutablue_curl -fsSL "${CRI_TOOLS_URL}.git/info/refs?service=git-upload-pack" \
    | grep -aoE "refs/tags/v${k8s_minor//./\\.}\.[0-9]+\$" | sed 's|refs/tags/||' | sort -V | tail -n 1)"
if [[ -z "${crictl_version}" ]]
then
    echo "ERROR: no cri-tools release for Kubernetes ${k8s_minor}" >&2
    exit 1
fi
crictl_tarball="crictl-${crictl_version}-linux-${k8s_arch}.tar.gz"
crictl_url="${CRI_TOOLS_URL}/releases/download/${crictl_version}/${crictl_tarball}"
immutablue_curl -fsSLo "${work_dir}/${crictl_tarball}" "${crictl_url}"
echo "$(immutablue_curl -fsSL "${crictl_url}.sha256")  ${work_dir}/${crictl_tarball}" | sha256sum -c -
tar -xzf "${work_dir}/${crictl_tarball}" -C "${work_dir}" crictl
install -m 0755 "${work_dir}/crictl" /usr/bin/crictl

# The bundle installer records what it installed in the builder's home.
rm -f "${HOME:-/root}/.crio-install"
rm -rf "${work_dir}"


# -----------------------------------
# Verify.
# -----------------------------------
kubeadm version -o short
kubelet --version
kubectl version --client
crio --version
crictl --version
