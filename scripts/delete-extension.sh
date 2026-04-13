#!/bin/bash
#
# delete-extension.sh — Remove the OSM Arc extension from an Azure Arc-connected cluster.
#
# This script uses a direct REST API call to the Azure Arc Extensions API to
# delete the OSM extension. It does NOT use `az k8s-extension delete` because
# this script predates that CLI command. The REST call triggers the Arc RP to
# instruct the on-cluster agent to uninstall the Helm release.
#
# After deletion:
#   - Extension deployments in arc-osm-system are removed
#   - The arc-osm-system namespace remains (empty)
#   - The azure-arc namespace and its agents are unaffected
#   - Deletion SLA is approximately 10 minutes
#
# Required environment variables (from .env):
#   SUBSCRIPTION  - Azure subscription ID
#   RESOURCEGROUP - Resource group containing the Arc-connected cluster
#   CLUSTERNAME   - Arc-connected cluster name
#
# Optional environment variables:
#   EXTENSION_NAME - Extension instance name (default: osm)
#   API_VERSION    - Arc Extensions API version (default: 2020-07-01-preview)
#

# Load environment variables from .env file
source .env

# Build the ARM resource ID for the Arc-connected cluster.
# This is used to construct the full REST API URI for the extension resource.
export RESOURCEID="subscriptions/$SUBSCRIPTION/resourceGroups/$RESOURCEGROUP/providers/Microsoft.Kubernetes/connectedClusters/$CLUSTERNAME"
EXTENSION_NAME="${EXTENSION_NAME:-osm}"
API_VERSION="${API_VERSION:-2020-07-01-preview}"

# Set the active Azure subscription
az account set --subscription="$SUBSCRIPTION"

# Delete the OSM extension via direct REST API call.
# URI format: https://management.azure.com/{clusterId}/providers/Microsoft.KubernetesConfiguration/extensions/{extensionName}
az rest \
   --method DELETE \
   --uri "https://management.azure.com/$RESOURCEID/providers/Microsoft.KubernetesConfiguration/extensions/$EXTENSION_NAME?api-Version=$API_VERSION" \
   --debug
