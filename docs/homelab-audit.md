# Homelab audit and mapping (2026-10-22)

Snapshot of the woohp cluster, collected read-only with `kubectl` and `talosctl` plus a Homelable LAN scan. The repo is public: unidentified LAN devices are deliberately left out.

## At a glance

| | |
|---|---|
| Nodes | 4 (3 control-plane + 1 GPU worker) |
| Capacity | 16 vCPU, about 43 GiB RAM |
| OS / Kubernetes | Talos v1.14.1 / Kubernetes v1.37.1 |
| ArgoCD applications | 24 (+ `app-of-apps`) |
| Pods | 122 |
| Tailscale Ingress | 17 |
| Volumes | 19 Longhorn (RWO) + 1 NFS (RWX) |

## Nodes

| Node | IP | Role | RAM usage | CPU usage | Pods |
|---|---|---|---|---|---|
| sam | 192.168.1.101 | control-plane + etcd | 88% | 11% | 24 |
| clover | 192.168.1.102 | control-plane + etcd | 65% | 11% | 26 |
| alex | 192.168.1.103 | control-plane + etcd | 65% | 9% | 26 |
| mandy | 192.168.1.104 | worker, NVIDIA GPU, 23 GiB | 41% | 25% | 46 |

The Kubernetes API is served on the Talos VIP `192.168.1.100:6443`. Control-plane nodes also run workloads.

## Network and access

```mermaid
flowchart TB
  Internet((Internet)) --- Box[Freebox<br/>192.168.1.254]
  Box --- LAN{{LAN 192.168.1.0/24}}
  LAN --- sam[sam .101<br/>control-plane]
  LAN --- clover[clover .102<br/>control-plane]
  LAN --- alex[alex .103<br/>control-plane]
  LAN --- mandy[mandy .104<br/>GPU worker]
  LAN --- NAS[(TrueNAS .110)]
  VIP([API VIP .100:6443]) -.- sam & clover & alex
  Tailnet((Tailnet)) -->|subnet router<br/>192.168.1.0/24| LAN
  Tailnet -->|17 Ingress, tailscale class| mandy
  NAS -->|NFS media| mandy
```

Every web UI is reachable only through Tailscale (`ingressClassName: tailscale`). A `Connector` (`lan-subnet-router`) advertises the LAN to the tailnet. No service is exposed publicly.

## GitOps layers

```mermaid
flowchart LR
  Git[(GitHub main)] --> Root[app-of-apps]
  Root --> Apps["k8s/apps/*.yaml<br/>24 Applications"]
  Apps --> Charts["k8s/charts/*<br/>Helm"]
  Charts --> K8s[Cluster]
  Sops["SOPS + age<br/>secrets.yaml"] --> Charts
  Talos["talos/talconfig.yaml<br/>talhelper"] --> Nodes[4 Talos nodes]
  Nodes --> K8s
```

A merged commit is the deploy: ArgoCD auto-syncs with prune and self-heal.

## Media stack

```mermaid
flowchart LR
  Seerr[Seerr requests] --> Sonarr & Radarr
  Sonarr & Radarr --> Prowlarr[Prowlarr indexers]
  Prowlarr --- Flare[FlareSolverr]
  Sonarr & Radarr --> Qbit["qBittorrent<br/>+ Gluetun VPN sidecar"]
  Qbit --> NFS[(NFS media<br/>TrueNAS)]
  Unpackerr --> NFS
  Bazarr[Bazarr subtitles] --> NFS
  NFS --> Jelly[Jellyfin<br/>NVIDIA transcoding]
  Qui[qui] --- Qbit
```

## Storage

```mermaid
flowchart LR
  subgraph Longhorn[Longhorn, RWO, 19 volumes]
    A[app configs: *arr, jellyfin, qui, seerr, mealie]
    B[CNPG databases: n8n, paperless]
    C[app data: paperless, snapotter, homelable]
  end
  subgraph NFS[NFS RWX, 1 volume]
    D[media-data-nfs<br/>192.168.1.110:/mnt/default/woohp/medias<br/>UID/GID 3001]
  end
```

## Findings

| Severity | Finding | Suggested action |
|---|---|---|
| Medium | `sam` is at 88% memory while `mandy` is at 41%. | Move workloads (for example paperless) toward `mandy`, or add RAM. |
| Medium | `mandy` runs 46 pods, hosts the GPU, 6 of 12 media pods and most Tailscale proxies. It is a single point of failure for media. | Document recovery, or add a second worker. |
| Medium | Every app runs one replica. | Accept for a homelab, or add replicas for the few apps that matter. |
| Low | `AGENTS.md` lists 3 nodes and Talos v1.13.6 / Kubernetes v1.36.2. The cluster has 4 nodes on Talos v1.14.1 / Kubernetes v1.37.1. | Update `AGENTS.md` and `talconfig.yaml` notes. |
| Low | Longhorn replica count and backup target were not audited. | Check `kubectl get settings.longhorn.io -n longhorn-system`. |
| Info | Homelable runs in its own `privileged` namespace because its scanner needs `NET_RAW`. | Keep it isolated. |
