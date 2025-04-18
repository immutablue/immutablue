+++
date = '2025-04-18T15:30:00-05:00'
draft = false
title = 'Maintenance and Troubleshooting'
+++

# Immutablue Maintenance and Troubleshooting

This guide covers common maintenance tasks and troubleshooting steps for Immutablue systems.

## System Maintenance

### Regular Updates

To keep your Immutablue system up to date, run the following command periodically:

```bash
immutablue update
```

This will update all components of the system, including:
- The core system image (via rpm-ostree)
- Flatpak applications
- Distrobox containers
- Homebrew packages (on x86_64 systems)

If the core system is updated, you will need to reboot to use the new system image. To automate this, use:

```bash
REBOOT=1 immutablue update
```

### System Rollbacks

One advantage of rpm-ostree's transactional updates is the ability to easily roll back to a previous system state if something goes wrong.

To see available deployments:

```bash
rpm-ostree status
```

To roll back to the previous deployment:

```bash
sudo rpm-ostree rollback
sudo systemctl reboot
```

### Manual System Cleaning

While Immutablue generally manages its own cleanup, you can manually clean up unused deployments:

```bash
sudo rpm-ostree cleanup -m
```

This removes all deployments except the current one and the previous one.

### Flatpak Maintenance

To remove unused Flatpak runtimes:

```bash
flatpak uninstall --unused
```

### Homebrew Cleanup

To clean up old Homebrew packages:

```bash
brew cleanup
```

## Common Troubleshooting

### Boot Problems

If your system fails to boot properly, you can select an older deployment from the bootloader menu (typically accessible by pressing SPACE during boot for GRUB).

#### Emergency Shell

If you need to access an emergency shell, add `systemd.debug-shell=1` to the kernel command line in the bootloader menu.

### Network Issues

#### Checking Network Status

To check the status of your network interfaces:

```bash
nmcli device status
```

#### Restarting NetworkManager

If you're experiencing network issues, try restarting NetworkManager:

```bash
sudo systemctl restart NetworkManager
```

### Display and Graphics Issues

#### NVIDIA-specific Issues

If you're using a system with NVIDIA graphics and experiencing issues:

1. Check if the NVIDIA kernel module is loaded:
   ```bash
   lsmod | grep nvidia
   ```

2. Check the NVIDIA kernel module status:
   ```bash
   dkms status
   ```

3. If necessary, rebuild the kernel module:
   ```bash
   sudo dkms autoinstall
   ```

### Reinstalling First-Boot Services

If you need to re-run the first-boot configuration, for example after making significant changes:

```bash
sudo rm /etc/immutablue/setup/did_first_boot /etc/immutablue/setup/did_first_boot_graphical
rm $HOME/.config/.immutablue_did_first_login
sudo systemctl unmask immutablue-first-boot.service
systemctl --user unmask immutablue-first-login.service
sudo reboot
```

This will clear the first-boot flags and unmask the services, allowing them to run again on the next boot.

### Package Management Issues

#### RPM-OSTree Issues

If you encounter problems with rpm-ostree operations:

1. Check the status of the system:
   ```bash
   rpm-ostree status
   ```

2. If an operation is stuck, try canceling it:
   ```bash
   sudo rpm-ostree cancel
   ```

3. For more serious issues, you may need to clear the cache:
   ```bash
   sudo rm -rf /var/cache/rpm-ostree
   ```

#### Flatpak Issues

If you have problems with Flatpak applications:

1. Update the Flatpak system:
   ```bash
   flatpak update
   ```

2. If an application is not working properly, try re-installing it:
   ```bash
   flatpak uninstall --user <app-id>
   flatpak install --user <app-id>
   ```

3. Check for Flatpak permissions issues:
   ```bash
   flatpak permissions
   ```

4. Reset Flatpak permissions for an application:
   ```bash
   flatpak permission-reset <app-id>
   ```

#### Distrobox Issues

If you have problems with Distrobox containers:

1. List existing containers:
   ```bash
   distrobox list
   ```

2. Stop a running container:
   ```bash
   distrobox stop <container-name>
   ```

3. Remove a problematic container:
   ```bash
   distrobox rm <container-name>
   ```

4. Create a new container:
   ```bash
   distrobox create <container-name> -i <image>
   ```

### System Information and Logs

When troubleshooting, it's often helpful to gather system information and logs.

#### System Information

```bash
immutablue-settings .immutablue
```

#### Journal Logs

To view logs for system services:

```bash
journalctl -b -u <service-name>
```

For example, to view first-boot service logs:

```bash
journalctl -b -u immutablue-first-boot.service
```

For user services:

```bash
journalctl --user -b -u <service-name>
```

#### Boot Logs

To view boot logs:

```bash
journalctl -b
```

### Advanced Troubleshooting

#### Accessing the Host from Distrobox

You can access the host system from within a Distrobox container using the `distrobox-host-exec` command:

```bash
distrobox-host-exec <command>
```

This is useful for performing host-system operations from within the container.

#### Debugging systemd Units

To debug systemd units:

1. View the status of a unit:
   ```bash
   systemctl status <unit-name>
   ```

2. For user units:
   ```bash
   systemctl --user status <unit-name>
   ```

3. To see all failed units:
   ```bash
   systemctl --failed
   ```

#### Testing with a Fresh User

If you're experiencing user-specific issues, create a new user to test:

```bash
sudo useradd -m testuser
sudo passwd testuser
```

Then log in as that user to see if the issue persists, which can help determine if it's a user configuration problem.

## Getting Help

If you can't resolve an issue using this guide, consider reaching out to the community:

- [File an issue on GitLab](https://gitlab.com/immutablue/immutablue/-/issues/new)
- Ask for help on the Immutablue community channels

When asking for help, include:
- A clear description of the problem
- Steps to reproduce the issue
- Relevant system information using the `immutablue sysinfo` command
- Any error messages or logs

The `immutablue sysinfo` command provides comprehensive information about your system that is useful for diagnosing issues:

```bash
# Save system information to a file
immutablue sysinfo > immutablue-sysinfo.txt

# Or pipe it directly to less to view it
immutablue sysinfo | less
```

This command collects information about your system configuration, installed packages, enabled services, and much more. Since the output can be quite verbose, it's recommended to save it to a file and attach that file to your issue report.