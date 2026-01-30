+++
title = 'Profile Configuration'
weight = 4
+++

# Profile Configuration

Immutablue customizes the shell environment via `/etc/profile.d/25-immutablue.sh`.

## Location

```
/etc/profile.d/25-immutablue.sh
```

This script runs for all users during login shell initialization.

## Features

### File Descriptor Limits

Sets the ulimit for non-root users:

```bash
ulimit -n 524288
```

Configurable via:
```yaml
# settings.yaml
immutablue:
  profile:
    ulimit_nofile: 524288
```

### Starship Prompt

Enables the Starship prompt by default:

```bash
eval "$(starship init bash)"
```

Configurable via:
```yaml
# settings.yaml
immutablue:
  profile:
    enable_starship: true
```

### Homebrew Bash Completions

Sources bash completions from Homebrew:

```bash
for f in /home/linuxbrew/.linuxbrew/etc/bash_completion.d/*; do
    source "${f}"
done
```

Configurable via:
```yaml
# settings.yaml
immutablue:
  profile:
    enable_brew_bash_completions: true
```

### fzf-git Integration

Sources fzf-git for enhanced git operations with fzf:

```bash
source /usr/bin/fzf-git
```

Configurable via:
```yaml
# settings.yaml
immutablue:
  profile:
    enable_sourcing_fzf_git: true
```

## All Profile Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `.immutablue.profile.ulimit_nofile` | `524288` | Max open file descriptors |
| `.immutablue.profile.enable_starship` | `true` | Enable Starship prompt |
| `.immutablue.profile.enable_brew_bash_completions` | `true` | Enable Homebrew completions |
| `.immutablue.profile.enable_sourcing_fzf_git` | `true` | Enable fzf-git integration |

## Customizing

To override these settings, create a user settings file:

```yaml
# ~/.config/immutablue/settings.yaml
immutablue:
  profile:
    enable_starship: false        # Disable Starship
    ulimit_nofile: 1048576        # Increase file limit
```

## Execution Order

Profile scripts run in alphanumeric order. The `25-` prefix ensures Immutablue's script runs:
- After system defaults (typically `00-` to `20-`)
- Before user customizations (typically `90-` and above)

## Checking Current Settings

```bash
# Check if Starship is enabled
immutablue-settings .immutablue.profile.enable_starship

# Check ulimit setting
immutablue-settings .immutablue.profile.ulimit_nofile

# Check current ulimit
ulimit -n
```

## Troubleshooting

### Starship not loading

1. Check if enabled:
   ```bash
   immutablue-settings .immutablue.profile.enable_starship
   ```

2. Check if Starship is installed:
   ```bash
   which starship
   ```

3. Ensure you're in a bash shell:
   ```bash
   echo $BASH_VERSION
   ```

### Completions not working

1. Check if enabled:
   ```bash
   immutablue-settings .immutablue.profile.enable_brew_bash_completions
   ```

2. Check if Homebrew is installed:
   ```bash
   ls /home/linuxbrew/.linuxbrew/etc/bash_completion.d/
   ```

## See Also

- [Settings Reference](/user-guide/settings/)
- [immutablue-settings](/cli-reference/immutablue-settings/)
