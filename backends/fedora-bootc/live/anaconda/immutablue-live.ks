# Kickstart sections every live-ISO install runs, interactive or not.
# Appended to /usr/share/anaconda/interactive-defaults.ks by build-live.sh,
# after the ostreecontainer line; build-live.sh replaces @BASE_IMAGE@ with the
# image's registry reference. A chrooted %post's --log path is inside the
# installed system, so those log straight to its /var/log; the --nochroot
# section copies the installer's own logs (from the live /tmp) there too.

%pre
mkdir -p /tmp/immutablue-install-logs
%end

# A previous Fedora-family install leaves EFI/fedora on a reused ESP; the
# image's shim and GRUB must replace it, not merge into it. Must match
# efi_dir in /etc/anaconda/conf.d/90-immutablue.conf.
%pre-install --erroronfail --log=/tmp/immutablue-install-logs/efi-dir.log
rm -rf /mnt/sysroot/boot/efi/EFI/fedora
%end

# The live root has no SELinux labels (it is the image's root as a plain
# filesystem), so relabel the installed policy store explicitly.
%post --erroronfail --log=/var/log/immutablue-install-selinux-labels.log
setenforce 0 || true
restorecon -R /etc/selinux
%end

# Installed from the OCI layout on the ISO; updates come from the registry
%post --erroronfail --log=/var/log/immutablue-install-bootc-switch.log
bootc switch --mutate-in-place --transport registry @BASE_IMAGE@
%end

%post --nochroot --log=/tmp/immutablue-install-logs/copy-logs.log
mkdir -p /mnt/sysimage/var/log/immutablue-install
cp -a /tmp/immutablue-install-logs/. /mnt/sysimage/var/log/immutablue-install/ || true
cp -a /tmp/anaconda.log /tmp/storage.log /tmp/packaging.log /mnt/sysimage/var/log/immutablue-install/ 2> /dev/null || true
%end
