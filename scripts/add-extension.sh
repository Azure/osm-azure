#!/bin/bash
set -x
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
      --version $EXTENSION_TAG \
      --auto-upgrade-minor-version false \
      --config Azure.enableMonitoring=true \
      --verbose
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
      --auto-upgrade-minor-version false \
      --config Azure.enableMonitoring=true \
      --configuration-settings-file $EXTENSION_SETTINGS \
      --verbose
fi

if [[ $? -ne 0 ]]; then
   echo "Failed to add OSM extension to cluster $CLUSTERNAME in resource group $RESOURCEGROUP"
   kubectl events -n $RELEASE_NAMESPACE
   exit 1
else
   echo "Successfully added OSM extension to cluster $CLUSTERNAME in resource group $RESOURCEGROUP"
fi
