#!/bin/bash

source .env

RELEASE_NAMESPACE="${RELEASE_NAMESPACE:-arc-osm-system}"
EXTENSION_NAME="${EXTENSION_NAME:-osm}"
EXTENSION_SETTINGS=$1
RELEASE_TRAIN="${RELEASE_TRAIN:-staging}"

az account set --subscription="$SUBSCRIPTION" > /dev/null 2>&1

# confirm
helm ls --all --all-namespaces

if [[ -z "$EXTENSION_SETTINGS" ]]; then
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
