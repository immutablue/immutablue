# enable the screen to render in the notched out area
asahi_enable_notch_render:
    #!/bin/bash 
    set -euo pipefail 

    sudo rpm-ostree kargs --append-if-missing=apple_dcp.show_notch=1

# disable the screen to render in the notched out area
asahi_disable_notch_render:
    #!/bin/bash 
    set -euo pipefail 

    sudo rpm-ostree kargs --delete-if-present=apple_dcp.show_notch=1

