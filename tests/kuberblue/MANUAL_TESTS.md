# Kuberblue Manual Tests

Tests that cannot be fully automated in CI and require manual execution.

## 1. Multi-Node Join Test

**Requirements:** 2 VMs (or bare-metal machines) with Tailscale installed and connected to the same tailnet.

**Steps:**
1. Build the kuberblue image on both nodes: `make KUBERBLUE=1 build`
2. On VM1 (control-plane), configure `/etc/kuberblue/cluster.yaml`:
   ```yaml
   cluster:
     topology: multi
     node_role: control-plane
     multi:
       worker_auto_join: true
       token_distribution: tailscale
   ```
3. On VM1, configure `/etc/kuberblue/cni.yaml`:
   ```yaml
   networking:
     tailscale:
       enabled: true
       tag: tag:kuberblue-cp
   ```
4. Reboot VM1 and wait for the cluster to initialize (watch `kuberblue status`).
5. On VM2 (worker), configure `/etc/kuberblue/cluster.yaml`:
   ```yaml
   cluster:
     topology: multi
     node_role: worker
     multi:
       worker_auto_join: true
       token_distribution: tailscale
   ```
6. Reboot VM2 and wait for it to auto-join (watch `kuberblue status` on VM1).
7. Verify: `kubectl get nodes` shows both nodes in `Ready` state.

**Expected Result:** Worker node automatically discovers the control-plane via Tailscale, fetches the join token, and joins the cluster.

---

## 2. HA Failover Test

**Requirements:** 3 VMs with Tailscale, connected to the same tailnet.

**Steps:**
1. Configure all 3 nodes with `topology: ha` and a shared `ha.vip_address`.
2. Boot all 3 nodes. The first node initializes; the others join as control-plane peers.
3. Verify `kuberblue status` shows 3 control-plane nodes.
4. Verify the VIP is reachable: `curl -k https://<vip>:6443/healthz`
5. Power off the node currently holding the VIP.
6. Wait 10-30 seconds for kube-vip ARP failover.
7. Verify the VIP is reachable again from one of the remaining nodes.
8. Verify `kubectl get nodes` shows 2 Ready nodes and 1 NotReady.
9. Verify `kubectl get pods -A` shows no disruption to workloads.
10. Power the killed node back on; verify it rejoins and becomes Ready.

**Expected Result:** VIP fails over within 30 seconds. etcd maintains quorum with 2/3 nodes. Cluster remains functional throughout.

---

## 3. Upgrade Path Test

**Requirements:** 1 VM, 2 kuberblue image versions (V1 and V2).

**Steps:**
1. Build and deploy the V1 image (pre-V2 spec).
2. Verify cluster is healthy: `kuberblue status`, `kuberblue doctor`.
3. Stage the V2 image: `rpm-ostree upgrade` (or rebase to V2 image ref).
4. Reboot into V2.
5. Run `kuberblue upgrade` to apply Kubernetes-level changes.
6. Verify: `kuberblue status` shows correct versions.
7. Verify: `kuberblue doctor` shows all PASS (config migration warnings acceptable).
8. Verify: existing workloads are still running.
9. Verify: new config files (`cni.yaml`, `security.yaml`) are loaded correctly.

**Expected Result:** Upgrade is non-disruptive. Old `/etc/kuberblue/` overrides produce migration warnings but do not break the cluster. `kuberblue doctor` identifies stale override names.

---

## 4. Tailscale Mesh Connectivity Test

**Requirements:** 2+ nodes with Tailscale on different physical networks (e.g., home + cloud).

**Steps:**
1. Verify Tailscale is connected on all nodes: `tailscale status`.
2. Bootstrap a multi-node cluster using Tailscale IPs as advertise addresses.
3. Deploy a test pod on each node.
4. Verify pod-to-pod connectivity across the Tailscale mesh:
   ```
   kubectl exec pod-on-node1 -- curl http://<pod-ip-on-node2>
   ```
5. Verify service-level connectivity works (ClusterIP routing through Cilium over Tailscale).
6. Test DNS resolution across nodes.

**Expected Result:** Full mesh connectivity through Tailscale, even across NATs and different networks. Cilium encapsulation works transparently over the Tailscale tunnel.

---

## 5. Full Mayastor Multi-Node Storage Test

**Requirements:** 3 nodes, each with an available block device or ZFS zvol for Mayastor.

**Steps:**
1. Configure `cluster.yaml` with `storage.backend: mayastor` and `storage.nodes` entries.
2. Deploy the cluster and verify Mayastor pods are running.
3. Verify DiskPools are created for each node: `kubectl get dsp -n openebs`.
4. Create a PVC with `storageClassName: openebs-replicated-3`.
5. Verify the volume is replicated across all 3 nodes.
6. Write data to the volume via a test pod.
7. Kill one storage node. Verify the volume remains accessible (degraded but functional).
8. Bring the node back. Verify the replica rebuilds automatically.
9. Delete and recreate the pod. Verify data persists.

**Expected Result:** Mayastor provides HA replicated storage. Single-node failure does not cause data loss. Replica auto-heals when the node returns.
