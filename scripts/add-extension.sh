#!/bin/bash
#
# add-extension.sh — Install the OSM Arc extension on an Azure Arc-connected Kubernetes cluster.
#
# This script uses the Azure CLI `az k8s-extension create` command to deploy
# Open Service Mesh (OSM) as an Arc extension. The Arc Extension RP will pull
# the registered Helm chart from ACR and install it on the cluster.
#
# Usage:
#   ./scripts/add-extension.sh                       # Install with defaults
#   ./scripts/add-extension.sh config-settings.json   # Install with custom settings file
#
# Required environment variables (from .env or pipeline):
#   SUBSCRIPTION    - Azure subscription ID
#   CLUSTERNAME     - Arc-connected cluster name
#   RESOURCEGROUP   - Azure resource group containing the cluster
#   EXTENSION_TAG   - Chart version to install (e.g., "1.1.1-1" or "1.1.1-1-pr")
#
# Optional environment variables:
#   RELEASE_NAMESPACE  - Kubernetes namespace for the extension (default: arc-osm-system)
#   EXTENSION_NAME     - Extension instance name (default: osm)
#   RELEASE_TRAIN      - Release train: staging, pilot, preview, or stable (default: staging)
#

# Load environment variables from .env file
source .env

# Set defaults for optional parameters
RELEASE_NAMESPACE="${RELEASE_NAMESPACE:-arc-osm-system}"
EXTENSION_NAME="${EXTENSION_NAME:-osm}"
EXTENSION_SETTINGS=$1  # Optional: path to a JSON file with custom configuration overrides
RELEASE_TRAIN="${RELEASE_TRAIN:-staging}"

# Set the active Azure subscription
az account set --subscription="$SUBSCRIPTION" > /dev/null 2>&1

# Print all current Helm releases for confirmation/debugging before install
helm ls --all --all-namespaces

if [[ -z "$EXTENSION_SETTINGS" ]]; then
   # Install extension with default configuration.
   # The Arc RP will look up the chart version ($EXTENSION_TAG) registered for
   # the given release train and pull the corresponding Helm chart from ACR.
   az k8s-extension create \
      --cluster-name $CLUSTERNAME \
      --resource-group $RESOURCEGROUP \
      --cluster-type connectedClusters \
      --extension-type Microsoft.openservicemesh \
      --scope cluster \
      --release-train $RELEASE_TRAIN \
      --name $EXTENSION_NAME \
      --release-namespace $RELEASE_NAMESPACE \
      --version $EXTENSION_TAG
else
   # Install extension with custom configuration settings from a JSON file.
   # The settings file can override values.yaml defaults (e.g., traffic policy mode,
   # sidecar injection settings, image overrides).
   az k8s-extension create \
      --cluster-name $CLUSTERNAME \
      --resource-group $RESOURCEGROUP \
      --cluster-type connectedClusters \
      --extension-type Microsoft.openservicemesh \
      --scope cluster \
      --release-train $RELEASE_TRAIN \
      --name $EXTENSION_NAME \
      --release-namespace $RELEASE_NAMESPACE \
      --version $EXTENSION_TAG \
      --configuration-settings-file $EXTENSION_SETTINGS
fi
