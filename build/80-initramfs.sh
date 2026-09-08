#!/bin/bash
set -euxo pipefail
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

# -----------------------------------
# Regenerate the initramfs so it reflects this image.
#
# The base image ships an initramfs generated during Fedora's own compose,
# long before this build copies anything into /usr or /etc. Nothing
# downstream rebuilds it: bootc *copies* /usr/lib/modules/$kver/initramfs.img
# to /boot at deploy time, it does not regenerate it. So until this script
# existed, every file the build placed in /usr or /etc that the initrd reads
# was silently ignored for the whole early-boot phase.
#
# The visible symptom was the boot splash. Immutablue ships
# /etc/plymouth/plymouthd.conf (Theme=spinner) and a branded
# /usr/share/plymouth/themes/spinner/watermark.png. Neither reached the
# initrd, so plymouth fell back to plymouthd.defaults (Theme=bgrt) with
# Fedora's watermark and the Immutablue logo never appeared at boot.
# Shutdown looked correct because by then plymouth has been restarted from
# the real root, which is why this presented for two years as the oddly
# specific "logo on shutdown, no logo on boot".
#
# The LTS variant was accidentally correct. It removes and reinstalls the
# kernel in 30-install-packages.sh, and that RPM transaction runs
# kernel-install -> dracut -- after 10-copy.sh has already landed the
# overrides. Nothing about LTS was special; it just happened to rebuild the
# initramfs late enough. Doing it explicitly here makes every variant
# correct on purpose rather than by accident, and picks up 50-remove-files.sh
# and 60-services.sh as well, which even the LTS path ran too early to see.
# -----------------------------------

# Distroless uses a different base entirely and ships no kernel.
if [[ "$(is_option_in_build_options distroless)" == "${TRUE}" ]]
then
    echo "=== Distroless build: skipping initramfs regeneration ==="
    exit 0
fi

if [[ "$(is_skipped initramfs)" == "${TRUE}" ]]
then
    echo "=== SKIP=initramfs: leaving the base image initramfs in place ==="
    exit 0
fi

if ! command -v dracut &>/dev/null
then
    echo "WARNING: dracut not found; leaving the initramfs untouched"
    exit 0
fi

# Collect every real kernel in the image. Globbing /usr/lib/modules is used
# rather than querying rpm because the package name differs between variants
# (kernel vs kernel-longterm) and a module directory without a vmlinuz is not
# a bootable kernel. Debug kernels are skipped; 90-post.sh deletes them.
kernel_versions=()
for moddir in /usr/lib/modules/*/
do
    kver="$(basename "${moddir}")"
    [[ "${kver}" == *+debug ]] && continue
    [[ -f "${moddir}/vmlinuz" ]] || continue
    kernel_versions+=("${kver}")
done

if [[ ${#kernel_versions[@]} -eq 0 ]]
then
    echo "WARNING: no kernel found under /usr/lib/modules; skipping initramfs regeneration"
    exit 0
fi

for kver in "${kernel_versions[@]}"
do
    initramfs="/usr/lib/modules/${kver}/initramfs.img"

    echo "=== Regenerating initramfs for ${kver} ==="

    # Record the module set the inherited initramfs was built with. It is the
    # only reference for what this image needs in order to boot, and it is
    # gone the moment dracut overwrites the file.
    mods_before="$(mktemp)"
    mods_after="$(mktemp)"
    lsinitrd "${initramfs}" 2>/dev/null \
        | sed -n '/^dracut modules:/,/^===/p' | grep -v '^===' | tail -n +2 | sort > "${mods_before}"

    # --add ostree is REQUIRED and must not be dropped. The 50ostree dracut
    # module returns 255 from its check(), which means "only if explicitly
    # requested" -- it is never pulled in automatically. Without it the
    # initrd has no ostree-prepare-root and the image does not boot at all.
    #
    # --no-hostonly is defensive. /usr/lib/dracut/dracut.conf.d already sets
    # hostonly=no for Atomic, but a hostonly initramfs generated inside a
    # build container would be built against the builder's hardware and fail
    # on every real machine, so it is not left to configuration.
    #
    # Everything else -- reproducible builds, do_strip=no, the tpm2-tss and
    # systemd-pcrphase modules that LUKS unlocking needs -- comes from the
    # base image's dracut.conf.d and is deliberately not overridden here.
    dracut \
        --force \
        --no-hostonly \
        --add ostree \
        --kver "${kver}" \
        "${initramfs}"

    # -----------------------------------
    # Verify the result before shipping it.
    #
    # A silently wrong initramfs is exactly the failure this script exists to
    # correct, and it is invisible until someone reboots a real machine, so
    # the build fails here instead.
    # -----------------------------------

    lsinitrd "${initramfs}" 2>/dev/null \
        | sed -n '/^dracut modules:/,/^===/p' | grep -v '^===' | tail -n +2 | sort > "${mods_after}"

    # Nothing the inherited initramfs shipped with may disappear. Checking the
    # whole set rather than a hand-written list of important modules is what
    # makes this safe across variants: it covers ostree everywhere, zfs on
    # trueblue, the crypt/tpm2-tss/systemd-pcrphase chain that LUKS unlocking
    # needs, and anything a future variant adds, without anyone remembering to
    # extend this check.
    if ! lost="$(comm -23 "${mods_before}" "${mods_after}")" || [[ -n "${lost}" ]]
    then
        echo "ERROR: regenerating the initramfs for ${kver} dropped dracut modules:" >&2
        while IFS= read -r lost_mod
        do
            echo "         ${lost_mod}" >&2
        done <<< "${lost}"
        echo "       refusing to ship an image that may not boot" >&2
        rm -f "${mods_before}" "${mods_after}"
        exit 1
    fi

    # Checked explicitly as well as by the comparison above, because a base
    # image that somehow lacked it would make the comparison vacuously true.
    # Without ostree the initrd cannot mount the deployment root at all.
    if ! grep -qx "ostree" "${mods_after}"
    then
        echo "ERROR: regenerated initramfs for ${kver} has no ostree module -- refusing to ship an unbootable image" >&2
        rm -f "${mods_before}" "${mods_after}"
        exit 1
    fi

    rm -f "${mods_before}" "${mods_after}"

    # If plymouth is configured, confirm its configuration actually made it in.
    if [[ -f /etc/plymouth/plymouthd.conf ]] && command -v lsinitrd &>/dev/null
    then
        want_theme="$(awk -F= '/^[[:space:]]*Theme[[:space:]]*=/ { gsub(/[[:space:]]/, "", $2); print $2 }' /etc/plymouth/plymouthd.conf)"

        if [[ -n "${want_theme}" ]]
        then
            got_theme="$(lsinitrd -f etc/plymouth/plymouthd.conf "${initramfs}" 2>/dev/null \
                | awk -F= '/^[[:space:]]*Theme[[:space:]]*=/ { gsub(/[[:space:]]/, "", $2); print $2 }')"

            if [[ "${got_theme}" != "${want_theme}" ]]
            then
                echo "ERROR: initramfs for ${kver} has plymouth theme '${got_theme}', expected '${want_theme}'" >&2
                echo "       the boot splash would silently fall back to the distribution default" >&2
                exit 1
            fi

            echo "initramfs ${kver}: plymouth theme '${got_theme}' confirmed"
        fi
    fi

    echo "=== initramfs for ${kver}: $(stat -c%s "${initramfs}") bytes ==="
done
