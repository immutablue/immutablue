+++
title = 'immutablue-doctor'
weight = 4
+++

# immutablue-doctor

Run comprehensive system health checks.

## Synopsis

```bash
immutablue-doctor [OPTIONS]
```

## Description

`immutablue-doctor` performs a series of health checks on your Immutablue system to verify everything is working correctly. Similar to `brew doctor` or `flutter doctor`, it helps you quickly identify and resolve issues.

## Options

| Option | Description |
|--------|-------------|
| `--verbose`, `-v` | Show detailed output for each check |
| `--fix`, `-f` | Attempt to automatically fix detected issues |
| `--json` | Output results in JSON format |
| `--yaml` | Output results in YAML format |
| `--help`, `-h` | Show help message |

## Health Checks Performed

### System Checks
- Internet connectivity (IPv4 and IPv6)
- bootc status and pending updates
- System service status

### Package Manager Checks
- Flatpak health
- Distrobox health
- Homebrew health

### Configuration Checks
- Settings file validity
- Required directories exist
- Permissions are correct

## Examples

### Basic health check

```bash
$ immutablue doctor
✓ Internet connectivity
✓ bootc status
✓ Flatpak health
✓ Distrobox health
✓ Homebrew health
✓ Settings valid

All checks passed!
```

### Verbose output

```bash
immutablue-doctor --verbose
```

### Attempt automatic fixes

```bash
immutablue-doctor --fix
```

### JSON output for scripting

```bash
immutablue-doctor --json | jq '.checks[] | select(.status == "fail")'
```

## Using via immutablue command

```bash
# Basic check
immutablue doctor

# Verbose
immutablue doctor_verbose

# With fixes
immutablue doctor_fix

# JSON output
immutablue doctor_json

# YAML output
immutablue doctor_yaml
```

## Exit Codes

| Code | Description |
|------|-------------|
| 0 | All checks passed |
| 1 | One or more checks failed |
| 2 | Error running checks |

## See Also

- [Doctor Guide](/user-guide/doctor/)
- [Maintenance Guide](/user-guide/maintenance/)
