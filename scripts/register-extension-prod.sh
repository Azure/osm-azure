#!/bin/bash
#
# register-extension-prod.sh — Register an osm-arc chart version for PRODUCTION multi-region rollout.
#
# This script registers a chart version with the Arc Registration API across all production
# release trains and regions. It implements the phased rollout strategy:
#
#   Phase 1 (Staging):       eastus2euap, eastus, westeurope — "staging" train only
#   Phase 2 (Canary):        eastus2euap — pilot, preview, stable trains
#   Phase 3 (Batch 1/Full):  19 production regions — pilot, preview, stable trains
#
# Each release train (pilot, preview, stable) can point to a DIFFERENT ACR registry/path,
# allowing independent chart promotion per train. The arrays REGISTRIES_PROD_CANARY and
# REGISTRIES_PROD_BATCH1 are indexed by position to match RELEASE_TRAINS_PROD:
#   index 0 = pilot, index 1 = preview, index 2 = stable
#
# Required environment variables:
#   ACCESS_TOKEN          - Bearer token for Arc API authentication
#   ARC_API_URL           - Base URL of the Arc Registration API
#   SUBSCRIPTION          - Azure subscription ID
#   VERSION               - Chart version to register
#   REGISTRY_STAGING      - ACR path for the staging chart
#   REGISTRIES_PROD_CANARY  - Space-separated array of ACR paths for canary (one per release train)
#   REGISTRIES_PROD_BATCH1  - Space-separated array of ACR paths for batch1 (one per release train)
#
# Optional environment variables (all have sensible defaults):
#   REGION_STAGING, REGIONS_CANARY_LIST, REGIONS_BATCH1_LIST,
#   RELEASE_TRAINS_LIST, PACKAGE_CONFIG_NAME, API_VERSION, METHOD
#

# --- Region definitions ---

# Staging regions: used for internal testing before customer-facing deployment
REGION_STAGING=${REGION_STAGING:-'"eastus2euap", "eastus", "westeurope"'}
RELEASE_TRAIN_STAGING=${RELEASE_TRAIN:-staging}

# Canary region: single region for early production validation (limited blast radius)
REGIONS_CANARY_PROD=${REGIONS_CANARY_LIST:-'"eastus2euap"'}

# Batch 1 regions: full production rollout across all supported Azure regions
REGIONS_BATCH1_PROD=${REGIONS_BATCH1_LIST:-'"eastus","westeurope","australiaeast","eastus2","francecentral","northeurope","southcentralus","southeastasia","uksouth","westcentralus","westus2","centralus","northcentralus","westus","koreacentral","japaneast","eastasia","westus3","usgovvirginia"'}

# Production release trains: pilot (early adopters), preview (public preview), stable (GA)
RELEASE_TRAINS_PROD=${RELEASE_TRAINS_LIST:-"pilot preview stable"}

PACKAGE_CONFIG_NAME="${PACKAGE_CONFIG_NAME:-microsoft.openservicemesh20220214}"
API_VERSION="${API_VERSION:-2021-05-01}"
METHOD="${METHOD:-put}"

# --- Build JSON request body ---

# Start with the staging artifact endpoint (Phase 1).
# This is always included and uses a separate staging ACR registry.
cat <<EOF > "request.json"
{
    "artifactEndpoints": [
        {
            "Regions": [
                $REGION_STAGING
            ],
            "Releasetrains": [
                "$RELEASE_TRAIN_STAGING"
            ],
            "FullPathToHelmChart": "$REGISTRY_STAGING",
            "ExtensionUpdateFrequencyInMinutes": 60,
            "IsCustomerHidden": false,
            "ReadyforRollout": true,
            "RollbackVersion": null,
            "PackageConfigName": "$PACKAGE_CONFIG_NAME"
        },
EOF

# Convert space-separated strings to bash arrays for indexed access.
# Each array is indexed by release train position: [0]=pilot, [1]=preview, [2]=stable
RELEASE_TRAINS_PROD=($RELEASE_TRAINS_PROD)
REGISTRIES_PROD_CANARY=($REGISTRIES_PROD_CANARY)
REGISTRIES_PROD_BATCH1=($REGISTRIES_PROD_BATCH1)

# Loop over each release train and append two artifact endpoints:
#   1. Canary endpoint (Phase 2): eastus2euap only, for limited blast radius validation
#   2. Batch 1 endpoint (Phase 3): all 19 production regions
# Each train gets its own ACR registry path from the corresponding arrays.
for i in ${!RELEASE_TRAINS_PROD[@]}
do
cat <<EOF >> "request.json"
        {
            "Regions": [
                $REGIONS_CANARY_PROD
            ],
            "Releasetrains": [
                "${RELEASE_TRAINS_PROD[$i]}"
            ],
            "FullPathToHelmChart": "${REGISTRIES_PROD_CANARY[$i]}",
            "ExtensionUpdateFrequencyInMinutes": 60,
            "IsCustomerHidden": false,
            "ReadyforRollout": true,
            "RollbackVersion": null,
            "PackageConfigName": "$PACKAGE_CONFIG_NAME"
        },
        {
            "Regions": [
                $REGIONS_BATCH1_PROD
            ],
            "Releasetrains": [
                "${RELEASE_TRAINS_PROD[$i]}"
            ],
            "FullPathToHelmChart": "${REGISTRIES_PROD_BATCH1[$i]}",
            "ExtensionUpdateFrequencyInMinutes": 60,
            "IsCustomerHidden": false,
            "ReadyforRollout": true,
            "RollbackVersion": null,
            "PackageConfigName": "$PACKAGE_CONFIG_NAME"
        },
EOF
done

# Remove the trailing comma from the last JSON entry to make valid JSON.
# The heredoc loop always appends a trailing comma, so we strip the last character.
sed -i '$ s/.$//' request.json

# Close the JSON array and object
cat <<EOF >> "request.json"
    ]
}
EOF

# Pretty-print the request body for logging/debugging
cat request.json | jq

# Send the registration request to the Arc Registration API.
# This creates or updates the full set of artifact endpoints for this version,
# covering all release trains and regions in a single API call.
az rest --method $METHOD --headers "{\"Authorization\": \"Bearer $ACCESS_TOKEN\", \"Content-Type\": \"application/json\"}" --body @request.json --uri $ARC_API_URL/subscriptions/$SUBSCRIPTION/extensionTypeRegistrations/microsoft.openservicemesh/versions/$VERSION?api-version=$API_VERSION
