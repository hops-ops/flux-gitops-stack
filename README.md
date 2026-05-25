# flux-gitops-stack

A Crossplane resource that provisions a Flux GitOps foundation: the Flux controllers, a GitHub repository, a Flux `GitRepository`, and optional Flux `Kustomization` syncs.

## Why FluxGitopsStack?

**Without FluxGitopsStack:**
- Controller install, repo creation, and source wiring happen in separate steps.
- Private repository credentials are easy to render in the wrong Secret format.
- GitOps paths drift from the repository template and cluster conventions.
- Deleting Flux before its custom resources can leave cleanup stuck.

**With FluxGitopsStack:**
- One XR installs Flux and creates the GitHub source repository.
- The Flux `GitRepository` URL is derived from the managed repo.
- ESO can project GitHub App credentials in Flux's expected Secret shape.
- Optional `Kustomization` resources reconcile `./apps` and `./crossplane`.
- GitHub repository deletion stays disabled unless explicitly allowed.

## The Journey

### Stage 1: Getting Started

Install Flux and create a private GitHub repository with default paths.

```yaml
apiVersion: hops.ops.com.ai/v1alpha1
kind: FluxGitopsStack
metadata:
  name: flux-gitops
  namespace: default
spec:
  clusterName: my-cluster
  repository:
    org: hops-ops
```

This creates a `flux2` Helm release in `flux-system`, a GitHub repo named `my-cluster-gitops`, a Flux `GitRepository` named `gitops`, and an apps `Kustomization` for `./apps` once the source is ready.

### Stage 2: Growing

Use a Flux-compatible template repo and tune the chart while preserving Hops defaults.

```yaml
apiVersion: hops.ops.com.ai/v1alpha1
kind: FluxGitopsStack
metadata:
  name: flux-gitops
  namespace: default
spec:
  clusterName: production
  labels:
    team: platform
    environment: production
  repository:
    org: hops-ops
    name: production-gitops
    topics: [gitops, flux, production]
    template:
      owner: hops-ops
      repository: flux-gitops-template
  flux:
    values:
      prometheus:
        podMonitor:
          create: true
```

When `repository.template` is set, GitHub initializes the repo from that template instead of creating an empty README.

### Stage 3: Enterprise Scale

Enable private repo credentials, Crossplane sync, and optional controller isolation.

```yaml
apiVersion: hops.ops.com.ai/v1alpha1
kind: FluxGitopsStack
metadata:
  name: flux-gitops
  namespace: default
spec:
  clusterName: production
  repository:
    org: hops-ops
    name: production-gitops
  externalSecrets:
    enabled: true
    secretStoreName: hops-aws-secrets-manager
    githubApp:
      secretPath: github/hops-gitops
      appIdKey: GH_APP_ID
      privateKeyKey: GH_APP_KEY
  kustomizations:
    crossplane:
      enabled: true
      path: ./crossplane
  nodePool:
    enabled: true
```

Flux GitHub App authentication requires `githubAppID`, `githubAppPrivateKey`, and exactly one of `githubAppInstallationOwner` or `githubAppInstallationID`. When `installationIdKey` is omitted, this stack writes `githubAppInstallationOwner` from `repository.org` unless `installationOwnerKey` is provided.

### Stage 4: Import Existing

Bring an existing repository under management without allowing accidental deletion.

```yaml
apiVersion: hops.ops.com.ai/v1alpha1
kind: FluxGitopsStack
metadata:
  name: flux-gitops
  namespace: default
spec:
  clusterName: production
  managementPolicies: ["Observe", "Update", "LateInitialize"]
  repository:
    org: hops-ops
    name: existing-gitops
    allowDelete: false
  kustomizations:
    apps:
      path: ./clusters/production/apps
```

`repository.allowDelete` defaults to `false`, so the GitHub repository uses observe/create/update/late-init policies unless deletion is explicitly enabled.

## Using FluxGitopsStack

Downstream stacks can read `status.repository.url` to display or link the GitOps repo. Operators can use `status.source.revision` and `status.kustomizations.*.lastAppliedRevision` to verify what Flux last reconciled.

## Status

| Field | Description |
|-------|-------------|
| `status.ready` | True when required composed resources are ready. |
| `status.repository.url` | GitHub repository URL. |
| `status.source.ready` | Provider-kubernetes readiness for the Flux `GitRepository` object. |
| `status.source.revision` | Observed Flux source artifact revision, when present. |
| `status.kustomizations.apps.ready` | Provider-kubernetes readiness for the apps `Kustomization`. |
| `status.kustomizations.apps.lastAppliedRevision` | Last revision applied by the apps `Kustomization`, when present. |
| `status.kustomizations.crossplane.ready` | Provider-kubernetes readiness for the Crossplane `Kustomization`. |
| `status.kustomizations.crossplane.lastAppliedRevision` | Last revision applied by the Crossplane `Kustomization`, when present. |

## Composed Resources

| Resource | Type | Purpose |
|----------|------|---------|
| `flux` | Helm `Release` | Installs Flux controllers and CRDs from the `flux2` chart. |
| `gitops-repository` | GitHub `Repository` | Creates or manages the GitOps source repository. |
| `gitops-auth-secret` | Kubernetes `Object` wrapping `ExternalSecret` | Projects GitHub App credentials for Flux source-controller. |
| `gitops-source` | Kubernetes `Object` wrapping Flux `GitRepository` | Points Flux at the managed repository. |
| `apps-kustomization` | Kubernetes `Object` wrapping Flux `Kustomization` | Reconciles application manifests from `./apps`. |
| `crossplane-kustomization` | Kubernetes `Object` wrapping Flux `Kustomization` | Optionally reconciles Crossplane resources from `./crossplane`. |
| `nodepool-gitops` | Kubernetes `Object` wrapping Karpenter `NodePool` | Optionally isolates Flux controllers on GitOps nodes. |
| Usage guards | Crossplane `Usage` | Keeps Flux installed until dependent Flux objects and secrets are deleted. |

## Development

```bash
make render:all
make validate:all
make test
make e2e
```

## License

Apache-2.0
