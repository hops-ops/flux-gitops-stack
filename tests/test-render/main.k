import models.ai.com.ops.hops.v1alpha1 as stacksv1alpha1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1

# ==============================================================================
# Unit tests for FluxGitopsStack XRD
#
# Philosophy: test the Hops API contract, not provider internals.
# ==============================================================================

_fluxAndRepoReady = [
    {
        apiVersion = "helm.m.crossplane.io/v1beta1"
        kind = "Release"
        metadata = {
            name = "flux"
            annotations = {"crossplane.io/composition-resource-name" = "flux"}
        }
        status.conditions = [
            {type = "Ready", status = "True"}
            {type = "Synced", status = "True"}
        ]
    }
    {
        apiVersion = "repo.github.m.upbound.io/v1alpha1"
        kind = "Repository"
        metadata = {
            name = "gitops-repository"
            annotations = {"crossplane.io/composition-resource-name" = "gitops-repository"}
        }
        status.conditions = [
            {type = "Ready", status = "True"}
            {type = "Synced", status = "True"}
        ]
        status.atProvider = {
            fullName = "hops-ops/test-cluster-gitops"
        }
    }
]

_authSecretReady = [
    {
        apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
        kind = "Object"
        metadata = {
            name = "gitops-auth-secret"
            annotations = {"crossplane.io/composition-resource-name" = "gitops-auth-secret"}
        }
        status.conditions = [
            {type = "Ready", status = "True"}
            {type = "Synced", status = "True"}
        ]
    }
]

_sourceReady = [
    {
        apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
        kind = "Object"
        metadata = {
            name = "gitops-source"
            annotations = {"crossplane.io/composition-resource-name" = "gitops-source"}
        }
        status.conditions = [
            {type = "Ready", status = "True"}
            {type = "Synced", status = "True"}
        ]
        status.atProvider = {
            manifest.status.artifact.revision = "main@sha1:abc123"
        }
    }
]

_kustomizationsReady = [
    {
        apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
        kind = "Object"
        metadata = {
            name = "apps-kustomization"
            annotations = {"crossplane.io/composition-resource-name" = "apps-kustomization"}
        }
        status.conditions = [
            {type = "Ready", status = "True"}
            {type = "Synced", status = "True"}
        ]
        status.atProvider = {
            manifest.status.lastAppliedRevision = "main@sha1:def456"
        }
    }
    {
        apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
        kind = "Object"
        metadata = {
            name = "crossplane-kustomization"
            annotations = {"crossplane.io/composition-resource-name" = "crossplane-kustomization"}
        }
        status.conditions = [
            {type = "Ready", status = "True"}
            {type = "Synced", status = "True"}
        ]
        status.atProvider = {
            manifest.status.lastAppliedRevision = "main@sha1:fedcba"
        }
    }
]

