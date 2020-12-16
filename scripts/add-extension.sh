#!/bin/bash

source .env
RELEASE_NAMESPACE="${RELEASE_NAMESPACE:-arc-osm-system}"

export RESOURCEID=subscriptions/$SUBSCRIPTION/resourceGroups/$RESOURCEGROUP/providers/Microsoft.Kubernetes/connectedClusters/$CLUSTERNAME
export HELM_EXPERIMENTAL_OCI=1

echo $RESOURCEID

jq -n \
    --arg tag "$CHECKOUT_TAG" \
    --arg namespace "$RELEASE_NAMESPACE" \
    '{properties: {extensionType: "Microsoft.openservicemesh", autoUpgradeMinorVersion: "false", version: $tag, releaseTrain: "Staging", scope: { cluster: { releaseNamespace: $namespace } } } }' > osm_extension.json

az account set --subscription=$SUBSCRIPTION > /dev/null 2>&1

az extension remove --name connectedk8s

az extension add --source https://shasbextensions.blob.core.windows.net/extensions/connectedk8s-0.3.1-py2.py3-none-any.whl -y

az -v 

# enable connected cluster
az connectedK8s connect -n  $CLUSTERNAME -g $RESOURCEGROUP -l $REGION > /dev/null 2>&1

# confirm
helm ls --all --all-namespaces

az resource tag --tags logAnalyticsWorkspaceResourceId=/$RESOURCEID --ids /$RESOURCEID > /dev/null 2>&1

# get extensions enabled on this cluster
az rest --method GET --uri "https://management.azure.com/$RESOURCEID/providers/Microsoft.KubernetesConfiguration/extensions?api-Version=2020-07-01-preview"

# enable the osm extension
az rest --method PUT --uri "https://management.azure.com/$RESOURCEID/providers/Microsoft.KubernetesConfiguration/extensions/osm?api-Version=2020-07-01-preview" --body @osm_extension.json --debug
