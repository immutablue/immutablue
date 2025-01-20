+++
date = '2025-01-19T21:02:23-05:00'
draft = false
title = 'Settings Yaml'
+++

# Settings.yaml 

The Immutablue `settings.yaml` is a type of runtime-settings file that is used for various parts of the system. There exist three locations that are supported, and are evaluated in this order:
```
${HOME}/.config/immutablue/settings.yaml
/etc/immutablue/settings.yaml
/usr/immutablue/settings.yaml
```
That is, if a specific setting is locatated in the `${HOME}` file, and the one located in `/usr`, the `${HOME}` value is used. This provides a "fall-through" approach.

## /usr/immutablue/settings.yaml
Immutablue default settings are located in the last file (`/usr/immutablue/settings.yaml`). These can also be overwritten downstream in an `immutablue-custom` build.

## /etc/immutablue/settings.yaml
System wide settings are located in the `/etc` location (`/etc/immutablue/settings.yaml`).

## ${HOME}/.config/immutablue/settings.yaml 
User specific overrides can be stored here. This will only be used for non-sudo current user things.


# Querying Settings 

Immutablue ships the `immutablue-settings` binary. It expects one parameter which is the key to yaml value you would like to extract:
```bash
immutablue-settings .services.syncthing.tailscale-mode
```

