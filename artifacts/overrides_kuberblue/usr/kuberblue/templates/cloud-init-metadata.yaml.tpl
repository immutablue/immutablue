# kuberblue cloud-init meta-data template
#
# Minimal meta-data for NoCloud datasource.
# Used when creating a seed ISO for bare-metal or VM installs.

instance-id: kuberblue-${CLUSTER_NAME:-default}
local-hostname: ${HOSTNAME:-kuberblue}
