#!/bin/bash

source .env

RELEASE_NAMESPACE="${RELEASE_NAMESPACE:-arc-osm-system}"
EXTENSION_NAME="${EXTENSION_NAME:-osm}"
EXTENSION_TYPE="${EXTENSION_TYPE:-Microsoft.openservicemesh}"
EXTENSION_SETTINGS=$1
API_VERSION="${API_VERSION:-2020-07-01-preview}"

export RESOURCEID=subscriptions/$SUBSCRIPTION/resourceGroups/$RESOURCEGROUP/providers/Microsoft.Kubernetes/connectedClusters/$CLUSTERNAME

echo "Azure Resource ID: $RESOURCEID"

if [[ -z "$EXTENSION_SETTINGS" ]]; then
    EXTENSION_SETTINGS="osm_extension.json"
    jq -n \
        --arg tag "$EXTENSION_TAG" \
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


#if [[ -z "$EXTENSION_SETTINGS" ]]; then
#    az k8s-extension create --cluster-name $CLUSTERNAME --resource-group $RESOURCEGROUP --cluster-type connectedClusters --extension-type $EXTENSION_TYPE --scope cluster --release-train staging --name $EXTENSION_NAME --release-namespace $RELEASE_NAMESPACE --version $EXTENSION_TAG
#else 
#    az k8s-extension create --cluster-name $CLUSTERNAME --resource-group $RESOURCEGROUP --cluster-type connectedClusters --extension-type $EXTENSION_TYPE --scope cluster --release-train staging --name $EXTENSION_NAME --release-namespace $RELEASE_NAMESPACE --version $EXTENSION_TAG --configuration-protected-settings-file $EXTENSION_SETTINGS
#fi
