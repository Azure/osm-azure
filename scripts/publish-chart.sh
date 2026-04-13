#!/bin/bash
#
# publish-chart.sh — Package and push the osm-arc Helm chart to Azure Container Registry.
#
# This script is used for manual chart publishing (outside of CI/CD pipelines).
# It packages the Helm chart into a .tgz archive and pushes it to ACR as an
# OCI artifact using ORAS (OCI Registry as Storage).
#
# Workflow:
#   1. Package the Helm chart with the specified version tag
#   2. Push the .tgz as an OCI artifact to ACR using ORAS
#   3. Verify the push by listing repository manifests
#
# After publishing, you must also register the chart version with the Arc
# Registration API (see register-extension.sh) for it to be installable.
#
# Required environment variables (from .env):
#   SUBSCRIPTION - Azure subscription ID
#   REGISTRY     - ACR registry name (e.g., "myacr.azurecr.io")
#   CHARTNAME    - Chart name (e.g., "osm-arc")
#   IMAGETAG     - Version tag for the chart (e.g., "1.1.1-1")
#   IMAGEDIR     - Directory to write the packaged chart file
#   REPO         - Path to the chart source directory
#
# Prerequisites:
#   - helm and oras must be installed and on PATH
#   - Azure CLI must be logged in with ACR push permissions
#

# Load environment variables from .env file
source .env

# Enable Helm OCI support (required for OCI-based chart operations)
export HELM_EXPERIMENTAL_OCI=1

# Set the active Azure subscription
az account set --subscription="$SUBSCRIPTION"

# Package the Helm chart into a versioned .tgz archive.
# --version: Override the chart version with $IMAGETAG
# --destination: Write the package to $IMAGEDIR
./helm package \
       --version "$IMAGETAG" \
       --destination "$IMAGEDIR" \
       "$REPO" \
       --debug

# Push the packaged chart to ACR as an OCI artifact using ORAS.
# The chart is stored at: $REGISTRY/$CHARTNAME:$IMAGETAG
# The mime type "application/tar+gzip" identifies it as a Helm chart archive.
oras push \
     "$REGISTRY/$CHARTNAME:$IMAGETAG" \
     "./$CHARTNAME-$IMAGETAG.tgz:application/tar+gzip" \
     --debug

# Verify the push by listing all manifests for this chart in the ACR repository
az acr repository show-manifests \
   --name "$REGISTRY" \
   --repository "$REPO"
