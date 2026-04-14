# OSM Azure Arc Extension — Release Guide

This guide documents the end-to-end process for releasing a new version of the OSM Azure Arc extension. It is based on the observed patterns from the repository's release history (tags, PRs, and CI/CD pipelines).

## Table of Contents

- [Release Overview](#release-overview)
- [Prerequisites](#prerequisites)
- [Step 1: Prepare the Upstream OSM Release](#step-1-prepare-the-upstream-osm-release)
- [Step 2: Create a Release Branch (if needed)](#step-2-create-a-release-branch-if-needed)
- [Step 3: Update the Helm Chart](#step-3-update-the-helm-chart)
- [Step 4: Update Image References](#step-4-update-image-references)
- [Step 5: Open a Release PR](#step-5-open-a-release-pr)
- [Step 6: CI Validation (Automated)](#step-6-ci-validation-automated)
- [Step 7: Merge and Tag](#step-7-merge-and-tag)
- [Step 8: Production Rollout](#step-8-production-rollout)
- [Common Release Scenarios](#common-release-scenarios)
- [Version Numbering Conventions](#version-numbering-conventions)
- [Troubleshooting](#troubleshooting)
- [Quick Reference Checklist](#quick-reference-checklist)

---

## Release Overview

A release follows this high-level flow:

```
Upstream OSM release available in MCR
    │
    ▼
Update Chart.yaml + values.yaml
    │
    ▼
Open PR to release-v1.2 (uses release checklist template)
    │
    ▼
Azure DevOps PR pipeline runs full E2E:
  package → publish to staging ACR → register → create AKS → Arc → install → BATS + ginkgo tests
    │
    ▼
3 maintainer approvals + merge
    │
    ▼
Tag the release (vX.Y.Z)
    │
    ▼
GitHub Actions publishes chart to GitHub Pages
    │
    ▼
Production registration via register-extension-prod.sh
  staging → canary (eastus2euap) → batch1 (19 regions)
```

---

## Prerequisites

Before starting a release, ensure you have:

1. **Azure DevOps access** — Push access to the `Azure/osm-azure` repo triggers the PR pipeline automatically.
2. **Arc Registration API credentials** — Service principal or access token with permissions to call the Arc Registration API for production registration.
3. **ACR access** — Push permissions to the staging and production Azure Container Registries.
4. **GitHub write access** — Ability to push tags and merge PRs to `Azure/osm-azure`.

---

## Step 1: Prepare the Upstream OSM Release

Before bumping the osm-arc chart, verify that the upstream OSM images are available in MCR (Microsoft Container Registry). The release PR template requires you to confirm this.

### Required images in MCR

All of the following must be available for **both amd64 and arm64** architectures (except grafana-image-renderer, which is amd64-only):

| Image | Source |
|---|---|
| `osm-controller` | `mcr.microsoft.com/oss/openservicemesh/osm-controller` |
| `osm-injector` | `mcr.microsoft.com/oss/openservicemesh/osm-injector` |
| `osm-bootstrap` | `mcr.microsoft.com/oss/openservicemesh/osm-bootstrap` |
| `osm-crds` | `mcr.microsoft.com/oss/openservicemesh/osm-crds` |
| `init` (init container) | `mcr.microsoft.com/oss/openservicemesh/init` |
| `envoy` | `mcr.microsoft.com/oss/envoyproxy/envoy` |
| `prometheus` | `mcr.microsoft.com/oss/prometheus/prometheus` |
| `grafana` | `mcr.microsoft.com/oss/grafana/grafana` |
| `grafana-image-renderer` | `mcr.microsoft.com/oss/grafana/grafana-image-renderer` (amd64 only) |
| `jaeger all-in-one` | `mcr.microsoft.com/oss/jaegertracing/all-in-one` |

### How to verify

```bash
# Check that a specific image+tag exists in MCR for both architectures
# Replace <image> and <tag> as needed
docker manifest inspect mcr.microsoft.com/oss/openservicemesh/osm-controller:<tag>
```

### Compare upstream changes

Compare the upstream OSM chart between the previous release and the new one to identify any values.yaml changes that need to be reflected in the osm-arc chart:

```
https://github.com/openservicemesh/osm/compare/v<old>...v<new>
```

Look for:
- New or renamed values in the upstream `values.yaml`
- Removed values
- Changed defaults that affect Arc behavior
- New CRDs or RBAC requirements

---

## Step 2: Create a Release Branch (if needed)

The active release branch is **`release-v1.2`** (protected). All release PRs target this branch, not `main`.

If a new major/minor version is needed (e.g., moving from v1.2.x to v1.3.x), create a new release branch:

```bash
git checkout main
git pull origin main
git checkout -b release-v1.3
git push origin release-v1.3
```

> **Note**: The `main` branch has historically diverged from the release branch. Feature work and infrastructure changes happen on `main`, while release-specific version bumps and hotfixes go to the release branch. Recent releases (v1.2.9 through v1.2.13) have all targeted `release-v1.2`.

---

## Step 3: Update the Helm Chart

Create a branch for your version bump:

```bash
git checkout release-v1.2
git pull origin release-v1.2
git checkout -b bump-<version>    # e.g., bump-1.2.14
```

### 3a. Update `charts/osm-arc/Chart.yaml`

Three fields need updating:

```yaml
# charts/osm-arc/Chart.yaml

version: 1.2.14           # Chart version — increment for every release
appVersion: v1.2.14        # App version — matches the chart version (with v prefix)

dependencies:
- name: osm
  version: "1.1.1"         # Upstream OSM chart version — update if tracking a new upstream release
  repository: "https://openservicemesh.github.io/osm"
```

**Version field rules:**
- `version` and `appVersion` should match (except `appVersion` has a `v` prefix for versions >= v1.0.0)
- The `dependencies[0].version` tracks the upstream OSM chart version. Only change this when pulling in a new upstream OSM release.

### 3b. Update `charts/osm-arc/values.yaml`

Update image tags to match the new upstream version:

```yaml
# charts/osm-arc/values.yaml

osm:
  osm:
    image:
      tag: v1.2.14                    # Upstream OSM image tag
    sidecarImage: mcr.microsoft.com/oss/envoyproxy/envoy:v1.34.x  # Envoy version (if changed)
```

If the release includes updated metrics agent images, also update:
- `metrics-agent-deployment.yaml` — envoy, mdm, prom-mdm-converter, and msi-adapter image tags

### What typically changes per release type

| Release Type | Files Changed | Example PR |
|---|---|---|
| **Version bump** (new upstream OSM) | `Chart.yaml` (version, appVersion, dep version), `values.yaml` (image.tag) | [#208](https://github.com/Azure/osm-azure/pull/208), [#207](https://github.com/Azure/osm-azure/pull/207) |
| **Envoy/security patch** | `values.yaml` (sidecarImage), `metrics-agent-deployment.yaml` | [#205](https://github.com/Azure/osm-azure/pull/205), [#193](https://github.com/Azure/osm-azure/pull/193) |
| **Metrics agent update** | `values.yaml` (msi-adapter tag), `metrics-agent-deployment.yaml` | [#186](https://github.com/Azure/osm-azure/pull/186), [#192](https://github.com/Azure/osm-azure/pull/192) |
| **Chart version bump only** (re-tag) | `Chart.yaml` (version, appVersion) | [#196](https://github.com/Azure/osm-azure/pull/196) |

---

## Step 4: Update Image References

If you're updating the Envoy sidecar image or metrics agent container images, update these files:

### Envoy sidecar (injected into application pods)

```yaml
# charts/osm-arc/values.yaml
osm:
  osm:
    sidecarImage: mcr.microsoft.com/oss/envoyproxy/envoy:v<new-version>
```

### Metrics agent containers (in `charts/osm-arc/templates/metrics-agent-deployment.yaml`)

There are typically 4 containers in the metrics agent pod that may need updating:

| Container | Image Source | When to Update |
|---|---|---|
| `mdm` | `linuxgeneva-microsoft.azurecr.io/genevamdm` | Geneva MDM security patches |
| `prom-mdm-converter` | `linuxgeneva-microsoft.azurecr.io/shared/prom-mdm-converter` | Converter bug fixes |
| `telegraf` | Referenced in `metrics-config.yaml` | Telegraf updates |
| `msi-adapter` | `mcr.microsoft.com/azurearck8s/msi-adapter` | MSI adapter security patches |

### Envoy image in the E2E pipeline

If the Envoy version changes, also update the Envoy image reference in the upstream E2E test configuration:

```yaml
# .pipelines/templates/run-upstream-e2e.yaml
# Look for the SIDECAR_IMAGE environment variable
```

---

## Step 5: Open a Release PR

Push your branch and open a PR **against `release-v1.2`** (not `main`):

```bash
git add -A
git commit -s -m "Bump to OSM <version>"
git push origin bump-<version>
```

### Use the release PR template

When creating the PR on GitHub, append `?template=release_pull_request_template.md` to the PR creation URL, or manually select the release template. The template includes a checklist:

```markdown
- [ ] I have ensured that required images are available in MCR:
    1. osm-controller, osm-injector, osm-bootstrap, osm-crds and init images
    2. envoy image of version listed in osm-arc/oss values.yaml
    3. grafana, grafana-image-renderer, prometheus, jaegertracing/all-in-one image
- [ ] I have ensured that all images are available for both amd64 and arm64
- [ ] I have updated the Helm chart:
    1. Updated the chart version, app version and dependency version in Chart.yaml
    2. Made applicable updates to values.yaml
- [ ] I have received 3 approvals from maintainers.
```

### Branch naming convention

Release PRs have historically followed these patterns:
- `bump-<version>` — e.g., `bump-1.2.13`, `bump-1.2.14`
- `bump-v<version>` — e.g., `bump-v1.2.11`
- `bump-to-<version>` — e.g., `bump-to-1.2.12`

### PR title convention

- `Bump to OSM <version>` — e.g., "Bump to OSM 1.2.12"
- `Bump <version>` — e.g., "Bump 1.2.13"

---

## Step 6: CI Validation (Automated)

When a PR is opened against `release-v1.2`, the Azure DevOps PR pipeline automatically runs. This pipeline:

1. **Packages** the Helm chart from your branch
2. **Publishes** it to a staging ACR with a `-pr` suffixed tag
3. **Registers** the chart with the Arc Registration API in staging regions (eastus2euap, eastus, westeurope) on the `staging` release train
4. **Creates** an ephemeral AKS cluster (random name, random region)
5. **Connects** the AKS cluster to Azure Arc
6. **Installs** the extension using the staging registration
7. **Runs BATS tests** — validates extension pods, CRDs, webhooks, namespaces, and labels
8. **Runs upstream OSM ginkgo e2e tests** — validates core mesh functionality
9. **Cleans up** — deletes the AKS resource group and staging ACR image

The pipeline takes approximately 60-90 minutes. You can monitor it in Azure DevOps.

### If the pipeline fails

- Check the debug resources step output for pod logs, events, and resource state
- Common failures: image pull errors (image not yet in MCR), AKS provisioning timeout, flaky upstream tests
- You can re-run the pipeline from Azure DevOps without pushing new commits

### Upgrade E2E (release validation)

For release-specific validation, the upgrade pipeline installs the **previous** published version first, runs tests, then upgrades to the new version and re-runs tests. This is triggered separately and verifies upgrade compatibility.

---

## Step 7: Merge and Tag

### Merge requirements

- **3 maintainer approvals** (per the release PR template)
- **CI pipeline passing** (Azure DevOps E2E)

### Create the Git tag

After the PR is merged, tag the merge commit on `release-v1.2`:

```bash
git checkout release-v1.2
git pull origin release-v1.2
git tag v<version>    # e.g., v1.2.14
git push origin v<version>
```

### What the tag triggers

Pushing a `v*` tag triggers the **GitHub Actions workflow** (`.github/workflows/release-chart.yml`) which publishes the Helm chart to **GitHub Pages** via the `gh-pages` branch. This makes the chart available at the public Helm repository URL.

> **Important**: The Git tag is what triggers the GitHub Pages chart publish. Without the tag, the chart is only in the staging ACR from the PR pipeline.

---

## Step 8: Production Rollout

After tagging, register the chart for production deployment. This is done via the Arc Registration API using `scripts/register-extension-prod.sh`.

### Phased rollout

Production rollout happens in three phases:

| Phase | Regions | Release Trains | Purpose |
|---|---|---|---|
| **1 — Staging** | eastus2euap, eastus, westeurope | `staging` | Internal testing with staging ACR |
| **2 — Canary** | eastus2euap | `pilot`, `preview`, `stable` | Limited blast radius production validation |
| **3 — Batch 1** | 19 production regions | `pilot`, `preview`, `stable` | Full production rollout |

### Running the production registration

```bash
# Set required environment variables
export ACCESS_TOKEN=$(az account get-access-token --resource <ARC_RESOURCE_TOKEN> | jq -r '.accessToken')
export ARC_API_URL=<arc-api-url>
export SUBSCRIPTION=<subscription-id>
export VERSION=<version>                              # e.g., 1.2.14
export REGISTRY_STAGING=<staging-acr-path>
export REGISTRIES_PROD_CANARY="<pilot-acr> <preview-acr> <stable-acr>"
export REGISTRIES_PROD_BATCH1="<pilot-acr> <preview-acr> <stable-acr>"

# Run the registration
./scripts/register-extension-prod.sh
```

The script generates a `request.json` with artifact endpoints for each phase and submits it to the Arc Registration API. Each release train (pilot, preview, stable) can point to a **different** ACR registry path, allowing independent chart promotion per train.

### Monitoring the rollout

After registration, the Arc Extension RP will begin serving the new version. Users installing or updating the extension with `az k8s-extension create/update` will get the new version based on their cluster's region and release train.

### Production validation

Use the production test pipeline (`.pipelines/test-prod-job/osm-arc-prod-test-job.yaml`) to validate a specific production version:

```bash
# Set these variables in the Azure DevOps pipeline
EXTENSION_VERSION=<version>
EXTENSION_RELEASE_TRAIN=<train>   # pilot, preview, or stable
```

This creates an ephemeral AKS cluster, installs the production extension version, runs BATS tests, and cleans up.

---

## Common Release Scenarios

### Scenario 1: New upstream OSM version

This is the most common release type. An upstream OSM version is rebuilt with security patches, and both the Chart.yaml dependency and image tags are updated.

1. Verify all upstream images are in MCR (amd64 + arm64)
2. Update `Chart.yaml`: `version`, `appVersion`, `dependencies.version`
3. Update `values.yaml`: `osm.osm.image.tag`
4. Compare upstream `values.yaml` for any new/changed/removed fields
5. Open PR → CI → 3 approvals → merge → tag → production registration

### Scenario 2: Envoy security patch

An Envoy CVE requires updating only the sidecar image, without a new upstream OSM release.

1. Verify new Envoy image is in MCR
2. Update `values.yaml`: `osm.osm.sidecarImage`
3. Bump `Chart.yaml`: `version` and `appVersion` (increment patch)
4. Update `.pipelines/templates/run-upstream-e2e.yaml` if it references the Envoy version
5. Open PR → CI → 3 approvals → merge → tag → production registration

### Scenario 3: Metrics agent image update

A security patch for the Geneva MDM, MSI adapter, or prom-mdm-converter images.

1. Verify new image is available in the source registry
2. Update `charts/osm-arc/templates/metrics-agent-deployment.yaml` with new image tag
3. Update `values.yaml` if the image reference is there (e.g., msi-adapter)
4. Bump `Chart.yaml`: `version` and `appVersion`
5. Open PR → CI → 3 approvals → merge → tag → production registration

### Scenario 4: Chart-only re-tag (no code changes)

Sometimes a chart version needs to be re-registered (e.g., the chart version already exists in ACR and needs a new version number to re-deploy).

1. Bump only `Chart.yaml`: `version` and `appVersion`
2. Open PR → CI → merge → tag → production registration

---

## Version Numbering Conventions

The repository has used the following versioning patterns:

| Pattern | Meaning | Example |
|---|---|---|
| `vX.Y.Z` | Stable release | `v1.2.13` |
| `vX.Y.Z-N` | Patch iteration on a version | `v1.1.1-1` (patch over v1.1.1) |
| `vX.Y.Z-rc.N` | Release candidate | `v1.0.0-rc.4` |
| `vX.Y.Z-beta-N` | Beta pre-release | `v1.2.3-beta-1` |
| `vX.Y.Z-N-pr` | PR build (ephemeral, CI only) | `v1.1.1-1-pr` |

### Version progression examples from the repo

```
v1.1.1 → v1.1.1-1 → v1.2.3-beta-1 → v1.2.3 → v1.2.6 → v1.2.9 → v1.2.10 → v1.2.11 → v1.2.12 → v1.2.13
```

> **Note**: Versions v1.2.7, v1.2.8 were skipped. Version gaps are acceptable — not every increment needs to be released.

### How the pipeline determines the "latest" version

The `get-latest-tag.yaml` template sorts Git tags using version sort, filters out alpha/beta/rc tags, and handles the `-N` suffix pattern. It sets the `LATEST_PUBLISHED_TAG` pipeline variable, which the upgrade E2E test uses to install the "previous" version before upgrading.

---

## Troubleshooting

### PR pipeline fails with image pull error

The upstream OSM images may not yet be available in MCR. Verify availability:
```bash
docker manifest inspect mcr.microsoft.com/oss/openservicemesh/osm-controller:v<tag>
```

### PR pipeline fails during Arc extension installation

- Check that the chart version doesn't conflict with an already-registered version in the staging registration
- The staging registration uses regions `eastus2euap, eastus, westeurope` on the `staging` train
- Look for HTTP 409 (conflict) errors in the register-extension step output

### Upgrade E2E tests fail

The `get-latest-tag.yaml` template determines the previous version to install. If your version numbering breaks the sort logic (e.g., unusual suffixes), the wrong previous version may be selected. Check the template output.

### GitHub Pages chart publish doesn't trigger

The GitHub Actions workflow (`.github/workflows/release-chart.yml`) only triggers on tags matching `v*`. Ensure:
- The tag starts with `v` (e.g., `v1.2.14`, not `1.2.14`)
- The tag was pushed to the `Azure/osm-azure` remote (not a fork)

### Production registration fails

- Verify `ACCESS_TOKEN` is fresh (tokens expire)
- Verify `ARC_API_URL` is correct for the target environment
- Check the `request.json` generated by the script for malformed JSON
- The Arc Registration API returns HTTP 200 on success

---

## Quick Reference Checklist

```
□ Verify upstream images in MCR (amd64 + arm64)
□ Compare upstream OSM values.yaml for changes
□ Create branch: bump-<version> from release-v1.2
□ Update charts/osm-arc/Chart.yaml:
    □ version
    □ appVersion
    □ dependencies[0].version (if upstream changed)
□ Update charts/osm-arc/values.yaml:
    □ osm.osm.image.tag
    □ osm.osm.sidecarImage (if Envoy changed)
□ Update metrics-agent-deployment.yaml (if metrics images changed)
□ Push branch and open PR against release-v1.2
□ Use release PR template
□ Wait for Azure DevOps E2E pipeline to pass
□ Get 3 maintainer approvals
□ Merge PR
□ Tag merge commit: git tag v<version> && git push origin v<version>
□ Verify GitHub Actions publishes chart to gh-pages
□ Run production registration: ./scripts/register-extension-prod.sh
□ Monitor rollout: staging → canary → batch1
□ (Optional) Run production validation pipeline
```
