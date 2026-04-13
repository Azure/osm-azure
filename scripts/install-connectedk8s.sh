#!/bin/bash
#
# install-connectedk8s.sh — Install or update the Azure CLI "connectedk8s" extension.
#
# The connectedk8s extension provides the `az connectedk8s` commands used to
# connect Kubernetes clusters to Azure Arc. This script does a clean reinstall
# by removing any existing version first, ensuring the latest version is used.
#
# Required environment variables:
#   SUBSCRIPTION - Azure subscription ID
#

# Set the active Azure subscription
az account set --subscription="$SUBSCRIPTION" > /dev/null 2>&1

# Remove existing connectedk8s extension (ignore errors if not installed)
az extension remove --name connectedk8s

# Install the latest version of the connectedk8s extension
az extension add --name connectedk8s

# Print Azure CLI version for logging/debugging
az -v
