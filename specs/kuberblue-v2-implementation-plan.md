# Kuberblue V2 Implementation Plan

## Context

Kuberblue V2 transforms kuberblue from a single-node, script-driven, hardcoded Kubernetes bootstrap into a declarative, topology-aware, GitOps-native Kubernetes platform. The full V2 spec was designed by Ben + Zach + clawdbot on 2026-03-02. A partial implementation exists (single-node works, core infra deploys). This plan closes all gaps between spec and implementation to make it production-ready.

**Codebase:** `~/Documents/01_Projects_Personal/immutablue`
**Config defaults:** `artifacts/overrides_kuberblue/usr/kuberblue/`
**Scripts:** `artifacts/overrides_kuberblue/usr/libexec/kuberblue/`
**Manifests:** `artifacts/overrides_kuberblue/etc/kuberblue/manifests/`
**Tests:** `tests/kuberblue/`
**CLI/Justfile:** `artifacts/overrides_kuberblue/usr/libexec/immutablue/just/30-kuberblue.justfile`

---

## Phase 1: Config Schema Normalization + State Foundation

**Goal:** Fix config naming to match spec, add missing fields, establish runtime state tracking.
**Why first:** Every subsequent phase reads config. Getting the schema right now avoids migration pain.

### Steps

**1.1 Rename `networking.yaml` → `cni.yaml`**
- Rename `/usr/kuberblue/networking.yaml` → `/usr/kuberblue/cni.yaml`
- Update all references in `variables.sh`, `kube_tailscale_setup.sh`, and any other files (grep entire tree)
- yq paths (`.networking.cni`, `.networking.tailscale.*`) stay the same — only filename changes

**1.2 Rename `secrets.yaml` → `security.yaml` and expand scope**
- Rename file, restructure YAML:
  ```yaml
  security:
    sops:           # existing secrets.* content moves here
      enabled: false
      age_key_path: /var/lib/kuberblue/secrets/age.key
      age_recipient: ""
      auto_generate_key: true
    kubeconfig:
      distribution: service-user-only  # service-user-only | all-users
      allowed_groups: [kuberblue]
    admin:
      user: kuberblue
      group: kuberblue
      uid: 970
  ```
- Update `variables.sh`, `kube_sops_setup.sh`, `first_boot.sh`

**1.3 Add missing config fields**
- `cluster.yaml`: add `cluster.name`, `cluster.container_runtime: crio`, `cluster.swap: disabled`, `cluster.auto_init: true`, expand `node_role` to support `auto`, add `multi.worker_auto_join: false`, `multi.token_distribution: manual`, `multi.token_ttl: 24h`, add `ha.control_planes: 3`, `ha.load_balancer: kube-vip`, `ha.external_etcd: false`
- `cni.yaml`: add `networking.tailscale.tag`, `networking.tailscale.api_server_on_tailnet: false`, `networking.tailscale.auth_key_secret`, `networking.cilium.routing_mode: tunnel`, `networking.cilium.encryption: disabled`, cloudflare tunnel fields (`token_secret`, `namespace`)
- `packages.yaml`: add `cert_manager` section, add `mayastor.enabled` toggle

**1.4 Establish runtime state directory + functions**
- New script: `kube_state.sh` providing:
  - `kuberblue_state_set <key> <value>` → writes `/var/lib/kuberblue/state/<key>`
  - `kuberblue_state_get <key> [default]` → reads state
  - `kuberblue_state_check <key>` → returns 0/1
- State markers: `node-role`, `cluster-initialized`, `flux-bootstrapped`, `sops-configured`, `tailscale-configured`
- Update `first_boot.sh` to write markers at each milestone

**1.5 Remove static `kubeadm.yaml` template — generate fully at runtime**
- Remove `/usr/kuberblue/kubeadm.yaml` from image
- Expand `kube_generate_kubeadm_config.sh` to read all values from `cluster.yaml` (name, container_runtime, HA fields)
- Keep user override: if `/etc/kuberblue/kubeadm.yaml` exists, use it as-is (existing behavior)
- Output to `/var/lib/kuberblue/generated/kubeadm-config.yaml`

