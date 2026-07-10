# Talos Operations

This document is the operational reference for Talos in this repository.

## Scope and Source of Truth

- Main config source: `talos/talconfig.yaml`
- Encrypted Talos secrets: `talos/talsecret.sops.yaml`
- Generated outputs: `talos/clusterconfig/*`
- Rollout helper script: `talos/gen_and_apply_conf_to_all_nodes.sh`

Do not manually edit `talos/clusterconfig/*`. Regenerate from `talconfig.yaml`.

## Cluster Topology

- VIP: `192.168.1.100`
- Nodes:
  - `sam` -> `192.168.1.101`
  - `clover` -> `192.168.1.102`
  - `alex` -> `192.168.1.103`

All nodes are control plane nodes and scheduling is enabled on masters (`allowSchedulingOnMasters: true`).

## Environment

The repository expects local environment variables from `.envrc`:

```bash
direnv allow
```

This exports:

- `KUBECONFIG`
- `TALOSCONFIG`
- `VIP`, `SAM`, `CLOVER`, `ALEX`

## Standard Workflow: Change Talos Config

1. Edit `talos/talconfig.yaml`.
2. From `talos/`, run:

```bash
./gen_and_apply_conf_to_all_nodes.sh
```

3. Review each `diff` shown by the script.
4. Confirm per-node apply only when expected.

The script behavior:

- Backs up generated files to `.bak`
- Runs `talhelper genconfig`
- Shows diffs for `sam`, `clover`, `alex`
- Applies with `talosctl apply-config` only if confirmed

## Health Checks

```bash
talosctl -n "$VIP" health
talosctl -n "$VIP" etcd members
```

Useful node-level checks:

```bash
talosctl -n "$SAM" get machineconfig
talosctl -n "$SAM" version
talosctl -n "$SAM" logs kubelet
```

## Upgrade Notes

Versions are pinned in `talos/talconfig.yaml` (`talosVersion`, `kubernetesVersion`), typically bumped by a Renovate PR. Merging the PR is **not** the upgrade — it only changes the source of truth, and `gen_and_apply_conf_to_all_nodes.sh` does not perform version upgrades.

For the full rollout procedure (OS `talosctl upgrade` per node → `upgrade-k8s` → persist config), follow the dedicated runbook: **[cluster-upgrade.md](cluster-upgrade.md)**.

## Secrets (SOPS + age)

- Talos SOPS policy: `talos/.sops.yaml`
- Expected private key path: `$HOME/.config/sops/age/keys.txt`

Edit encrypted Talos secret file:

```bash
sops talos/talsecret.sops.yaml
```

Never commit decrypted secret data.

## Pitfalls

- `talos/clusterconfig/*` is generated and can be overwritten at any time.
- The rollout script is interactive and can change live node config.
- Keep the VIP and node IPs consistent between `talconfig.yaml` and `.envrc`.
- `.bak` files are temporary artifacts and are gitignored.
