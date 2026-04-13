#!make
#
# Makefile — Local development and testing orchestration for the OSM Azure Arc extension.
#
# This Makefile provides targets for:
#   - Local E2E testing using KIND (Kubernetes in Docker) or an existing cluster
#   - Helm chart packaging
#   - Security scanning with Trivy
#   - Static analysis with shellcheck
#
# Quick start (local KIND cluster):
#   TEST_KIND=true make install-prerequisites e2e-bootstrap e2e-helm-deploy test-e2e e2e-cleanup
#
# Quick start (existing cluster):
#   make e2e-bootstrap e2e-helm-deploy test-e2e e2e-cleanup
#
# Environment variables:
#   TEST_KIND  — Set to "true" to use KIND for local testing (creates/destroys a cluster)
#   ARC_CLUSTER — Set to "false" to skip Arc-specific BATS tests (default: true)
#

# --- Version Pins ---
# These versions are pinned to ensure reproducible builds and test environments.
KIND_VERSION ?= 0.8.1

# Note: K8s version is pinned because KIND image availability lags behind upstream K8s releases.
KUBERNETES_VERSION ?= v1.19.0
BATS_VERSION ?= 1.2.1

# --- Helm Chart Packaging ---
# Package the osm-arc chart with its upstream OSM dependency.
# This runs `helm dependency update` to download the upstream OSM chart
# declared in Chart.yaml before packaging.
package-osm-chart:
	helm dependency update osm-arc

# --- Prerequisite Installation ---
# Install all tools needed for local testing: KIND (optional), kubectl, helm, and BATS.
install-prerequisites:
	# Setup kind if TEST_KIND is set to true
	if [ $(TEST_KIND) ]; then make setup-kind ; fi
	# Install kubectl if not installed (or if version doesn't match)
	kubectl version --short | grep -q $(KUBERNETES_VERSION) || (curl -L https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kubectl -o ${HOME}/bin/kubectl && chmod +x ${HOME}/bin/kubectl)
	# Install helm if not installed (requires Helm v3)
	helm version --short | grep -q v3 || (curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash)
	# Install bats if not installed
	bats --version | grep -q $(BATS_VERSION) || (sudo apt-get -o Acquire::Retries=30 update && sudo apt-get -o Acquire::Retries=30 install -y bats)

# --- KIND Cluster Setup ---
# Create a local Kubernetes cluster using KIND for testing without cloud infrastructure.
# Deletes any existing KIND cluster first to ensure a clean state.
.PHONY: setup-kind
setup-kind:
	# Download and install kind if not installed
	kind --version | grep -q $(KIND_VERSION) || (curl -L https://github.com/kubernetes-sigs/kind/releases/download/v${KIND_VERSION}/kind-linux-amd64 --output ${HOME}/bin/kind && chmod +x ${HOME}/bin/kind)
	# Create kind cluster (delete existing one first)
	kind delete cluster || true
	kind create cluster --image kindest/node:$(KUBERNETES_VERSION)

# --- E2E Test Bootstrap ---
# Create the Kubernetes namespaces required by the osm-arc chart.
# The azure-arc namespace is only created if it doesn't already exist
# (on Arc clusters it's already present from the Arc agent installation).
e2e-bootstrap:
	# Create azure-arc ns only if it doesn't exist (eg: for non-arc clusters)
	kubectl get ns | grep -q azure-arc || kubectl create namespace azure-arc
	kubectl create namespace arc-osm-system

# --- E2E Helm Deploy ---
# Deploy the osm-arc Helm chart to the local cluster for testing.
# Runs dependency update first to pull the upstream OSM chart, then installs.
e2e-helm-deploy:
	helm dependency update ./charts/osm-arc
	helm install osm ./charts/osm-arc --namespace arc-osm-system --dependency-update

# --- E2E Test Execution ---
# Run the BATS test suite that validates the deployed extension.
# Set EXTENSION_TAG env var to match the chart version you deployed.
# Set ARC_CLUSTER=false to skip Arc-specific tests on non-Arc clusters.
test-e2e:
	bats -t test/bats/test.bats

# --- E2E Cleanup ---
# Uninstall the Helm release, delete the namespace, and optionally destroy the KIND cluster.
e2e-cleanup:
	helm uninstall osm -n arc-osm-system
	kubectl delete namespace arc-osm-system
	if [ $(TEST_KIND) ]; then kind delete cluster; fi

# --- Security Scanning ---
# Install Trivy vulnerability scanner (used by the nightly image scan pipeline).
install-trivy:
	wget https://github.com/aquasecurity/trivy/releases/download/v0.18.0/trivy_0.18.0_Linux-64bit.tar.gz
	tar zxvf trivy_0.18.0_Linux-64bit.tar.gz

# Scan a container image for vulnerabilities using Trivy.
# First run shows all vulnerabilities for logging; second run exits with error code 1
# if any MEDIUM, HIGH, or CRITICAL OS-level vulnerabilities are found.
# Usage: IMAGE_NAME=myimage IMAGE_TAG=latest make trivy-scan-image
trivy-scan-image:
	# Show all vulnerabilities in logs
	./trivy "$(IMAGE_NAME):$(IMAGE_TAG)"


	# Exit if medium, high, or critical vulnerability for OS vulnerabilities
	./trivy --exit-code 1 --ignore-unfixed --vuln-type os --severity MEDIUM,HIGH,CRITICAL "$(IMAGE_NAME):$(IMAGE_TAG)" || exit 1

# --- Static Analysis ---
# Run shellcheck on all shell scripts in the repository.
# Install shellcheck with: "sudo apt install shellcheck"
.PHONY: shellcheck
shellcheck:
	shellcheck -x $(shell find . -name '*.sh')
