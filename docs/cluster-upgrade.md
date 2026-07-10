# Cluster Upgrade Runbook (Talos + Kubernetes)

Follow this top-to-bottom when a Renovate PR bumps `talosVersion` and/or
`kubernetesVersion` in `talos/talconfig.yaml`. Merging the PR is **not** the
upgrade — it only moves the source of truth. This runbook performs the actual
rollout.

> **`talos/gen_and_apply_conf_to_all_nodes.sh` does NOT upgrade anything.** It
> only runs `talosctl apply-config`, which does not reinstall Talos or roll
> Kubernetes. Version upgrades require the explicit `talosctl upgrade` /
> `upgrade-k8s` commands below. The script is still used — at step 4 — to
> persist the new image tags into the machine config.

## 0. Prerequisites

```bash
git pull --ff-only        # get the merged version bump
direnv allow              # exports KUBECONFIG, TALOSCONFIG, VIP, SAM, CLOVER, ALEX
```

Confirm the target versions:

```bash
grep -E 'talosVersion|kubernetesVersion' talos/talconfig.yaml
```

Talos and Kubernetes each support a single minor-version step at a time
(e.g. 1.35 → 1.36). For multi-minor jumps, repeat the runbook one minor at a time.

## 1. Health gate (must be green before touching anything)

```bash
talosctl -n "$VIP" -e "$VIP" health --server=false   # all checks OK
talosctl -n "$VIP" -e "$VIP" etcd members            # 3 members
kubectl get nodes                                    # all Ready
kubectl get pods -A --field-selector=status.phase!=Running | grep -v Completed   # empty
kubectl get applications -n argocd \
  -o custom-columns='N:.metadata.name,S:.status.sync.status,H:.status.health.status'   # all Synced+Healthy*
```

\* `app-of-apps` shows a persistent cosmetic `OutOfSync` (Healthy) — see [Known noise](#known-noise). Everything else must be Synced+Healthy.

If the gate is not green, stop and fix that first. Do not upgrade an unhealthy cluster.

## 2. Generate the exact commands

talhelper fills in the schematic image ID that matches the node extensions:

```bash
cd talos
talhelper gencommand upgrade       # per-node: talosctl upgrade --image ...:<talosVersion>
talhelper gencommand upgrade-k8s   # talosctl upgrade-k8s --to=<kubernetesVersion>
```

## 3. Upgrade Talos OS — one node at a time

Each `talosctl upgrade` reboots its node. Run **sam, then clover, then alex**,
and re-run the per-node check before moving on. `talosctl upgrade` blocks until
the node is back (`post check passed`).

```bash
# from talos/ , use the commands emitted by `talhelper gencommand upgrade`, e.g.:
talosctl upgrade --talosconfig=./clusterconfig/talosconfig --nodes="$SAM" \
  --image=factory.talos.dev/metal-installer/<schematicId>:<talosVersion>
```

> The schematic ID `613e1592…` encodes the extensions `siderolabs/iscsi-tools`
> and `siderolabs/util-linux-tools`. If extensions change in `talconfig.yaml`,
> the ID changes — always take it from `talhelper gencommand upgrade`, never
> hard-code it.

After each node, verify before continuing:

```bash
talosctl -n "$SAM" -e "$SAM" version | sed -n '/Server:/,$p' | grep Tag   # new talosVersion
talosctl -n "$VIP" -e "$VIP" etcd members                                 # still 3 members
kubectl get nodes                                                         # all Ready
```

## 4. Upgrade Kubernetes — once all nodes are on the new Talos version

`talosctl upgrade-k8s` sequences apiserver → kubelets across the whole cluster,
so it is run **once** (targeting any control-plane node):

```bash
talosctl upgrade-k8s --talosconfig=./clusterconfig/talosconfig --to=<kubernetesVersion> --nodes="$SAM"
```

Verify:

```bash
kubectl get nodes -o wide     # all Ready, VERSION = new kubernetesVersion, OS-IMAGE = new Talos
kubectl get pods -n kube-system \
  -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}' \
  | grep -E 'apiserver|scheduler|controller-manager' | sort -u   # all new version
```

**Order matters:** OS first, then k8s. Applying the new machine config (which
carries the new kubelet image) *before* `upgrade-k8s` would push kubelet ahead
of the apiserver — a forbidden version skew. That is why config-apply is last.

## 5. Persist the machine config

Now that the live cluster already runs the new versions, apply the regenerated
config so `install.image` and the k8s image tags in the machine config match:

```bash
cd talos && ./gen_and_apply_conf_to_all_nodes.sh
```

Review each diff — it should be **only** the expected version-tag bumps
(installer, kubelet, apiserver, controller-manager, scheduler, proxy). Apply is
non-disruptive: expect `Applied configuration without a reboot`. If you skip
this, a future reboot/reinstall would repoint at the old installer image.

## 6. Final validation

Re-run the full [health gate](#1-health-gate-must-be-green-before-touching-anything). All must pass:

- 3 nodes `Ready`, on the new Kubernetes version and new `Talos (…)` OS-image
- `talosctl health` all OK, 3 etcd members
- no non-Running pods (excluding `Completed`)
- all ArgoCD child apps Synced+Healthy

`talos/clusterconfig/*` is gitignored, so `git status` stays clean — there is
nothing to commit from the upgrade itself (the version bump was the merged PR).

## Known noise

- **`app-of-apps` persistent `OutOfSync` (Healthy):** ArgoCD adds
  `pre-delete-finalizer.argocd.argoproj.io` finalizers and an
  `argocd.argoproj.io/tracking-id` annotation to child `Application` objects
  that are not present in git, so the parent always sees a diff. Pre-existing,
  unrelated to upgrades, safe to ignore.
- **Transient child `OutOfSync` during rollout:** normal while pods reschedule;
  ArgoCD self-heal reconciles it.

## If a node does not come back

- Check console/logs: `talosctl -n "$NODE" -e "$NODE" dmesg` / `talosctl -n "$NODE" -e "$NODE" logs kubelet`
- etcd quorum tolerates one node down (3-node cluster). Do **not** upgrade a
  second node until the first is healthy again, or you lose quorum.
- Recovery procedures: see [talos-operations.md](talos-operations.md) and [k8s-bootstrap.md](k8s-bootstrap.md).
