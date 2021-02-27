#!/bin/bash

source .env

export RESOURCEID="subscriptions/$SUBSCRIPTION/resourceGroups/$RESOURCEGROUP/providers/Microsoft.Kubernetes/connectedClusters/$CLUSTERNAME"
EXTENSION_NAME="${EXTENSION_NAME:-osm}"
API_VERSION="${API_VERSION:-2020-07-01-preview}"

az account set --subscription="$SUBSCRIPTION"

# disable the osm extension
az rest \
   --method DELETE \
   --uri "https://management.azure.com/$RESOURCEID/providers/Microsoft.KubernetesConfiguration/extensions/$EXTENSION_NAME?api-Version=$API_VERSION" \
   --debug
