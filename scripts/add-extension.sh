#!/bin/bash

source .env

RELEASE_NAMESPACE="${RELEASE_NAMESPACE:-arc-osm-system}"
EXTENSION_NAME="${EXTENSION_NAME:-osm}"
API_VERSION="${API_VERSION:-2020-07-01-preview}"
EXTENSION_SETTINGS=$1

export RESOURCEID=subscriptions/$SUBSCRIPTION/resourceGroups/$RESOURCEGROUP/providers/Microsoft.Kubernetes/connectedClusters/$CLUSTERNAME

echo "Azure Resource ID: $RESOURCEID"

if [[ -z "$EXTENSION_SETTINGS" ]]; then
    EXTENSION_SETTINGS="osm_extension.json"
    jq -n \
        --arg tag "$CHECKOUT_TAG" \
        --arg namespace "$RELEASE_NAMESPACE" \
        '{properties: {extensionType: "Microsoft.openservicemesh", autoUpgradeMinorVersion: "false", version: $tag, releaseTrain: "Staging", scope: { cluster: { releaseNamespace: $namespace } }, "osm.OpenServiceMesh.fluentBit.logLevel": "debug" } }' > osm_extension.json
fi

az account set --subscription="$SUBSCRIPTION" > /dev/null 2>&1

# confirm
helm ls --all --all-namespaces

az resource tag \
   --tags logAnalyticsWorkspaceResourceId="/$RESOURCEID" \
   --ids "/$RESOURCEID" > /dev/null 2>&1

# get extensions enabled on this cluster
az rest \
   --method GET \
   --uri "https://management.azure.com/$RESOURCEID/providers/Microsoft.KubernetesConfiguration/extensions?api-Version=$API_VERSION"

# enable the osm extension
az rest \
   --method PUT \
   --uri "https://management.azure.com/$RESOURCEID/providers/Microsoft.KubernetesConfiguration/extensions/$EXTENSION_NAME?api-Version=$API_VERSION" \
   --body @$EXTENSION_SETTINGS \
   --debug
