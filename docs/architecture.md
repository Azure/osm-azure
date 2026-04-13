# OSM Azure Arc Extension — Architecture Deep Dive

This document provides a detailed technical reference for the OSM Azure Arc extension: how it works internally, how the Helm chart is structured, how the CI/CD pipelines operate, and how regional rollout is orchestrated.

## Table of Contents

- [Extension Lifecycle](#extension-lifecycle)
- [Helm Chart Architecture](#helm-chart-architecture)
- [Metrics Pipeline](#metrics-pipeline)
- [CI/CD Pipeline Architecture](#cicd-pipeline-architecture)
- [Regional Rollout Mechanics](#regional-rollout-mechanics)
- [Conformance Testing](#conformance-testing)
- [Key Environment Variables](#key-environment-variables)
- [Troubleshooting](#troubleshooting)

---

## Extension Lifecycle

### Install Flow

```
User/Pipeline
    │
    ▼
az k8s-extension create
    --extension-type Microsoft.openservicemesh
    --release-train {staging|pilot|preview|stable}
    --version {chart_version}
    │
    ▼
Arc Extension Resource Provider (RP)
    │  Looks up registered artifactEndpoints
    │  for the given version + release train + region
    │
    ▼
Arc Extension Agent (on-cluster, in azure-arc ns)
    │  Pulls Helm chart from ACR
    │  Runs: helm install osm charts/osm-arc --namespace arc-osm-system
    │
    ▼
Helm Pre-Install Hook (osm-label job)
    │  Labels kube-system, azure-arc, arc-osm-system
    │  with "openservicemesh.io/ignore: true"
    │  Labels arc-osm-system with "admission.policy.azure.com/ignore: true"
    │
    ▼
OSM Dependency Chart Install
    │  Upstream OSM chart v1.1.1 deploys:
    │    - osm-controller (1 replica)
    │    - osm-injector (1 replica)
    │    - osm-bootstrap (1 replica)
    │    - MutatingWebhookConfiguration (arc-osm-webhook-osm)
    │
    ▼
Arc-Specific Resources
    │  - AzureExtensionIdentity CRD (in azure-arc ns)
    │  - osm-metrics-agent Deployment (4 containers)
    │  - RBAC roles/bindings for identity + metrics
    │
    ▼
Extension Running ✓
```

### Update Flow

Updates are handled via `az k8s-extension update` (or `create` with a config file):
1. The RP instructs the on-cluster agent to update the Helm release
2. Only next-minor-version upgrades are supported
3. CRDs may need to be manually deleted before upgrade (see `docs/update-extension.md`)
4. ConfigMap customizations may be reverted during upgrade

The upgrade pipeline (`upgrade-job/`) validates this by:
1. Installing the previously published version
2. Running BATS tests 
3. Upgrading to the new version
4. Re-running tests

### Delete Flow

Extension deletion uses a direct REST API call to the Arc Extensions API:
```
DELETE https://management.azure.com/{resourceId}/providers/Microsoft.KubernetesConfiguration/extensions/{name}?api-version=2020-07-01-preview
```

This removes all extension deployments from `arc-osm-system` but leaves the namespace itself and the `azure-arc` namespace intact.

---

## Helm Chart Architecture

### Chart.yaml — Dependency Declaration

The `osm-arc` chart declares the upstream OSM chart as its only dependency:
```yaml
dependencies:
  - name: osm
    version: "1.1.1"
    repository: "https://openservicemesh.github.io/osm"
```

When `helm dependency update` runs, it downloads the upstream chart into `charts/osm-arc/charts/osm-1.1.1.tgz`.

### values.yaml — Configuration Hierarchy

Values are structured in three tiers:

1. **Azure metadata** (populated by Arc RP at install time):
   ```yaml
   Azure:
     Cluster:
       Distribution: <cluster_distribution>  # aks, gke, eks, openshift, rancher_rke
       Region: ""                            # Used for metrics routing
     Extension:
       Name: ""                              # Extension instance name
       ResourceId: ""                        # ARM resource ID
   ```

2. **OSM Arc settings**:
   ```yaml
   OpenServiceMesh:
     ignoreNamespaces: "kube-system azure-arc arc-osm-system"
   ```

3. **Upstream OSM overrides** (nested under `osm:`):
   - All images pinned to `mcr.microsoft.com/oss/openservicemesh/*`
   - Permissive traffic policy enabled by default
   - Prometheus and Jaeger deployment disabled (metrics handled by Arc pipeline)
   - Webhook config prefix set to `arc-osm-webhook`

### Template Resources

| Template | Resource Type | Purpose |
|----------|--------------|---------|
| `_helpers.tpl` | Template helper | Defines `osm.arcLabels` — standard labels applied to all resources |
| `azure-extension-identity.yaml` | `AzureExtensionIdentity` CRD | Links extension service account to Arc managed identity tokens |
| `metrics-agent-deployment.yaml` | `Deployment` | 4-container metrics collection pod |
| `metrics-config.yaml` | 2x `ConfigMap` | MDM config + Telegraf scraping/shipping config |
| `metrics-rbac.yaml` | Roles, RoleBindings, ClusterRoles | RBAC for identity requests, pod watching, namespace patching |
| `osm-label.yml` | SA, ClusterRole, RoleBindings, Job | Pre-install hook: labels system namespaces to exclude from mesh |

### Pre-Install Labeling Hook (osm-label.yml)

This is a critical Helm hook (`helm.sh/hook: pre-install`) that runs **before** the main chart installs:

1. Creates a temporary ServiceAccount, ClusterRole, and RoleBindings (hook weights 25-35)
2. Runs a Job (weight 40) that:
   - Iterates over namespaces in `OpenServiceMesh.ignoreNamespaces`
   - Labels each with `openservicemesh.io/ignore: "true"` (prevents sidecar injection)
   - Labels the release namespace with `admission.policy.azure.com/ignore: "true"` (prevents Azure Policy rejection)
3. All hook resources are deleted after successful execution (`hook-delete-policy: before-hook-creation,hook-succeeded`)

The job uses the Kubernetes API directly via `curl` from an Alpine container, authenticating with the mounted service account token.

---

## Metrics Pipeline

The `osm-metrics-agent` deployment collects OSM metrics and ships them to Azure's Geneva monitoring system:

```
osm-controller (exposes Prometheus metrics)
        │
        ▼
    telegraf
    ├── Scrapes Prometheus endpoints (label: app.kubernetes.io/component=osm-controller)
    ├── Collects Kubernetes pod inventory
    ├── Filters out noisy metrics (GC, memstats, workqueue, etc.)
    └── Writes to prom-mdm-converter via HTTP (localhost:8090)
        │
        ▼
  prom-mdm-converter
    ├── Converts Prometheus remote write format to MDM
    ├── Routes to Geneva account "AzureServiceMesh"
    └── Uses cluster region as default MDM namespace
        │
        ▼
      mdm (Geneva MDM agent)
    ├── Emits metrics via statsd (UDP + TCP)
    └── Uses config from osm-mdm-config ConfigMap
        
  msi-adapter (runs alongside)
    ├── Provides managed identity tokens for authentication
    ├── Connects to Arc identity system via TOKEN_NAMESPACE
    └── Requires NET_ADMIN capability for MSI token acquisition
```

### Telemetry Routing

- **Geneva Account**: `AzureServiceMesh`
- **MDM Namespace**: Set to the cluster's Azure region (e.g., `eastus`)
- **Extension ARM ID**: Passed to both msi-adapter and prom-mdm-converter for resource attribution
- **Update interval**: Telegraf scrapes every 60s, flushes every 10s

---

## CI/CD Pipeline Architecture

### Pipeline Dependency Graph

```
                    ┌─────────────────────────────┐
                    │  PR E2E (e2e-job.yaml)       │
                    │  Trigger: PR/push to main    │
                    └──────────────┬──────────────┘
                                   │
                    ┌──────────────▼──────────────┐
                    │  e2e-aks-arc.yaml            │
                    │  (main test orchestrator)    │
                    └──────────────┬──────────────┘
                                   │
        ┌──────────────────────────┼───────────────────────────┐
        │                          │                           │
   Install Tools            Package & Publish           Test Execution
   ┌──────────┐           ┌──────────────┐           ┌──────────────┐
   │ Helm 3   │           │ helm package │           │ BATS tests   │
   │ ORAS     │           │ oras push    │           │ Upstream e2e │
   │ BATS     │           │ register ext │           └──────────────┘
   └──────────┘           └──────────────┘
                                                     Infrastructure
                                                    ┌──────────────┐
                                                    │ AKS create   │
                                                    │ Arc enable   │
                                                    │ Extension add│
                                                    │ AKS cleanup  │
                                                    │ ACR cleanup  │
                                                    └──────────────┘
```

### Template Reuse

All pipelines compose from shared templates in `.pipelines/templates/`:

| Template | Used By | Purpose |
|----------|---------|---------|
| `install-helm3.yaml` | PR, Upgrade, Prod, Addon | Install Helm v3.1.1 |
| `install-oras.yaml` | PR, Upgrade, Conformance | Install ORAS v0.8.1 for OCI pushes |
| `install-bats.yaml` | PR, Upgrade, Prod | Install BATS v1.2.0 |
| `package-helm-chart.yaml` | PR, Upgrade | `helm dependency update` + `helm package` |
| `publish-helm-chart.yaml` | PR, Upgrade | Push chart to staging ACR, generate SBOM |
| `register-extension.yaml` | PR, Upgrade | Register version with Arc API |
| `aks-setup.yaml` | All E2E | Create ephemeral AKS cluster |
| `enable-arc.yaml` | All Arc E2E | Connect AKS to Arc |
| `add-arc-extension.yaml` | PR, Upgrade, Prod | Install extension on cluster |
| `run-upstream-e2e.yaml` | PR, Addon | Run upstream OSM ginkgo tests |
| `debug-resources.yaml` | PR, Addon | Collect logs/state on failure |
| `acr-cleanup.yaml` | PR, Upgrade | Delete chart from staging ACR |
| `aks-cleanup.yaml` | All E2E | Delete AKS resource group |

### Ephemeral Cluster Naming

AKS clusters are created with random names: `osm-helm-e2e-{6-random-hex-chars}`. The same name is used for both the resource group and the cluster, simplifying cleanup via `az group delete`.

### Upstream E2E Test Branch Selection

The `run-upstream-e2e.yaml` template automatically checks out the matching upstream OSM branch:
- Extracts the major.minor version from `CHART_VERSION`
- Checks out `release-v{major}.{minor}` branch of the upstream OSM repo
- Handles the `-{digit}` suffix pattern (e.g., `1.1.1-1` → `release-v1.1`)

---

## Regional Rollout Mechanics

### Registration API

Both `register-extension.sh` (staging) and `register-extension-prod.sh` (production) send PUT requests to:
```
{ARC_API_URL}/subscriptions/{SUBSCRIPTION}/extensionTypeRegistrations/microsoft.openservicemesh/versions/{VERSION}?api-version=2021-05-01
```

The request body contains an `artifactEndpoints` array. Each entry maps:
- A set of **regions** to a set of **release trains** to an **ACR chart path**

### Staging Registration (register-extension.sh)

Creates a single endpoint:
```json
{
  "artifactEndpoints": [{
    "Regions": ["eastus2euap", "eastus", "westeurope"],
    "Releasetrains": ["staging"],
    "FullPathToHelmChart": "{ACR_PATH}",
    "ExtensionUpdateFrequencyInMinutes": 60
  }]
}
```

### Production Registration (register-extension-prod.sh)

Creates multiple endpoints by looping over release trains (`pilot`, `preview`, `stable`) and adding entries for both canary and batch1 region sets. Each release train gets:
- One canary endpoint (eastus2euap only)
- One batch1 endpoint (19 production regions)
- One staging endpoint (shared across all trains)

The script uses bash arrays (`REGISTRIES_PROD_CANARY`, `REGISTRIES_PROD_BATCH1`) indexed by release train position, allowing each train to point to a different ACR registry/path.

### ACR Registry Strategy

Different registries are used for different environments:
- **Staging**: Separate staging ACR for development/testing
- **Production canary**: Production ACR, canary path per release train
- **Production batch1**: Production ACR, batch1 path per release train

This allows independent chart promotion through the staging → canary → batch1 pipeline.

---

## Conformance Testing

The Sonobuoy conformance plugin runs as a Kubernetes Job on Arc-connected clusters:

1. **Plugin image** is built from `conformance/plugins/osm-arc/Dockerfile` and pushed to `osmazure.azurecr.io`
2. **Sonobuoy** orchestrates the test run using `conformance.yaml` plugin config
3. **Test execution** (`osm_arc_conformance.sh`):
   - Logs in via service principal
   - Installs the OSM Arc extension on the target cluster
   - Clones the Azure/osm fork at a specified branch
   - Runs upstream e2e tests via `gotestsum` with ginkgo
   - On failure: parses JUnit XML, extracts failed test names, retries with `ginkgo.focus`
   - Packages results as `results.tar.gz` for Sonobuoy
4. **Failure reporting**: If setup fails, `setup_failure_handler.py` generates a JUnit XML report with the error message

---

## Key Environment Variables

### From `.env` / `.env.example`

| Variable | Purpose |
|----------|---------|
| `SUBSCRIPTION` | Azure subscription ID |
| `RESOURCEGROUP` | Resource group for the Arc-connected cluster |
| `REGION` | Azure region (e.g., `eastus2euap`) |
| `CLUSTERNAME` | Kubernetes cluster name |
| `CHECKOUT_TAG` | Chart version to install |
| `RELEASE_NAMESPACE` | Target namespace (default: `arc-osm-system`) |
| `EXTENSION_NAME` | Extension instance name (default: `osm`) |
| `REGISTRY` / `REPO` | ACR publishing coordinates |
| `IMAGETAG` | Chart version tag for ACR |

### Pipeline Variables (set in Azure DevOps)

| Variable | Purpose |
|----------|---------|
| `SUBSCRIPTION_ID` | Azure subscription |
| `REGISTRY_NAME` | Staging ACR name |
| `REPOSITORY_NAME` | Full ACR repository path |
| `ARC_RESOURCE_TOKEN` | Resource URL for Arc API auth |
| `ARC_API_URL` | Arc Registration API base URL |
| `ARC_CLUSTER_LOCATION` | Region for Arc cluster |
| `AKS_CLUSTER_LOCATION` | Region for ephemeral AKS cluster |
| `release.namespace` | Extension release namespace |
| `UPSTREAM_DOCKER_REGISTRY` | Docker registry for upstream e2e images |
| `K8S_VERSION` | Kubernetes version for AKS addon tests |

---

## Troubleshooting

### Common Issues

**Extension install hangs or fails:**
- Check Arc agent health: `kubectl get pods -n azure-arc`
- Verify the chart version is registered: the extension agent needs to find the chart in ACR
- Check namespace labels: `kubectl get ns --show-labels`

**Metrics not flowing:**
- Check msi-adapter logs: `kubectl logs -l app=osm-metrics-agent -c msi-adapter -n arc-osm-system`
- Verify managed identity: the `AzureExtensionIdentity` CRD must exist in `azure-arc` namespace
- Check telegraf config: ensure `osm-controller` pods have the `app.kubernetes.io/component=osm-controller` label

**Upgrade fails:**
- Only next-minor upgrades supported; delete CRDs first if upgrading across minor versions
- Check Helm history: `helm history osm -n arc-osm-system`

**Pipeline failures:**
- Debug template (`debug-resources.yaml`) runs on failure and captures pod logs, events, and Helm history
- Check ACR cleanup: stale staging images can cause version conflicts
