# Kubernetes Bootstrap

This document covers one-time or infrequent bootstrap tasks for the Kubernetes/ArgoCD layer.

## Scope

- Initial app-of-apps setup
- ArgoCD prerequisite secret for SOPS decryption
- First secret encryption/edit workflow checks

For day-2 operations, use `docs/k8s-argocd-operations.md`.

## Prerequisites

- `kubectl` configured against this cluster
- Age private key available at `$HOME/.config/sops/age/keys.txt`
- Access to namespace `argocd`

## Step 1: Bootstrap app-of-apps

Apply `k8s/bootstrap/app_of_apps.yaml` to create the root ArgoCD application.

Expected result:

- ArgoCD starts reconciling files from `k8s/apps/`

## Step 2: Bootstrap SOPS age key in ArgoCD

ArgoCD repo-server uses this secret to decrypt encrypted Helm values via helm-secrets.

```bash
kubectl create secret generic sops-age-key \
  -n argocd \
  --from-file=key.txt=$HOME/.config/sops/age/keys.txt
```

Expected result:

- Secret `sops-age-key` exists in namespace `argocd`
- ArgoCD can decrypt `k8s/charts/*/secrets.yaml` files when referenced

## Step 3: Validate bootstrap quickly

```bash
kubectl get applications -n argocd
kubectl get secret sops-age-key -n argocd
```

If apps stay OutOfSync/Degraded, continue with troubleshooting in `docs/k8s-argocd-operations.md`.

## Secret File Workflow (Authoring)

Encrypt in place:

```bash
sops -e -i k8s/charts/<app>/secrets.yaml
```

Edit encrypted file:

```bash
sops k8s/charts/<app>/secrets.yaml
```

Never commit decrypted secret data.
