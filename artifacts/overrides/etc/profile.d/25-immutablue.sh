#!/bin/bash
# This profile script is part of immutalblue
# - https://gitlab.com/immutablue/immutablue

# Set ulimits
if [[ "$(whoami)" != "root" ]]; then 
    ulimit -n 65535
fi