### Acceptance Criteria
- [ ] `networking.yaml` no longer exists; `cni.yaml` used everywhere
- [ ] `secrets.yaml` no longer exists; `security.yaml` used everywhere with expanded scope
- [ ] All new config fields have sane defaults with inline YAML comments
- [ ] `kuberblue_state_*` functions work correctly
- [ ] `kubeadm.yaml` no longer shipped in image; generated at runtime
- [ ] Single-node boot flow works end-to-end (no regressions)
- [ ] shellcheck passes on all modified scripts
- [ ] `test_kuberblue_container.sh` passes

---

## Phase 2: CLI Completeness

**Goal:** Implement 10 missing CLI commands. Operators need these for day-2 operations and testing subsequent phases.
**Why second:** CLI is the primary operator interface. `status`, `doctor`, `reset` make testing all later phases much easier.

### Steps

**2.1 `kuberblue status`**
- New justfile recipe
- Output: topology, node-role (from state), node ready status (`kubectl get nodes`), pod summary, Flux status, storage backend
- Read state markers from Phase 1

**2.2 `kuberblue doctor`**
- Health checks: kubelet running, CRI-O running, kubeadm config valid, Cilium health, CoreDNS running, StorageClass exists, Flux controllers healthy, Tailscale connected (if enabled), disk space, required binaries present
- Output: PASS/WARN/FAIL per check with remediation hints
- Warn if `/etc/kuberblue/` override is older than `/usr/kuberblue/` version

**2.3 `kuberblue reset` (full rewrite)**
- Replace stub with full flow: drain node → `kubeadm reset --force` → remove first-boot marker → clear all state markers → remove kubeconfig → clean CNI state (`/etc/cni/net.d/`) → flush iptables → optionally purge secrets (`--purge-secrets` flag)
- Safety: prompt confirmation unless `--force`

**2.4 `kuberblue join`**
- Worker-side: takes join command string or reads from `${STATE_DIR}/worker-join-command`
- Validates: kubelet not already joined, CRI-O running
- Runs `kubeadm join`, writes state markers (`node-role=worker`, `cluster-initialized`)

**2.5 `kuberblue refresh-token`**
- CP only: `kubeadm token create --print-join-command`
- Write to `${STATE_DIR}/worker-join-command`
- Support `--ttl` flag (default from `cluster.yaml`)

**2.6 `kuberblue override <file>`**
- Copy `/usr/kuberblue/<file>.yaml` → `/etc/kuberblue/<file>.yaml`
- Open in `$EDITOR` or print path
- Validate result is parseable YAML

**2.7 `kuberblue encrypt` / `kuberblue decrypt`**
- Wraps `sops --encrypt` / `sops --decrypt` with cluster Age key
- Reads key from `/var/lib/kuberblue/secrets/age.key`

**2.8 `kuberblue upgrade`**
- Verify etcd health → drain self → `kubeadm upgrade apply` (CP) or `kubeadm upgrade node` (worker) → verify version skew policy
- For rpm-ostree: detect if kubelet/kubeadm versions changed after OS upgrade

**2.9 `kuberblue mcp-serve`**
- Start MCP server binary from `mcp-kuberblue-glib`
- Placeholder until Phase 6 wires up real tools

### Acceptance Criteria
- [ ] All 12 CLI commands callable via `kuberblue <command>`
- [ ] `kuberblue status` produces correct output on running single-node cluster
- [ ] `kuberblue doctor` produces useful PASS/WARN/FAIL output
- [ ] `kuberblue reset && reboot` round-trips cleanly (boots fresh cluster)
- [ ] `kuberblue encrypt`/`decrypt` round-trips a test YAML file
- [ ] `kuberblue override cluster.yaml` copies file and validates YAML

---

## Phase 3: Multi-Node + HA Automation

