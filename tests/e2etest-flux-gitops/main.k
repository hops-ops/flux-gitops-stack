import base64
import file
import datetime
import math
import models.ai.com.ops.hops.v1alpha1 as stacksv1alpha1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1

# ==============================================================================
# E2E Test for FluxGitopsStack
#
# Creates a real GitHub repository, installs Flux via Helm, and creates a Flux
# GitRepository source. The repo is public for this test so no ESO dependency is
# required inside the ephemeral control plane.
#
# Credentials required:
#   secrets/github-creds - provider-upjet-github credentials JSON.
#
# Run: make e2e
# Run without cleanup: up test run tests/e2etest-flux-gitops --e2e --skip-control-plane-cleanup
# ==============================================================================
_github_creds = file.read("secrets/github-creds")
_base64_github_creds = base64.encode(_github_creds)

_now = str(int(math.floor(datetime.ticks())))
_test_name = "e2e-flux-gitops-stack" + _now

_items = [
    metav1alpha1.E2ETest {
        metadata.name = "flux-gitops-e2e"
        spec = {
            crossplane = {
                autoUpgrade.channel = "Rapid"
            }
            defaultConditions = ["Ready"]
            timeoutSeconds = 1800
            cleanupTimeoutSeconds = 600
            skipDelete = False
            extraResources = [
                {
                    apiVersion = "rbac.authorization.k8s.io/v1"
                    kind = "ClusterRoleBinding"
                    metadata.name = "crossplane-system-cluster-admin"
                    roleRef = {
                        apiGroup = "rbac.authorization.k8s.io"
                        kind = "ClusterRole"
                        name = "cluster-admin"
                    }
                    subjects = [
                        {
                            kind = "Group"
                            name = "system:serviceaccounts:crossplane-system"
                            apiGroup = "rbac.authorization.k8s.io"
                        }
                    ]
                }
                {
                    apiVersion = "helm.m.crossplane.io/v1beta1"
                    kind = "ProviderConfig"
                    metadata = {
                        name = "default"
                        namespace = "default"
                    }
                    spec.credentials.source = "InjectedIdentity"
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "ProviderConfig"
                    metadata = {
                        name = "default"
                        namespace = "default"
                    }
                    spec.credentials.source = "InjectedIdentity"
                }
                {
                    apiVersion = "v1"
                    kind = "Secret"
                    metadata = {
                        name = "github-creds"
                        namespace = "default"
                    }
                    data = {
                        creds = _base64_github_creds
                    }
                }
                {
                    apiVersion = "github.m.upbound.io/v1beta1"
                    kind = "ProviderConfig"
                    metadata = {
                        name = "default"
                        namespace = "default"
                    }
                    spec.credentials = {
                        source = "Secret"
                        secretRef = {
                            namespace = "default"
                            name = "github-creds"
                            key = "creds"
                        }
                    }
                }
            ]
            manifests = [
                stacksv1alpha1.FluxGitopsStack {
                    metadata = {
                        name = _test_name
                        namespace = "default"
                    }
                    spec = {
                        clusterName = "default"
                        namespace = "flux-system"
                        managementPolicies = ["*"]
                        labels = {
                            "hops.ops.com.ai/e2etest" = "true"
                            "hops.ops.com.ai/test-run" = _now
                        }
                        helmProviderConfigRef = {
                            name = "default"
                            kind = "ProviderConfig"
                        }
                        kubernetesProviderConfigRef = {
                            name = "default"
                            kind = "ProviderConfig"
                        }
                        githubProviderConfigRef = {
                            name = "default"
                            kind = "ProviderConfig"
                        }
                        repository = {
                            org = "hops-ops"
                            name = _test_name
                            description = "E2E test repo - safe to delete"
                            visibility = "public"
                            allowDelete = True
                        }
                        flux = {
                            values = {
                                sourceController.resources.requests = {cpu = "10m", memory = "64Mi"}
                                kustomizeController.resources.requests = {cpu = "10m", memory = "64Mi"}
                                helmController.resources.requests = {cpu = "10m", memory = "64Mi"}
                                notificationController.resources.requests = {cpu = "10m", memory = "64Mi"}
                                imageAutomationController.resources.requests = {cpu = "10m", memory = "64Mi"}
                                imageReflectionController.resources.requests = {cpu = "10m", memory = "64Mi"}
                            }
                        }
                        kustomizations = {
                            apps.enabled = False
                        }
                    }
                }
            ]
        }
    }
]
items = _items
