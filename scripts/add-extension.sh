#!/bin/bash

source .env
RELEASE_NAMESPACE="${RELEASE_NAMESPACE:-arc-osm-system}"
EXTENSION_NAME="${EXTENSION_NAME:-osm}"
API_VERSION="${API_VERSION:-2020-07-01-preview}"
CONNECTEDK8S_VERSION="${CONNECTEDK8S_VERSION:-0.3.5}"

export RESOURCEID=subscriptions/$SUBSCRIPTION/resourceGroups/$RESOURCEGROUP/providers/Microsoft.Kubernetes/connectedClusters/$CLUSTERNAME

echo $RESOURCEID

jq -n \
    --arg tag "$CHECKOUT_TAG" \
    --arg namespace "$RELEASE_NAMESPACE" \
    '{properties: {extensionType: "Microsoft.openservicemesh", autoUpgradeMinorVersion: "false", version: $tag, releaseTrain: "Staging", scope: { cluster: { releaseNamespace: $namespace } } } }' > osm_extension.json

az account set --subscription=$SUBSCRIPTION > /dev/null 2>&1

az extension remove --name connectedk8s

az extension add --source https://shasbextensions.blob.core.windows.net/extensions/connectedk8s-$CONNECTEDK8S_VERSION-py2.py3-none-any.whl -y

az -v 

# enable connected cluster
az connectedK8s connect -n  $CLUSTERNAME -g $RESOURCEGROUP -l $REGION > /dev/null 2>&1

# confirm
helm ls --all --all-namespaces

az resource tag --tags logAnalyticsWorkspaceResourceId=/$RESOURCEID --ids /$RESOURCEID > /dev/null 2>&1

# get extensions enabled on this cluster
az rest --method GET --uri "https://management.azure.com/$RESOURCEID/providers/Microsoft.KubernetesConfiguration/extensions?api-Version=$API_VERSION"

# enable the osm extension
az rest --method PUT --uri "https://management.azure.com/$RESOURCEID/providers/Microsoft.KubernetesConfiguration/extensions/$EXTENSION_NAME?api-Version=$API_VERSION" --body @osm_extension.json --debug