**Goal:** Automated worker join and HA topology with kube-vip.
**Depends on:** Phase 1 (config fields, state), Phase 2 (join, reset, refresh-token CLI)

### Steps

**3.1 `node_role: auto` detection**
- In `variables.sh`, when role resolves to `auto`:
  - If `cluster-initialized` state exists → read stored role
  - If `/etc/kubernetes/admin.conf` exists → `control-plane`
  - If Tailscale available, check for existing CP via tags → `worker`
  - Default for multi-node: `worker`

**3.2 Tailscale-based token distribution**
- When `multi.token_distribution: tailscale`:
  - CP: after init, serve join token via `tailscale serve --bg --https=443 --set-path=/kuberblue/join-token`
  - Worker: discover CP via `tailscale status --json` (filter by `networking.tailscale.tag`), fetch token via `curl https://<cp-ts-ip>/kuberblue/join-token`
- New script: `kube_token_distribute.sh`

**3.3 Update `first_boot.sh` for automated worker join**
- When `topology=multi` + `node_role=worker`:
  - If `worker_auto_join: true` + `token_distribution: tailscale` → discover CP, fetch token, `kubeadm join`
  - Otherwise → print manual instructions and exit

**3.4 HA control-plane join flow**
- When `topology=ha` + `node_role=control-plane`:
  - First CP: existing init + `kubeadm init phase upload-certs --upload-certs` + serve cert key
  - Non-first CPs: fetch certificate key + join token, `kubeadm join --control-plane`
  - Detection: first CP has no existing state; non-first discover via Tailscale

**3.5 Kube-vip for HA VIP**
- Kube-vip runs as **static pod** (not through manifest pipeline — must exist before kubeadm init)
- Generate static pod manifest in `/etc/kubernetes/manifests/kube-vip.yaml` from config (`ha.vip_address`, `ha.vip_interface`)
- Add to `first_boot.sh` HA flow: generate kube-vip manifest → kubeadm init → rest of flow

### Acceptance Criteria
- [ ] 2-node cluster (1 CP + 1 worker) auto-joins with `topology: multi, token_distribution: tailscale, worker_auto_join: true`
- [ ] 3-node HA cluster with kube-vip VIP works (all 3 CPs join successfully)
- [ ] `kuberblue status` shows correct topology and role on all nodes
- [ ] Token auto-expires based on `multi.token_ttl`
- [ ] Kill one HA CP → VIP fails over to another CP (kube-vip ARP)

---

## Phase 4: Missing Manifests + Deploy Hardening

**Goal:** Add 5 missing package manifests and fix deploy pipeline robustness.
**Depends on:** Phase 1 (config fields). Can partially overlap with Phase 3.

### Steps

**4.1 Mayastor manifests**
- Create `00-infrastructure/11-mayastor/{00-metadata.yaml, 10-values.yaml}`
- Helm chart: OpenEBS Mayastor
- DiskPool CRs: generate from `cluster.yaml storage.nodes[]` at deploy time (template via yq)
- StorageClasses: `openebs-replicated-3` (default for HA), `openebs-replicated-2`
- ZFS-on-root support: handle zvol paths in DiskPool CRs
- New helper in `kube_deploy.sh`: `deploy_mayastor()` for DiskPool templating

**4.2 Tailscale Operator manifests**
- Create `10-networking/00-tailscale-operator/{00-metadata.yaml, 10-values.yaml}`
- Helm chart: `tailscale/tailscale-operator`
- OAuth credentials from SOPS-encrypted secret

**4.3 Cloudflare Tunnel manifests**
- Create `10-networking/10-cloudflared/{00-metadata.yaml, 10-values.yaml}`
- DaemonSet using official `cloudflared` image
- Tunnel token from K8s secret (ref in `cni.yaml`)
- Support `mode: daemonset | deployment` from config

**4.4 Velero backup manifests**
- Create `50-backup/00-velero/{00-metadata.yaml, 10-values.yaml}`
- Helm chart: `vmware-tanzu/velero`
- Storage location config (S3-compatible)

