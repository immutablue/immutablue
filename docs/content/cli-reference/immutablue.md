+++
date = '2025-01-12T19:29:53-05:00'
draft = false
title = 'Justfiles and the $(immutablue) command'
+++

# Justfiles and immutablue command

First and foremost, it should be noted that the `immutablue` command is just a wrapper around the `Justfile` stored at `/usr/libexec/immutablue/just/Justfile`.

This `Justfile`'s only purpose is to include other justfiles. By default, Immutablue ships the `00-base.justfile` only which contains a few basic operations for installs of various Immutablue components, collecting sysinfo, and rebooting to the BIOS

## Including Justfiles 
If you want to add more justfiles such as in your custom immutablue build you will need to do two things:
1. Add to `/usr/libexec/immutablue/just/` and call it something like `90-custom.justfile` (or whatever you prefer)
2. (Assuming you called it `90-custom.justfile`) run the following somewhere in your build process:
```bash
echo -e 'import "./90-custom.justfile"' >> /usr/libexec/immutablue/just/Justfile
```

## For more about Justfiles

See the official [documentation here](https://just.systems/man/en/introduction.html)

