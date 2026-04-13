#!/bin/bash
#
# update-extension.sh — Update an existing OSM Arc extension to a new version.
#
# This script upgrades the OSM Arc extension on an Arc-connected cluster.
# Two code paths exist:
#   1. Without settings file: uses `az k8s-extension update` for a simple version bump
#   2. With settings file: uses `az k8s-extension create` to apply new configuration
#      (the create command with an existing extension performs an update)
#
# Important constraints:
#   - Only next-minor-version upgrades are supported
#   - CRDs may need to be manually deleted before upgrade across minor versions
#   - Custom ConfigMap edits may be reverted during upgrade
#   - Release train is hardcoded to "staging" in this script
#
# Usage:
#   ./scripts/update-extension.sh                        # Simple version update
#   ./scripts/update-extension.sh osm_extension.json     # Update with config changes
#
# Required environment variables (from .env or pipeline):
#   SUBSCRIPTION  - Azure subscription ID
#   CLUSTERNAME   - Arc-connected cluster name
#   RESOURCEGROUP - Resource group containing the cluster
#   EXTENSION_TAG - New chart version to upgrade to
#
# Optional environment variables:
#   RELEASE_NAMESPACE - Kubernetes namespace (default: arc-osm-system)
#   EXTENSION_NAME    - Extension instance name (default: osm)
#

# Load environment variables from .env file
source .env

# Set defaults for optional parameters
RELEASE_NAMESPACE="${RELEASE_NAMESPACE:-arc-osm-system}"
EXTENSION_NAME="${EXTENSION_NAME:-osm}"
EXTENSION_SETTINGS=$1  # Optional: path to a JSON configuration settings file

# Set the active Azure subscription
az account set --subscription="$SUBSCRIPTION" > /dev/null 2>&1

# Print all current Helm releases for confirmation/debugging before update
helm ls --all --all-namespaces

if [[ -z "$EXTENSION_SETTINGS" ]]; then
   # Simple version update without configuration changes.
   # Uses `az k8s-extension update` which updates the version in-place.
   az k8s-extension update \
      --cluster-name $CLUSTERNAME \
      --resource-group $RESOURCEGROUP \
      --cluster-type connectedClusters \
      --release-train staging \
      --name $EXTENSION_NAME \
      --version $EXTENSION_TAG
else
   # Update with custom configuration settings file.
   # Uses `az k8s-extension create` which, when the extension already exists,
   # performs an update with the new version and configuration overrides.
   az k8s-extension create \
      --cluster-name $CLUSTERNAME \
      --resource-group $RESOURCEGROUP \
      --cluster-type connectedClusters \
      --release-train staging \
      --name $EXTENSION_NAME \
      --version $EXTENSION_TAG \
      --configuration-settings-file $EXTENSION_SETTINGS
fi
