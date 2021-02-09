#!/bin/bash

source .env

RELEASE_NAMESPACE="${RELEASE_NAMESPACE:-arc-osm-system}"
EXTENSION_NAME="${EXTENSION_NAME:-osm}"
EXTENSION_TYPE="${EXTENSION_TYPE:-Microsoft.openservicemesh}"
EXTENSION_SETTINGS=$1
K8S_EXTENSION_VERSION="${K8S_EXTENSION_VERSION:-0.1PP.12}"

export RESOURCEID="subscriptions/$SUBSCRIPTION/resourceGroups/$RESOURCEGROUP/providers/Microsoft.Kubernetes/connectedClusters/$CLUSTERNAME"

echo "Azure Resource ID: $RESOURCEID"

if [[ -z "$EXTENSION_SETTINGS" ]]; then
    EXTENSION_SETTINGS="osm_extension.json"
    jq -n \
        --arg tag "$CHECKOUT_TAG" \
        --arg namespace "$RELEASE_NAMESPACE" \
        '{properties: {extensionType: "Microsoft.openservicemesh", autoUpgradeMinorVersion: "false", version: $tag, releaseTrain: "Staging", scope: { cluster: { releaseNamespace: $namespace } }, "configurationProtectedSettings": { "osm.OpenServiceMesh.controllerLogLevel": "debug", } } }' > osm_extension.json
fi

az account set --subscription="$SUBSCRIPTION" > /dev/null 2>&1

# enable the OSM Extension
az rest \
   --method PUT \
   --uri "https://management.azure.com/$RESOURCEID/providers/Microsoft.KubernetesConfiguration/extensions/$EXTENSION_NAME?api-Version=$API_VERSION" \
   --body @$EXTENSION_SETTINGS \
   --debug
