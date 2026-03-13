# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is a GitOps-managed homelab Kubernetes cluster called **woohp**. It uses:

- **Talos Linux** (v1.12.4) as the immutable OS for all nodes
- **Kubernetes** v1.35.0
- **ArgoCD** for GitOps continuous delivery (app-of-apps pattern)
- **SOPS** with **age** encryption for secrets
- **Helm** for packaging Kubernetes applications
- **Tailscale** operator for network connectivity

## Architecture

### Cluster Topology

Three bare-metal control plane nodes (all schedulable via `allowSchedulingOnMasters: true`):

- **sam** — 192.168.1.101
- **clover** — 192.168.1.102
- **alex** — 192.168.1.103

A shared VIP at **192.168.1.100** is the cluster API endpoint. All nodes use static IPs on `enp1s0f0` with gateway 192.168.1.254.

### Directory Structure

- `talos/` — Talos Linux cluster configuration managed by **talhelper**
  - `talconfig.yaml` — Source of truth for cluster config (talhelper input)
  - `talsecret.sops.yaml` — SOPS-encrypted cluster secrets
  - `clusterconfig/` — Generated node configs (output of `talhelper genconfig`). Do not edit directly.
  - `gen_and_apply_conf_to_all_nodes.sh` — Interactive script to regenerate and apply configs to all nodes
- `k8s/` — Kubernetes manifests and Helm charts deployed via ArgoCD
  - `k8s/bootstrap/app_of_apps.yaml` — Root ArgoCD Application that watches `k8s/apps/`
  - `k8s/apps/` — ArgoCD Application manifests (one per service)
  - `k8s/charts/` — Helm umbrella charts with `values.yaml` overrides

### GitOps Flow

ArgoCD syncs from this repo's `main` branch. The app-of-apps in `k8s/bootstrap/` auto-discovers all Application manifests in `k8s/apps/`. Each Application points to a Helm chart in `k8s/charts/`. Pushing to `main` triggers automatic sync with pruning and self-healing.

## Key Commands

### Environment Setup

The `.envrc` (direnv) sets `KUBECONFIG` and `TALOSCONFIG` automatically. Ensure `direnv` is allowed:
```
direnv allow
```

### Talos Node Management

Edit `talos/talconfig.yaml`, then regenerate and apply:
```
cd talos && ./gen_and_apply_conf_to_all_nodes.sh
```
This runs `talhelper genconfig`, diffs each node's config, and prompts before applying.

To check cluster health:
```
talosctl -n $VIP health
talosctl -n $VIP etcd members
```

#### Talos Node Upgrade
```
talosctl upgrade --nodes $NODE --image factory.talos.dev/metal-installer/613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245:<VERSION>
```

### Kubernetes

```
kubectl get nodes
kubectl get applications -n argocd
```

### Secrets

Secrets are encrypted with SOPS using age. The age key must be at `$HOME/.config/sops/age/keys.txt`.

To decrypt/edit a secret:
```
sops talos/talsecret.sops.yaml
```

### Adding a New Application

1. Add a Helm umbrella chart in `k8s/charts/<app-name>/` with `Chart.yaml` and `values.yaml`
2. Create an ArgoCD Application manifest in `k8s/apps/<app-name>.yaml` pointing to the chart path
3. Commit and push to `main` — ArgoCD will auto-sync

## Important Conventions

- Never commit decrypted secrets or the `woohp-kubeconfig` file (both are in `.gitignore`)
- Files in `talos/clusterconfig/` are generated — edit `talconfig.yaml` instead
- Helm chart dependency tarballs and lockfiles are gitignored; only `Chart.yaml` and `values.yaml` are tracked
- `.bak` files are generated during config updates and are gitignored
