#!/bin/bash
#
# install-k8s-extension.sh — Install or update the Azure CLI "k8s-extension" extension.
#
# The k8s-extension CLI extension provides the `az k8s-extension` commands used to
# create, update, and manage Arc extensions on connected clusters. This script does
# a clean reinstall by removing any existing version first.
#
# Required environment variables:
#   SUBSCRIPTION - Azure subscription ID
#

# Set the active Azure subscription
az account set --subscription="$SUBSCRIPTION" > /dev/null 2>&1

# Remove existing k8s-extension (ignore errors if not installed)
az extension remove --name k8s-extension

# Install the latest version of the k8s-extension CLI extension
az extension add --name k8s-extension

# Print Azure CLI version for logging/debugging
az -v
