# Kubernetes and ArgoCD Operations

This document is the operational reference for Kubernetes/ArgoCD GitOps in this repository.

## Scope

- ArgoCD applications: `k8s/apps/*.yaml`
- Helm charts: `k8s/charts/*`
- Kubernetes SOPS policy: `k8s/.sops.yaml`

Bootstrap steps are documented in `docs/k8s-bootstrap.md`.

## GitOps Model

- Root ArgoCD app (`app-of-apps`) watches `k8s/apps`
- Each file in `k8s/apps/` points to one chart in `k8s/charts/`
- Sync policy is automated (`prune: true`, `selfHeal: true`)

Consequence: merge to `main` updates desired state and ArgoCD reconciles automatically.

## Daily Validation

```bash
kubectl get nodes
kubectl get applications -n argocd
kubectl get pods -n argocd
```

Inspect one app quickly:

```bash
kubectl describe application argocd -n argocd
```

## Secrets Workflow

Kubernetes secret files matching `k8s/charts/*/secrets.yaml` are encrypted with SOPS (see `k8s/.sops.yaml`).

Encrypt in place:

```bash
sops -e -i k8s/charts/<app>/secrets.yaml
```

Edit encrypted file safely:

```bash
sops k8s/charts/<app>/secrets.yaml
```

## Add a New Application

1. Create chart folder: `k8s/charts/<app>/`
2. Add at least `Chart.yaml` and `values.yaml`
3. Create ArgoCD app manifest: `k8s/apps/<app>.yaml`
4. Set `spec.source.path` to `k8s/charts/<app>`
5. Commit and push to `main`

ArgoCD app-of-apps will discover and sync the new app.

### Add Service Monitor to Glance Dashboard

When deploying a new application with a web UI (optional but recommended):

1. Edit `k8s/charts/glance/config/glance.yml`
2. Locate the `monitor` widget under `sites:`
3. Add an entry with the service name, Tailscale ingress URL, internal service check URL, and Simple Icons icon:

```yaml
- title: MyApp
  url: https://myapp.raccoon-pence.ts.net/
  check-url: http://myapp.namespace.svc.woohp.local:PORT
  icon: si:myapp
```

Example for a service in the `media` namespace on port 8080:
```yaml
- title: MyService
  url: https://myservice.raccoon-pence.ts.net/
  check-url: http://myservice.media.svc.woohp.local:8080
  icon: si:myservice
```

Glance polls each `check-url` internally and displays the health status with a colored indicator on the dashboard.

## Apps with CNPG PostgreSQL Database

When an application needs a dedicated PostgreSQL database, declare a `postgresql.cnpg.io/v1 Cluster` resource directly inside the app's Helm chart (no separate chart required). The CNPG operator (deployed via `k8s/charts/cnpg/`) watches all namespaces and reconciles the cluster automatically.

### Minimal cluster template

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: <app>-db
spec:
  instances: 1
  storage:
    storageClass: longhorn
    size: 5Gi
  bootstrap:
    initdb:
      database: <app>
      owner: <app>
```

### CNPG naming conventions

| Resource | Name |
|---|---|
| Secret with credentials | `<cluster-name>-app` |
| Read-write service | `<cluster-name>-rw` |
| Read-only service | `<cluster-name>-r` |
| Read service (any) | `<cluster-name>-ro` |

The secret `<cluster-name>-app` contains keys: `username`, `password`, `host`, `port`, `dbname`, `uri`. Inject into the app deployment via `secretKeyRef`:

```yaml
- name: DB_USER
  valueFrom:
    secretKeyRef:
      name: <app>-db-app
      key: username
- name: DB_PASS
  valueFrom:
    secretKeyRef:
      name: <app>-db-app
      key: password