_items = [
    metav1alpha1.CompositionTest {
        metadata.name = "minimal-renders-flux-and-repo"
        spec = {
            compositionPath = "apis/fluxgitopsstacks/composition.yaml"
            xrdPath = "apis/fluxgitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.FluxGitopsStack {
                metadata.name = "test-flux"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                }
            }
            assertResources = [
                {
                    apiVersion = "helm.m.crossplane.io/v1beta1"
                    kind = "Release"
                    metadata.name = "flux"
                    spec.forProvider = {
                        chart = {
                            name = "flux2"
                            repository = "oci://ghcr.io/fluxcd-community/charts"
                            version = "2.18.3"
                        }
                        namespace = "flux-system"
                        values.installCRDs = True
                    }
                }
                {
                    apiVersion = "repo.github.m.upbound.io/v1alpha1"
                    kind = "Repository"
                    metadata.name = "gitops-repository"
                    spec = {
                        managementPolicies = ["Observe", "Create", "Update", "LateInitialize"]
                        forProvider = {
                            name = "test-cluster-gitops"
                            visibility = "private"
                            hasIssues = True
                        }
                    }
                }
            ]
        }
    }

    metav1alpha1.CompositionTest {
        metadata.name = "custom-labels-merged-with-defaults"
        spec = {
            compositionPath = "apis/fluxgitopsstacks/composition.yaml"
            xrdPath = "apis/fluxgitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.FluxGitopsStack {
                metadata.name = "labeled-flux"
                spec = {
                    clusterName = "test-cluster"
                    labels = {team = "platform", environment = "staging"}
                    repository.org = "hops-ops"
                }
            }
            assertResources = [
                {
                    apiVersion = "helm.m.crossplane.io/v1beta1"
                    kind = "Release"
                    metadata = {
                        name = "flux"
                        labels = {
                            "hops.ops.com.ai/managed" = "true"
                            "hops.ops.com.ai/fluxgitopsstack" = "labeled-flux"
                            team = "platform"
                            environment = "staging"
                        }
                    }
                }
                {
                    apiVersion = "repo.github.m.upbound.io/v1alpha1"
                    kind = "Repository"
                    metadata = {
                        name = "gitops-repository"
                        labels = {
                            "hops.ops.com.ai/managed" = "true"
                            "hops.ops.com.ai/fluxgitopsstack" = "labeled-flux"
                            team = "platform"
                            environment = "staging"
                        }
                    }
                }
            ]
        }
    }

    metav1alpha1.CompositionTest {
        metadata.name = "flux-override-all-values"
        spec = {
            compositionPath = "apis/fluxgitopsstacks/composition.yaml"
            xrdPath = "apis/fluxgitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.FluxGitopsStack {
                metadata.name = "override-test"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                    flux.overrideAllValues = {
                        installCRDs = False
                        sourceController.create = False
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "helm.m.crossplane.io/v1beta1"
                    kind = "Release"
                    metadata.name = "flux"
                    spec.forProvider.values = {
                        installCRDs = False
                        sourceController.create = False
                    }
                }
            ]
        }
    }

    metav1alpha1.CompositionTest {
        metadata.name = "flux-values-merge-with-defaults"
        spec = {
            compositionPath = "apis/fluxgitopsstacks/composition.yaml"
            xrdPath = "apis/fluxgitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.FluxGitopsStack {
                metadata.name = "merge-test"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                    flux.values = {
                        notificationController.create = False
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "helm.m.crossplane.io/v1beta1"
                    kind = "Release"
                    metadata.name = "flux"
                    spec.forProvider.values = {
                        installCRDs = True
                        prometheus.podMonitor.create = False
                        notificationController.create = False
                        sourceController.resources.requests = {
                            cpu = "100m"
                            memory = "64Mi"
                        }
                    }
                }
            ]
        }
    }

    metav1alpha1.CompositionTest {
        metadata.name = "repo-template-no-autoinit"
        spec = {
            compositionPath = "apis/fluxgitopsstacks/composition.yaml"
            xrdPath = "apis/fluxgitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.FluxGitopsStack {
                metadata.name = "tmpl-test"
                spec = {
                    clusterName = "test-cluster"
                    repository = {
                        org = "hops-ops"
                        template = {
                            owner = "hops-ops"
                            repository = "flux-gitops-template"
                        }
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "repo.github.m.upbound.io/v1alpha1"
                    kind = "Repository"
                    metadata.name = "gitops-repository"
                    spec.initProvider = {
                        deleteBranchOnMerge = True
                        template = [
                            {
                                owner = "hops-ops"
                                repository = "flux-gitops-template"
                                includeAllBranches = False
                            }
                        ]
                    }
                }
            ]
        }
    }

    metav1alpha1.CompositionTest {
        metadata.name = "repo-allow-delete-uses-xr-policies"
        spec = {
            compositionPath = "apis/fluxgitopsstacks/composition.yaml"
            xrdPath = "apis/fluxgitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.FluxGitopsStack {
                metadata.name = "delete-test"
                spec = {
                    clusterName = "test-cluster"
                    managementPolicies = ["*"]
                    repository = {
                        org = "hops-ops"
                        allowDelete = True
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "repo.github.m.upbound.io/v1alpha1"
                    kind = "Repository"
                    metadata.name = "gitops-repository"
                    spec.managementPolicies = ["*"]
                }
            ]
        }
    }

    metav1alpha1.CompositionTest {
        metadata.name = "gitrepository-renders-after-flux-and-repo-ready"
        spec = {
            compositionPath = "apis/fluxgitopsstacks/composition.yaml"
            xrdPath = "apis/fluxgitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.FluxGitopsStack {
                metadata.name = "source-test"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                    source = {
                        name = "platform"
                        branch = "develop"
                        interval = "1m"
                        timeout = "30s"
                    }
                }
            }
            observedResources = _fluxAndRepoReady
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "gitops-source"
                    spec.forProvider.manifest = {
                        apiVersion = "source.toolkit.fluxcd.io/v1"
                        kind = "GitRepository"
                        metadata = {
                            name = "platform"
                            namespace = "flux-system"
                        }
                        spec = {
                            interval = "1m"
                            timeout = "30s"
                            url = "https://github.com/hops-ops/test-cluster-gitops.git"
                            ref.branch = "develop"
                        }
                    }
                }
            ]
        }
    }

    metav1alpha1.CompositionTest {
        metadata.name = "apps-kustomization-renders-after-source-ready"
        spec = {
            compositionPath = "apis/fluxgitopsstacks/composition.yaml"
            xrdPath = "apis/fluxgitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.FluxGitopsStack {
                metadata.name = "apps-test"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                    kustomizations.apps = {
                        path = "./clusters/prod/apps"
                        interval = "2m"
                        prune = False
                        wait = False
                        timeout = "5m"
                    }
                }
            }
            observedResources = _fluxAndRepoReady + _sourceReady
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "apps-kustomization"
                    spec.forProvider.manifest = {
                        apiVersion = "kustomize.toolkit.fluxcd.io/v1"
                        kind = "Kustomization"
                        metadata = {
                            name = "apps"
                            namespace = "flux-system"
                        }
                        spec = {
                            interval = "2m"
                            path = "./clusters/prod/apps"
                            prune = False
                            wait = False
                            timeout = "5m"
                            sourceRef = {
                                kind = "GitRepository"
                                name = "gitops"
                            }
                        }
                    }
                }
            ]
        }
    }

    metav1alpha1.CompositionTest {
        metadata.name = "crossplane-kustomization-renders-when-enabled"
        spec = {
            compositionPath = "apis/fluxgitopsstacks/composition.yaml"
            xrdPath = "apis/fluxgitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.FluxGitopsStack {
                metadata.name = "crossplane-test"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                    kustomizations.crossplane = {
                        enabled = True
                        name = "xp"
                        path = "./platform/crossplane"
                    }
                }
            }
            observedResources = _fluxAndRepoReady + _sourceReady
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "crossplane-kustomization"
                    spec.forProvider.manifest = {
                        apiVersion = "kustomize.toolkit.fluxcd.io/v1"
                        kind = "Kustomization"
                        metadata.name = "xp"
                        spec = {
                            path = "./platform/crossplane"
                            sourceRef.name = "gitops"
                        }
                    }
                }
            ]
        }
    }

    metav1alpha1.CompositionTest {
        metadata.name = "eso-renders-flux-github-app-secret"
        spec = {
            compositionPath = "apis/fluxgitopsstacks/composition.yaml"
            xrdPath = "apis/fluxgitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.FluxGitopsStack {
                metadata.name = "eso-test"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                    externalSecrets = {
                        enabled = True
                        secretStoreName = "aws-secrets"
                        githubApp = {
                            secretPath = "github/flux-creds"
                            appIdKey = "app_id"
                            privateKeyKey = "pem_key"
                        }
                    }
                }
            }
            observedResources = _fluxAndRepoReady
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "gitops-auth-secret"
                    spec.forProvider.manifest.spec = {
                        secretStoreRef = {
                            name = "aws-secrets"
                            kind = "ClusterSecretStore"
                        }
                        target = {
                            name = "gitops-github-app"
                            template.data = {
                                githubAppID = "{{ .githubAppID }}"
                                githubAppInstallationOwner = "hops-ops"
                                githubAppPrivateKey = "{{ .githubAppPrivateKey }}"
                            }
                        }
                        data = [
                            {
                                secretKey = "githubAppID"
                                remoteRef = {
                                    key = "github/flux-creds"
                                    property = "app_id"
                                }
                            }
                            {
                                secretKey = "githubAppPrivateKey"
                                remoteRef = {
                                    key = "github/flux-creds"
                                    property = "pem_key"
                                }
                            }
                        ]
                    }
                }
            ]
        }
    }

    metav1alpha1.CompositionTest {
        metadata.name = "eso-installation-id-omits-owner"
        spec = {
            compositionPath = "apis/fluxgitopsstacks/composition.yaml"
            xrdPath = "apis/fluxgitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.FluxGitopsStack {
                metadata.name = "eso-id"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "my-org"
                    externalSecrets = {
                        enabled = True
                        githubApp = {
                            secretPath = "github/app"
                            installationOwnerKey = "ignored_owner"
                            installationIdKey = "installation_id"
                        }
                    }
                }
            }
            observedResources = _fluxAndRepoReady
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "gitops-auth-secret"
                    spec.forProvider.manifest.spec = {
                        target.template.data = {
                            githubAppID = "{{ .githubAppID }}"
                            githubAppInstallationID = "{{ .githubAppInstallationID }}"
                            githubAppPrivateKey = "{{ .githubAppPrivateKey }}"
                        }
                        data = [
                            {
                                secretKey = "githubAppID"
                                remoteRef.property = "appId"
                            }
                            {
                                secretKey = "githubAppInstallationID"
                                remoteRef.property = "installation_id"
                            }
                            {
                                secretKey = "githubAppPrivateKey"
                                remoteRef.property = "privateKey"
                            }
                        ]
                    }
                }
            ]
        }
    }

    metav1alpha1.CompositionTest {
        metadata.name = "eso-ready-unlocks-authenticated-source"
        spec = {
            compositionPath = "apis/fluxgitopsstacks/composition.yaml"
            xrdPath = "apis/fluxgitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.FluxGitopsStack {
                metadata.name = "eso-source"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                    externalSecrets = {
                        enabled = True
                        githubApp.secretPath = "github/creds"
                    }
                }
            }
            observedResources = _fluxAndRepoReady + _authSecretReady
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "gitops-source"
                    spec.forProvider.manifest.spec = {
                        provider = "github"
                        secretRef.name = "gitops-github-app"
                    }
                }
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata.name = "delete-auth-secret-before-flux"
                }
            ]
        }
    }

    metav1alpha1.CompositionTest {
        metadata.name = "nodepool-adds-flux-placement-and-resources"
        spec = {
            compositionPath = "apis/fluxgitopsstacks/composition.yaml"
            xrdPath = "apis/fluxgitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.FluxGitopsStack {
                metadata.name = "nodepool-test"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                    nodePool.enabled = True
                }
            }
            assertResources = [
                {
                    apiVersion = "helm.m.crossplane.io/v1beta1"
                    kind = "Release"
                    metadata.name = "flux"
                    spec.forProvider.values = {
                        sourceController = {
                            nodeSelector = {"workload-type" = "gitops"}
                            tolerations = [
                                {
                                    key = "gitops"
                                    operator = "Equal"
                                    value = "true"
                                    effect = "NoSchedule"
                                }
                            ]
                            resources.requests = {
                                cpu = "100m"
                                memory = "64Mi"
                            }
                        }
                        kustomizeController.nodeSelector = {"workload-type" = "gitops"}
                        helmController.nodeSelector = {"workload-type" = "gitops"}
                        notificationController.nodeSelector = {"workload-type" = "gitops"}
                        imageAutomationController.nodeSelector = {"workload-type" = "gitops"}
                        imageReflectionController.nodeSelector = {"workload-type" = "gitops"}
                    }
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "nodepool-gitops"
                    spec.forProvider.manifest = {
                        apiVersion = "karpenter.sh/v1"
                        kind = "NodePool"
                        metadata.name = "hops-gitops"
                        spec.template.metadata.labels = {"workload-type" = "gitops"}
                        spec.template.spec.taints = [
                            {
                                key = "gitops"
                                value = "true"
                                effect = "NoSchedule"
                            }
                        ]
                    }
                }
            ]
        }
    }

    metav1alpha1.CompositionTest {
        metadata.name = "status-exposes-flux-readiness-slices"
        spec = {
            compositionPath = "apis/fluxgitopsstacks/composition.yaml"
            xrdPath = "apis/fluxgitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.FluxGitopsStack {
                metadata.name = "status-test"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                    kustomizations.crossplane.enabled = True
                }
            }
            observedResources = _fluxAndRepoReady + _sourceReady + _kustomizationsReady
            assertResources = [
                {
                    apiVersion = "hops.ops.com.ai/v1alpha1"
                    kind = "FluxGitopsStack"
                    metadata.name = "status-test"
                    status = {
                        ready = True
                        repository.url = "https://github.com/hops-ops/test-cluster-gitops"
                        source = {
                            ready = True
                            revision = "main@sha1:abc123"
                        }
                        kustomizations = {
                            apps = {
                                ready = True
                                lastAppliedRevision = "main@sha1:def456"
                            }
                            crossplane = {
                                ready = True
                                lastAppliedRevision = "main@sha1:fedcba"
                            }
                        }
                    }
                }
            ]
        }
    }
]

items = _items
