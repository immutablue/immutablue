+++
title = 'immutablue-settings'
weight = 2
+++

# immutablue-settings

Query configuration values from the Immutablue settings system.

## Synopsis

```bash
immutablue-settings <jq-path>
```

## Description

`immutablue-settings` retrieves configuration values from the hierarchical settings system. It uses jq-style paths to query YAML configuration files.

Settings are loaded in order of precedence:
1. `~/.config/immutablue/settings.yaml` (user settings, highest priority)
2. `/etc/immutablue/settings.yaml` (system settings)
3. `/usr/immutablue/settings.yaml` (default settings, lowest priority)

## Arguments

| Argument | Description |
|----------|-------------|
| `<jq-path>` | A jq-style path to the setting (e.g., `.immutablue.profile.enable_starship`) |

## Examples

### Query a boolean setting

```bash
$ immutablue-settings .immutablue.profile.enable_starship
true
```

### Query a string setting

```bash
$ immutablue-settings .immutablue.header.has_internet_host_v4
9.9.9.9
```

### Query a nested setting

```bash
$ immutablue-settings .services.syncthing.tailscale_mode
true
```

### Use in a script

```bash
#!/bin/bash
if [[ "$(immutablue-settings .immutablue.profile.enable_starship)" == "true" ]]; then
    eval "$(starship init bash)"
fi
```

## Common Settings

| Path | Default | Description |
|------|---------|-------------|
| `.immutablue.run_bootc_update` | `true` | Update bootc during `immutablue-update` |
| `.immutablue.profile.enable_starship` | `true` | Enable Starship prompt |
| `.immutablue.profile.ulimit_nofile` | `524288` | File descriptor limit |
| `.immutablue.header.preferred_terminal` | `auto` | Preferred terminal emulator |

See [Settings Reference](/user-guide/settings/) for the complete list of available settings.

## Exit Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | Setting not found or invalid path |

## See Also

- [Settings Reference](/user-guide/settings/)
- [immutablue-header.sh](/system-components/header-library/)
