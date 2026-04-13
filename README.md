
# OSM Azure Arc Extension

This repository contains the packaging, deployment infrastructure, CI/CD pipelines, and test suites for delivering [Open Service Mesh (OSM)](https://openservicemesh.io/) as an [Azure Arc-enabled Kubernetes extension](https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/extensions). The extension allows customers to install and manage OSM on any Arc-connected Kubernetes cluster through the Azure control plane.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Repository Structure](#repository-structure)
- [How the Arc Extension Works](#how-the-arc-extension-works)
- [Helm Chart Packaging and Publishing](#helm-chart-packaging-and-publishing)
- [Regional Rollout Strategy](#regional-rollout-strategy)
- [CI/CD Pipelines](#cicd-pipelines)
- [Local Development and Testing](#local-development-and-testing)
- [Operational Runbooks](#operational-runbooks)
- [Contributing](#contributing)

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                        Azure Control Plane                          │
│                                                                     │
│  ┌─────────────────┐    ┌──────────────────┐    ┌────────────────┐  │
│  │ Arc Registration │    │  Azure Container  │    │  Arc Extension │  │
│  │      API         │───▶│  Registry (ACR)   │◀───│  RP (Resource  │  │
│  │                  │    │  (Helm Charts)    │    │   Provider)    │  │
│  └─────────────────┘    └──────────────────┘    └───────┬────────┘  │
│                                                         │           │
└─────────────────────────────────────────────────────────┼───────────┘
                                                          │
                          Pulls Helm chart via             │
                          extension agent                  │
                                                          ▼
┌──────────────────────────────────────────────────────────────────────┐
│                   Arc-Connected Kubernetes Cluster                   │
│                                                                     │
│  ┌──────────────┐  ┌─────────────────┐  ┌────────────────────────┐  │
│  │  azure-arc   │  │ arc-osm-system  │  │    kube-system         │  │
│  │  namespace   │  │   namespace     │  │    namespace           │  │
│  │              │  │                 │  │                        │  │
│  │ Arc agents   │  │ osm-controller  │  │ (labeled with          │  │
│  │ Extension    │  │ osm-injector    │  │  openservicemesh.io/   │  │
│  │  agent       │  │ osm-bootstrap   │  │  ignore: "true")       │  │
│  │              │  │ osm-metrics-    │  │                        │  │
│  │              │  │   agent         │  │                        │  │
│  └──────────────┘  └─────────────────┘  └────────────────────────┘  │
│                                                                     │
└──────────────────────────────────────────────────────────────────────┘
```

### Key Components

| Component | Description |
|-----------|-------------|
| **osm-arc Helm chart** | Wraps the upstream OSM Helm chart as a dependency, adding Azure Arc identity, metrics collection, and namespace labeling |
| **Arc Extension RP** | Azure resource provider that manages extension lifecycle (install, update, delete) on Arc-connected clusters |
| **Arc Registration API** | Registers chart versions with specific regions and release trains so the RP knows where to pull charts |
| **Metrics Agent** | 4-container pod (mdm, msi-adapter, prom-mdm-converter, telegraf) that collects OSM metrics and ships them to Geneva/MDM |
| **Pre-install labeling job** | Helm hook that labels system namespaces with `openservicemesh.io/ignore: "true"` to prevent sidecar injection |

---

## Repository Structure

```
osm-azure/
├── charts/osm-arc/              # Helm chart for the Arc extension
│   ├── Chart.yaml               #   Chart metadata + upstream OSM dependency
│   ├── values.yaml              #   Default values (images, config, Azure metadata)
│   └── templates/               #   Kubernetes resource templates
│       ├── _helpers.tpl          #     Shared label definitions
│       ├── azure-extension-identity.yaml  # Arc managed identity CRD
│       ├── metrics-agent-deployment.yaml  # Telemetry collection pod
│       ├── metrics-config.yaml            # Telegraf + MDM config
│       ├── metrics-rbac.yaml              # RBAC for metrics + identity
│       └── osm-label.yml                  # Pre-install namespace labeling hook
│
├── scripts/                     # Operational scripts
│   ├── add-extension.sh         #   Install OSM extension on an Arc cluster
│   ├── update-extension.sh      #   Update an existing extension
│   ├── delete-extension.sh      #   Remove an extension (direct REST API call)
│   ├── connect-to-arc.sh        #   Connect a K8s cluster to Azure Arc
│   ├── install-connectedk8s.sh  #   Install/update az connectedk8s CLI extension
│   ├── install-k8s-extension.sh #   Install/update az k8s-extension CLI extension
│   ├── publish-chart.sh         #   Package + push Helm chart to ACR via ORAS
│   ├── register-extension.sh    #   Register chart version with Arc API (staging)
│   └── register-extension-prod.sh # Register chart for production rollout (multi-region)
│
├── .pipelines/                  # Azure DevOps pipeline definitions
│   ├── pr-job/                  #   PR validation + main branch E2E tests
│   ├── upgrade-job/             #   Extension upgrade E2E tests
│   ├── test-prod-job/           #   Production version validation
│   ├── aks-addon-nightly/       #   Nightly AKS addon tests (non-Arc path)
│   ├── conformance-test-job/    #   Sonobuoy conformance plugin build/push
│   ├── nightly-image-scan/      #   Trivy vulnerability scanning
│   └── templates/               #   Reusable pipeline step templates
│
├── test/bats/                   # BATS test suite for extension validation
│   ├── test.bats                #   Test cases (pod counts, labels, webhooks, etc.)
│   └── helpers.bash             #   Test utility functions
│
├── conformance/plugins/osm-arc/ # Sonobuoy conformance test plugin
│   ├── conformance.yaml         #   Sonobuoy plugin configuration
│   ├── Dockerfile               #   Conformance test container image
│   ├── osm_arc_conformance.sh   #   Conformance test runner script
│   └── setup_failure_handler.py #   JUnit report generator for setup failures
│
├── docs/                        # User-facing documentation
│   ├── get-started.md           #   Initial setup guide
│   ├── update-extension.md      #   Upgrade procedures
│   ├── delete-extension.md      #   Removal guide
│   ├── testing-guide.md         #   Local testing instructions
│   └── osm-with-azure-policy.md #   Azure Policy integration
│
├── Makefile                     # Local dev targets (bootstrap, deploy, test, cleanup)
└── .env.example                 # Environment variable template
```

---

## How the Arc Extension Works

### End-to-End Flow

1. **Cluster onboarding**: A Kubernetes cluster is connected to Azure Arc using `az connectedk8s connect`, which installs Arc agents in the `azure-arc` namespace.

2. **Extension installation**: A user (or pipeline) runs `az k8s-extension create --extension-type Microsoft.openservicemesh`, specifying a version and release train.

3. **Chart resolution**: The Arc Extension RP looks up the registered chart version for the requested release train and region from the Arc Registration API. It resolves the full ACR path to the Helm chart.

4. **Chart pull and deployment**: The extension agent running on the cluster pulls the `osm-arc` Helm chart from Azure Container Registry (ACR) and installs it into `arc-osm-system` namespace.

5. **Pre-install hooks**: Before the main chart installs, a Helm pre-install hook job runs that labels `kube-system`, `azure-arc`, and `arc-osm-system` namespaces with `openservicemesh.io/ignore: "true"` to prevent Envoy sidecar injection into system components.

6. **OSM deployment**: The upstream OSM chart (declared as a dependency in `Chart.yaml`) deploys `osm-controller`, `osm-injector`, and `osm-bootstrap` pods.

7. **Metrics agent deployment**: An additional `osm-metrics-agent` pod is deployed with four containers:
   - **telegraf**: Scrapes Prometheus metrics from `osm-controller` and Kubernetes pod inventory
   - **prom-mdm-converter**: Converts Prometheus metrics to Geneva/MDM format
   - **mdm**: Geneva Monitoring Data Model agent for metric emission
   - **msi-adapter**: Provides managed identity authentication for the metrics pipeline

8. **Arc identity**: An `AzureExtensionIdentity` CRD resource is created, linking the extension's service account to the Arc managed identity system.

### Helm Chart Dependency Chain

```
osm-arc (this chart)
  └── osm v1.1.1 (upstream, from https://openservicemesh.github.io/osm)
        ├── osm-controller
        ├── osm-injector
        └── osm-bootstrap
```

The `osm-arc` chart wraps the upstream OSM chart and adds:
- Azure Arc extension identity (`AzureExtensionIdentity` CRD)
- Metrics collection infrastructure (telegraf, MDM, prom-mdm-converter, msi-adapter)
- Namespace labeling pre-install hook
- RBAC for metrics collection and identity management

---

## Helm Chart Packaging and Publishing

### How Charts Reach ACR

1. **Package**: `helm dependency update` pulls the upstream OSM chart, then `helm package` creates a `.tgz` archive.

2. **Push to ACR**: Charts are pushed to Azure Container Registry as OCI artifacts using [ORAS (OCI Registry as Storage)](https://oras.land/). The ORAS push uses mime type `application/tar+gzip`.

3. **Register with Arc API**: After pushing to ACR, the chart version is registered with the Arc Registration API via a PUT request. This tells the Arc RP where to find the chart for each region and release train combination.

### Tagging Convention

| Context | Tag Format | Example |
|---------|-----------|---------|
| PR builds | `{chart_version}-pr` | `1.1.1-1-pr` |
| Release builds | `{chart_version}-{git_short_sha}-release` | `1.1.1-1-a3b4c5d-release` |
| Production | `{chart_version}` | `1.1.1-1` |

### Manual Chart Publishing (from `.env`)

```bash
source .env
./scripts/publish-chart.sh
```

Required env vars: `SUBSCRIPTION`, `REGISTRY`, `CHARTNAME`, `IMAGETAG`, `IMAGEDIR`, `REPO`

---

## Regional Rollout Strategy

Production rollout follows a phased approach defined in `scripts/register-extension-prod.sh`:

### Phase 1: Staging
- **Regions**: `eastus2euap`, `eastus`, `westeurope`
- **Release train**: `staging`
- **Purpose**: Internal validation before any customer-facing deployment

### Phase 2: Production Canary
- **Region**: `eastus2euap` (single canary region)
- **Release trains**: `pilot`, `preview`, `stable`
- **Purpose**: Early production validation in a limited blast radius

### Phase 3: Production Batch 1 (Full Rollout)
- **Regions**: `eastus`, `westeurope`, `australiaeast`, `eastus2`, `francecentral`, `northeurope`, `southcentralus`, `southeastasia`, `uksouth`, `westcentralus`, `westus2`, `centralus`, `northcentralus`, `westus`, `koreacentral`, `japaneast`, `eastasia`, `westus3`, `usgovvirginia`
- **Release trains**: `pilot`, `preview`, `stable`
- **Purpose**: Broad production availability

### Release Trains

| Train | Purpose |
|-------|---------|
| `staging` | Internal testing only; not customer-visible |
| `pilot` | Early adopter customers |
| `preview` | Public preview customers |
| `stable` | General availability |

### Registration Process

Each phase creates an `artifactEndpoints` entry in a JSON request body sent to the Arc Registration API. Each endpoint specifies:
- Target regions
- Release train
- Full ACR path to the Helm chart
- Update frequency (60 minutes)
- Visibility flags (`IsCustomerHidden`, `ReadyforRollout`)

---

## CI/CD Pipelines

All pipelines are Azure DevOps YAML pipelines in `.pipelines/`. They run on the `staging-pool-amd64-mariner-2` agent pool.

### Pipeline Overview

| Pipeline | Trigger | Purpose |
|----------|---------|---------|
| **PR E2E** (`.pipelines/pr-job/e2e-job.yaml`) | PRs and pushes to `main`/`release-v*` | Full E2E: package chart → push to staging ACR → register → create AKS → enable Arc → install extension → run BATS + upstream tests → cleanup |
| **Upgrade E2E** (`.pipelines/upgrade-job/upgrade-e2e-job.yaml`) | Changes to `Chart.yaml`, `add-extension.sh`, or `update-extension.sh` | Install previous version → run tests → upgrade to new version → re-test |
| **Prod Test** (`.pipelines/test-prod-job/osm-arc-prod-test-job.yaml`) | Manual trigger | Test a specific production version + release train on a fresh AKS+Arc cluster |
| **AKS Addon Nightly** (`.pipelines/aks-addon-nightly/e2e-aks-addon.yaml`) | Nightly cron (00:00 UTC) | Tests the AKS native OSM addon path (non-Arc) |
| **Conformance Plugin** (`.pipelines/conformance-test-job/conf-test-plugin-job.yaml`) | Manual trigger | Build and push the Sonobuoy conformance test plugin image |
| **Nightly Image Scan** (`.pipelines/nightly-image-scan/image-scan.yaml`) | Nightly cron + changes to `tools/helm` or `conformance/plugins/` | Trivy vulnerability scan of conformance test image |

### PR E2E Pipeline Flow (Detailed)

```
1. Install tools (Helm 3.1.1, ORAS 0.8.1, BATS 1.2.0)
2. Package Helm chart (helm dependency update + helm package)
3. Publish chart to staging ACR with PR tag
4. Register extension version with Arc Registration API
5. Checkout upstream OSM repo
6. Create ephemeral AKS cluster (osm-helm-e2e-{random})
7. Connect cluster to Azure Arc
8. Install OSM Arc extension
9. Run osm-azure BATS tests (pod counts, labels, webhooks, metrics containers)
10. Run upstream OSM e2e tests (ginkgo, 120min timeout)
11. Debug resource collection (on failure)
12. Cleanup: delete chart from staging ACR, delete AKS resource group
```

---

## Local Development and Testing

### Prerequisites

```bash
cp .env.example .env
# Edit .env with your Azure subscription, region, and cluster details
```

### Quick Start (KIND cluster)

```bash
make install-prerequisites      # Install KIND, kubectl, helm, bats
TEST_KIND=true make e2e-bootstrap  # Create KIND cluster + namespaces
make e2e-helm-deploy            # Deploy chart locally
make test-e2e                   # Run BATS tests
TEST_KIND=true make e2e-cleanup # Teardown
```

### Testing Against Arc Cluster

```bash
make e2e-bootstrap              # Create namespaces (azure-arc must exist)
make e2e-helm-deploy            # Deploy chart
make test-e2e                   # Run tests (includes Arc-specific tests)
make e2e-cleanup                # Uninstall + delete namespace
```

Set `ARC_CLUSTER=false` to skip Arc-specific tests when testing locally without Arc.

See [docs/testing-guide.md](docs/testing-guide.md) for full details.

---

## Operational Runbooks

| Task | Documentation |
|------|--------------|
| First-time setup | [docs/get-started.md](docs/get-started.md) |
| Update extension | [docs/update-extension.md](docs/update-extension.md) |
| Delete extension | [docs/delete-extension.md](docs/delete-extension.md) |
| Azure Policy integration | [docs/osm-with-azure-policy.md](docs/osm-with-azure-policy.md) |
| Local testing | [docs/testing-guide.md](docs/testing-guide.md) |

### Common Operations

**Register a new version for staging:**
```bash
export VERSION="1.1.1-1"
export REGISTRY_PATH="your-acr.azurecr.io/oss/openservicemesh/osm-arc"
./scripts/register-extension.sh
```

**Register a new version for production (phased rollout):**
```bash
export VERSION="1.1.1-1"
export REGISTRY_STAGING="staging-acr-path"
export REGISTRIES_PROD_CANARY=("canary-pilot-path" "canary-preview-path" "canary-stable-path")
export REGISTRIES_PROD_BATCH1=("batch1-pilot-path" "batch1-preview-path" "batch1-stable-path")
./scripts/register-extension-prod.sh
```

---

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
