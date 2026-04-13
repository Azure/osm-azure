#!/bin/bash
#
# register-extension.sh — Register an osm-arc chart version with the Arc Registration API (staging).
#
# This script registers a specific chart version with the Azure Arc Extension Registration API,
# making it discoverable by the Arc Extension RP. When a user runs `az k8s-extension create`,
# the RP looks up registered versions to find the correct ACR path for the requested
# version + release train + region combination.
#
# This script is used for STAGING registrations only. For production multi-region
# rollout, see register-extension-prod.sh.
#
# Workflow:
#   1. Construct a JSON request body with artifact endpoint metadata
#   2. Send a PUT request to the Arc Registration API
#
# Required environment variables:
#   ACCESS_TOKEN   - Bearer token for Arc API authentication (from `az account get-access-token`)
#   ARC_API_URL    - Base URL of the Arc Registration API
#   SUBSCRIPTION   - Azure subscription ID
#   VERSION        - Chart version to register (e.g., "1.1.1-1-pr")
#   REGISTRY_PATH  - Full ACR path to the Helm chart (e.g., "myacr.azurecr.io/oss/openservicemesh/osm-arc")
#
# Optional environment variables:
#   REGION              - Comma-separated quoted region list (default: eastus2euap, eastus, westeurope)
#   RELEASE_TRAINS      - Release train name (default: staging)
#   PACKAGE_CONFIG_NAME - Package config identifier (default: microsoft.openservicemesh20220214)
#   API_VERSION         - Arc Registration API version (default: 2021-05-01)
#   METHOD              - HTTP method (default: put)
#

# Default regions for staging: eastus2euap (canary), plus eastus and westeurope
REGION=${REGION:-'"eastus2euap", "eastus", "westeurope"'}
RELEASE_TRAINS="${RELEASE_TRAINS:-staging}"
PACKAGE_CONFIG_NAME="${PACKAGE_CONFIG_NAME:-microsoft.openservicemesh20220214}"
API_VERSION="${API_VERSION:-2021-05-01}"
METHOD="${METHOD:-put}"

# Build the JSON request body with a single artifact endpoint.
# artifactEndpoints tells the Arc RP:
#   - Which regions this chart version is available in
#   - Which release trains it belongs to
#   - Where to find the Helm chart in ACR
#   - How frequently to check for updates (60 minutes)
#   - Whether it's visible to customers and ready for rollout
cat <<EOF > "request.json"
{
  "artifactEndpoints": [
    {
      "Regions": [
          $REGION
      ],
      "Releasetrains": [
          "$RELEASE_TRAINS"
      ],
      "FullPathToHelmChart": "$REGISTRY_PATH",
      "ExtensionUpdateFrequencyInMinutes": 60,
      "IsCustomerHidden": false,
      "ReadyforRollout": true,
      "RollbackVersion": null,
      "PackageConfigName": "$PACKAGE_CONFIG_NAME"
    }
  ]
}
EOF

# Send the registration request to the Arc Registration API.
# URI format: {ARC_API_URL}/subscriptions/{sub}/extensionTypeRegistrations/microsoft.openservicemesh/versions/{version}
# This creates or updates the version registration, making it available for installation.
az rest --method $METHOD --headers "{\"Authorization\": \"Bearer $ACCESS_TOKEN\", \"Content-Type\": \"application/json\"}" --body @request.json --uri $ARC_API_URL/subscriptions/$SUBSCRIPTION/extensionTypeRegistrations/microsoft.openservicemesh/versions/$VERSION?api-version=$API_VERSION