**4.5 Harden `kube_deploy.sh`**
- Replace `sleep 5` with `kubectl wait --for=condition=available` or Helm `--wait --timeout 10m`
- Add rollback on Helm upgrade failure (`helm rollback`)
- Add dependency ordering (Cilium first, storage before monitoring)
- Post-deploy validation: check for non-Running/non-Succeeded pods and warn

**4.6 Fix first_boot.sh marker bug (CRITICAL)**
- Current: `touch "${FIRST_BOOT_MARKER}"` runs BEFORE post-install
- Fix: move marker write to AFTER entire flow succeeds
- If post-install fails: clean up (kubeadm reset), exit with clear error, no marker = retry on next boot

**4.7 SOPS-encrypt Tailscale authkey**
- If `networking.tailscale.auth_key_secret` set → decrypt via `sops -d` before `tailscale up`
- Chicken-and-egg: on first boot, Age key doesn't exist yet. Accept plaintext with deprecation warning, or accept externally-encrypted file (operator's own Age key)

### Acceptance Criteria
- [ ] All 5 new manifest packages deploy successfully when enabled
- [ ] `kube_deploy.sh` uses `kubectl wait` / `helm --wait` instead of `sleep 5`
- [ ] Partial deploy failure does not leave cluster in broken state
- [ ] First boot failure is recoverable (reboot retries init)
- [ ] Mayastor DiskPools created for each node in `storage.nodes`
- [ ] Tailscale authkey can be SOPS-encrypted

---

## Phase 5: Testing + Validation

**Goal:** Fill testing gaps for multi-node, HA, SOPS, Flux, Mayastor, upgrade paths.
**Depends on:** Phases 1-4. Test design can start earlier.

### Steps

**5.1 Config validation tests**
- Verify all YAML defaults are valid
- Verify `kuberblue_config_get` returns expected defaults
- Verify override precedence (file-level replacement)

**5.2 SOPS encrypt/decrypt round-trip test**
- Generate Age key, encrypt test secret, decrypt, verify match
- No cluster required (unit-level)

**5.3 Flux reconciliation test (Chainsaw)**
- Apply GitRepository + Kustomization pointing to test fixture → verify resources appear
- Requires running cluster with Flux

**5.4 Mayastor storage test (Chainsaw)**
- Create PVC with `openebs-replicated` StorageClass → mount in Pod → write data → delete Pod → recreate → verify data persists
- Requires multi-node cluster

**5.5 Multi-node join test**
- 2 VMs (QEMU/libvirt) with Tailscale → verify worker auto-joins
- Integration test — document manual steps if not fully automated in CI

**5.6 HA failover test**
- 3-node HA cluster → verify VIP → kill one CP → verify VIP failover → verify etcd quorum
- Heavy test — manual acceptance or dedicated CI

**5.7 Upgrade path test**
- Build two image versions → boot V1 → `rpm-ostree upgrade` → `kuberblue upgrade` → verify health
- Manual or CI-only

**5.8 CLI tests**
- `kuberblue status` output format validation
- `kuberblue doctor` check coverage
- `kuberblue reset` round-trip

### Acceptance Criteria
- [ ] Config validation tests pass
- [ ] SOPS round-trip test passes
- [ ] Flux reconciliation test passes on single-node
- [ ] Multi-node and HA tests documented with clear manual steps
- [ ] All Chainsaw tests follow existing `*_test.yaml` naming convention
- [ ] `test_kuberblue_container.sh` updated with new file names/paths

---

## Phase 6: MCP Server + Documentation

**Goal:** Wire up MCP tools and write all 13 doc pages.
**Why last:** Polish layer. MCP tools are thin wrappers around Phase 2 CLI. Docs capture everything.

### Steps

