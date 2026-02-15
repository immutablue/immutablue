# if you have an asmedia usb-to-sata controller with buggy uas use this
# dmesg will show something along the lines of:
#   [142937.996268] scsi host10: uas_eh_device_reset_handler start
#   [143006.040213] sd 12:0:0:0: [sdh] tag#8 uas_eh_abort_handler 0 uas-tag 2 inflight: CMD IN
#   [143040.866179] sd 12:0:0:0: [sdh] tag#21 uas_eh_abort_handler 0 uas-tag 3 inflight: CMD IN
# prefer usb-storage driver over uas for (buggy) asmedia sata bridges:
hardware_override_asmedia_prefer_usb_storage_over_uas:
    #!/usr/bin/bash 
    sudo rpm-ostree kargs --append-if-missing="usb-storage.quirks=174c:55aa:u"

# use this to undo `hardware_override_asmedia_prefer_usb_storage_over_uas`:
hardware_override_asmedia_unprefer_usb_storage_over_uas:
    #!/usr/bin/bash 
    sudo rpm-ostree kargs --delete-if-present="usb-storage.quirks=174c:55aa:u"