```

Set `DBHOST` to `<app>-db-rw` (the write service, in the same namespace).

### Startup ordering

CNPG takes ~30–60s to bootstrap a new cluster. The application pod will crashloop until the DB secret exists and the cluster is ready. This is expected — Kubernetes will restart the pod automatically. No sync-wave or init-container is required for typical apps. Increase `initialDelaySeconds` on the readinessProbe if the app takes time to run migrations.

### Validate cluster health

```bash
kubectl get cluster -n <namespace>
kubectl describe cluster <app>-db -n <namespace>
```

## VPN Sidecar Pattern (Gluetun)

Use Gluetun as a native Kubernetes sidecar for applications that require VPN networking (e.g. qBittorrent).

Native sidecar definition — place in `initContainers` with `restartPolicy: Always` so it starts before the main container and restarts independently:

```yaml
initContainers:
  - name: gluetun
    image: qmcgaw/gluetun:v3.41.0
    restartPolicy: Always
    securityContext:
      capabilities:
        add: [NET_ADMIN]
    env:
      - name: VPN_SERVICE_PROVIDER
        value: custom
      - name: VPN_TYPE
        value: wireguard
      - name: FIREWALL_OUTBOUND_SUBNETS
        value: "192.168.1.0/24,10.244.0.0/16,10.96.0.0/12"
      - name: HTTP_CONTROL_SERVER_AUTH_DEFAULT_ROLE
        value: '{"auth":"none"}'
    readinessProbe:
      httpGet:
        path: /v1/vpn/status
        port: 8320
```

WireGuard credentials (private key, addresses) live in a SOPS-encrypted `secrets.yaml` and are injected via `envFrom`.

**Pitfall — Gluetun auth (v3.39.1+)**: The HTTP control server requires authentication by default since v3.39.1. Without `HTTP_CONTROL_SERVER_AUTH_DEFAULT_ROLE: '{"auth":"none"}'`, readiness probes to `/v1/vpn/status` return 401 and the pod never becomes ready. The deprecated endpoint `/v1/openvpn/status` was removed; always use `/v1/vpn/status`.

## Shared Infrastructure Chart Pattern

When multiple applications in the same namespace share resources (Namespace, PersistentVolume, Secrets), create a dedicated `<namespace>-infra` chart deployed at `sync-wave: -1`.

Example: `k8s/charts/media-infra/` creates:
- `Namespace: media`
- NFS `PersistentVolume` + `PersistentVolumeClaim` (`ReadWriteMany`) shared by all media apps
- `Secret: gluetun-wireguard` consumed by the qBittorrent chart

ArgoCD annotation to set wave in `k8s/apps/<infra-app>.yaml`:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
```

The infra chart deploys before any application chart that mounts the shared PVC or namespace.

## NFS Volumes and PUID/PGID

For apps mounting NFS shares from the TrueNAS NAS (`192.168.1.110:/mnt/default/woohp/medias`):

- Use `ReadWriteMany` access mode on the PVC
- Set `securityContext.fsGroup`, `runAsUser`, and `runAsGroup` to match the NAS dataset owner (currently `3001`/`3001`)
- For LinuxServer.io images, use `PUID=3001` and `PGID=3001` environment variables instead of `securityContext`

Mismatched UID/GID causes permission-denied errors on files written to the NFS share even when the pod starts cleanly.

## Chart and Repo Conventions

- Helm dependency archives (`*.tgz`) are not tracked.
- `Chart.lock` is not tracked.
- Generated `template.yml` snapshots can exist but should not be treated as authoritative source.
- Secrets must stay encrypted in git.

## Troubleshooting

If an app is OutOfSync or Degraded:

1. Check app events/conditions:

```bash
kubectl describe application <app> -n argocd
```

2. Check repo-server logs:

```bash
kubectl logs deploy/argocd-repo-server -n argocd
```

3. Validate secret decryption prerequisites:
- `sops-age-key` exists in `argocd` namespace
- Age private key format is valid in `key.txt`
- File path in ArgoCD chart still matches mounted key path

If ArgoCD cannot decrypt values, start by validating `k8s/charts/argocd/values.yaml` repo-server env and mounts.