**6.1 Wire up 6 existing MCP tool stubs**
- `kuberblue_status` → parse `kuberblue status` output to JSON
- `kuberblue_logs` → `kubectl logs` via GSubprocess
- `kuberblue_packages` → list enabled/available from `packages.yaml`
- `kuberblue_deploy` → `kubectl apply` wrapper
- `kuberblue_diagnostics` → `kuberblue doctor` output as JSON
- `kuberblue_secrets` → `sops encrypt/decrypt` wrapper

**6.2 Implement 3 missing MCP tools**
- `kuberblue_enable` → toggle package in `/etc/kuberblue/packages.yaml` + deploy manifest
- `kuberblue_disable` → remove package (helm uninstall / kubectl delete)
- `kuberblue_join_token` → `kuberblue refresh-token`, return token string

**6.3 Tool registration with mcp-glib API**
- Register all 9 tools with descriptions, parameter schemas, return types
- Depends on mcp-glib API being finalized

**6.4 Documentation (13 pages)**
Write in Hugo-compatible markdown at `docs/content/variants/kuberblue/`:
1. `_index.md` — Overview + architecture diagram
2. `quick-start.md` — Single-node in 5 minutes
3. `configuration.md` — All config files, 3-tier hierarchy
4. `networking.md` — Cilium + Tailscale + Cloudflare (3 layers)
5. `storage.md` — OpenEBS hostpath + Mayastor HA
6. `security.md` — SOPS+Age, RBAC, kubeconfig policy
7. `multi-node.md` — Tailscale setup, auto-join, token distribution
8. `ha.md` — Kube-vip, cross-DC, HA topology
9. `gitops.md` — Flux CD integration
10. `packages.md` — Package catalog (Tier 1/2/3)
11. `cli-reference.md` — All kuberblue commands
12. `mcp.md` — MCP server tools reference
13. `troubleshooting.md` — Common issues + `kuberblue doctor`

### Acceptance Criteria
- [ ] `kuberblue mcp-serve` starts and responds to all 9 tool calls
- [ ] All MCP tools return structured JSON
- [ ] All 13 doc pages exist and render in Hugo
- [ ] Doc pages include working examples and correct config references

---

## Dependency Graph

```
Phase 1 (Config + State)
    |
    +---> Phase 2 (CLI)
    |         |
    |         +---> Phase 3 (Multi-Node / HA)
    |         |         |
    |         |         +---> Phase 5 (Testing) [multi-node tests]
    |         |
    |         +---> Phase 4 (Manifests + Hardening) [can overlap Phase 3]
    |                   |
    |                   +---> Phase 5 (Testing) [full suite]
    |
    +---> Phase 6 (MCP + Docs) [docs can start early; MCP needs Phase 2]
```

Phases 3 and 4 can be worked in parallel (different files). Phase 5 tests written alongside each phase.

## Risk Areas

| Risk | Impact | Mitigation |
|------|--------|------------|
| First boot marker bug | Node bricked on failed post-install | Fix in Phase 4.6 — move marker to end. `kuberblue reset` is workaround until then |
| SOPS + Tailscale chicken-and-egg | Can't decrypt authkey before Age key exists | Accept plaintext with warning; or use external Age key |
| Kube-vip must pre-exist kubeadm init | HA VIP unreachable during bootstrap | Static pod manifest generated before kubeadm init in Phase 3.5 |
| mcp-glib API not finalized | MCP tools can't register | Phase 6 is last; defer if API not ready |
| Config renames break existing deployments | Users with `/etc/kuberblue/networking.yaml` overrides | `kuberblue doctor` warns about stale overrides; migration note in docs |

## Verification Strategy

After each phase, verify with:
1. **Phase 1:** `shellcheck` all scripts + `test_kuberblue_container.sh` + single-node boot test
2. **Phase 2:** Manual CLI exercise on running cluster + round-trip `reset → boot`
3. **Phase 3:** 2-node multi + 3-node HA boot test (Tailscale-connected VMs)
4. **Phase 4:** Enable each new package individually, verify deployment, verify rollback on failure
5. **Phase 5:** Run full Chainsaw suite + manual HA failover test
6. **Phase 6:** MCP tool call tests + Hugo doc build + link validation
