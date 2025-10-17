# Add Nix to the system profile
# this will put nix in the $PATH
if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]
then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

