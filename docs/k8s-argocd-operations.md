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

For Paperless, `k8s/apps/paperless.yaml` includes `secrets.yaml` in Helm `valueFiles`, and helm-secrets handles decryption in ArgoCD.

## Add a New Application

1. Create chart folder: `k8s/charts/<app>/`
2. Add at least `Chart.yaml` and `values.yaml`
3. Create ArgoCD app manifest: `k8s/apps/<app>.yaml`
4. Set `spec.source.path` to `k8s/charts/<app>`
5. Commit and push to `main`

ArgoCD app-of-apps will discover and sync the new app.

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
