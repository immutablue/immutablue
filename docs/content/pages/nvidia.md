+++
date = '2025-02-01T21:26:21-05:00'
draft = false
title = 'Nvidia'
+++

# Nvidia support on Immutablue

To get Nvidia support on Immutablue its a two step process:
- rebase to any Immutablue image that has `-cyan` in it (such as quay.io/immutablue/immutablue:41-cyan) and reboot
- run `immutablue enable_nvidia_kmod` and reboot after it is finished one last time

## Validating

You can validate that the nvidia kmod is loaded with:
```bash
lsmod | grep -i nvidia
```

