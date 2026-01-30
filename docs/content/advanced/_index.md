+++
title = 'Advanced Topics'
weight = 7
+++

# Advanced Topics

This section covers advanced use cases and specialized features.

## Topics

- [Lima VM Testing](lima-testing/) - Test Immutablue in Lima VMs
- [IBus Speech-to-Text](ibus-speech/) - Voice input configuration

## Lima VM Testing

Lima provides lightweight VMs for testing Immutablue without installing:

```bash
# Generate Lima config
immutablue-lima-gen

# Start the VM
limactl start immutablue

# Shell into the VM
limactl shell immutablue
```

See [Lima VM Testing](lima-testing/) for full documentation.
