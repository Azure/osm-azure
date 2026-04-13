#!/bin/bash
#
# connect-to-arc.sh — Connect an existing Kubernetes cluster to Azure Arc.
#
# This script onboards a Kubernetes cluster to Azure Arc, which installs Arc agents
# in the "azure-arc" namespace and creates a ConnectedCluster resource in Azure.
# After this step, the cluster can receive Arc extensions (including OSM).
#
# Required environment variables:
#   SUBSCRIPTION  - Azure subscription ID
#   CLUSTERNAME   - Name for the Arc-connected cluster resource in Azure
#   RESOURCEGROUP - Azure resource group to place the ConnectedCluster resource
#   REGION        - Azure region (e.g., eastus2euap, eastus, westeurope)
#
# Prerequisites:
#   - kubectl must be configured with access to the target cluster
#   - az connectedk8s extension must be installed (see install-connectedk8s.sh)
#

# Set the active Azure subscription
az account set --subscription="$SUBSCRIPTION" > /dev/null 2>&1

# Install Crypto package — needed temporarily to unblock the connectedk8s connect step
# due to a dependency issue in the Azure CLI extension.
python -m pip install install Crypto

# Connect the Kubernetes cluster to Azure Arc.
# This installs Arc agents on the cluster and registers it as a ConnectedCluster
# resource in the specified resource group and region.
az connectedk8s connect -n  "$CLUSTERNAME" -g "$RESOURCEGROUP" -l "$REGION" > /dev/null 2>&1
