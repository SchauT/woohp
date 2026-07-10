# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Read this first

`AGENTS.md` is the authoritative guide for this repo. Read it before doing anything — it holds the architecture, conventions, commands, pitfalls, the **Why/How/Validation** planning convention, and the session close-out rules. This file only tells you *where* things live so the docs stay the single source of truth and don't drift.

## Where to find what

| You need to… | Look in |
| --- | --- |
| Understand the repo & rules (start here) | `AGENTS.md` |
| Operate Talos nodes (regen config, rollout, recovery) | `docs/talos-operations.md` |
| Upgrade Talos/K8s versions (Renovate bump rollout) | `docs/cluster-upgrade.md` |
| Operate K8s/ArgoCD (deploy, sync, add a service, VPN sidecar) | `docs/k8s-argocd-operations.md` |
| Bootstrap the cluster from scratch | `docs/k8s-bootstrap.md` |
| Change node OS config | `talos/talconfig.yaml`, `talos/talsecret.sops.yaml` (never `talos/clusterconfig/*` — generated) |
| Add/change a service | new chart in `k8s/charts/<app>/` + ArgoCD app in `k8s/apps/<app>.yaml` |

## What's non-obvious about this repo

These framing points aren't a single section in the docs but shape every change:

- **A merged commit is the deploy.** ArgoCD tracks `main`/`HEAD` and auto-syncs with prune + self-heal. There is no separate apply step for K8s apps, and no build/test pipeline — validation is operational (`kubectl`/`talosctl`/HTTP probes), per AGENTS.md's planning convention.
- **The repo is public.** Secrets only ever land here SOPS+age encrypted. Treat any plaintext secret as a hard stop.
- **Generated files are not source of truth, but the inverse also holds:** `talos/clusterconfig/*` is generated from `talconfig.yaml`, yet `k8s/charts/*/template.yml` snapshots can drift — there the live chart templates are authoritative. Know which direction applies before editing.
- **`talos/gen_and_apply_conf_to_all_nodes.sh` mutates live nodes interactively.** Review diffs before confirming.

When in doubt about a procedure, prefer the matching `docs/` runbook over reasoning from the manifests.
