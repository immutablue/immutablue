#!/bin/bash
# 36-ffmpeg-freeworld.sh
#
# Swaps Fedora's patent-stripped ffmpeg-free family for RPM Fusion's
# full ffmpeg.  Without this, libavcodec cannot decode H.264 Main /
# High profile or HEVC --- which is what nearly every IP camera, screen
# recording, and Blu-ray rip uses.
#
# Downstream impact:
#   - cmacs-video's #+BEGIN_VIDEO blocks and cmacs-video-open-url
#     against Unifi Protect / Reolink / Amcrest / Hikvision / Axis
#     cameras reach state=paused but never produce frames.
#     decodebin logs "Missing element: H.264 (Main Profile) decoder".
#   - mpv / VLC / Firefox playback of H.264 Main/High videos silently
#     fails or falls back to software decode of a degraded variant.
#   - gst-plugins-libav's avdec_h264 / avdec_h265 elements are not
#     registered.
#
# Order:
#   30-install-packages.sh installs the RPM Fusion release packages
#     (from packages.yaml :: rpm_url[FEDORA_VERSION]).
#   35-mesa-freeworld.sh swaps the Mesa VA/VDPAU drivers.
#   --> this script then swaps ffmpeg-free for full ffmpeg.
#   40-uninstall-packages.sh runs after.

set -euxo pipefail
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

# Distroless builds use GNOME OS base and have no dnf5
if [[ "$(is_option_in_build_options distroless)" == "${TRUE}" ]]; then
    echo "=== Distroless build: skipping ffmpeg freeworld swap ==="
    exit 0
fi

# Only swap if ffmpeg-free is actually installed.  It usually is via
# transitive deps (GNOME pulls it in), but minimal images may not have
# it.  Without the source package present, dnf swap is a no-op anyway.
if rpm -q ffmpeg-free >/dev/null 2>&1; then
    # dnf5 swap auto-resolves the entire libav* family:
    #   ffmpeg-free     -> ffmpeg
    #   libavcodec-free -> libavcodec
    #   libavformat-free -> libavformat
    #   libavfilter-free -> libavfilter
    #   libavdevice-free -> libavdevice
    #   libavutil-free   -> libavutil
    #   libswscale-free  -> libswscale
    #   libswresample-free -> libswresample
    # --allowerasing is required because the -free family has a Conflicts
    # tag against the unsuffixed package and vice versa.
    dnf5 -y swap ffmpeg-free ffmpeg --allowerasing
else
    echo "=== ffmpeg-free not installed; nothing to swap ==="
fi

# Install ffmpeg-devel here rather than in 30-install-packages.sh.
#
# ffmpeg-devel only exists in RPM Fusion and pulls in the full
# ffmpeg-libs, which carries a Conflicts against Fedora's patent-stripped
# libav*-free family (libswscale-free, etc.).  Installing it in the
# general package list (step 30) runs *before* the swap above, while the
# -free libs are still present, so dnf cannot resolve the transaction and
# the build aborts.  Doing it here guarantees the full ffmpeg-libs is
# already in place.  --allowerasing covers the minimal-image case where
# the -free libs linger but the ffmpeg-free metapackage was never pulled
# in (swap branch skipped).
dnf5 -y install --allowerasing ffmpeg-devel
