# gitops-apps: the application code

[![CI](https://github.com/rosaliei/gitops-apps/actions/workflows/ci.yaml/badge.svg)](https://github.com/rosaliei/gitops-apps/actions/workflows/ci.yaml)
[![Release](https://github.com/rosaliei/gitops-apps/actions/workflows/release-please.yaml/badge.svg)](https://github.com/rosaliei/gitops-apps/actions/workflows/release-please.yaml)
[![Security](https://github.com/rosaliei/gitops-apps/actions/workflows/security.yaml/badge.svg)](https://github.com/rosaliei/gitops-apps/actions/workflows/security.yaml)

The **app repo** of a two-repo GitOps setup. It is owned by developers. It holds code, tests and
Dockerfiles, and produces **signed container images**.

**It does not deploy anything.** What runs where lives in the **GitOps repo**,
[rosaliei/gitops-monorepo](https://github.com/rosaliei/gitops-monorepo): the Helm chart, `environments/dev|qa|prod`,
and ArgoCD. Start there for the full picture, diagrams and walkthroughs.

```
  THIS REPO (app team)                                    GITOPS REPO (devops team)
  ┌──────────────────────────────┐   commit new tag    ┌──────────────────────────────┐     ArgoCD
  │ PR -> test, e2e, build, scan │ ──────────────────► │ environments/dev/<app>.yaml  │ ──► reads ONLY
  │ main -> push + sign image    │   (deploy key)      │ environments/qa/   (PR)      │     this repo
  │ release-please -> versions   │ ── promote/qa-* ──► │ environments/prod/ (approval)│
  └──────────────────────────────┘      branch         └──────────────────────────────┘
```

| App | Stack | Image |
|---|---|---|
| [`orders-api`](orders-api) | Python / FastAPI | `ghcr.io/rosaliei/orders-api` |
| [`inventory-svc`](inventory-svc) | Node.js | `ghcr.io/rosaliei/inventory-svc` |
| [`web-frontend`](web-frontend) | nginx status page (calls the two APIs) | `ghcr.io/rosaliei/web-frontend` |

## 1. By hand

```bash
make test     # lint + unit tests for all 3 apps
make build    # build the images locally
make e2e      # run them with the REAL chart from the GitOps repo on a throwaway kind cluster
```

## 2. Automation

| When | What runs | Result |
|---|---|---|
| **Pull request** | [`ci.yaml`](.github/workflows/ci.yaml): tests, e2e with the GitOps repo's chart, build + Trivy scan | Nothing is published |
| **Merge to main** | Same checks, then push + cosign-sign the image (with SBOM + provenance) | The bot commits `sha-xxxxxxx` + digest into the GitOps repo's `environments/dev`, and ArgoCD deploys dev |
| **`feat:` / `fix:` merged** | [`release-please.yaml`](.github/workflows/release-please.yaml) opens or updates a release PR (next version + CHANGELOG) | Merging it builds `x.y.z` and pushes a `promote/qa-*` branch to the GitOps repo, which opens the qa PR |
| **Weekly + every PR** | [`security.yaml`](.github/workflows/security.yaml): Gitleaks + Trivy (deps, Dockerfiles) | Results in the Security tab |

**How CI writes to the other repo:** a **deploy key** (SSH, write access to the GitOps repo only) stored as the
secret `GITOPS_DEPLOY_KEY`. It can push commits but cannot call the GitHub API or merge PRs. CI never gets
cluster credentials: ArgoCD pulls from inside the cluster.

## Versioning

Conventional Commits in PR titles, e.g. `fix(orders-api): ...` → patch, `feat(orders-api): ...` → minor.
Every app has its own version (`<app>/version.txt`), CHANGELOG and tag (`orders-api-v0.2.0`).
Tags are immutable. `sha-<commit>` tags go to dev only. Only `x.y.z` releases are promoted to qa and prod,
always the same digest.

<sub>History before this repo existed (the 0.1.0 and 0.2.0 releases) was moved here from gitops-monorepo with `git filter-repo`.</sub>
