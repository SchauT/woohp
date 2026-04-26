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

Talos version is pinned in `talos/talconfig.yaml` (`talosVersion`).

For image-based upgrades (when needed):

```bash
talosctl upgrade --nodes "$NODE" --image factory.talos.dev/metal-installer/613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245:<VERSION>
```

Run upgrades one node at a time and verify etcd quorum after each node.

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
